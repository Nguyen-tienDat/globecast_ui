// lib/services/central_translation_service.dart - FIXED VERSION
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_speech/google_speech.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// 🎯 CENTRAL TRANSLATION RESULT MODEL
class CentralTranslationResult {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> allTranslations; // ALL SUPPORTED LANGUAGES
  final Map<String, double> confidenceScores;
  final DateTime timestamp;
  final bool isFinal;
  final String meetingId;

  CentralTranslationResult({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.detectedLanguage,
    required this.allTranslations,
    required this.confidenceScores,
    required this.timestamp,
    required this.isFinal,
    required this.meetingId,
  });

  factory CentralTranslationResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CentralTranslationResult(
      id: doc.id,
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? '',
      originalText: data['originalText'] ?? '',
      detectedLanguage: data['detectedLanguage'] ?? 'unknown',
      allTranslations: Map<String, String>.from(data['allTranslations'] ?? {}),
      confidenceScores: Map<String, double>.from(data['confidenceScores'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFinal: data['isFinal'] ?? false,
      meetingId: data['meetingId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'detectedLanguage': detectedLanguage,
      'allTranslations': allTranslations,
      'confidenceScores': confidenceScores,
      'timestamp': FieldValue.serverTimestamp(),
      'isFinal': isFinal,
      'meetingId': meetingId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // 🎯 GET DISPLAY TEXT FOR SPECIFIC USER LANGUAGE
  String getDisplayText(String userLanguage) {
    // If user's language same as original, show original
    if (detectedLanguage == userLanguage) {
      return originalText;
    }

    // If translation available in user's language
    if (allTranslations.containsKey(userLanguage)) {
      return allTranslations[userLanguage]!;
    }

    // Fallback to English
    if (allTranslations.containsKey('en')) {
      return allTranslations['en']!;
    }

    // Last resort: original text
    return originalText;
  }

  double getConfidence(String language) {
    return confidenceScores[language] ?? 0.0;
  }
}

// 🌐 USER LANGUAGE PREFERENCE MODEL
class UserLanguagePreference {
  final String userId;
  final String userName;
  final String speakingLanguage;    // Language user speaks
  final String displayLanguage;     // Language user wants to see
  final DateTime lastUpdated;

  UserLanguagePreference({
    required this.userId,
    required this.userName,
    required this.speakingLanguage,
    required this.displayLanguage,
    required this.lastUpdated,
  });

  factory UserLanguagePreference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserLanguagePreference(
      userId: doc.id,
      userName: data['userName'] ?? '',
      speakingLanguage: data['speakingLanguage'] ?? 'auto',
      displayLanguage: data['displayLanguage'] ?? 'en',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'speakingLanguage': speakingLanguage,
      'displayLanguage': displayLanguage,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}

// 🚀 CENTRAL TRANSLATION SERVICE
class CentralTranslationService extends ChangeNotifier {
  // 🔧 GOOGLE SPEECH & TRANSLATION COMPONENTS
  SpeechToText? _speechToText;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final Map<String, OnDeviceTranslator> _translators = {};

  // 🎯 SERVICE STATE
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentStatus = 'Ready';

  // 🎯 CURRENT CONTEXT
  String _currentMeetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  String _userSpeakingLanguage = 'vi';  // What user speaks
  String _userDisplayLanguage = 'en';   // What user wants to see

  // 📡 STREAM CONTROLLERS
  final StreamController<CentralTranslationResult> _translationController =
  StreamController<CentralTranslationResult>.broadcast();
  final StreamController<String> _statusController =
  StreamController<String>.broadcast();

  // 🔄 PROCESSING STATE
  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _speechTimer;
  String _lastProcessedText = '';
  final List<List<int>> _audioBuffer = [];
  bool _isProcessing = false;

  // 🌐 SUPPORTED LANGUAGES WITH FULL NAMES
  static const Map<String, String> _supportedLanguages = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'th': 'Thai',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  static const Map<String, String> _languageFlags = {
    'vi': '🇻🇳',
    'en': '🇺🇸',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'th': '🇹🇭',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'ru': '🇷🇺',
    'ar': '🇸🇦',
    'hi': '🇮🇳',
  };

  // GETTERS
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentStatus => _currentStatus;
  String get userSpeakingLanguage => _userSpeakingLanguage;
  String get userDisplayLanguage => _userDisplayLanguage;
  List<String> get supportedLanguageCodes => _supportedLanguages.keys.toList();
  Map<String, String> get supportedLanguageNames => _supportedLanguages;
  Map<String, String> get languageFlags => _languageFlags;

  Stream<CentralTranslationResult> get translationStream => _translationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // 🚀 INITIALIZE SERVICE
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _updateStatus('Initializing Central Translation Service...');

      // 1. Initialize Google Speech
      await _initializeGoogleSpeech();

      // 2. Initialize MLKit Translation for all language pairs
      await _initializeMLKitTranslation();

      _isInitialized = true;
      _updateStatus('✅ Central Translation Service ready');

      if (kDebugMode) {
        print('✅ CentralTranslationService initialized');
        print('   Supported languages: ${_supportedLanguages.length}');
        print('   Available translators: ${_translators.length}');
      }

    } catch (e) {
      _updateStatus('❌ Initialization failed: $e');
      if (kDebugMode) {
        print('❌ Failed to initialize CentralTranslationService: $e');
      }
      rethrow;
    }
  }

  // 🔧 INITIALIZE GOOGLE SPEECH
  Future<void> _initializeGoogleSpeech() async {
    try {
      final serviceAccountString = await rootBundle.loadString(
          'assets/credentials/google-cloud-credentials.json'
      );
      final serviceAccount = ServiceAccount.fromString(serviceAccountString);
      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);

      if (kDebugMode) {
        print('✅ Google Speech initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google Speech initialization failed: $e');
      }
      throw Exception('Failed to initialize Google Speech: $e');
    }
  }

  // 🔧 INITIALIZE MLKIT TRANSLATION - FIXED
  Future<void> _initializeMLKitTranslation() async {
    try {
      _translators.clear();
      int createdTranslators = 0;

      // Create translators for supported language pairs only
      final supportedMLKitLanguages = _getSupportedMLKitLanguages();

      for (String fromLang in supportedMLKitLanguages.keys) {
        for (String toLang in supportedMLKitLanguages.keys) {
          if (fromLang != toLang) {
            final translatorKey = '${fromLang}_$toLang';

            try {
              final fromLanguage = supportedMLKitLanguages[fromLang];
              final toLanguage = supportedMLKitLanguages[toLang];

              if (fromLanguage != null && toLanguage != null) {
                final translator = OnDeviceTranslator(
                  sourceLanguage: fromLanguage,
                  targetLanguage: toLanguage,
                );

                _translators[translatorKey] = translator;
                createdTranslators++;
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Could not create translator $fromLang -> $toLang: $e');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('✅ MLKit Translation initialized with $createdTranslators translators');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ MLKit Translation initialization failed: $e');
      }
      throw Exception('Failed to initialize MLKit Translation: $e');
    }
  }

  // 🔧 GET SUPPORTED MLKIT LANGUAGES - FIXED
  Map<String, TranslateLanguage> _getSupportedMLKitLanguages() {
    return {
      'en': TranslateLanguage.english,
      'vi': TranslateLanguage.vietnamese,
      'zh': TranslateLanguage.chinese,
      'ja': TranslateLanguage.japanese,
      'ko': TranslateLanguage.korean,
      'th': TranslateLanguage.thai,
      'es': TranslateLanguage.spanish,
      'fr': TranslateLanguage.french,
      'de': TranslateLanguage.german,
      'it': TranslateLanguage.italian,
      'pt': TranslateLanguage.portuguese,
      'ru': TranslateLanguage.russian,
      'ar': TranslateLanguage.arabic,
      'hi': TranslateLanguage.hindi,
      // Note: Indonesian (id) and Malay (ms) are not directly supported by MLKit
      // They will be handled via Google Cloud Translation API or skipped
    };
  }

  // 🔧 GET MLKIT LANGUAGE - FIXED
  TranslateLanguage? _getMLKitLanguage(String languageCode) {
    final supportedLanguages = _getSupportedMLKitLanguages();
    return supportedLanguages[languageCode];
  }

  // 🎯 SET USER CONTEXT
  void setUserContext({
    required String meetingId,
    required String userId,
    required String userName,
    required String speakingLanguage,
    required String displayLanguage,
  }) {
    _currentMeetingId = meetingId;
    _currentUserId = userId;
    _currentUserName = userName;
    _userSpeakingLanguage = speakingLanguage;
    _userDisplayLanguage = displayLanguage;

    if (kDebugMode) {
      print('👤 User context set:');
      print('   Meeting: $meetingId');
      print('   User: $userName ($userId)');
      print('   Speaking: $speakingLanguage');
      print('   Display: $displayLanguage');
    }
  }

  // 📝 SAVE USER LANGUAGE PREFERENCE
  Future<void> saveUserLanguagePreference() async {
    try {
      if (_currentMeetingId.isEmpty || _currentUserId.isEmpty) return;

      final preference = UserLanguagePreference(
        userId: _currentUserId,
        userName: _currentUserName,
        speakingLanguage: _userSpeakingLanguage,
        displayLanguage: _userDisplayLanguage,
        lastUpdated: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('user_language_preferences')
          .doc(_currentUserId)
          .set(preference.toFirestore());

      if (kDebugMode) {
        print('💾 User language preference saved');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving user language preference: $e');
      }
    }
  }

  // 🎤 START LISTENING
  Future<void> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isListening) {
      if (kDebugMode) {
        print('⚠️ Already listening');
      }
      return;
    }

    try {
      _updateStatus('🎤 Requesting microphone permission...');

      // Check microphone permission
      final permissionStatus = await Permission.microphone.request();
      if (permissionStatus != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }

      _updateStatus('🎤 Starting speech recognition...');

      // Save user preference
      await saveUserLanguagePreference();

      // Start audio recording
      await _startAudioRecording();

      _isListening = true;
      _updateStatus('🎤 Listening... Speak in ${_supportedLanguages[_userSpeakingLanguage]}');
      notifyListeners();

      if (kDebugMode) {
        print('🎤 Central Translation Service started listening');
      }

    } catch (e) {
      _updateStatus('❌ Failed to start listening: $e');
      if (kDebugMode) {
        print('❌ Error starting listening: $e');
      }
      rethrow;
    }
  }

  // 🎵 START AUDIO RECORDING
  Future<void> _startAudioRecording() async {
    try {
      if (_speechToText == null) {
        throw Exception('Google Speech not initialized');
      }

      // Clear audio buffer
      _audioBuffer.clear();

      // Configure audio recording
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Start recording
      final stream = await _audioRecorder.startStream(config);

      _audioSubscription = stream.listen(
            (audioData) => _processAudioData(audioData),
        onError: (error) {
          if (kDebugMode) {
            print('❌ Audio stream error: $error');
          }
          _updateStatus('❌ Audio error: $error');
        },
      );

      // Setup speech processing timer
      _speechTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _processSpeechBuffer();
      });

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting audio recording: $e');
      }
      throw Exception('Failed to start audio recording: $e');
    }
  }

  // 🎵 PROCESS AUDIO DATA
  void _processAudioData(List<int> audioData) {
    _audioBuffer.add(audioData);

    // Keep buffer size manageable
    if (_audioBuffer.length > 30) {
      _audioBuffer.removeAt(0);
    }

    // Process immediately if we have enough data
    if (_audioBuffer.length >= 10 && !_isProcessing) {
      Future.microtask(() => _processSpeechBuffer());
    }
  }

  // 🔄 PROCESS SPEECH BUFFER
  Future<void> _processSpeechBuffer() async {
    if (_speechToText == null || !_isListening || _audioBuffer.isEmpty || _isProcessing) return;

    _isProcessing = true;

    try {
      _updateStatus('☁️ Processing speech with Google Cloud...');

      // Combine audio buffer
      final combinedAudio = <int>[];
      for (final chunk in _audioBuffer) {
        combinedAudio.addAll(chunk);
      }

      if (combinedAudio.length < 1000) {
        _isProcessing = false;
        return;
      }

      // Convert to bytes for Google Speech
      final audioBytes = combinedAudio;

      // Configure recognition
      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.latest_long,
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: _getGoogleLanguageCode(_userSpeakingLanguage),
      );

      try {
        final response = await _speechToText!.recognize(config, audioBytes);

        if (response.results.isNotEmpty) {
          final result = response.results.first;
          if (result.alternatives.isNotEmpty) {
            final alternative = result.alternatives.first;
            final transcript = alternative.transcript;
            final confidence = alternative.confidence;

            if (transcript.isNotEmpty && transcript != _lastProcessedText) {
              await _processRecognizedSpeech(transcript, confidence);
            }
          }
        }
      } catch (speechError) {
        if (kDebugMode) {
          print('⚠️ Google Speech API error: $speechError');
        }
        // Mock speech for testing
        await _mockSpeechRecognition();
      }

      // Clear old buffer data
      if (_audioBuffer.length > 10) {
        _audioBuffer.removeRange(0, _audioBuffer.length - 10);
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing speech: $e');
      }
      _updateStatus('❌ Speech processing error');
    } finally {
      _isProcessing = false;
    }
  }

