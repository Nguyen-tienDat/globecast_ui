#!/usr/bin/env python3
"""
GlobeCast Enhanced Whisper Streaming Server
Real-time Speech-to-Text with Auto Translation for Video Meetings
Version: 2.0
"""

import asyncio
import websockets
import json
import logging
import base64
import time
import threading
import queue
import numpy as np
from typing import Dict, Set, Optional, List, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
import traceback
from concurrent.futures import ThreadPoolExecutor
import gc

# Core dependencies
try:
    from faster_whisper import WhisperModel
    import requests
    import soundfile as sf
    from scipy import signal
    import webrtcvad
except ImportError as e:
    print(f"❌ Missing dependency: {e}")
    print("Run: pip install faster-whisper requests soundfile scipy webrtcvad")
    exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('WhisperServer')

@dataclass
class TranscriptionResult:
    """Enhanced transcription result with metadata"""
    speaker_id: str
    speaker_name: str
    original_text: str
    original_language: str
    original_language_confidence: float
    translated_text: str
    target_language: str
    transcription_confidence: float
    translation_confidence: float
    is_final: bool
    timestamp: float
    audio_duration: float
    processing_time: float
    is_voice: bool
    audio_quality: float

@dataclass
class ClientSession:
    """Enhanced client session with audio processing"""
    websocket: websockets.WebSocketServerProtocol
    user_id: str
    display_name: str
    target_language: str
    native_language: str
    last_activity: float
    audio_buffer: queue.Queue
    processing_stats: dict
    is_active: bool = True
    total_audio_processed: float = 0.0
    error_count: int = 0

class EnhancedLanguageDetector:
    """Advanced language detection with confidence scoring"""

    LANGUAGE_MAP = {
        'auto': None,
        'en': 'english', 'vi': 'vietnamese', 'zh': 'chinese',
        'ja': 'japanese', 'ko': 'korean', 'fr': 'french',
        'de': 'german', 'es': 'spanish', 'ar': 'arabic',
        'ru': 'russian', 'pt': 'portuguese', 'it': 'italian',
        'th': 'thai', 'hi': 'hindi', 'nl': 'dutch',
        'pl': 'polish', 'tr': 'turkish', 'sv': 'swedish'
    }

    # Character patterns for quick detection
    LANGUAGE_PATTERNS = {
        'vi': 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ',
        'zh': '\u4e00-\u9fff',
        'ja': '\u3040-\u309f\u30a0-\u30ff',
        'ko': '\uac00-\ud7af',
        'ar': '\u0600-\u06ff',
        'ru': 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя',
        'th': '\u0e00-\u0e7f'
    }

    @classmethod
    def detect_language_from_text(cls, text: str) -> Tuple[str, float]:
        """Enhanced text-based language detection with confidence"""
        if not text.strip():
            return 'en', 0.0

        text_lower = text.lower()
        scores = {}

        # Character-based detection
        for lang, pattern in cls.LANGUAGE_PATTERNS.items():
            if lang in ['zh', 'ja', 'ko', 'ar', 'th']:
                # Unicode range detection
                if lang == 'zh':
                    matches = sum(1 for char in text if '\u4e00' <= char <= '\u9fff')
                elif lang == 'ja':
                    matches = sum(1 for char in text if '\u3040' <= char <= '\u309f' or '\u30a0' <= char <= '\u30ff')
                elif lang == 'ko':
                    matches = sum(1 for char in text if '\uac00' <= char <= '\ud7af')
                elif lang == 'ar':
                    matches = sum(1 for char in text if '\u0600' <= char <= '\u06ff')
                elif lang == 'th':
                    matches = sum(1 for char in text if '\u0e00' <= char <= '\u0e7f')
                else:
                    matches = 0
            else:
                # Character set detection
                matches = sum(1 for char in text_lower if char in pattern)

            if matches > 0:
                scores[lang] = matches / len(text)

        # Word-based detection for Latin scripts
        common_words = {
            'en': ['the', 'is', 'and', 'to', 'a', 'in', 'it', 'you', 'that', 'of'],
            'vi': ['là', 'của', 'có', 'và', 'với', 'được', 'trong', 'cho', 'từ', 'một'],
            'fr': ['le', 'de', 'et', 'à', 'un', 'il', 'être', 'et', 'en', 'avoir'],
            'de': ['der', 'die', 'und', 'in', 'den', 'von', 'zu', 'das', 'mit', 'sich'],
            'es': ['el', 'de', 'que', 'y', 'a', 'en', 'un', 'es', 'se', 'no'],
            'pt': ['o', 'de', 'que', 'e', 'do', 'a', 'em', 'para', 'é', 'com'],
            'it': ['il', 'di', 'che', 'e', 'la', 'per', 'una', 'in', 'del', 'è']
        }

        words = text_lower.split()
        for lang, word_list in common_words.items():
            matches = sum(1 for word in words if word in word_list)
            if matches > 0:
                scores[lang] = scores.get(lang, 0) + (matches / len(words)) * 0.5

        if not scores:
            return 'en', 0.1

        best_lang = max(scores, key=scores.get)
        confidence = min(scores[best_lang], 1.0)

        return best_lang, confidence

    @classmethod
    def get_whisper_language(cls, lang_code: str) -> Optional[str]:
        """Convert language code to Whisper language"""
        return cls.LANGUAGE_MAP.get(lang_code.lower())

