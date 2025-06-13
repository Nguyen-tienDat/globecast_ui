#!/usr/bin/env python3
"""
GlobeCast Whisper Streaming Server - Improved Version
Real-time Speech-to-Text + Translation with Enhanced Performance
"""

import asyncio
import websockets
import json
import logging
import tempfile
import os
import time
import gc
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any, List
from concurrent.futures import ThreadPoolExecutor

# Core imports
try:
    from faster_whisper import WhisperModel
    WHISPER_AVAILABLE = True
    print("✅ faster-whisper available")
except ImportError:
    print("❌ faster-whisper not installed. Install with: pip install faster-whisper")
    WHISPER_AVAILABLE = False

try:
    import requests
    REQUESTS_AVAILABLE = True
    print("✅ requests available for translation")
except ImportError:
    print("❌ requests not installed. Install with: pip install requests")
    REQUESTS_AVAILABLE = False

# Audio processing
try:
    import soundfile as sf
    import numpy as np
    AUDIO_PROCESSING_AVAILABLE = True
    print("✅ audio processing libraries available")
except ImportError:
    print("⚠️ soundfile/numpy not available. Audio conversion may be limited")
    AUDIO_PROCESSING_AVAILABLE = False

@dataclass
class TranscriptionResult:
    """Enhanced transcription result with more metadata"""
    text: str
    language: str
    confidence: float
    is_final: bool
    timestamp: float
    duration: Optional[float] = None
    translation: Optional[str] = None
    translation_lang: Optional[str] = None
    translation_confidence: Optional[float] = None
    detected_language_confidence: Optional[float] = None

@dataclass
class ServerStats:
    """Server performance statistics"""
    total_requests: int = 0
    successful_transcriptions: int = 0
    successful_translations: int = 0
    total_audio_duration: float = 0.0
    average_processing_time: float = 0.0
    active_connections: int = 0

# Global variables
logger = logging.getLogger(__name__)
clients = set()
whisper_model = None
server_stats = ServerStats()
thread_pool = ThreadPoolExecutor(max_workers=4)

# Enhanced language support
SUPPORTED_LANGUAGES = {
    "en": {"name": "English", "flag": "🇺🇸"},
    "vi": {"name": "Tiếng Việt", "flag": "🇻🇳"},
    "zh": {"name": "中文", "flag": "🇨🇳"},
    "ja": {"name": "日本語", "flag": "🇯🇵"},
    "ko": {"name": "한국어", "flag": "🇰🇷"},
    "th": {"name": "ไทย", "flag": "🇹🇭"},
    "fr": {"name": "Français", "flag": "🇫🇷"},
    "de": {"name": "Deutsch", "flag": "🇩🇪"},
    "es": {"name": "Español", "flag": "🇪🇸"},
    "ru": {"name": "Русский", "flag": "🇷🇺"},
    "ar": {"name": "العربية", "flag": "🇸🇦"},
    "hi": {"name": "हिन्दी", "flag": "🇮🇳"},
    "pt": {"name": "Português", "flag": "🇧🇷"},
    "it": {"name": "Italiano", "flag": "🇮🇹"},
    "nl": {"name": "Nederlands", "flag": "🇳🇱"}
}

def initialize_whisper(model_name="base"):
    """Initialize Whisper model with better error handling"""
    global whisper_model

    if not WHISPER_AVAILABLE:
        logger.error("faster-whisper not available")
        return False

    try:
        logger.info(f"Loading Whisper model: {model_name}")

        # Try different compute types based on system
        compute_types = ["int8", "float16", "float32"]

        for compute_type in compute_types:
            try:
                whisper_model = WhisperModel(
                    model_name,
                    device="cpu",
                    compute_type=compute_type,
                    num_workers=2
                )
                logger.info(f"✅ Whisper model loaded with {compute_type}")
                return True
            except Exception as e:
                logger.warning(f"Failed with {compute_type}: {e}")
                continue

        logger.error("Failed to load model with any compute type")
        return False

    except Exception as e:
        logger.error(f"❌ Failed to initialize Whisper: {e}")
        return False