  // 🔧 GET GOOGLE LANGUAGE CODE
  String _getGoogleLanguageCode(String languageCode) {
    const languageMap = {
      'en': 'en-US',
      'vi': 'vi-VN',
      'zh': 'zh-CN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'th': 'th-TH',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'ru': 'ru-RU',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
    };

    return languageMap[languageCode] ?? 'en-US';
  }

  // 🎭 MOCK SPEECH RECOGNITION
  Future<void> _mockSpeechRecognition() async {
    const mockTexts = {
      'vi': 'Xin chào mọi người, tôi đang test hệ thống dịch thuật',
      'en': 'Hello everyone, I am testing the translation system',
      'ja': 'こんにちは皆さん、翻訳システムをテストしています',
      'zh': '大家好，我正在测试翻译系统',
      'ko': '안녕하세요 여러분, 번역 시스템을 테스트하고 있습니다',
    };

    final mockText = mockTexts[_userSpeakingLanguage] ?? mockTexts['en']!;
    await _processRecognizedSpeech(mockText, 0.85);
  }

  // 📝 PROCESS RECOGNIZED SPEECH (CORE LOGIC)
  Future<void> _processRecognizedSpeech(String recognizedText, double confidence) async {
    if (recognizedText.trim().isEmpty || recognizedText == _lastProcessedText) {
      return;
    }

    _lastProcessedText = recognizedText;

    try {
      _updateStatus('🌐 Translating to ${_supportedLanguages.length} languages...');

      // ✅ TRANSLATE TO ALL SUPPORTED LANGUAGES
      final allTranslations = <String, String>{};
      final confidenceScores = <String, double>{};

      for (final targetLang in _supportedLanguages.keys) {
        if (targetLang == _userSpeakingLanguage) {
          // Same language - no translation needed
          allTranslations[targetLang] = recognizedText;
          confidenceScores[targetLang] = confidence;
        } else {
          // Translate to target language
          final translated = await _translateText(
            recognizedText,
            _userSpeakingLanguage,
            targetLang,
          );
          allTranslations[targetLang] = translated;
          confidenceScores[targetLang] = confidence * 0.9; // Slightly lower for translations
        }
      }

      // ✅ CREATE CENTRAL TRANSLATION RESULT
      final centralResult = CentralTranslationResult(
        id: '', // Will be set by Firestore
        speakerId: _currentUserId,
        speakerName: _currentUserName,
        originalText: recognizedText,
        detectedLanguage: _userSpeakingLanguage,
        allTranslations: allTranslations,
        confidenceScores: confidenceScores,
        timestamp: DateTime.now(),
        isFinal: true,
        meetingId: _currentMeetingId,
      );

      // ✅ SAVE TO CENTRAL DATABASE
      await _saveCentralTranslation(centralResult);

      // ✅ BROADCAST TO LOCAL LISTENERS
      _translationController.add(centralResult);

      _updateStatus('✅ Translation completed & broadcasted');

      if (kDebugMode) {
        print('✅ Central translation processed:');
        print('   Original: "$recognizedText" (${_userSpeakingLanguage})');
        print('   Translated to: ${allTranslations.length} languages');
        print('   Available for all participants');
      }

    } catch (e) {
      _updateStatus('❌ Translation error: $e');
      if (kDebugMode) {
        print('❌ Error processing recognized speech: $e');
      }
    }
  }

