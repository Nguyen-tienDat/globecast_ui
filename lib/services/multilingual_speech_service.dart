// lib/services/multilingual_speech_service.dart - FIXED VERSION
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'translation_service.dart';

class MultilingualSpeechService extends ChangeNotifier {
  // Separate Speech-to-Text instance (independent from WebRTC)
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
  bool _isSTTEnabled = false; // Only enable when needed
  bool _continuousMode = false;
  int _pauseDuration = 2; // seconds

  // Language detection
  String _detectedLanguage = 'en';
  bool _autoDetectLanguage = true;

  // Error handling
  bool _isInitializing = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  DateTime? _lastErrorTime;

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

  // Constructor - lightweight initialization
  MultilingualSpeechService() {
    // Don't initialize speech immediately to save resources
    if (kDebugMode) {
      print('🎤 Multilingual Speech Service created (STT not initialized)');
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

      // Make sure previous instance is properly disposed
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

      // Wait a bit to ensure cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      _speech = stt.SpeechToText();
      _isAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: kDebugMode,
      );

      if (_isAvailable) {
        _isSTTEnabled = true;
        _retryCount = 0; // Reset retry count on success
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

  // Disable STT (to save resources when not needed)
  Future<void> disableSTT() async {
    if (!_isSTTEnabled && !_isInitializing) return;

    try {
      // Stop listening first
      if (_isListening) {
        await stopListening();
      }

      // Wait for any ongoing operations to complete
      await Future.delayed(const Duration(milliseconds: 300));

      _isSTTEnabled = false;
      _isAvailable = false;
      _isInitializing = false;
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

  // Check if we can start listening (with error handling)
  bool _canStartListening() {
    // Don't start if already listening or initializing
    if (_isListening || _isInitializing) {
      if (kDebugMode) {
        print('⚠️ Cannot start: already listening or initializing');
      }
      return false;
    }

    // Don't start if not available
    if (!_isAvailable || !_isSTTEnabled) {
      if (kDebugMode) {
        print('⚠️ Cannot start: STT not available or enabled');
      }
      return false;
    }

    // Check if we're in error cooldown period
    if (_lastErrorTime != null) {
      final timeSinceError = DateTime.now().difference(_lastErrorTime!);
      if (timeSinceError.inSeconds < 2) {
        if (kDebugMode) {
          print('⚠️ Cannot start: in error cooldown period');
        }
        return false;
      }
    }

    // Check retry limit
    if (_retryCount >= _maxRetries) {
      if (kDebugMode) {
        print('⚠️ Cannot start: max retries exceeded');
      }
      return false;
    }

    return true;
  }

  // Start listening - FIXED WITH BETTER ERROR HANDLING
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

      // Set locale based on user's speaking language preference
      if (_translationService?.userPreference != null) {
        final speakingLang = _translationService!.userPreference!.speakingLanguage;
        _currentLocale = _speechLocales[speakingLang] ?? 'en_US';
        _detectedLanguage = speakingLang;
      } else if (locale != null) {
        _currentLocale = _speechLocales[locale] ?? 'en_US';
        _detectedLanguage = locale;
      }

      // CHANGE: Set continuous mode to false for manual control
      _continuousMode = false; // Always use manual mode

      // Clear previous text
      _text = '';
      _lastWords = '';

      // FIXED: Use SpeechListenOptions instead of deprecated parameters
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30), // Fixed duration
        pauseFor: Duration(seconds: _pauseDuration),
        partialResults: true,
        localeId: _currentLocale,
        onSoundLevelChange: _onSoundLevelChange,
        // REMOVED: cancelOnError and listenMode are deprecated
      );

      _isListening = true;
      _retryCount = 0; // Reset retry count on successful start
      notifyListeners();

      if (kDebugMode) {
        print('🎤 Started listening in $_currentLocale (manual mode)');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting speech recognition: $e');
      }
      _isListening = false;
      _retryCount++;
      _lastErrorTime = DateTime.now();

      // Auto-retry with exponential backoff if not at max retries
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

  // Stop listening - IMPROVED
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      if (kDebugMode) {
        print('🛑 Stopping speech recognition...');
      }

      await _speech.stop();
      _isListening = false;
      _continuousMode = false;

      // Save final result when manually stopping
      if (_text.isNotEmpty) {
        await _saveTranscriptionToDatabase(true);
      }

      notifyListeners();
      if (kDebugMode) {
        print('🛑 Stopped listening');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping speech recognition: $e');
      }
      // Force stop
      _isListening = false;
      notifyListeners();
    }
  }

