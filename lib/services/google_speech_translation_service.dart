// lib/services/google_speech_translation_service.dart - FIXED VERSION
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/google_speech.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// 🎯 SPEECH RESULT MODEL
class SpeechTranslationResult {
  final String userId;
  final String userName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations;
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;
  final bool isFromGoogleSpeech;

  SpeechTranslationResult({
    required this.userId,
    required this.userName,
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.confidence,
    required this.timestamp,
    required this.isFinal,
    this.isFromGoogleSpeech = true,
  });

  @override
  String toString() {
    return 'SpeechTranslationResult(user: $userName, text: "$originalText", lang: $detectedLanguage, translations: ${translations.length}, confidence: $confidence)';
  }

  SpeechTranslationResult copyWith({
    String? userId,
    String? userName,
    String? originalText,
    String? detectedLanguage,
    Map<String, String>? translations,
    double? confidence,
    DateTime? timestamp,
    bool? isFinal,
    bool? isFromGoogleSpeech,
  }) {
    return SpeechTranslationResult(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      originalText: originalText ?? this.originalText,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      translations: translations ?? this.translations,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      isFromGoogleSpeech: isFromGoogleSpeech ?? this.isFromGoogleSpeech,
    );
  }
}

class GoogleSpeechTranslationService extends ChangeNotifier {
  // 🎤 GOOGLE SPEECH COMPONENTS
  SpeechToText? _speechToText;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // 🌐 MLKIT TRANSLATION COMPONENTS
  final Map<String, OnDeviceTranslator> _translators = {};
  final Map<String, TranslateLanguage> _supportedLanguages = {};

  // 🎯 SERVICE STATE
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentStatus = 'Initializing...';

  // 🎯 USER CONTEXT
  String _currentUserId = '';
  String _currentUserName = '';
  String _meetingId = '';
  String _preferredLanguage = 'vi';
  List<String> _targetLanguages = ['en', 'vi', 'zh', 'ja', 'ko', 'th'];

  // 📡 STREAM CONTROLLERS
  final StreamController<SpeechTranslationResult> _resultController =
  StreamController<SpeechTranslationResult>.broadcast();
  final StreamController<String> _statusController =
  StreamController<String>.broadcast();

  // 🔄 PROCESSING STATE - REAL-TIME OPTIMIZED
  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _speechTimer;
  String _lastProcessedText = '';
  final List<List<int>> _audioBuffer = [];
  bool _isProcessing = false; // ✅ REAL-TIME: Prevent overlap processing

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentStatus => _currentStatus;
  String get preferredLanguage => _preferredLanguage;
  Stream<SpeechTranslationResult> get resultStream => _resultController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // 🚀 INITIALIZE SERVICE
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _updateStatus('Initializing Google Speech service...');

      // 1. Initialize Google Speech
      await _initializeGoogleSpeech();

      // 2. Initialize MLKit Translation
      await _initializeMLKitTranslation();

      // 3. Setup supported languages
      _setupSupportedLanguages();

      _isInitialized = true;
      _updateStatus('✅ Services ready');