class EnhancedTranslator:
    """Multi-provider translation service with caching and fallback"""

    def __init__(self):
        self.cache = {}
        self.cache_size_limit = 5000
        self.translation_stats = {}

        # Provider configurations
        self.providers = {
            'google': {
                'url': 'https://translate.googleapis.com/translate_a/single',
                'enabled': True,
                'rate_limit': 0.1  # seconds between requests
            },
            'mymemory': {
                'url': 'https://api.mymemory.translated.net/get',
                'enabled': True,
                'rate_limit': 0.5
            }
        }

        self.last_request_time = {}

    async def translate(self, text: str, target_lang: str, source_lang: str = 'auto') -> Tuple[str, float]:
        """Enhanced translation with confidence scoring"""
        if not text.strip():
            return text, 0.0

        # Normalize language codes
        source_lang = self._normalize_lang_code(source_lang)
        target_lang = self._normalize_lang_code(target_lang)

        # Check if translation is needed
        if source_lang == target_lang and source_lang != 'auto':
            return text, 1.0

        # Check cache
        cache_key = f"{text[:100]}:{source_lang}:{target_lang}"
        if cache_key in self.cache:
            return self.cache[cache_key], 0.9

        # Try translation providers
        for provider_name, config in self.providers.items():
            if not config['enabled']:
                continue

            try:
                result, confidence = await self._translate_with_provider(
                    text, target_lang, source_lang, provider_name
                )

                if result and result != text:
                    # Cache successful translation
                    if len(self.cache) < self.cache_size_limit:
                        self.cache[cache_key] = result

                    # Update stats
                    self.translation_stats[provider_name] = self.translation_stats.get(provider_name, 0) + 1

                    return result, confidence

            except Exception as e:
                logger.warning(f"Translation provider {provider_name} failed: {e}")
                continue

        # Fallback: return original text
        return text, 0.0

    async def _translate_with_provider(self, text: str, target_lang: str,
                                       source_lang: str, provider: str) -> Tuple[str, float]:
        """Translate using specific provider"""

        # Rate limiting
        now = time.time()
        last_time = self.last_request_time.get(provider, 0)
        rate_limit = self.providers[provider]['rate_limit']

        if now - last_time < rate_limit:
            await asyncio.sleep(rate_limit - (now - last_time))

        if provider == 'google':
            return await self._translate_google(text, target_lang, source_lang)
        elif provider == 'mymemory':
            return await self._translate_mymemory(text, target_lang, source_lang)

        return text, 0.0

    async def _translate_google(self, text: str, target_lang: str, source_lang: str) -> Tuple[str, float]:
        """Google Translate implementation"""
        try:
            url = self.providers['google']['url']
            params = {
                'client': 'gtx',
                'sl': source_lang,
                'tl': target_lang,
                'dt': 't',
                'q': text[:1000]  # Limit text length
            }

            response = requests.get(url, params=params, timeout=3)
            self.last_request_time['google'] = time.time()

            if response.status_code == 200:
                result = response.json()
                if result and result[0]:
                    translated = ''.join([item[0] for item in result[0] if item[0]])
                    confidence = 0.8 if translated != text else 0.0
                    return translated, confidence

        except Exception as e:
            logger.warning(f"Google Translate error: {e}")

        return text, 0.0

    async def _translate_mymemory(self, text: str, target_lang: str, source_lang: str) -> Tuple[str, float]:
        """MyMemory translation implementation"""
        try:
            url = self.providers['mymemory']['url']
            params = {
                'q': text[:500],
                'langpair': f"{source_lang}|{target_lang}"
            }

            response = requests.get(url, params=params, timeout=3)
            self.last_request_time['mymemory'] = time.time()

            if response.status_code == 200:
                result = response.json()
                if result.get('responseStatus') == 200:
                    translated = result['responseData']['translatedText']
                    match_quality = result['responseData'].get('match', 0)
                    confidence = min(match_quality / 100.0, 0.7)
                    return translated, confidence

        except Exception as e:
            logger.warning(f"MyMemory error: {e}")

        return text, 0.0

    def _normalize_lang_code(self, lang_code: str) -> str:
        """Normalize language codes for translation APIs"""
        mapping = {
            'zh': 'zh-cn',
            'auto': 'auto'
        }
        return mapping.get(lang_code, lang_code)

