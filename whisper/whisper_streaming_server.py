#!/usr/bin/env python3
"""
GlobeCast Whisper Streaming Server
Real-time Speech-to-Text and Translation for Flutter app
"""

import asyncio
import websockets
import json
import logging
import argparse
import numpy as np
from io import BytesIO
import threading
import queue
import time
from dataclasses import dataclass
from typing import Optional, Dict, Any

# Whisper Streaming imports
try:
    from faster_whisper import WhisperModel
    BACKEND_AVAILABLE = True
except ImportError:
    print("faster-whisper not installed. Install with: pip install faster-whisper")
    BACKEND_AVAILABLE = False

@dataclass
class TranscriptionResult:
    """Result from Whisper transcription"""
    text: str
    language: str
    confidence: float
    is_final: bool
    timestamp: float
    translation: Optional[str] = None

class WhisperStreamingProcessor:
    """Real-time Whisper processing with streaming capabilities"""

    def __init__(self,
                 model_size: str = "large-v3",
                 language: str = "auto",
                 task: str = "transcribe",
                 device: str = "auto"):

        if not BACKEND_AVAILABLE:
            raise RuntimeError("faster-whisper not available")

        self.model_size = model_size
        self.language = language
        self.task = task
        self.device = device

        # Initialize Whisper model
        print(f"Loading Whisper model: {model_size}")
        self.model = WhisperModel(
            model_size,
            device=device,
            compute_type="float16" if device == "cuda" else "int8"
        )

        # Audio processing parameters
        self.sample_rate = 16000
        self.chunk_duration = 1.0  # 1 second chunks
        self.buffer_duration = 10.0  # 10 second buffer

        # Audio buffer
        self.audio_buffer = np.array([], dtype=np.float32)
        self.last_processed_time = 0
        self.processing_lock = threading.Lock()

        print(f"Whisper processor initialized - Language: {language}, Task: {task}")

    def add_audio_chunk(self, audio_data: bytes) -> None:
        """Add audio chunk to processing buffer"""
        try:
            # Convert bytes to numpy array
            audio_array = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32) / 32768.0

            with self.processing_lock:
                self.audio_buffer = np.concatenate([self.audio_buffer, audio_array])

                # Trim buffer if too long
                max_samples = int(self.buffer_duration * self.sample_rate)
                if len(self.audio_buffer) > max_samples:
                    self.audio_buffer = self.audio_buffer[-max_samples:]

        except Exception as e:
            logging.error(f"Error adding audio chunk: {e}")

    def process_audio(self) -> Optional[TranscriptionResult]:
        """Process current audio buffer and return transcription"""
        try:
            with self.processing_lock:
                if len(self.audio_buffer) < int(self.chunk_duration * self.sample_rate):
                    return None

                # Get audio to process
                audio_to_process = self.audio_buffer.copy()

            # Transcribe with Whisper
            segments, info = self.model.transcribe(
                audio_to_process,
                language=None if self.language == "auto" else self.language,
                task=self.task,
                vad_filter=True,
                vad_parameters=dict(min_silence_duration_ms=500),
                word_timestamps=True
            )

            # Combine segments
            full_text = ""
            confidence_scores = []

            for segment in segments:
                full_text += segment.text + " "
                confidence_scores.append(segment.avg_logprob)

            if not full_text.strip():
                return None

            # Calculate average confidence
            avg_confidence = np.mean(confidence_scores) if confidence_scores else 0.0
            confidence = float(np.exp(avg_confidence))  # Convert log prob to probability

            # Determine if translation occurred
            translation = None
            if self.task == "translate" and info.language != "en":
                translation = full_text.strip()

            result = TranscriptionResult(
                text=full_text.strip(),
                language=info.language,
                confidence=confidence,
                is_final=True,
                timestamp=time.time(),
                translation=translation
            )

            return result

        except Exception as e:
            logging.error(f"Error processing audio: {e}")
            return None

