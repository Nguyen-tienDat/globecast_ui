#!/usr/bin/env python3
"""
GlobeCast Whisper Streaming Server - Final Working Version
"""

import asyncio
import websockets
import json
import logging
import tempfile
import os
import time
from dataclasses import dataclass
from typing import Optional, Dict, Any


# Whisper imports
try:
    from faster_whisper import WhisperModel
    BACKEND_AVAILABLE = True
    print("✅ faster-whisper available")
except ImportError:
    print("❌ faster-whisper not installed. Install with: pip install faster-whisper")
    BACKEND_AVAILABLE = False

@dataclass
class TranscriptionResult:
    text: str
    language: str
    confidence: float
    is_final: bool
    timestamp: float
    translation: Optional[str] = None

# Global variables
logger = logging.getLogger(__name__)
clients = set()
whisper_model = None

def initialize_whisper(model_name="base"):
    """Initialize Whisper model"""
    global whisper_model

    if not BACKEND_AVAILABLE:
        logger.error("faster-whisper not available")
        return False

    try:
        logger.info(f"Loading Whisper model: {model_name}")
        whisper_model = WhisperModel(model_name, device="cpu", compute_type="int8")
        logger.info("✅ Model loaded successfully")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to initialize Whisper: {e}")
        return False

async def handle_client(websocket):
    """Handle WebSocket client connection - SIMPLIFIED VERSION"""
    client_address = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
    logger.info(f"🔗 Client connected: {client_address}")
    clients.add(websocket)

    try:
        # Send welcome message
        welcome_msg = {
            "type": "connection",
            "status": "connected",
            "message": "Connected to GlobeCast Whisper Server",
            "model": "base" if whisper_model else "unavailable",
            "timestamp": time.time()
        }
        await websocket.send(json.dumps(welcome_msg))

        # Listen for messages
        async for message in websocket:
            await process_message(websocket, message)

    except websockets.exceptions.ConnectionClosed:
        logger.info(f"📴 Client disconnected: {client_address}")
    except Exception as e:
        logger.error(f"❌ Error handling client {client_address}: {e}")
        import traceback
        traceback.print_exc()
    finally:
        clients.discard(websocket)

async def process_message(websocket, message):
    """Process incoming message from client"""
    try:
        # Handle JSON messages
        if isinstance(message, str):
            try:
                data = json.loads(message)
                await handle_json_message(websocket, data)
                return
            except json.JSONDecodeError:
                logger.warning("Invalid JSON received")
                return

        # Handle binary data (audio)
        if isinstance(message, bytes):
            await handle_audio_data(websocket, message)

    except Exception as e:
        logger.error(f"Error processing message: {e}")
        await send_error(websocket, f"Error: {str(e)}")

async def handle_json_message(websocket, data):
    """Handle JSON text messages"""
    message_type = data.get("type", "unknown")
    logger.info(f"📨 Received JSON message: {message_type}")

    if message_type == "test":
        response = {
            "type": "test_response",
            "message": "✅ Test message received successfully!",
            "echo": data.get("message", ""),
            "server_status": "running",
            "model_status": "loaded" if whisper_model else "not_loaded",
            "timestamp": time.time()
        }
        await websocket.send(json.dumps(response))
        logger.info("📤 Test response sent")

    elif message_type == "ping":
        response = {"type": "pong", "timestamp": time.time()}
        await websocket.send(json.dumps(response))

    else:
        logger.warning(f"❓ Unknown message type: {message_type}")

async def handle_audio_data(websocket, audio_data):
    """Handle audio data and perform transcription"""
    logger.info(f"🎵 Processing audio data: {len(audio_data)} bytes")

    if not whisper_model:
        await send_error(websocket, "Whisper model not available")
        return

    try:
        # Save audio to temp file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
            temp_file.write(audio_data)
            temp_path = temp_file.name

        # Transcribe audio
        result = await transcribe_audio(temp_path)

        # Send result
        if result:
            response = {
                "type": "transcription",
                "text": result.text,
                "language": result.language,
                "confidence": result.confidence,
                "is_final": result.is_final,
                "timestamp": result.timestamp
            }

            if result.translation:
                response["translation"] = result.translation

            await websocket.send(json.dumps(response))
            logger.info(f"📝 Transcription sent: {result.text[:50]}...")
        else:
            await send_error(websocket, "No transcription generated")

        # Cleanup
        try:
            os.unlink(temp_path)
        except:
            pass

    except Exception as e:
        logger.error(f"❌ Error processing audio: {e}")
        await send_error(websocket, f"Audio processing error: {str(e)}")

async def transcribe_audio(audio_path):
    """Transcribe audio file using Whisper"""
    try:
        # Run transcription in thread pool
        loop = asyncio.get_event_loop()
        segments, info = await loop.run_in_executor(
            None,
            lambda: whisper_model.transcribe(audio_path, task="transcribe")
        )

        # Combine segments
        full_text = ""
        confidence_scores = []

        for segment in segments:
            full_text += segment.text + " "
            confidence_scores.append(getattr(segment, 'avg_logprob', 0))

        if not full_text.strip():
            return None

        avg_confidence = sum(confidence_scores) / len(confidence_scores) if confidence_scores else 0

        return TranscriptionResult(
            text=full_text.strip(),
            language=info.language,
            confidence=float(avg_confidence),
            is_final=True,
            timestamp=time.time()
        )

    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        return None

async def send_error(websocket, error_message):
    """Send error message to client"""
    error_response = {
        "type": "error",
        "message": error_message,
        "timestamp": time.time()
    }
    try:
        await websocket.send(json.dumps(error_response))
    except:
        pass

async def start_server(host="localhost", port=8766):
    """Start the WebSocket server"""
    logger.info(f"🚀 Starting GlobeCast Whisper Server on {host}:{port}")

    try:
        # Start WebSocket server - SIMPLIFIED without path argument
        server = await websockets.serve(
            handle_client,  # No path argument needed
            host,
            port,
            ping_interval=20,
            ping_timeout=10,
            max_size=10 * 1024 * 1024
        )

        logger.info("✅ Server started successfully!")
        logger.info("⏳ Waiting for connections...")

        # Keep server running
        await server.wait_closed()

    except Exception as e:
        logger.error(f"❌ Server error: {e}")
        raise

def main():
    """Main function"""
    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

    # Initialize Whisper
    if not initialize_whisper("base"):
        print("❌ Failed to initialize Whisper model")
        return

    # Start server
    try:
        asyncio.run(start_server())
    except KeyboardInterrupt:
        print("\n👋 Shutting down server...")
    except Exception as e:
        print(f"❌ Server failed to start: {e}")

if __name__ == "__main__":
    main()