async def translate_text_enhanced(text, target_lang="en", source_lang="auto", timeout=15):
    """Enhanced translation with better error handling and retries"""
    if not REQUESTS_AVAILABLE or not text or not text.strip():
        return None, None, 0.0

    clean_text = text.strip()
    if len(clean_text) > 4000:  # Limit for stability
        clean_text = clean_text[:4000] + "..."

    # Skip translation if source and target are the same
    if source_lang == target_lang:
        return clean_text, target_lang, 1.0

    max_retries = 3
    for attempt in range(max_retries):
        try:
            url = "https://translate.googleapis.com/translate_a/single"
            params = {
                'client': 'gtx',
                'sl': source_lang,
                'tl': target_lang,
                'dt': 't',
                'q': clean_text
            }

            # Use thread pool for non-blocking HTTP request
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                thread_pool,
                lambda: requests.get(url, params=params, timeout=timeout)
            )

            if response.status_code == 200:
                result = response.json()
                if result and len(result) > 0 and result[0]:
                    translated_parts = []
                    for part in result[0]:
                        if part and len(part) > 0 and isinstance(part[0], str):
                            translated_parts.append(part[0])

                    if translated_parts:
                        translated_text = ''.join(translated_parts)
                        detected_lang = result[2] if len(result) > 2 and result[2] else source_lang
                        confidence = 0.95 - (attempt * 0.1)  # Reduce confidence with retries

                        logger.info(f"🌍 Translation successful (attempt {attempt + 1}): {clean_text[:30]}... → {translated_text[:30]}...")
                        return translated_text, detected_lang, confidence

            logger.warning(f"Translation API returned status {response.status_code} (attempt {attempt + 1})")

        except asyncio.TimeoutError:
            logger.warning(f"Translation timeout (attempt {attempt + 1})")
        except Exception as e:
            logger.warning(f"Translation attempt {attempt + 1} failed: {e}")

        # Wait before retry
        if attempt < max_retries - 1:
            await asyncio.sleep(1)

    logger.error("All translation attempts failed")
    return None, None, 0.0

async def handle_client(websocket, path):
    """Enhanced client handler with better connection management"""
    client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
    logger.info(f"🔗 Client connected: {client_id}")

    clients.add(websocket)
    server_stats.active_connections += 1

    try:
        # Send enhanced welcome message
        welcome_msg = {
            "type": "connection",
            "status": "connected",
            "message": "Connected to GlobeCast Whisper Server (Enhanced)",
            "server_info": {
                "version": "2.0",
                "whisper_available": whisper_model is not None,
                "translation_available": REQUESTS_AVAILABLE,
                "audio_processing": AUDIO_PROCESSING_AVAILABLE
            },
            "capabilities": {
                "whisper": "loaded" if whisper_model else "unavailable",
                "translation": "available" if REQUESTS_AVAILABLE else "unavailable",
                "supported_languages": SUPPORTED_LANGUAGES,
                "max_audio_size": "10MB",
                "supported_formats": ["wav", "mp3", "webm", "ogg", "m4a"]
            },
            "stats": asdict(server_stats),
            "timestamp": time.time()
        }
        await websocket.send(json.dumps(welcome_msg))

        # Listen for messages with proper error handling
        async for message in websocket:
            try:
                await process_message(websocket, message, client_id)
            except Exception as e:
                logger.error(f"Error processing message from {client_id}: {e}")
                await send_error(websocket, f"Processing error: {str(e)}")

    except websockets.exceptions.ConnectionClosed:
        logger.info(f"📴 Client disconnected: {client_id}")
    except Exception as e:
        logger.error(f"❌ Error handling client {client_id}: {e}")
    finally:
        clients.discard(websocket)
        server_stats.active_connections -= 1

async def process_message(websocket, message, client_id):
    """Enhanced message processing with performance tracking"""
    start_time = time.time()
    server_stats.total_requests += 1

    try:
        # Handle JSON messages
        if isinstance(message, str):
            try:
                data = json.loads(message)
                await handle_json_message(websocket, data, client_id)
                return
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON from {client_id}")
                await send_error(websocket, "Invalid JSON format")
                return

        # Handle binary data (audio)
        if isinstance(message, bytes):
            await handle_audio_data(websocket, message, client_id)

    except Exception as e:
        logger.error(f"Error processing message from {client_id}: {e}")
        await send_error(websocket, f"Processing error: {str(e)}")
    finally:
        # Update performance stats
        processing_time = time.time() - start_time
        server_stats.average_processing_time = (
                (server_stats.average_processing_time * (server_stats.total_requests - 1) + processing_time)
                / server_stats.total_requests
        )