class AudioProcessor:
    """Enhanced audio processing with VAD and quality assessment"""

    def __init__(self):
        self.vad = webrtcvad.Vad(2)  # Aggressiveness level 2
        self.sample_rate = 16000
        self.frame_duration_ms = 30  # 30ms frames for VAD
        self.frame_size = int(self.sample_rate * self.frame_duration_ms / 1000)

    def process_audio(self, audio_data: bytes) -> Tuple[np.ndarray, dict]:
        """Process audio and return enhanced metadata"""
        try:
            # Convert to numpy array
            if len(audio_data) % 2 != 0:
                audio_data = audio_data[:-1]  # Remove odd byte

            audio_array = np.frombuffer(audio_data, dtype=np.int16)

            if len(audio_array) == 0:
                return np.array([]), {'is_voice': False, 'quality': 0.0}

            # Convert to float
            audio_float = audio_array.astype(np.float32) / 32768.0

            # Quality assessment
            quality_metrics = self._assess_audio_quality(audio_float)

            # Voice activity detection
            is_voice = self._detect_voice_activity(audio_data)

            # Noise reduction (simple)
            if quality_metrics['snr'] < 10:  # Low SNR
                audio_float = self._reduce_noise(audio_float)

            metadata = {
                'is_voice': is_voice,
                'quality': quality_metrics['overall_quality'],
                'snr': quality_metrics['snr'],
                'duration': len(audio_float) / self.sample_rate,
                'rms_level': quality_metrics['rms_level']
            }

            return audio_float, metadata

        except Exception as e:
            logger.error(f"Audio processing error: {e}")
            return np.array([]), {'is_voice': False, 'quality': 0.0}

    def _assess_audio_quality(self, audio: np.ndarray) -> dict:
        """Assess audio quality metrics"""
        # RMS level
        rms_level = np.sqrt(np.mean(audio ** 2))

        # Signal-to-noise ratio estimation
        # Simple method: compare energy in different frequency bands
        if len(audio) > 1024:
            freqs = np.fft.fftfreq(len(audio), 1/self.sample_rate)
            fft = np.abs(np.fft.fft(audio))

            # Voice range (300-3400 Hz)
            voice_mask = (freqs >= 300) & (freqs <= 3400)
            voice_energy = np.sum(fft[voice_mask] ** 2)

            # Noise range (outside voice range)
            noise_mask = ~voice_mask
            noise_energy = np.sum(fft[noise_mask] ** 2)

            snr = 10 * np.log10(voice_energy / (noise_energy + 1e-10))
        else:
            snr = 5.0  # Default for short audio

        # Overall quality (0-1 scale)
        quality = 0.0
        if 0.01 < rms_level < 0.8:  # Good level range
            quality += 0.4
        if snr > 5:  # Acceptable SNR
            quality += 0.6 * min(snr / 20, 1.0)

        return {
            'rms_level': float(rms_level),
            'snr': float(snr),
            'overall_quality': min(quality, 1.0)
        }

    def _detect_voice_activity(self, audio_data: bytes) -> bool:
        """Enhanced voice activity detection"""
        try:
            # Ensure audio data length is suitable for VAD
            if len(audio_data) < self.frame_size * 2:  # Not enough data
                return False

            # Process in frames
            voice_frames = 0
            total_frames = 0

            for i in range(0, len(audio_data) - self.frame_size * 2, self.frame_size * 2):
                frame = audio_data[i:i + self.frame_size * 2]

                if len(frame) == self.frame_size * 2:
                    try:
                        is_speech = self.vad.is_speech(frame, self.sample_rate)
                        if is_speech:
                            voice_frames += 1
                        total_frames += 1
                    except:
                        continue

            if total_frames == 0:
                return False

            # At least 30% of frames should contain voice
            voice_ratio = voice_frames / total_frames
            return voice_ratio >= 0.3

        except Exception as e:
            logger.warning(f"VAD error: {e}")
            return True  # Default to true if VAD fails

    def _reduce_noise(self, audio: np.ndarray) -> np.ndarray:
        """Simple noise reduction using spectral subtraction"""
        try:
            if len(audio) < 1024:
                return audio

            # Simple high-pass filter to remove low-frequency noise
            sos = signal.butter(4, 300, btype='high', fs=self.sample_rate, output='sos')
            filtered = signal.sosfilt(sos, audio)

            # Gentle compression to even out levels
            threshold = 0.1
            ratio = 0.5
            compressed = np.where(
                np.abs(filtered) > threshold,
                np.sign(filtered) * (threshold + (np.abs(filtered) - threshold) * ratio),
                filtered
            )

            return compressed.astype(np.float32)

        except Exception as e:
            logger.warning(f"Noise reduction error: {e}")
            return audio