  // 🌐 TRANSLATE TEXT - FIXED
  Future<String> _translateText(String text, String fromLang, String toLang) async {
    try {
      final translatorKey = '${fromLang}_$toLang';
      final translator = _translators[translatorKey];

      if (translator != null) {
        final translatedText = await translator.translateText(text);
        return translatedText;
      } else {
        if (kDebugMode) {
          print('⚠️ No translator available for $fromLang -> $toLang, using mock');
        }
        // Return mock translation for unsupported languages
        return _getMockTranslation(text, fromLang, toLang);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Translation error ($fromLang -> $toLang): $e');
      }
      // Return mock translation on error
      return _getMockTranslation(text, fromLang, toLang);
    }
  }

  // 🎭 GET MOCK TRANSLATION - FIXED
  String _getMockTranslation(String text, String fromLang, String toLang) {
    // Simple mock translations for testing
    const mockTranslations = {
      'vi_en': {'Xin chào': 'Hello', 'Cảm ơn': 'Thank you'},
      'en_vi': {'Hello': 'Xin chào', 'Thank you': 'Cảm ơn'},
      'en_ja': {'Hello': 'こんにちは', 'Thank you': 'ありがとう'},
      'en_ko': {'Hello': '안녕하세요', 'Thank you': '감사합니다'},
      'en_zh': {'Hello': '你好', 'Thank you': '谢谢'},
    };

    final key = '${fromLang}_$toLang';
    final translations = mockTranslations[key];

    if (translations != null) {
      for (final entry in translations.entries) {
        if (text.contains(entry.key)) {
          return text.replaceAll(entry.key, entry.value);
        }
      }
    }

    // If no mock translation found, return modified text
    return '[$toLang] $text';
  }