async def handle_json_message(websocket, data, client_id):
    """Enhanced JSON message handling"""
    message_type = data.get("type", "unknown")
    logger.info(f"📨 {client_id} sent: {message_type}")

    if message_type == "test":
        response = {
            "type": "test_response",
            "message": "✅ GlobeCast server is running perfectly!",
            "echo": str(data.get("message", "")),
            "client_id": client_id,
            "server_status": {
                "whisper": "ready" if whisper_model else "not_loaded",
                "translation": "ready" if REQUESTS_AVAILABLE else "unavailable",
                "uptime": time.time(),
                "active_connections": server_stats.active_connections
            },
            "timestamp": time.time()
        }
        await websocket.send(json.dumps(response))

    elif message_type == "ping":
        response = {
            "type": "pong",
            "timestamp": time.time(),
            "server_stats": asdict(server_stats)
        }
        await websocket.send(json.dumps(response))

    elif message_type == "get_stats":
        response = {
            "type": "server_stats",
            "stats": asdict(server_stats),
            "supported_languages": SUPPORTED_LANGUAGES,
            "timestamp": time.time()
        }
        await websocket.send(json.dumps(response))

    elif message_type == "translate_request":
        text = str(data.get("text", "")).strip()
        target_lang = str(data.get("target_lang", "en"))
        source_lang = str(data.get("source_lang", "auto"))

        if text and REQUESTS_AVAILABLE:
            try:
                translated_text, detected_lang, confidence = await translate_text_enhanced(
                    text, target_lang, source_lang
                )

                if translated_text and translated_text.strip():
                    server_stats.successful_translations += 1
                    response = {
                        "type": "translation_result",
                        "original_text": text,
                        "translated_text": str(translated_text),
                        "source_language": str(detected_lang or source_lang),
                        "target_language": str(target_lang),
                        "confidence": float(confidence),
                        "timestamp": time.time()
                    }
                    await websocket.send(json.dumps(response))
                else:
                    await send_error(websocket, "Translation failed - empty result")
            except Exception as e:
                logger.error(f"Translation error: {e}")
                await send_error(websocket, f"Translation error: {str(e)}")
        else:
            await send_error(websocket, "Translation not available or invalid text")

    else:
        logger.warning(f"❓ Unknown message type from {client_id}: {message_type}")

async def handle_audio_data(websocket, audio_data, client_id):
    """Enhanced audio processing with format detection"""
    logger.info(f"🎵 Processing audio from {client_id}: {len(audio_data)} bytes")

    if not whisper_model:
        await send_error(websocket, "Whisper model not available")
        return

    if len(audio_data) > 10 * 1024 * 1024:  # 10MB limit
        await send_error(websocket, "Audio file too large (max 10MB)")
        return

    temp_path = None
    try:
        # Save audio to temp file with proper format detection
        with tempfile.NamedTemporaryFile(suffix=".webm", delete=False) as temp_file:
            temp_file.write(audio_data)
            temp_path = temp_file.name

        # Process audio in thread pool to avoid blocking
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            thread_pool,
            process_audio_file,
            temp_path,
            client_id
        )

        if result:
            server_stats.successful_transcriptions += 1
            if result.duration:
                server_stats.total_audio_duration += result.duration

            # Send result
            response = {
                "type": "transcription",
                "text": str(result.text),
                "language": str(result.language),
                "confidence": float(result.confidence),
                "is_final": bool(result.is_final),
                "timestamp": float(result.timestamp),
                "duration": result.duration,
                "detected_language_confidence": result.detected_language_confidence
            }

            # Add translation if available
            if result.translation and result.translation.strip():
                response["translation"] = {
                    "text": str(result.translation),
                    "language": str(result.translation_lang),
                    "confidence": float(result.translation_confidence)
                }

            await websocket.send(json.dumps(response))
            logger.info(f"📝 Sent transcription to {client_id}: {result.text[:50]}...")
        else:
            await send_error(websocket, "No transcription generated")

    except Exception as e:
        logger.error(f"❌ Error processing audio from {client_id}: {e}")
        await send_error(websocket, f"Audio processing error: {str(e)}")
    finally:
        # Cleanup temp file
        if temp_path:
            try:
                os.unlink(temp_path)
            except:
                pass
        # Force garbage collection for memory management
        gc.collect()