class GlobeCastWhisperServer:
    """WebSocket server for GlobeCast Flutter app"""

    def __init__(self, host: str = "localhost", port: int = 8765):
        self.host = host
        self.port = port
        self.processors: Dict[str, WhisperStreamingProcessor] = {}

    async def handle_client(self, websocket, path):
        """Handle WebSocket client connection"""
        client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
        logging.info(f"Client connected: {client_id}")

        try:
            async for message in websocket:
                await self.process_message(websocket, client_id, message)

        except websockets.exceptions.ConnectionClosed:
            logging.info(f"Client disconnected: {client_id}")
        except Exception as e:
            logging.error(f"Error handling client {client_id}: {e}")
        finally:
            # Cleanup
            if client_id in self.processors:
                del self.processors[client_id]

    async def process_message(self, websocket, client_id: str, message):
        """Process incoming message from Flutter app"""
        try:
            if isinstance(message, bytes):
                # Audio data
                if client_id in self.processors:
                    self.processors[client_id].add_audio_chunk(message)

                    # Process and send result
                    result = self.processors[client_id].process_audio()
                    if result:
                        response = {
                            "type": "transcription",
                            "data": {
                                "text": result.text,
                                "language": result.language,
                                "confidence": result.confidence,
                                "is_final": result.is_final,
                                "timestamp": result.timestamp,
                                "translation": result.translation
                            }
                        }
                        await websocket.send(json.dumps(response))
            else:
                # JSON command
                data = json.loads(message)
                await self.handle_command(websocket, client_id, data)

        except Exception as e:
            logging.error(f"Error processing message: {e}")
            error_response = {
                "type": "error",
                "message": str(e)
            }
            await websocket.send(json.dumps(error_response))

    async def handle_command(self, websocket, client_id: str, data: Dict[str, Any]):
        """Handle JSON commands from Flutter"""
        command = data.get("command")

        if command == "start_transcription":
            # Initialize processor for this client
            language = data.get("language", "auto")
            task = data.get("task", "transcribe")  # transcribe or translate
            model_size = data.get("model", "large-v3")

            try:
                self.processors[client_id] = WhisperStreamingProcessor(
                    model_size=model_size,
                    language=language,
                    task=task
                )

                response = {
                    "type": "status",
                    "message": f"Transcription started - Language: {language}, Task: {task}"
                }
                await websocket.send(json.dumps(response))

            except Exception as e:
                error_response = {
                    "type": "error",
                    "message": f"Failed to start transcription: {e}"
                }
                await websocket.send(json.dumps(error_response))

        elif command == "stop_transcription":
            if client_id in self.processors:
                del self.processors[client_id]

            response = {
                "type": "status",
                "message": "Transcription stopped"
            }
            await websocket.send(json.dumps(response))

        elif command == "ping":
            response = {
                "type": "pong",
                "timestamp": time.time()
            }
            await websocket.send(json.dumps(response))

    async def start_server(self):
        """Start the WebSocket server"""
        logging.info(f"Starting GlobeCast Whisper Server on {self.host}:{self.port}")

        async with websockets.serve(self.handle_client, self.host, self.port):
            logging.info("Server started successfully!")
            await asyncio.Future()  # Run forever

def main():
    parser = argparse.ArgumentParser(description="GlobeCast Whisper Streaming Server")
    parser.add_argument("--host", default="localhost", help="Server host")
    parser.add_argument("--port", type=int, default=8765, help="Server port")
    parser.add_argument("--log-level", default="INFO", help="Logging level")

    args = parser.parse_args()

    # Setup logging
    logging.basicConfig(
        level=getattr(logging, args.log_level.upper()),
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

    # Check if backend is available
    if not BACKEND_AVAILABLE:
        logging.error("faster-whisper not available. Please install requirements.")
        return

    # Start server
    server = GlobeCastWhisperServer(host=args.host, port=args.port)
    asyncio.run(server.start_server())

if __name__ == "__main__":
    main()