  // Cancel listening - IMPROVED
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
      notifyListeners();

      if (kDebugMode) {
        print('❌ Cancelled listening');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cancelling speech recognition: $e');
      }
      // Force cancel
      _isListening = false;
      _text = '';
      _lastWords = '';
      notifyListeners();
    }
  }

  // Speech status callback - IMPROVED ERROR HANDLING
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
          notifyListeners();
        }
        break;

      case 'done':
      case 'doneNoResult':
        _isListening = false;

        // Save final result when speech ends
        if (_text.isNotEmpty && status == 'done') {
          _saveTranscriptionToDatabase(true);
        }

        notifyListeners();
        break;
    }
  }

  // Speech error callback - FIXED ERROR TYPE ACCESS
  void _onSpeechError(SpeechRecognitionError error) {
    if (kDebugMode) {
      print('❌ Speech error: ${error.errorMsg} (type: ${error.errorType})');
    }

    _isListening = false;
    _lastErrorTime = DateTime.now();

    // FIXED: Use proper error type access
    final errorTypeString = error.errorType.toString();

    // Handle specific error types
    if (errorTypeString.contains('busy')) {
      if (kDebugMode) {
        print('🔄 Speech service busy, will retry...');
      }
      _retryCount++;

      // Retry after a delay if not at max retries
      if (_retryCount < _maxRetries) {
        Future.delayed(Duration(seconds: 2 + _retryCount), () async {
          if (!_isListening) {
            // Force reinitialize STT
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
        print('❓ Unknown error type: ${error.errorType}');
      }
      _retryCount++;
    }

    notifyListeners();
  }

  // Speech result callback - UNCHANGED
  void _onSpeechResult(SpeechRecognitionResult result) {
    _text = result.recognizedWords;
    _lastWords = result.recognizedWords;
    _confidence = result.confidence;

    if (kDebugMode) {
      print('🎯 Speech result: "$_text" (confidence: ${(_confidence * 100).toInt()}%)');
    }

    // Only save on final result in manual mode
    if (result.finalResult &&
        _text.isNotEmpty &&
        _translationService != null &&
        _currentUserId != null &&
        _currentUserName != null) {

      _saveTranscriptionToDatabase(result.finalResult);

      // Clear text after saving in manual mode
      Future.delayed(const Duration(milliseconds: 500), () {
        _text = '';
        _lastWords = '';
        notifyListeners();
      });
    }

    notifyListeners();
  }

  // Save transcription to database via translation service
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
    // if (kDebugMode) print('🔊 Sound level: $level');
  }

  // Manual save current text
  Future<void> saveCurrentText() async {
    if (_text.isNotEmpty) {
      await _saveTranscriptionToDatabase(true);
      clearText();
    }
  }

  // Toggle listening - IMPROVED WITH BETTER ERROR HANDLING
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      // Reset retry count when manually toggling
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

  // Set pause duration for continuous listening
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

  void toggleTranslation() {
    // This is now handled by TranslationService
    if (kDebugMode) {
      print('ℹ️ Translation is now managed by TranslationService');
    }
  }

  void setSourceLanguage(String languageCode) {
    setSpeakingLanguage(languageCode);
  }

  void setTargetLanguage(String languageCode) {
    // This is now handled by TranslationService
    if (_translationService != null) {
      _translationService!.updateDisplayLanguage(languageCode);
    }
  }

  void swapLanguages() {
    // This is now handled by TranslationService
    if (kDebugMode) {
      print('ℹ️ Language swapping is now managed by TranslationService');
    }
  }

  Future<void> translateCurrentText() async {
    // This is now handled automatically by TranslationService
    await saveCurrentText();
  }

  // Dispose - IMPROVED
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

    _isSTTEnabled = false;
    _isAvailable = false;
    _isListening = false;
    _isInitializing = false;
    _translationService = null;
    _currentUserId = null;
    _currentUserName = null;
    _retryCount = 0;
    _lastErrorTime = null;

    super.dispose();
  }
}

extension on SpeechRecognitionError {
  get errorType => null;
}