def process_audio_file(audio_path, client_id):
    """Process audio file with Whisper - runs in thread pool"""
    try:
        start_time = time.time()

        # Enhanced transcription with better options
        segments, info = whisper_model.transcribe(
            audio_path,
            task="transcribe",
            language=None,  # Auto-detect
            condition_on_previous_text=False,
            temperature=0.0,
            compression_ratio_threshold=2.4,
            log_prob_threshold=-1.0,
            no_speech_threshold=0.6
        )

        # Combine segments with better handling
        full_text = ""
        confidence_scores = []
        segment_count = 0

        for segment in segments:
            if segment.text.strip():  # Only add non-empty segments
                full_text += segment.text.strip() + " "
                confidence_scores.append(getattr(segment, 'avg_logprob', -1.0))
                segment_count += 1

        if not full_text.strip():
            logger.warning(f"No speech detected in audio from {client_id}")
            return None

        # Calculate confidence
        avg_confidence = sum(confidence_scores) / len(confidence_scores) if confidence_scores else -1.0

        # Convert log probability to percentage (rough approximation)
        confidence_percentage = max(0, min(1, (avg_confidence + 1.0) / 1.0))

        processing_time = time.time() - start_time
        logger.info(f"🎯 Transcription completed for {client_id}: {processing_time:.2f}s, {segment_count} segments")

        # Create result
        result = TranscriptionResult(
            text=full_text.strip(),
            language=info.language,
            confidence=float(confidence_percentage),
            is_final=True,
            timestamp=time.time(),
            duration=getattr(info, 'duration', None),
            detected_language_confidence=getattr(info, 'language_probability', 0.0)
        )

        logger.info(f"📝 Transcribed ({info.language}): {full_text[:100]}...")
        return result

    except Exception as e:
        logger.error(f"Transcription failed for {client_id}: {e}")
        return None

async def send_error(websocket, error_message):
    """Send error message with enhanced formatting"""
    error_response = {
        "type": "error",
        "message": str(error_message),
        "timestamp": time.time(),
        "error_id": f"err_{int(time.time())}"
    }
    try:
        await websocket.send(json.dumps(error_response))
    except:
        pass

async def broadcast_stats():
    """Periodically broadcast server stats to all clients"""
    while True:
        try:
            await asyncio.sleep(30)  # Every 30 seconds

            if clients:
                stats_message = {
                    "type": "server_stats_broadcast",
                    "stats": asdict(server_stats),
                    "timestamp": time.time()
                }

                # Send to all connected clients
                disconnected_clients = []
                for client in clients.copy():
                    try:
                        await client.send(json.dumps(stats_message))
                    except:
                        disconnected_clients.append(client)

                # Remove disconnected clients
                for client in disconnected_clients:
                    clients.discard(client)
                    server_stats.active_connections -= 1

        except Exception as e:
            logger.error(f"Error broadcasting stats: {e}")

async def start_server(host="127.0.0.1", port=8766):
    """Start the enhanced WebSocket server"""
    logger.info(f"🚀 Starting GlobeCast Enhanced Whisper Server on {host}:{port}")

    try:
        # Start stats broadcaster
        asyncio.create_task(broadcast_stats())

        # Start WebSocket server with enhanced configuration
        server = await websockets.serve(
            handle_client,
            host,
            port,
            ping_interval=30,
            ping_timeout=15,
            max_size=15 * 1024 * 1024,  # 15MB max message size
            compression='deflate'
        )

        logger.info("✅ Enhanced server started successfully!")
        logger.info(f"📊 Server capabilities:")
        logger.info(f"   - Whisper: {'✅ Ready' if whisper_model else '❌ Not available'}")
        logger.info(f"   - Translation: {'✅ Ready' if REQUESTS_AVAILABLE else '❌ Not available'}")
        logger.info(f"   - Audio Processing: {'✅ Ready' if AUDIO_PROCESSING_AVAILABLE else '❌ Limited'}")
        logger.info(f"   - Max connections: Unlimited")
        logger.info(f"   - Thread pool: 4 workers")
        logger.info("⏳ Waiting for connections...")

        # Keep server running
        await server.wait_closed()

    except Exception as e:
        logger.error(f"❌ Server error: {e}")
        raise

def main():
    """Enhanced main function with better configuration"""
    # Setup enhanced logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('globecast_server.log', mode='a')
        ]
    )

    logger.info("🌍 GlobeCast Enhanced Whisper Server Starting...")

    # Initialize components
    whisper_ready = initialize_whisper("base")

    if not whisper_ready:
        logger.error("❌ Failed to initialize Whisper model - server cannot start")
        return

    if not REQUESTS_AVAILABLE:
        logger.warning("⚠️ Translation not available - install requests: pip install requests")
        logger.warning("⚠️ Continuing with transcription only")
    else:
        logger.info("✅ Translation ready using enhanced requests implementation")

    if not AUDIO_PROCESSING_AVAILABLE:
        logger.warning("⚠️ Limited audio processing - install soundfile and numpy for better support")

    # Start server
    try:
        asyncio.run(start_server())
    except KeyboardInterrupt:
        logger.info("\n👋 Shutting down server gracefully...")
        # Cleanup
        thread_pool.shutdown(wait=True)
        logger.info("🧹 Cleanup completed")
    except Exception as e:
        logger.error(f"❌ Server failed to start: {e}")

if __name__ == "__main__":
    main()