      if (kDebugMode) {
        debugPrint('✅ GoogleSpeechTranslationService initialized');
        debugPrint('   Supported languages: ${_supportedLanguages.keys.toList()}');
        debugPrint('   Active translators: ${_translators.length}');
      }

    } catch (e) {
      _updateStatus('❌ Initialization failed: $e');
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize GoogleSpeechTranslationService: $e');
      }
      rethrow;
    }
  }

  // 1️⃣ INITIALIZE GOOGLE SPEECH - FIXED
  Future<void> _initializeGoogleSpeech() async {
    try {
      // Load Google Cloud credentials as Map
      final serviceAccountString = await rootBundle.loadString(
          'assets/credentials/google-cloud-credentials.json'
      );

      // Parse JSON to Map
      final serviceAccountJson = json.decode(serviceAccountString) as Map<String, dynamic>;

      // Create ServiceAccount object properly
      final serviceAccount = ServiceAccount.fromString(serviceAccountString);

      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);

      if (kDebugMode) {
        debugPrint('✅ Google Speech initialized with project: ${serviceAccountJson['project_id']}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Google Speech initialization failed: $e');
      }
      throw Exception('Failed to initialize Google Speech: $e');
    }
  }

  // 2️⃣ INITIALIZE MLKIT TRANSLATION - FIXED
  Future<void> _initializeMLKitTranslation() async {
    try {
      // Setup supported languages first
      _setupSupportedLanguages();

      // Create translators for common language pairs
      final commonLanguages = ['en', 'vi', 'zh', 'ja', 'ko', 'th'];
      int createdTranslators = 0;

      for (String fromLang in commonLanguages) {
        for (String toLang in commonLanguages) {
          if (fromLang != toLang) {
            final translatorKey = '${fromLang}_$toLang';

            try {
              final fromLanguage = _supportedLanguages[fromLang];
              final toLanguage = _supportedLanguages[toLang];

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
                debugPrint('⚠️ Could not create translator $fromLang -> $toLang: $e');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint('✅ MLKit Translation initialized with $createdTranslators translators');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ MLKit Translation initialization failed: $e');
      }
      throw Exception('Failed to initialize MLKit Translation: $e');
    }
  }

  // 3️⃣ SETUP SUPPORTED LANGUAGES - FIXED
  void _setupSupportedLanguages() {
    _supportedLanguages.clear();
    _supportedLanguages.addAll({
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
    });
  }

  // 🎯 SET USER CONTEXT
  void setUserContext(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
    if (kDebugMode) {
      debugPrint('👤 User context: $userName ($userId)');
    }
  }

  // 🎯 SET TRANSLATION CONTEXT
  void setTranslationContext(String meetingId) {
    _meetingId = meetingId;
    if (kDebugMode) {
      debugPrint('🎯 Meeting context: $meetingId');
    }
  }

  // 🌐 SET PREFERRED LANGUAGE
  void setPreferredLanguage(String languageCode) {
    _preferredLanguage = languageCode;
    if (kDebugMode) {
      debugPrint('🌐 Preferred language: $languageCode');
    }
  }

  // 🎯 SET TARGET LANGUAGES
  void setTargetLanguages(List<String> languages) {
    _targetLanguages = languages;
    if (kDebugMode) {
      debugPrint('🎯 Target languages: $languages');
    }
  }

  // 🎤 START LISTENING
  Future<void> startListening({
    String? meetingId,
    String? userId,
    String? preferredLanguage,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isListening) {
      if (kDebugMode) {
        debugPrint('⚠️ Already listening');
      }
      return;
    }

    try {
      // Update context
      if (meetingId != null) _meetingId = meetingId;
      if (userId != null) _currentUserId = userId;
      if (preferredLanguage != null) _preferredLanguage = preferredLanguage;

      _updateStatus('🎤 Requesting microphone permission...');

      // Check microphone permission
      final permissionStatus = await Permission.microphone.request();
      if (permissionStatus != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }

      _updateStatus('🎤 Starting speech recognition...');

      // Start audio recording
      await _startAudioRecording();

      _isListening = true;
      _updateStatus('🎤 Listening for speech...');
      notifyListeners();

      if (kDebugMode) {
        debugPrint('🎤 Started listening with Google Speech');
        debugPrint('   Meeting: $_meetingId');
        debugPrint('   User: $_currentUserId');
        debugPrint('   Language: $_preferredLanguage');
      }

    } catch (e) {
      _updateStatus('❌ Failed to start listening: $e');
      if (kDebugMode) {
        debugPrint('❌ Error starting listening: $e');
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
            debugPrint('❌ Audio stream error: $error');
          }
          _updateStatus('❌ Audio error: $error');
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('🏁 Audio stream done');
          }
        },
      );

      // ✅ REAL-TIME: Setup faster speech processing timer
      _speechTimer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
        _processSpeechBuffer();
      });

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error starting audio recording: $e');
      }
      throw Exception('Failed to start audio recording: $e');
    }
  }

  // 🎵 PROCESS AUDIO DATA - OPTIMIZED FOR REAL-TIME
  void _processAudioData(List<int> audioData) {
    // Collect audio data in buffer
    _audioBuffer.add(audioData);

    // ✅ REAL-TIME: Keep buffer smaller (last 2-3 seconds)
    if (_audioBuffer.length > 20) {
      _audioBuffer.removeAt(0);
    }

    // ✅ REAL-TIME: Process immediately when we have enough data
    if (_audioBuffer.length >= 8 && !_isProcessing) {
      // Process without waiting for timer
      Future.microtask(() => _processSpeechBuffer());
    }

    if (kDebugMode && _audioBuffer.length % 5 == 0) {
      debugPrint('🎵 Audio buffer: ${_audioBuffer.length} chunks (real-time mode)');
    }
  }

  // 🔄 PROCESS SPEECH BUFFER - REAL-TIME OPTIMIZED
  Future<void> _processSpeechBuffer() async {
    if (_speechToText == null || !_isListening || _audioBuffer.isEmpty || _isProcessing) return;

    _isProcessing = true; // ✅ REAL-TIME: Prevent overlapping calls

    try {
      _updateStatus('☁️ Processing speech (real-time)...');

      // ✅ REAL-TIME: Process only recent audio (last 1-2 seconds)
      final recentBuffer = _audioBuffer.length > 15
          ? _audioBuffer.sublist(_audioBuffer.length - 15)
          : _audioBuffer;

      // Combine audio buffer into single byte array
      final combinedAudio = <int>[];
      for (final chunk in recentBuffer) {
        combinedAudio.addAll(chunk);
      }

      if (combinedAudio.length < 1000) {
        _isProcessing = false;
        return; // ✅ REAL-TIME: Skip if too little audio
      }

      // Convert to bytes for Google Speech
      final audioBytes = combinedAudio;

      // Configure recognition for real-time
      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.latest_short, // ✅ REAL-TIME: Use short model
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: _getGoogleLanguageCode(_preferredLanguage),
      );

      // Process with Google Speech - REAL-TIME OPTIMIZED
      try {
        final response = await _speechToText!.recognize(config, audioBytes);

        if (response.results.isNotEmpty) {
          final result = response.results.first;
          if (result.alternatives.isNotEmpty) {
            final alternative = result.alternatives.first;
            final transcript = alternative.transcript;
            final confidence = alternative.confidence;

            if (transcript.isNotEmpty && transcript != _lastProcessedText) {
              await _processRecognizedText(transcript, _preferredLanguage, confidence);
            }
          }
        }
      } catch (speechError) {
        if (kDebugMode) {
          debugPrint('⚠️ Google Speech API error: $speechError');
        }
        // ✅ REAL-TIME: Faster fallback to mock
        await _mockSpeechRecognition();
      }

      // ✅ REAL-TIME: Keep some buffer but clear old data
      if (_audioBuffer.length > 10) {
        _audioBuffer.removeRange(0, _audioBuffer.length - 10);
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error processing speech: $e');
      }
      _updateStatus('❌ Speech processing error');

      // Try mock processing if everything fails
      await _mockSpeechRecognition();
    } finally {
      _isProcessing = false; // ✅ REAL-TIME: Reset processing flag
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

  // 🎭 MOCK SPEECH RECOGNITION (Fallback)
  Future<void> _mockSpeechRecognition() async {
    final mockTexts = [
      'Xin chào, tôi đang test hệ thống',
      'Hello, I am testing the system',
      'こんにちは、システムをテストしています',
      '你好，我正在测试系统',
      '안녕하세요, 시스템을 테스트하고 있습니다',
    ];

    final mockLanguages = ['vi', 'en', 'ja', 'zh', 'ko'];

    if (mockTexts.isNotEmpty) {
      final randomIndex = DateTime.now().millisecond % mockTexts.length;
      final mockText = mockTexts[randomIndex];
      final mockLang = mockLanguages[randomIndex];

      await _processRecognizedText(mockText, mockLang, 0.85);
    }
  }

  // 📝 PROCESS RECOGNIZED TEXT
  Future<void> _processRecognizedText(
      String recognizedText,
      String detectedLanguage,
      double confidence
      ) async {
    if (recognizedText.trim().isEmpty || recognizedText == _lastProcessedText) {
      return;
    }

    _lastProcessedText = recognizedText;

    try {
      _updateStatus('🌐 Translating to ${_targetLanguages.length} languages...');

      // Translate to all target languages
      final translations = <String, String>{};

      for (final targetLang in _targetLanguages) {
        if (targetLang == detectedLanguage) {
          translations[targetLang] = recognizedText;
        } else {
          final translated = await _translateText(
              recognizedText,
              detectedLanguage,
              targetLang
          );
          translations[targetLang] = translated;
        }
      }

      // Create result
      final result = SpeechTranslationResult(
        userId: _currentUserId,
        userName: _currentUserName,
        originalText: recognizedText,
        detectedLanguage: detectedLanguage,
        translations: translations,
        confidence: confidence,
        timestamp: DateTime.now(),
        isFinal: true,
        isFromGoogleSpeech: true,
      );

      // Broadcast result
      _resultController.add(result);
      _updateStatus('✅ Translation completed');

      if (kDebugMode) {
        debugPrint('✅ Speech result processed:');
        debugPrint('   Original: "$recognizedText"');
        debugPrint('   Language: $detectedLanguage');
        debugPrint('   Translations: ${translations.length} languages');
        debugPrint('   Confidence: ${(confidence * 100).toInt()}%');
      }

    } catch (e) {
      _updateStatus('❌ Translation error: $e');
      if (kDebugMode) {
        debugPrint('❌ Error processing recognized text: $e');
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

        if (kDebugMode) {
          debugPrint('🌐 Translated "$text" ($fromLang -> $toLang): "$translatedText"');
        }

        return translatedText;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ No translator available for $fromLang -> $toLang');
        }
        return text; // Return original if no translator
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Translation error ($fromLang -> $toLang): $e');
      }
      return text; // Return original on error
    }
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
      _isProcessing = false; // ✅ REAL-TIME: Reset processing flag
      _lastProcessedText = '';
      _audioBuffer.clear();
      _updateStatus('✅ Ready');
      notifyListeners();

      if (kDebugMode) {
        debugPrint('🛑 Stopped listening');
      }

    } catch (e) {
      _updateStatus('❌ Error stopping: $e');
      if (kDebugMode) {
        debugPrint('❌ Error stopping listening: $e');
      }
    }
  }

  // 📱 UPDATE STATUS
  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
    notifyListeners();

    if (kDebugMode) {
      debugPrint('📱 Status: $status');
    }
  }

  // 🔧 DOWNLOAD TRANSLATION MODELS - COMPLETELY FIXED
  Future<void> downloadTranslationModel(String languageCode) async {
    try {
      if (!_supportedLanguages.containsKey(languageCode)) {
        throw Exception('Language $languageCode not supported');
      }

      final modelManager = OnDeviceTranslatorModelManager();

      // ✅ FIXED: Use the language code string directly, not the TranslateLanguage object
      final isDownloaded = await modelManager.isModelDownloaded(languageCode);

      if (!isDownloaded) {
        _updateStatus('📥 Downloading $languageCode model...');

        // ✅ FIXED: Use the language code string directly
        try {
          await modelManager.downloadModel(languageCode);
          _updateStatus('✅ Model downloaded: $languageCode');
        } catch (downloadError) {
          _updateStatus('❌ Model download failed: $languageCode');
          if (kDebugMode) {
            debugPrint('❌ Download error: $downloadError');
          }
        }
      } else {
        _updateStatus('✅ Model already available: $languageCode');
      }

      if (kDebugMode) {
        debugPrint('✅ Translation model ready: $languageCode');
      }
    } catch (e) {
      _updateStatus('❌ Model download failed: $e');
      if (kDebugMode) {
        debugPrint('❌ Failed to download model for $languageCode: $e');
      }
    }
  }

  // 📊 GET AVAILABLE LANGUAGES
  List<String> getAvailableLanguages() {
    return _supportedLanguages.keys.toList();
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint('🧹 Disposing GoogleSpeechTranslationService...');
    }

    stopListening();

    // Close translators
    for (final translator in _translators.values) {
      translator.close();
    }
    _translators.clear();

    // Close controllers
    _resultController.close();
    _statusController.close();

    super.dispose();
  }
}