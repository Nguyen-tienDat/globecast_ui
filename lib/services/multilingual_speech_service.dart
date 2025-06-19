// lib/services/multilingual_speech_service.dart - ENHANCED WITH WEBRTC AUDIO MANAGEMENT
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'translation_service.dart';

class MultilingualSpeechService extends ChangeNotifier {
  // Speech-to-Text instance
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;
  String _text = '';
  String _lastWords = '';
  double _confidence = 1.0;
  String _currentLocale = 'en_US';

  // Translation service integration
  TranslationService? _translationService;

  // Performance optimization
  bool _isSTTEnabled = false;
  bool _continuousMode = false;
  int _pauseDuration = 2;

  // Language detection
  String _detectedLanguage = 'en';
  bool _autoDetectLanguage = true;

  // Error handling
  bool _isInitializing = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  DateTime? _lastErrorTime;

  // 🎯 WEBRTC AUDIO MANAGEMENT - THE TRICK FROM PROJECT 1
  MediaStream? _webrtcStream;
  bool _webrtcAudioWasEnabled = true;
  bool _isManagingWebRTCAudio = false;

  // Available languages for STT
  final Map<String, String> _supportedLanguages = {
    'en': 'English',
    'vi': 'Vietnamese',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ru': 'Russian',
    'ar': 'Arabic',
  };

  // Speech locales mapping for STT
  final Map<String, String> _speechLocales = {
    'en': 'en_US',
    'vi': 'vi_VN',
    'zh': 'zh_CN',
    'ja': 'ja_JP',
    'ko': 'ko_KR',
    'es': 'es_ES',
    'fr': 'fr_FR',
    'de': 'de_DE',
    'ru': 'ru_RU',
    'ar': 'ar_SA',
  };

  // Current user context
  String? _currentUserId;
  String? _currentUserName;

  // Getters
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  bool get isSTTEnabled => _isSTTEnabled;
  bool get isInitializing => _isInitializing;
  String get text => _text;
  String get lastWords => _lastWords;
  double get confidence => _confidence;
  String get detectedLanguage => _detectedLanguage;
  bool get autoDetectLanguage => _autoDetectLanguage;
  bool get continuousMode => _continuousMode;
  Map<String, String> get supportedLanguages => _supportedLanguages;

  // Translation service getters
  bool get isTranslationEnabled => _translationService != null;
  String get translatedText => '';
  String get sourceLanguage => _detectedLanguage;
  String get targetLanguage => _translationService?.userPreference?.displayLanguage ?? 'en';
  bool get isTranslating => false;

  // Constructor
  MultilingualSpeechService() {
    if (kDebugMode) {
      print('🎤 Multilingual Speech Service created (STT not initialized)');
    }
  }

  // 🎯 SET WEBRTC STREAM - KEY METHOD FOR AUDIO MANAGEMENT
  void setWebRTCStream(MediaStream? stream) {
    _webrtcStream = stream;
    if (kDebugMode) {
      print('🔗 WebRTC stream ${stream != null ? "connected" : "disconnected"} to Speech service');
      if (stream != null) {
        print('   📹 Video tracks: ${stream.getVideoTracks().length}');
        print('   🎤 Audio tracks: ${stream.getAudioTracks().length}');
      }
    }
  }

  // 🎯 DISABLE WEBRTC AUDIO - THE TRICK!
  void _disableWebRTCAudio() {
    if (_webrtcStream == null || _isManagingWebRTCAudio) return;

    try {
      final audioTracks = _webrtcStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        // Store current state
        _webrtcAudioWasEnabled = audioTracks.first.enabled;

        // Disable ALL audio tracks
        for (var track in audioTracks) {
          track.enabled = false;
        }

        _isManagingWebRTCAudio = true;

        if (kDebugMode) {
          print('🔇 WebRTC audio disabled for speech recognition (was: $_webrtcAudioWasEnabled)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error disabling WebRTC audio: $e');
      }
    }
  }

