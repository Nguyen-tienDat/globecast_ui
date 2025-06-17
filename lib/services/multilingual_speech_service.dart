// lib/services/multilingual_speech_service.dart
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:translator/translator.dart';

class MultilingualSpeechService extends ChangeNotifier {
  // Speech-to-Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;
  String _text = '';
  String _lastWords = '';
  double _confidence = 1.0;
  String _currentLocale = 'en_US';

  // Translation
  final GoogleTranslator _translator = GoogleTranslator();
  String _translatedText = '';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'vi';
  bool _isTranslationEnabled = false;
  bool _isTranslating = false;

  // Continuous listening
  bool _continuousListening = false;
  int _pauseDuration = 3; // seconds

  // Available languages
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

  // Speech locales mapping
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

  // Getters
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get text => _text;
  String get lastWords => _lastWords;
  String get translatedText => _translatedText;
  double get confidence => _confidence;
  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;
  bool get isTranslationEnabled => _isTranslationEnabled;
  bool get isTranslating => _isTranslating;
  bool get continuousListening => _continuousListening;
  Map<String, String> get supportedLanguages => _supportedLanguages;

  // Constructor
  MultilingualSpeechService() {
    _initializeSpeech();
  }

  // Initialize speech recognition
  Future<void> _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();
      _isAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: kDebugMode,
      );

      if (_isAvailable) {
        print('✅ Speech recognition initialized successfully');
      } else {
        print('❌ Speech recognition not available');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing speech: $e');
      _isAvailable = false;
      notifyListeners();
    }
  }

  // Start listening
  Future<void> startListening({
    String? locale,
    bool continuous = false,
  }) async {
    if (!_isAvailable || _isListening) return;

    try {
      // Set locale if provided
      if (locale != null) {
        _currentLocale = _speechLocales[locale] ?? 'en_US';
      } else {
        _currentLocale = _speechLocales[_sourceLanguage] ?? 'en_US';
      }

      _continuousListening = continuous;

      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: continuous ? const Duration(minutes: 10) : const Duration(seconds: 30),
        pauseFor: Duration(seconds: _pauseDuration),
        partialResults: true,
        localeId: _currentLocale,
        onSoundLevelChange: _onSoundLevelChange,
        cancelOnError: false,
        listenMode: continuous
            ? stt.ListenMode.confirmation
            : stt.ListenMode.search,
      );

      _isListening = true;
      notifyListeners();

      print('🎤 Started listening in $_currentLocale mode${continuous ? ' (continuous)' : ''}');

    } catch (e) {
      print('❌ Error starting speech recognition: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      _continuousListening = false;
      notifyListeners();

      print('🛑 Stopped listening');
    } catch (e) {
      print('❌ Error stopping speech recognition: $e');
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speech.cancel();
      _isListening = false;
      _continuousListening = false;
      _text = '';
      _lastWords = '';
      notifyListeners();

      print('❌ Cancelled listening');
    } catch (e) {
      print('❌ Error cancelling speech recognition: $e');
    }
  }

  // Speech status callback
  void _onSpeechStatus(String status) {
    print('🔄 Speech status: $status');

    if (status == 'done' && _continuousListening && _isAvailable) {
      // Restart listening for continuous mode
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_continuousListening && !_isListening) {
          startListening(continuous: true);
        }
      });
    }

    if (status == 'notListening') {
      _isListening = false;
      notifyListeners();
    }
  }

  // Speech error callback
  void _onSpeechError(SpeechRecognitionError error) {
    print('❌ Speech error: ${error.errorMsg}');
    _isListening = false;
    notifyListeners();

    // Auto-restart on certain errors in continuous mode
    if (_continuousListening &&
        (error.errorMsg.contains('network') ||
            error.errorMsg.contains('timeout'))) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_continuousListening && !_isListening) {
          startListening(continuous: true);
        }
      });
    }
  }

  // Speech result callback
  void _onSpeechResult(SpeechRecognitionResult result) {
    _text = result.recognizedWords;
    _lastWords = result.recognizedWords;
    _confidence = result.confidence;

    print('🎯 Speech result: "$_text" (confidence: ${(_confidence * 100).toInt()}%)');

    // Auto-translate if enabled and result is final
    if (_isTranslationEnabled && result.finalResult && _text.isNotEmpty) {
      _translateText(_text);
    }

    notifyListeners();
  }

  // Sound level callback
  void _onSoundLevelChange(double level) {
    // Optional: Use this for voice activity indicator
    // print('🔊 Sound level: $level');
  }

  // Translate text
  Future<void> _translateText(String text) async {
    if (text.isEmpty || _sourceLanguage == _targetLanguage) {
      _translatedText = text;
      notifyListeners();
      return;
    }

    _isTranslating = true;
    notifyListeners();

    try {
      final translation = await _translator.translate(
        text,
        from: _sourceLanguage,
        to: _targetLanguage,
      );

      _translatedText = translation.text;

      print('🌐 Translated "$text" → "$_translatedText"');

    } catch (e) {
      print('❌ Translation error: $e');
      _translatedText = text; // Fallback to original text
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  // Manual translation trigger
  Future<void> translateCurrentText() async {
    if (_text.isNotEmpty) {
      await _translateText(_text);
    }
  }

  // Set languages
  void setSourceLanguage(String languageCode) {
    _sourceLanguage = languageCode;
    _currentLocale = _speechLocales[languageCode] ?? 'en_US';
    notifyListeners();

    print('🗣️ Source language set to: ${_supportedLanguages[languageCode]}');
  }

  void setTargetLanguage(String languageCode) {
    _targetLanguage = languageCode;
    notifyListeners();

    print('🎯 Target language set to: ${_supportedLanguages[languageCode]}');
  }

  void swapLanguages() {
    final temp = _sourceLanguage;
    _sourceLanguage = _targetLanguage;
    _targetLanguage = temp;
    _currentLocale = _speechLocales[_sourceLanguage] ?? 'en_US';
    notifyListeners();

    print('🔄 Languages swapped: ${_supportedLanguages[_sourceLanguage]} ↔ ${_supportedLanguages[_targetLanguage]}');
  }

  // Toggle translation
  void toggleTranslation() {
    _isTranslationEnabled = !_isTranslationEnabled;
    notifyListeners();

    print('${_isTranslationEnabled ? '✅' : '❌'} Translation ${_isTranslationEnabled ? 'enabled' : 'disabled'}');

    // Translate current text if just enabled
    if (_isTranslationEnabled && _text.isNotEmpty) {
      _translateText(_text);
    }
  }

  // Set continuous listening mode
  void setContinuousListening(bool enabled) {
    _continuousListening = enabled;
    notifyListeners();

    print('${enabled ? '🔄' : '⏯️'} Continuous listening ${enabled ? 'enabled' : 'disabled'}');
  }

  // Set pause duration for continuous listening
  void setPauseDuration(int seconds) {
    _pauseDuration = seconds.clamp(1, 10);
    notifyListeners();

    print('⏱️ Pause duration set to $_pauseDuration seconds');
  }

  // Clear text
  void clearText() {
    _text = '';
    _lastWords = '';
    _translatedText = '';
    _confidence = 1.0;
    notifyListeners();

    print('🗑️ Text cleared');
  }

  // Get available speech locales
  Future<List<String>> getAvailableLocales() async {
    if (!_isAvailable) return [];

    try {
      final locales = await _speech.locales();
      return locales.map((locale) => locale.localeId).toList();
    } catch (e) {
      print('❌ Error getting locales: $e');
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
    if (!_isAvailable) return 'unavailable';
    if (_isListening) return 'listening';
    return 'ready';
  }

  // Dispose
  @override
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }
}

// Data model for transcription items
class TranscriptionItem {
  final String id;
  final String speaker;
  final String originalText;
  final String? translatedText;
  final DateTime timestamp;
  final bool isCurrentUser;
  final double confidence;
  final String sourceLanguage;
  final String? targetLanguage;

  TranscriptionItem({
    required this.id,
    required this.speaker,
    required this.originalText,
    this.translatedText,
    required this.timestamp,
    this.isCurrentUser = false,
    this.confidence = 1.0,
    this.sourceLanguage = 'en',
    this.targetLanguage,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'speaker': speaker,
    'originalText': originalText,
    'translatedText': translatedText,
    'timestamp': timestamp.toIso8601String(),
    'isCurrentUser': isCurrentUser,
    'confidence': confidence,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
  };

  // Create from JSON
  factory TranscriptionItem.fromJson(Map<String, dynamic> json) => TranscriptionItem(
    id: json['id'],
    speaker: json['speaker'],
    originalText: json['originalText'],
    translatedText: json['translatedText'],
    timestamp: DateTime.parse(json['timestamp']),
    isCurrentUser: json['isCurrentUser'] ?? false,
    confidence: json['confidence']?.toDouble() ?? 1.0,
    sourceLanguage: json['sourceLanguage'] ?? 'en',
    targetLanguage: json['targetLanguage'],
  );
}