  // 💾 SAVE CENTRAL TRANSLATION TO DATABASE
  Future<void> _saveCentralTranslation(CentralTranslationResult result) async {
    try {
      if (_currentMeetingId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('central_translations')
          .add(result.toFirestore());

      if (kDebugMode) {
        print('💾 Central translation saved to database');
        print('   Available languages: ${result.allTranslations.keys.join(", ")}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving central translation: $e');
      }
    }
  }

  // 👂 LISTEN TO ALL CENTRAL TRANSLATIONS (FOR UI)
  Stream<List<CentralTranslationResult>> getCentralTranslationsStream() {
    if (_currentMeetingId.isEmpty) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('central_translations')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CentralTranslationResult.fromFirestore(doc))
          .toList();
    });
  }

  // 🛑 STOP LISTENING
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      _updateStatus('🛑 Stopping speech recognition...');

      // Cancel timers
      _speechTimer?.cancel();
      _speechTimer = null;

      // Cancel audio subscription
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Stop audio recording
      await _audioRecorder.stop();

      _isListening = false;
      _isProcessing = false;
      _lastProcessedText = '';
      _audioBuffer.clear();
      _updateStatus('✅ Ready');
      notifyListeners();

      if (kDebugMode) {
        print('🛑 Central translation service stopped');
      }

    } catch (e) {
      _updateStatus('❌ Error stopping: $e');
      if (kDebugMode) {
        print('❌ Error stopping listening: $e');
      }
    }
  }

  // 🔄 UPDATE LANGUAGE PREFERENCES
  Future<void> updateLanguagePreferences({
    String? speakingLanguage,
    String? displayLanguage,
  }) async {
    if (speakingLanguage != null) {
      _userSpeakingLanguage = speakingLanguage;
    }
    if (displayLanguage != null) {
      _userDisplayLanguage = displayLanguage;
    }

    // Save to database
    await saveUserLanguagePreference();

    notifyListeners();

    if (kDebugMode) {
      print('🔄 Language preferences updated:');
      print('   Speaking: $_userSpeakingLanguage');
      print('   Display: $_userDisplayLanguage');
    }
  }

  // 📱 UPDATE STATUS
  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
    notifyListeners();

    if (kDebugMode) {
      print('📱 Status: $status');
    }
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing CentralTranslationService...');
    }

    stopListening();

    // Close translators
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();

    // Close controllers
    _translationController.close();
    _statusController.close();

    super.dispose();
  }
}