class WhisperStreamingServer:
    """Enhanced Whisper streaming server with advanced features"""

    def __init__(self, model_size: str = "base", device: str = "cpu", max_clients: int = 50):
        self.model_size = model_size
        self.device = device
        self.max_clients = max_clients

        # Core components
        self.model = None
        self.translator = EnhancedTranslator()
        self.audio_processor = AudioProcessor()
        self.language_detector = EnhancedLanguageDetector()

        # Client management
        self.clients: Dict[str, ClientSession] = {}
        self.processing_queue = queue.Queue()
        self.thread_pool = ThreadPoolExecutor(max_workers=4)

        # Server configuration
        self.host = "0.0.0.0"  # Accept connections from any IP
        self.port = 8766
        self.chunk_duration = 1.5  # Process every 1.5 seconds
        self.max_buffer_size = 32000  # ~2 seconds of audio

        # Performance monitoring
        self.stats = {
            'total_clients': 0,
            'active_clients': 0,
            'total_audio_processed': 0.0,
            'total_transcriptions': 0,
            'total_translations': 0,
            'average_processing_time': 0.0,
            'error_count': 0,
            'start_time': time.time()
        }

        logger.info(f"🚀 Initializing Enhanced Whisper Server")
        logger.info(f"📦 Model: {model_size}, Device: {device}")
        logger.info(f"👥 Max clients: {max_clients}")

    async def initialize(self) -> bool:
        """Initialize the server components"""
        try:
            logger.info("📥 Loading Whisper model...")
            self.model = WhisperModel(
                self.model_size,
                device=self.device,
                compute_type="float16" if self.device == "cuda" else "int8"
            )
            logger.info("✅ Whisper model loaded successfully!")

            # Start background processing
            asyncio.create_task(self._background_processor())
            asyncio.create_task(self._stats_monitor())

            return True

        except Exception as e:
            logger.error(f"❌ Failed to initialize server: {e}")
            return False

    async def register_client(self, websocket, user_data: dict):
        """Register a new client with enhanced validation"""
        try:
            if len(self.clients) >= self.max_clients:
                await self.send_error(websocket, "Server at maximum capacity")
                return False

            user_id = user_data.get('userId', f'user_{int(time.time() * 1000)}')
            display_name = user_data.get('displayName', 'Anonymous User')
            target_language = user_data.get('displayLanguage', 'en')
            native_language = user_data.get('nativeLanguage', 'auto')

            # Validate languages
            if target_language not in self.language_detector.LANGUAGE_MAP:
                target_language = 'en'

            session = ClientSession(
                websocket=websocket,
                user_id=user_id,
                display_name=display_name,
                target_language=target_language,
                native_language=native_language,
                last_activity=time.time(),
                audio_buffer=queue.Queue(maxsize=100),
                processing_stats={
                    'audio_chunks_received': 0,
                    'transcriptions_sent': 0,
                    'translations_sent': 0,
                    'errors': 0
                }
            )

            self.clients[user_id] = session
            self.stats['total_clients'] += 1
            self.stats['active_clients'] = len(self.clients)

            logger.info(f"👤 Client registered: {display_name} ({user_id})")
            logger.info(f"🌍 Languages: {native_language} → {target_language}")

            await self.send_message(websocket, {
                'type': 'connection_established',
                'userId': user_id,
                'serverInfo': {
                    'model': self.model_size,
                    'supportedLanguages': list(self.language_detector.LANGUAGE_MAP.keys()),
                    'features': ['real_time_transcription', 'auto_translation', 'voice_activity_detection']
                }
            })

            return True

        except Exception as e:
            logger.error(f"❌ Client registration error: {e}")
            await self.send_error(websocket, f"Registration failed: {str(e)}")
            return False

    async def handle_audio_data(self, session: ClientSession, message: dict):
        """Handle incoming audio data with enhanced processing"""
        try:
            # Extract audio data
            audio_base64 = message.get('audioData', '')
            speaker_id = message.get('speakerId', session.user_id)
            speaker_name = message.get('speakerName', session.display_name)

            if not audio_base64:
                return

            # Decode audio
            try:
                audio_bytes = base64.b64decode(audio_base64)
            except Exception as e:
                logger.warning(f"❌ Audio decode error for {speaker_name}: {e}")
                return

            # Update activity
            session.last_activity = time.time()
            session.processing_stats['audio_chunks_received'] += 1

            # Add to processing queue if not full
            if not session.audio_buffer.full():
                audio_chunk = {
                    'session': session,
                    'audio_data': audio_bytes,
                    'speaker_id': speaker_id,
                    'speaker_name': speaker_name,
                    'timestamp': time.time()
                }
                session.audio_buffer.put(audio_chunk)
            else:
                logger.warning(f"⚠️ Audio buffer full for {speaker_name}, dropping chunk")

        except Exception as e:
            logger.error(f"❌ Audio handling error: {e}")
            session.processing_stats['errors'] += 1

    async def _background_processor(self):
        """Background audio processing worker"""
        while True:
            try:
                # Process audio from all active clients
                for user_id, session in list(self.clients.items()):
                    if not session.is_active:
                        continue

                    # Collect audio chunks
                    audio_chunks = []
                    while not session.audio_buffer.empty() and len(audio_chunks) < 5:
                        try:
                            chunk = session.audio_buffer.get_nowait()
                            audio_chunks.append(chunk)
                        except queue.Empty:
                            break

                    # Process chunks
                    if audio_chunks:
                        await self._process_audio_chunks(audio_chunks)

                await asyncio.sleep(0.1)  # Small delay to prevent busy waiting

            except Exception as e:
                logger.error(f"❌ Background processor error: {e}")
                await asyncio.sleep(1)

    async def _process_audio_chunks(self, chunks: List[dict]):
        """Process collected audio chunks"""
        if not chunks:
            return

        session = chunks[0]['session']

        try:
            # Combine audio data
            combined_audio = b''.join(chunk['audio_data'] for chunk in chunks)
            speaker_id = chunks[0]['speaker_id']
            speaker_name = chunks[0]['speaker_name']

            # Process audio
            audio_array, audio_metadata = self.audio_processor.process_audio(combined_audio)

            if not audio_metadata['is_voice'] or audio_metadata['quality'] < 0.2:
                return  # Skip non-voice or low-quality audio

            # Transcribe with Whisper
            start_time = time.time()
            results = await self._transcribe_audio(
                audio_array, session, speaker_id, speaker_name, audio_metadata
            )
            processing_time = time.time() - start_time

            # Update stats
            self.stats['total_audio_processed'] += audio_metadata['duration']
            self.stats['average_processing_time'] = (
                    self.stats['average_processing_time'] * 0.9 + processing_time * 0.1
            )

            # Send results
            if results:
                for result in results:
                    await self.broadcast_transcription(result)
                    session.processing_stats['transcriptions_sent'] += 1
                    if result.translated_text != result.original_text:
                        session.processing_stats['translations_sent'] += 1

        except Exception as e:
            logger.error(f"❌ Audio processing error: {e}")
            session.processing_stats['errors'] += 1
            self.stats['error_count'] += 1

    async def _transcribe_audio(self, audio: np.ndarray, session: ClientSession,
                                speaker_id: str, speaker_name: str, metadata: dict) -> List[TranscriptionResult]:
        """Enhanced transcription with better error handling"""
        try:
            if len(audio) == 0:
                return []

            # Transcribe with Whisper
            segments, info = self.model.transcribe(
                audio,
                language=self.language_detector.get_whisper_language(session.native_language),
                beam_size=1,
                best_of=1,
                vad_filter=False,
                vad_parameters=dict(
                    min_silence_duration_ms=500,
                    speech_pad_ms=400
                ),
                word_timestamps=False,  # Disable for speed
                condition_on_previous_text=False
            )

            results = []

            for segment in segments:
                if not segment.text.strip() or len(segment.text.strip()) < 3:
                    continue

                original_text = segment.text.strip()

                # Enhanced language detection
                detected_lang = info.language if info.language else 'en'
                text_lang, text_confidence = self.language_detector.detect_language_from_text(original_text)

                # Use text detection if more confident
                if text_confidence > 0.5:
                    detected_lang = text_lang

                # Translate if needed
                translated_text = original_text
                translation_confidence = 1.0

                if detected_lang != session.target_language:
                    translated_text, translation_confidence = await self.translator.translate(
                        original_text, session.target_language, detected_lang
                    )

                result = TranscriptionResult(
                    speaker_id=speaker_id,
                    speaker_name=speaker_name,
                    original_text=original_text,
                    original_language=detected_lang,
                    original_language_confidence=float(getattr(info, 'language_probability', 0.8)),
                    translated_text=translated_text,
                    target_language=session.target_language,
                    transcription_confidence=float(segment.avg_logprob),
                    translation_confidence=translation_confidence,
                    is_final=True,
                    timestamp=time.time(),
                    audio_duration=metadata['duration'],
                    processing_time=0.0,  # Will be set by caller
                    is_voice=metadata['is_voice'],
                    audio_quality=metadata['quality']
                )

                results.append(result)
                self.stats['total_transcriptions'] += 1

                if translated_text != original_text:
                    self.stats['total_translations'] += 1

            return results

        except Exception as e:
            logger.error(f"❌ Transcription error: {e}")
            traceback.print_exc()
            return []

    async def broadcast_transcription(self, result: TranscriptionResult):
        """Broadcast transcription to all active clients"""
        message = {
            'type': 'transcription_result',
            'data': asdict(result)
        }

        # Send to all connected clients
        disconnected_clients = []

        for user_id, session in self.clients.items():
            try:
                if session.is_active:
                    await self.send_message(session.websocket, message)
            except websockets.exceptions.ConnectionClosed:
                disconnected_clients.append(user_id)
                session.is_active = False
            except Exception as e:
                logger.warning(f"⚠️ Failed to send to {session.display_name}: {e}")
                if "close code" in str(e).lower():
                    disconnected_clients.append(user_id)
                    session.is_active = False

        # Clean up disconnected clients
        for user_id in disconnected_clients:
            await self._cleanup_client(user_id)

    async def _cleanup_client(self, user_id: str):
        """Clean up disconnected client"""
        session = self.clients.pop(user_id, None)
        if session:
            session.is_active = False
            self.stats['active_clients'] = len(self.clients)
            logger.info(f"👋 Client cleaned up: {session.display_name} ({user_id})")

    async def handle_language_change(self, session: ClientSession, message: dict):
        """Handle language preference changes"""
        target_language = message.get('displayLanguage')
        native_language = message.get('nativeLanguage')

        updated = False

        if target_language and target_language in self.language_detector.LANGUAGE_MAP:
            session.target_language = target_language
            updated = True
            logger.info(f"🌍 {session.display_name} changed target language to: {target_language}")

        if native_language and native_language in self.language_detector.LANGUAGE_MAP:
            session.native_language = native_language
            updated = True
            logger.info(f"🗣️ {session.display_name} changed native language to: {native_language}")

        if updated:
            await self.send_message(session.websocket, {
                'type': 'language_updated',
                'displayLanguage': session.target_language,
                'nativeLanguage': session.native_language
            })

    async def _stats_monitor(self):
        """Monitor and log server statistics"""
        while True:
            try:
                await asyncio.sleep(60)  # Log stats every minute

                uptime = time.time() - self.stats['start_time']

                logger.info(f"📊 Server Stats:")
                logger.info(f"   👥 Active clients: {self.stats['active_clients']}")
                logger.info(f"   🎙️ Audio processed: {self.stats['total_audio_processed']:.1f}s")
                logger.info(f"   📝 Transcriptions: {self.stats['total_transcriptions']}")
                logger.info(f"   🌍 Translations: {self.stats['total_translations']}")
                logger.info(f"   ⚡ Avg processing time: {self.stats['average_processing_time']:.3f}s")
                logger.info(f"   ⏱️ Uptime: {uptime/3600:.1f}h")

                # Garbage collection
                if uptime % 1800 == 0:  # Every 30 minutes
                    gc.collect()
                    logger.info("🧹 Performed garbage collection")

            except Exception as e:
                logger.error(f"❌ Stats monitor error: {e}")

    async def send_message(self, websocket, message: dict):
        """Send message to websocket with error handling"""
        try:
            await websocket.send(json.dumps(message, ensure_ascii=False))
        except websockets.exceptions.ConnectionClosed:
            pass  # Connection already closed
        except Exception as e:
            logger.warning(f"⚠️ Send message error: {e}")

    async def send_error(self, websocket, error_message: str):
        """Send error message to client"""
        await self.send_message(websocket, {
            'type': 'error',
            'message': error_message,
            'timestamp': time.time()
        })

    async def handle_client(self, websocket, path):
        """Enhanced client connection handler"""
        client_id = None
        client_ip = websocket.remote_address[0] if websocket.remote_address else "unknown"

        try:
            logger.info(f"🔗 New client connected from {client_ip}")

            async for message_raw in websocket:
                try:
                    message = json.loads(message_raw)
                    message_type = message.get('type')

                    if message_type == 'connect':
                        success = await self.register_client(websocket, message)
                        if success:
                            client_id = message.get('userId')

                    elif message_type == 'audio_data':
                        if client_id and client_id in self.clients:
                            await self.handle_audio_data(self.clients[client_id], message)
                        else:
                            await self.send_error(websocket, "Client not registered")

                    elif message_type == 'language_update':
                        if client_id and client_id in self.clients:
                            await self.handle_language_change(self.clients[client_id], message)
                        else:
                            await self.send_error(websocket, "Client not registered")

                    elif message_type == 'ping':
                        await self.send_message(websocket, {
                            'type': 'pong',
                            'timestamp': time.time()
                        })

                    elif message_type == 'get_stats':
                        if client_id and client_id in self.clients:
                            stats = self.stats.copy()
                            stats['client_stats'] = self.clients[client_id].processing_stats
                            await self.send_message(websocket, {
                                'type': 'stats_response',
                                'data': stats
                            })

                    else:
                        await self.send_error(websocket, f"Unknown message type: {message_type}")

                except json.JSONDecodeError:
                    await self.send_error(websocket, "Invalid JSON format")
                except Exception as e:
                    logger.error(f"❌ Message handling error: {e}")
                    await self.send_error(websocket, f"Message processing failed")

        except websockets.exceptions.ConnectionClosed:
            pass  # Normal disconnection
        except Exception as e:
            logger.error(f"❌ Client handler error: {e}")
        finally:
            if client_id:
                await self._cleanup_client(client_id)

    async def start_server(self):
        """Start the enhanced WebSocket server"""
        if not await self.initialize():
            logger.error("❌ Failed to initialize server")
            return

        logger.info(f"🚀 Starting Enhanced Whisper Server on {self.host}:{self.port}")

        try:
            async with websockets.serve(
                    self.handle_client,
                    self.host,
                    self.port,
                    max_size=10 * 1024 * 1024,  # 10MB max message size
                    ping_interval=30,  # Send ping every 30 seconds
                    ping_timeout=10,   # Wait 10 seconds for pong
                    close_timeout=10   # Wait 10 seconds when closing
            ):
                logger.info("=" * 60)
                logger.info("🎉 GlobeCast Enhanced Whisper Server is READY!")
                logger.info("=" * 60)
                logger.info(f"🌐 WebSocket URL: ws://{self.host}:{self.port}")
                logger.info(f"📦 Model: {self.model_size}")
                logger.info(f"🔧 Features: Real-time transcription, Auto-translation, VAD")
                logger.info(f"👥 Max clients: {self.max_clients}")
                logger.info("🚀 Ready for Flutter connections!")
                logger.info("=" * 60)

                # Keep server running
                await asyncio.Future()

        except KeyboardInterrupt:
            logger.info("🛑 Server shutdown requested")
        except Exception as e:
            logger.error(f"❌ Server error: {e}")