  // 🎯 RESTORE WEBRTC AUDIO - THE RESTORATION!
  void _restoreWebRTCAudio() {
    if (_webrtcStream == null || !_isManagingWebRTCAudio) return;

    try {
      final audioTracks = _webrtcStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        // Restore previous state
        for (var track in audioTracks) {
          track.enabled = _webrtcAudioWasEnabled;
        }

        _isManagingWebRTCAudio = false;

        if (kDebugMode) {
          print('🔊 WebRTC audio restored (enabled: $_webrtcAudioWasEnabled)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error restoring WebRTC audio: $e');
      }
    }
  }

  // Set translation service integration
  void setTranslationService(TranslationService translationService) {
    _translationService = translationService;
    if (kDebugMode) {
      print('🔗 Translation service connected to Speech service');
    }
  }

  // Set user context
  void setUserContext(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
    if (kDebugMode) {
      print('👤 Speech service user context set: $userName ($userId)');
    }
  }

  // Enable STT (only when needed for performance)
  Future<void> enableSTT() async {
    if (_isSTTEnabled || _isInitializing) return;

    _isInitializing = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('🎤 Enabling Speech-to-Text...');
      }

      // Cleanup previous instance
      if (_speech != null) {
        try {
          await _speech.stop();
          await _speech.cancel();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error stopping previous speech instance: $e');
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));

      _speech = stt.SpeechToText();
      _isAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: kDebugMode,
      );

      if (_isAvailable) {
        _isSTTEnabled = true;
        _retryCount = 0;
        if (kDebugMode) {
          print('✅ STT enabled successfully');
        }

        // Auto-detect user's speaking language from preference
        if (_translationService?.userPreference != null) {
          final speakingLang = _translationService!.userPreference!.speakingLanguage;
          _detectedLanguage = speakingLang;
          _currentLocale = _speechLocales[speakingLang] ?? 'en_US';
          if (kDebugMode) {
            print('🗣️ Set speaking language from preference: $speakingLang');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ STT not available');
        }
        _isSTTEnabled = false;
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enabling STT: $e');
      }
      _isAvailable = false;
      _isSTTEnabled = false;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  // Disable STT
  Future<void> disableSTT() async {
    if (!_isSTTEnabled && !_isInitializing) return;

    try {
      if (_isListening) {
        await stopListening();
      }

      await Future.delayed(const Duration(milliseconds: 300));

      _isSTTEnabled = false;
      _isAvailable = false;
      _isInitializing = false;

      // Ensure WebRTC audio is restored
      _restoreWebRTCAudio();

      if (kDebugMode) {
        print('🔇 STT disabled to save resources');
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disabling STT: $e');
      }
    }
  }

  // Check if we can start listening
  bool _canStartListening() {
    if (_isListening || _isInitializing) {
      if (kDebugMode) {
        print('⚠️ Cannot start: already listening or initializing');
      }
      return false;
    }

    if (!_isAvailable || !_isSTTEnabled) {
      if (kDebugMode) {
        print('⚠️ Cannot start: STT not available or enabled');
      }
      return false;
    }

    if (_lastErrorTime != null) {
      final timeSinceError = DateTime.now().difference(_lastErrorTime!);
      if (timeSinceError.inSeconds < 2) {
        if (kDebugMode) {
          print('⚠️ Cannot start: in error cooldown period');
        }
        return false;
      }
    }

    if (_retryCount >= _maxRetries) {
      if (kDebugMode) {
        print('⚠️ Cannot start: max retries exceeded');
      }
      return false;
    }

    return true;
  }

  // 🎯 START LISTENING - ENHANCED WITH WEBRTC AUDIO MANAGEMENT
  Future<void> startListening({
    String? locale,
    bool continuous = false,
  }) async {
    // Auto-enable STT if not enabled
    if (!_isSTTEnabled) {
      await enableSTT();
    }

    if (!_canStartListening()) return;

    try {
      if (kDebugMode) {
        print('🎤 Attempting to start listening...');
      }

      // 🎯 THE TRICK: DISABLE WEBRTC AUDIO BEFORE STARTING STT
      _disableWebRTCAudio();

      // Set locale based on user's speaking language preference
      if (_translationService?.userPreference != null) {
        final speakingLang = _translationService!.userPreference!.speakingLanguage;
        _currentLocale = _speechLocales[speakingLang] ?? 'en_US';
        _detectedLanguage = speakingLang;
      } else if (locale != null) {
        _currentLocale = _speechLocales[locale] ?? 'en_US';
        _detectedLanguage = locale;
      }

      _continuousMode = false; // Always use manual mode

      // Clear previous text
      _text = '';
      _lastWords = '';

      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: Duration(seconds: _pauseDuration),
        partialResults: true,
        localeId: _currentLocale,
        onSoundLevelChange: _onSoundLevelChange,
      );

      _isListening = true;
      _retryCount = 0;
      notifyListeners();

      if (kDebugMode) {
        print('🎤 Started listening in $_currentLocale (WebRTC audio disabled)');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting speech recognition: $e');
      }

      // 🎯 RESTORE WEBRTC AUDIO ON ERROR
      _restoreWebRTCAudio();

      _isListening = false;
      _retryCount++;
      _lastErrorTime = DateTime.now();

      if (_retryCount < _maxRetries) {
        final retryDelay = Duration(seconds: _retryCount * 2);
        if (kDebugMode) {
          print('🔄 Retrying in ${retryDelay.inSeconds} seconds... (attempt $_retryCount/$_maxRetries)');
        }

        Future.delayed(retryDelay, () {
          if (!_isListening) {
            startListening(locale: locale, continuous: continuous);
          }
        });
      }

      notifyListeners();
    }
  }

  // 🎯 STOP LISTENING - ENHANCED WITH WEBRTC AUDIO RESTORATION
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      if (kDebugMode) {
        print('🛑 Stopping speech recognition...');
      }

      await _speech.stop();
      _isListening = false;
      _continuousMode = false;

      // 🎯 THE RESTORATION: RESTORE WEBRTC AUDIO AFTER STOPPING STT
      _restoreWebRTCAudio();

      // Save final result when manually stopping
      if (_text.isNotEmpty) {
        await _saveTranscriptionToDatabase(true);
      }

      notifyListeners();
      if (kDebugMode) {
        print('🛑 Stopped listening (WebRTC audio restored)');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping speech recognition: $e');
      }

      // Force restore on error
      _restoreWebRTCAudio();
      _isListening = false;
      notifyListeners();
    }
  }

  // 🎯 CANCEL LISTENING - ENHANCED WITH WEBRTC AUDIO RESTORATION
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      if (kDebugMode) {
        print('❌ Cancelling speech recognition...');
      }

      await _speech.cancel();
      _isListening = false;
      _continuousMode = false;
      _text = '';
      _lastWords = '';

      // 🎯 RESTORE WEBRTC AUDIO ON CANCEL
      _restoreWebRTCAudio();

      notifyListeners();

      if (kDebugMode) {
        print('❌ Cancelled listening (WebRTC audio restored)');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cancelling speech recognition: $e');
      }

      // Force restore on error
      _restoreWebRTCAudio();
      _isListening = false;
      _text = '';
      _lastWords = '';
      notifyListeners();
    }
  }

  // 🎯 SPEECH STATUS CALLBACK - ENHANCED WITH WEBRTC AUDIO MANAGEMENT
  void _onSpeechStatus(String status) {
    if (kDebugMode) {
      print('🔄 Speech status: $status');
    }

    switch (status) {
      case 'listening':
        if (!_isListening) {
          _isListening = true;
          notifyListeners();
        }
        break;

      case 'notListening':
        if (_isListening) {
          _isListening = false;
          // 🎯 RESTORE WEBRTC AUDIO WHEN NOT LISTENING
          _restoreWebRTCAudio();
          notifyListeners();
        }
        break;

      case 'done':
      case 'doneNoResult':
        _isListening = false;

        // 🎯 RESTORE WEBRTC AUDIO WHEN DONE
        _restoreWebRTCAudio();

        // Save final result when speech ends
        if (_text.isNotEmpty && status == 'done') {
          _saveTranscriptionToDatabase(true);
        }

        notifyListeners();
        break;
    }
  }

  // 🎯 SPEECH ERROR CALLBACK - ENHANCED WITH WEBRTC AUDIO RESTORATION
  void _onSpeechError(SpeechRecognitionError error) {
    if (kDebugMode) {
      print('❌ Speech error: ${error.errorMsg}');
    }

    _isListening = false;
    _lastErrorTime = DateTime.now();

    // 🎯 ALWAYS RESTORE WEBRTC AUDIO ON ERROR
    _restoreWebRTCAudio();

    final errorTypeString = error.errorMsg.toString();

    if (errorTypeString.contains('busy')) {
      if (kDebugMode) {
        print('🔄 Speech service busy, will retry...');
      }
      _retryCount++;

      if (_retryCount < _maxRetries) {
        Future.delayed(Duration(seconds: 2 + _retryCount), () async {
          if (!_isListening) {
            await disableSTT();
            await Future.delayed(const Duration(milliseconds: 1000));
            await enableSTT();

            if (_isAvailable) {
              await startListening();
            }
          }
        });
      }
    } else if (errorTypeString.contains('noMatch')) {
      if (kDebugMode) {
        print('🤷 No speech detected');
      }
    } else if (errorTypeString.contains('audio')) {
      if (kDebugMode) {
        print('🎵 Audio error - check microphone permissions');
      }
    } else if (errorTypeString.contains('permission')) {
      if (kDebugMode) {
        print('🚫 Microphone permission denied');
      }
    } else {
      if (kDebugMode) {
        print('❓ Unknown error type: ${error.errorMsg}');
      }
      _retryCount++;
    }

    notifyListeners();
  }

  // Speech result callback - unchanged
  void _onSpeechResult(SpeechRecognitionResult result) {
    _text = result.recognizedWords;
    _lastWords = result.recognizedWords;
    _confidence = result.confidence;

    if (kDebugMode) {
      print('🎯 Speech result: "$_text" (confidence: ${(_confidence * 100).toInt()}%)');
    }

    if (result.finalResult &&
        _text.isNotEmpty &&
        _translationService != null &&
        _currentUserId != null &&
        _currentUserName != null) {

      _saveTranscriptionToDatabase(result.finalResult);

      Future.delayed(const Duration(milliseconds: 500), () {
        _text = '';
        _lastWords = '';
        notifyListeners();
      });
    }

    notifyListeners();
  }

  // Save transcription to database
  Future<void> _saveTranscriptionToDatabase(bool isFinal) async {
    if (_translationService == null ||
        _currentUserId == null ||
        _currentUserName == null ||
        _text.trim().isEmpty) return;

    try {
      await _translationService!.saveSpeechTranscription(
        speakerId: _currentUserId!,
        speakerName: _currentUserName!,
        originalText: _text,
        originalLanguage: _detectedLanguage,
        isFinal: isFinal,
        confidence: _confidence,
      );

      if (kDebugMode) {
        print('💾 Transcription saved to database: $_text');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving transcription to database: $e');
      }
    }
  }

  // Sound level callback
  void _onSoundLevelChange(double level) {
    // Optional: Use this for voice activity indicator
  }

  // Manual save current text
  Future<void> saveCurrentText() async {
    if (_text.isNotEmpty) {
      await _saveTranscriptionToDatabase(true);
      clearText();
    }
  }

  // Toggle listening
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      if (_retryCount >= _maxRetries) {
        _retryCount = 0;
        _lastErrorTime = null;
        if (kDebugMode) {
          print('🔄 Reset retry count for manual toggle');
        }
      }

      await startListening(continuous: false);
    }
  }

  // Reset error state
  void resetErrorState() {
    _retryCount = 0;
    _lastErrorTime = null;
    if (kDebugMode) {
      print('🔄 Error state reset');
    }
    notifyListeners();
  }

  // Set speaking language
  void setSpeakingLanguage(String languageCode) {
    _detectedLanguage = languageCode;
    _currentLocale = _speechLocales[languageCode] ?? 'en_US';
    notifyListeners();

    if (kDebugMode) {
      print('🗣️ Speaking language set to: ${_supportedLanguages[languageCode]}');
    }
  }

  // Toggle auto language detection
  void toggleAutoDetectLanguage() {
    _autoDetectLanguage = !_autoDetectLanguage;
    notifyListeners();

    if (kDebugMode) {
      print('${_autoDetectLanguage ? '🤖' : '👤'} Auto language detection ${_autoDetectLanguage ? 'enabled' : 'disabled'}');
    }
  }

  // Set continuous listening mode
  void setContinuousListening(bool enabled) {
    _continuousMode = enabled;
    notifyListeners();

    if (kDebugMode) {
      print('${enabled ? '🔄' : '⏯️'} Continuous listening ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  // Set pause duration
  void setPauseDuration(int seconds) {
    _pauseDuration = seconds.clamp(1, 10);
    notifyListeners();

    if (kDebugMode) {
      print('⏱️ Pause duration set to $_pauseDuration seconds');
    }
  }

  // Clear text
  void clearText() {
    _text = '';
    _lastWords = '';
    _confidence = 1.0;
    notifyListeners();

    if (kDebugMode) {
      print('🗑️ Text cleared');
    }
  }

  // Get available speech locales
  Future<List<String>> getAvailableLocales() async {
    if (!_isAvailable) return [];

    try {
      final locales = await _speech.locales();
      return locales.map((locale) => locale.localeId).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting locales: $e');
      }
      return [];
    }
  }

  // Check if specific locale is available
  Future<bool> isLocaleAvailable(String localeId) async {
    final availableLocales = await getAvailableLocales();
    return availableLocales.contains(localeId);
  }

  // Get speech recognition status
  String getSpeechStatus() {
    if (_isInitializing) return 'initializing';
    if (!_isSTTEnabled) return 'disabled';
    if (!_isAvailable) return 'unavailable';
    if (_isListening) return 'listening';
    if (_retryCount >= _maxRetries) return 'error';
    return 'ready';
  }

  // Get error info
  String getErrorInfo() {
    if (_retryCount >= _maxRetries) {
      return 'Max retries exceeded. Tap to reset.';
    }
    if (_lastErrorTime != null) {
      final timeSinceError = DateTime.now().difference(_lastErrorTime!);
      if (timeSinceError.inSeconds < 2) {
        return 'Error cooldown: ${2 - timeSinceError.inSeconds}s';
      }
    }
    return '';
  }

  // 🎯 DISPOSE - ENHANCED WITH WEBRTC AUDIO CLEANUP
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing Multilingual Speech Service...');
    }

    // Stop listening if active
    if (_isListening) {
      try {
        _speech.stop();
        _speech.cancel();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error stopping speech during dispose: $e');
        }
      }
    }

    // 🎯 ENSURE WEBRTC AUDIO IS RESTORED ON DISPOSE
    _restoreWebRTCAudio();

    // Cleanup
    _isSTTEnabled = false;
    _isAvailable = false;
    _isListening = false;
    _isInitializing = false;
    _translationService = null;
    _currentUserId = null;
    _currentUserName = null;
    _retryCount = 0;
    _lastErrorTime = null;
    _webrtcStream = null;
    _isManagingWebRTCAudio = false;

    super.dispose();
  }

  // Legacy methods for compatibility
  void toggleTranslation() {
    if (kDebugMode) {
      print('ℹ️ Translation is now managed by TranslationService');
    }
  }

  void setSourceLanguage(String languageCode) {
    setSpeakingLanguage(languageCode);
  }

  void setTargetLanguage(String languageCode) {
    if (_translationService != null) {
      _translationService!.updateDisplayLanguage(languageCode);
    }
  }

  void swapLanguages() {
    if (kDebugMode) {
      print('ℹ️ Language swapping is now managed by TranslationService');
    }
  }

  Future<void> translateCurrentText() async {
    await saveCurrentText();
  }
}