def main():
    """Enhanced main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='GlobeCast Enhanced Whisper Server')
    parser.add_argument('--model', default='base',
                        choices=['tiny', 'base', 'small', 'medium', 'large'],
                        help='Whisper model size (default: base)')
    parser.add_argument('--device', default='cpu', choices=['cpu', 'cuda'],
                        help='Device to run on (default: cpu)')
    parser.add_argument('--host', default='0.0.0.0',
                        help='Host to bind to (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=8766,
                        help='Port to bind to (default: 8766)')
    parser.add_argument('--max-clients', type=int, default=50,
                        help='Maximum concurrent clients (default: 50)')

    args = parser.parse_args()

    print("🌍 GlobeCast Enhanced Whisper Server v2.0")
    print("=" * 60)
    print(f"📦 Model: {args.model}")
    print(f"💻 Device: {args.device}")
    print(f"🌐 Address: {args.host}:{args.port}")
    print(f"👥 Max clients: {args.max_clients}")
    print("📋 Features:")
    print("   🎙️ Real-time speech-to-text")
    print("   🌍 Auto language detection & translation")
    print("   🔊 Voice activity detection")
    print("   📊 Quality assessment")
    print("   📈 Performance monitoring")
    print("=" * 60)

    server = WhisperStreamingServer(
        model_size=args.model,
        device=args.device,
        max_clients=args.max_clients
    )
    server.host = args.host
    server.port = args.port

    try:
        asyncio.run(server.start_server())
    except KeyboardInterrupt:
        print("\n👋 Server stopped. Goodbye!")
    except Exception as e:
        print(f"❌ Fatal error: {e}")

if __name__ == "__main__":
    main()