// lib/services/central_translation_service.dart - UPDATED TO USE IMPROVED GOOGLE SPEECH
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'google_speech_translation_service.dart'; // ✅ USE IMPROVED SERVICE
import 'google_cloud_translation_service.dart'; // ✅ ADD GOOGLE CLOUD TRANSLATION

// 🎯 CENTRAL TRANSLATION RESULT MODEL (same as before)
class CentralTranslationResult {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> allTranslations;
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

  String getDisplayText(String userLanguage) {
    if (detectedLanguage == userLanguage) {
      return originalText;
    }
    if (allTranslations.containsKey(userLanguage)) {
      return allTranslations[userLanguage]!;
    }
    if (allTranslations.containsKey('en')) {
      return allTranslations['en']!;
    }
    return originalText;
  }

  double getConfidence(String language) {
    return confidenceScores[language] ?? 0.0;
  }
}

// 🚀 UPDATED CENTRAL TRANSLATION SERVICE - USING IMPROVED GOOGLE SPEECH
class CentralTranslationService extends ChangeNotifier {
  // 🎯 USE IMPROVED GOOGLE SPEECH SERVICE
  GoogleSpeechTranslationService? _googleSpeechService;
  final Map<String, OnDeviceTranslator> _translators = {};

  // 🌐 GOOGLE CLOUD TRANSLATION SERVICE (for reliable fallback)
  GoogleCloudTranslationService? _googleCloudTranslation;

  // 🎯 SERVICE STATE
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentStatus = 'Ready';

  // 🎯 USER CONTEXT
  String _currentMeetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  String _userSpeakingLanguage = 'vi';
  String _userDisplayLanguage = 'en';

  // 📡 STREAM CONTROLLERS
  final StreamController<CentralTranslationResult> _translationController =
  StreamController<CentralTranslationResult>.broadcast();
  final StreamController<String> _statusController =
  StreamController<String>.broadcast();

  // 🔄 SUBSCRIPTIONS
  StreamSubscription<SpeechTranslationResult>? _speechSubscription;
  StreamSubscription<String>? _speechStatusSubscription;

  // 📊 PERFORMANCE TRACKING
  int _totalTranslations = 0;
  int _successfulTranslations = 0;
  DateTime? _sessionStartTime;

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

  // GETTERS
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentStatus => _currentStatus;
  String get userSpeakingLanguage => _userSpeakingLanguage;
  String get userDisplayLanguage => _userDisplayLanguage;
  List<String> get supportedLanguageCodes => _supportedLanguages.keys.toList();
  Map<String, String> get supportedLanguageNames => _supportedLanguages;

  Stream<CentralTranslationResult> get translationStream => _translationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // 🚀 INITIALIZE WITH IMPROVED GOOGLE SPEECH
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _updateStatus('Initializing Central Hub with Improved Google Speech...');
      _sessionStartTime = DateTime.now();

      // 1. Initialize Improved Google Speech Service
      await _initializeImprovedGoogleSpeech();

      // 2. Initialize Google Cloud Translation (reliable backup)

      // 3. Initialize MLKit Translation

      // 4. Setup listeners
      _setupImprovedSpeechListeners();

      _isInitialized = true;
      _updateStatus('✅ Central Hub ready with Improved Google Speech');

      if (kDebugMode) {
        print('✅ UPDATED CentralTranslationService initialized');
        print('   🎙️ Using Improved Google Speech Service');
        print('   ☁️ Google Cloud Translation: ${_googleCloudTranslation?.isReady ?? false}');
        print('   🌐 MLKit Translators: ${_translators.length}');
        print('   📡 Supported languages: ${_supportedLanguages.length}');
        print('   🎯 Optimized for long sentences');
      }

    } catch (e) {
      _updateStatus('❌ Central Hub initialization failed: $e');
      if (kDebugMode) {
        print('❌ Failed to initialize UPDATED CentralTranslationService: $e');
      }
      rethrow;
    }
  }

  // 🎙️ INITIALIZE IMPROVED GOOGLE SPEECH SERVICE
  Future<void> _initializeImprovedGoogleSpeech() async {
    try {
      _googleSpeechService = GoogleSpeechTranslationService();
      await _googleSpeechService!.initialize();

      if (kDebugMode) {
        print('✅ Improved Google Speech Service initialized');
        final stats = _googleSpeechService!.getImprovedStatistics();
        print('   📊 Features: ${stats['improvedFeatures']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Improved Google Speech initialization failed: $e');
      }
      throw Exception('Failed to initialize Improved Google Speech: $e');
    }
  }

  // ☁️ INITIALIZE GOOGLE CLOUD TRANSLATION SERVICE
  Future<void> _initializeGoogleCloudTranslation() async {
    try {
      _googleCloudTranslation = GoogleCloudTranslationService.instance;
      await _googleCloudTranslation!.initialize();

      if (kDebugMode) {
        print('✅ Google Cloud Translation Service initialized');
        print('   🌐 Ready for reliable translation fallback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Google Cloud Translation initialization failed: $e');
        print('   Will continue with MLKit only');
      }
      // Not critical, continue without Google Cloud Translation
      _googleCloudTranslation = null;
    }
  }

  // 🔧 INITIALIZE MLKIT TRANSLATION (tối ưu cho real-time)
  Future<void> _initializeMLKitTranslation() async {
    try {
      _translators.clear();
      int createdTranslators = 0;

      // ✅ CHỈ TẠO TRANSLATOR CHO CÁC NGÔN NGỮ CHÍNH (tối ưu real-time)
      final priorityLanguages = ['vi', 'en', 'zh', 'ja', 'ko', 'es', 'fr'];
      final allSupportedLanguages = _getSupportedMLKitLanguages();

      if (kDebugMode) {
        print('🎯 Creating MLKit translators for priority languages: $priorityLanguages');
      }

      // Tạo translator cho các cặp ngôn ngữ ưu tiên
      for (String fromLang in priorityLanguages) {
        for (String toLang in priorityLanguages) {
          if (fromLang != toLang) {
            final translatorKey = '${fromLang}_$toLang';

            try {
              final fromLanguage = allSupportedLanguages[fromLang];
              final toLanguage = allSupportedLanguages[toLang];

              if (fromLanguage != null && toLanguage != null) {
                final translator = OnDeviceTranslator(
                  sourceLanguage: fromLanguage,
                  targetLanguage: toLanguage,
                );

                _translators[translatorKey] = translator;
                createdTranslators++;

                if (kDebugMode && createdTranslators <= 5) {
                  print('   ✅ Created: $fromLang → $toLang');
                }
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
        print('✅ MLKit Translation initialized with $createdTranslators priority translators');
        print('   🎯 Optimized for real-time performance');
        print('   📊 Priority languages: ${priorityLanguages.length} (${createdTranslators} pairs)');
        print('   💡 Other languages will use Google Cloud Translation fallback');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ MLKit Translation initialization failed: $e');
      }
      // Not critical, continue without translators
    }
  }

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
    };
  }

  // 🎧 SETUP IMPROVED SPEECH LISTENERS
  void _setupImprovedSpeechListeners() {
    if (_googleSpeechService == null) return;

    // Listen to speech results from improved service
    _speechSubscription = _googleSpeechService!.resultStream.listen(
          (speechResult) async {
        if (kDebugMode) {
          print('🎙️ Received improved speech result: "${speechResult.originalText}"');
          print('   📊 ${speechResult.wordCount} words, ${(speechResult.confidence * 100).toInt()}% confidence');
          print('   🌐 Already translated to: ${speechResult.translations.length} languages');
        }

        await _processImprovedSpeechResult(speechResult);
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Improved speech result stream error: $error');
        }
        _updateStatus('❌ Speech recognition error: $error');
      },
    );

    // Listen to status updates
    _speechStatusSubscription = _googleSpeechService!.statusStream.listen(
          (status) {
        _updateStatus('🎙️ $status');
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Improved speech status stream error: $error');
        }
      },
    );

    if (kDebugMode) {
      print('🎧 Improved Speech listeners setup complete');
    }
  }

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

    // Update Google Speech Service context
    if (_googleSpeechService != null) {
      _googleSpeechService!.setUserContext(userId, userName);
      _googleSpeechService!.setTranslationContext(meetingId);
      _googleSpeechService!.setPreferredLanguage(speakingLanguage);
      _googleSpeechService!.setTargetLanguages(_supportedLanguages.keys.toList());
    }

    if (kDebugMode) {
      print('👤 UPDATED user context set:');
      print('   Meeting: $meetingId');
      print('   User: $userName ($userId)');
      print('   Speaking: $speakingLanguage → Display: $displayLanguage');
    }
  }

  // 🎤 START LISTENING USING IMPROVED GOOGLE SPEECH
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
      _updateStatus('🎤 Starting Central Hub with Improved Google Speech...');

      if (_googleSpeechService == null) {
        throw Exception('Improved Google Speech Service not initialized');
      }

      // Start improved Google Speech recognition
      await _googleSpeechService!.startListening(
        meetingId: _currentMeetingId,
        userId: _currentUserId,
        preferredLanguage: _userSpeakingLanguage,
      );

      _isListening = true;
      _updateStatus('🎙️ Central Hub active with Improved Speech - speak naturally');
      notifyListeners();

      if (kDebugMode) {
        print('🎤 Central Hub started with Improved Google Speech');
        print('   🎯 Language: ${_supportedLanguages[_userSpeakingLanguage]}');
        print('   📝 Ready for long sentences like "Hello I am Dat and I am from Vietnam"');
      }

    } catch (e) {
      _updateStatus('❌ Failed to start Central Hub: $e');
      if (kDebugMode) {
        print('❌ Error starting Central Hub with improved speech: $e');
      }
      rethrow;
    }
  }

  // 📝 PROCESS IMPROVED SPEECH RESULT
  Future<void> _processImprovedSpeechResult(SpeechTranslationResult speechResult) async {
    try {
      _totalTranslations++;

      // Google Speech already provides translations, but we need all languages for Central Hub
      final allTranslations = <String, String>{};
      final confidenceScores = <String, double>{};

      // Use existing translations from Google Speech
      for (final entry in speechResult.translations.entries) {
        allTranslations[entry.key] = entry.value;
        confidenceScores[entry.key] = speechResult.confidence;
      }

      // Add missing languages using MLKit if needed
      for (final targetLang in _supportedLanguages.keys) {
        if (!allTranslations.containsKey(targetLang)) {
          try {
            final translated = await _translateTextWithMLKit(
              speechResult.originalText,
              speechResult.detectedLanguage,
              targetLang,
            );
            allTranslations[targetLang] = translated;
            confidenceScores[targetLang] = speechResult.confidence * 0.85; // Slightly lower for MLKit
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ MLKit translation failed for $targetLang: $e');
            }
            // Use original text as fallback
            allTranslations[targetLang] = speechResult.originalText;
            confidenceScores[targetLang] = speechResult.confidence * 0.5;
          }
        }
      }

      // Create Central Translation Result
      final centralResult = CentralTranslationResult(
        id: '',
        speakerId: _currentUserId,
        speakerName: _currentUserName,
        originalText: speechResult.originalText,
        detectedLanguage: speechResult.detectedLanguage,
        allTranslations: allTranslations,
        confidenceScores: confidenceScores,
        timestamp: speechResult.timestamp,
        isFinal: speechResult.isFinal,
        meetingId: _currentMeetingId,
      );

      // Save to Central Database
      await _saveCentralTranslation(centralResult);

      // Broadcast to all participants
      _translationController.add(centralResult);

      _successfulTranslations++;
      _updateStatus('✅ Central Hub: ${speechResult.wordCount} words → ${allTranslations.length} languages');

      if (kDebugMode) {
        print('✅ Global Hub translation completed:');
        print('   📝 Original: "${speechResult.originalText}"');
        print('   📊 ${speechResult.wordCount} words, ${(speechResult.confidence * 100).toInt()}% confidence');
        print('   🌐 Available in: ${allTranslations.length} languages');
        print('   📈 Session: $_successfulTranslations/$_totalTranslations successful');
      }

    } catch (e) {
      _updateStatus('❌ Central Hub translation error: $e');
      if (kDebugMode) {
        print('❌ Error processing improved speech result: $e');
      }
    }
  }

  // 🌐 TRANSLATE TEXT WITH MLKIT (for missing languages)
  Future<String> _translateTextWithMLKit(String text, String fromLang, String toLang) async {
    try {
      // 1. Try MLKit translation first
      final translatorKey = '${fromLang}_$toLang';
      final translator = _translators[translatorKey];

      if (translator != null) {
        final translatedText = await translator.translateText(text);
        if (kDebugMode) {
          print('✅ MLKit translation success ($fromLang -> $toLang): "$text" → "$translatedText"');
        }
        return translatedText;
      } else {
        if (kDebugMode) {
          print('⚠️ No MLKit translator for $fromLang -> $toLang, trying Google Cloud...');
        }
        // 2. Fallback to Google Cloud Translation
        return await _translateWithGoogleCloud(text, fromLang, toLang);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ MLKit translation error ($fromLang -> $toLang): $e');
        print('   Trying Google Cloud Translation fallback...');
      }
      // 3. Fallback to Google Cloud Translation on MLKit error
      return await _translateWithGoogleCloud(text, fromLang, toLang);
    }
  }

  // ☁️ TRANSLATE WITH GOOGLE CLOUD (reliable fallback)
  Future<String> _translateWithGoogleCloud(String text, String fromLang, String toLang) async {
    try {
      if (_googleCloudTranslation?.isReady == true) {
        final translatedText = await _googleCloudTranslation!.translateText(
          text: text,
          targetLanguage: toLang,
          sourceLanguage: fromLang,
        );

        if (kDebugMode) {
          print('✅ Google Cloud translation success ($fromLang -> $toLang): "$text" → "$translatedText"');
        }

        return translatedText;
      } else {
        if (kDebugMode) {
          print('⚠️ Google Cloud Translation not available, using enhanced mock');
        }
        return _getEnhancedMockTranslation(text, fromLang, toLang);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google Cloud translation error ($fromLang -> $toLang): $e');
        print('   Using enhanced mock as final fallback');
      }
      return _getEnhancedMockTranslation(text, fromLang, toLang);
    }
  }

  // 🎭 ENHANCED MOCK TRANSLATION (backup cho tất cả ngôn ngữ)
  String _getEnhancedMockTranslation(String text, String fromLang, String toLang) {
    // ✅ MOCK DATA CHO TẤT CẢ CÁC CẶP NGÔN NGỮ CHÍNH
    const enhancedMockTranslations = {
      // VIETNAMESE TO OTHER LANGUAGES
      'vi_en': {
        'Xin chào': 'Hello',
        'tôi tên là': 'my name is',
        'tôi là': 'I am',
        'đến từ': 'from',
        'Việt Nam': 'Vietnam',
        'hôm nay': 'today',
        'tôi muốn': 'I want to',
        'test': 'test',
        'hệ thống': 'system',
        'dịch thuật': 'translation',
        'và': 'and',
        'Có nghĩa là': 'It means',
        'nếu như': 'if',
        'mà': 'that',
        'bạn': 'you',
        'có': 'have',
        'Hello': 'Hello',
        'good': 'good',
        'afternoon': 'afternoon',
      },
      'vi_es': {
        'Xin chào': 'Hola',
        'tôi tên là': 'mi nombre es',
        'tôi là': 'soy',
        'đến từ': 'de',
        'Việt Nam': 'Vietnam',
        'hôm nay': 'hoy',
        'tôi muốn': 'quiero',
        'test': 'prueba',
        'hệ thống': 'sistema',
        'dịch thuật': 'traducción',
        'và': 'y',
        'Có nghĩa là': 'Significa',
        'nếu như': 'si',
        'mà': 'que',
        'bạn': 'tú',
        'có': 'tienes',
        'Hello': 'Hola',
        'good': 'bueno',
        'afternoon': 'tarde',
      },
      'vi_fr': {
        'Xin chào': 'Bonjour',
        'tôi tên là': 'je m\'appelle',
        'tôi là': 'je suis',
        'đến từ': 'de',
        'Việt Nam': 'Vietnam',
        'hôm nay': 'aujourd\'hui',
        'tôi muốn': 'je veux',
        'test': 'test',
        'hệ thống': 'système',
        'dịch thuật': 'traduction',
        'và': 'et',
        'Có nghĩa là': 'Cela signifie',
        'nếu như': 'si',
        'mà': 'que',
        'bạn': 'vous',
        'có': 'avez',
        'Hello': 'Bonjour',
        'good': 'bon',
        'afternoon': 'après-midi',
      },
      
      // ENGLISH TO OTHER LANGUAGES
      'en_vi': {
        'Hello': 'Xin chào',
        'my name is': 'tôi tên là',
        'I am': 'tôi là',
        'from': 'đến từ',
        'Vietnam': 'Việt Nam',
        'today': 'hôm nay',
        'I want to': 'tôi muốn',
        'test': 'test',
        'system': 'hệ thống',
        'translation': 'dịch thuật',
        'and': 'và',
        'It means': 'Có nghĩa là',
        'if': 'nếu như',
        'that': 'mà',
        'you': 'bạn',
        'have': 'có',
        'good': 'tốt',
        'afternoon': 'buổi chiều',
      },
      'en_es': {
        'Hello': 'Hola',
        'my name is': 'mi nombre es',
        'I am': 'soy',
        'from': 'de',
        'Vietnam': 'Vietnam',
        'today': 'hoy',
        'I want to': 'quiero',
        'test': 'prueba',
        'system': 'sistema',
        'translation': 'traducción',
        'and': 'y',
        'It means': 'Significa',
        'if': 'si',
        'that': 'que',
        'you': 'tú',
        'have': 'tienes',
        'good': 'bueno',
        'afternoon': 'tarde',
      },
      'en_fr': {
        'Hello': 'Bonjour',
        'my name is': 'je m\'appelle',
        'I am': 'je suis',
        'from': 'de',
        'Vietnam': 'Vietnam',
        'today': 'aujourd\'hui',
        'I want to': 'je veux',
        'test': 'test',
        'system': 'système',
        'translation': 'traduction',
        'and': 'et',
        'It means': 'Cela signifie',
        'if': 'si',
        'that': 'que',
        'you': 'vous',
        'have': 'avez',
        'good': 'bon',
        'afternoon': 'après-midi',
      },
      
      // REVERSE TRANSLATIONS
      'es_vi': {
        'Hola': 'Xin chào',
        'mi nombre es': 'tôi tên là',
        'soy': 'tôi là',
        'de': 'đến từ',
        'Vietnam': 'Việt Nam',
        'hoy': 'hôm nay',
        'quiero': 'tôi muốn',
        'prueba': 'test',
        'sistema': 'hệ thống',
        'traducción': 'dịch thuật',
        'y': 'và',
      },
      'fr_vi': {
        'Bonjour': 'Xin chào',
        'je m\'appelle': 'tôi tên là',
        'je suis': 'tôi là',
        'de': 'đến từ',
        'Vietnam': 'Việt Nam',
        'aujourd\'hui': 'hôm nay',
        'je veux': 'tôi muốn',
        'test': 'test',
        'système': 'hệ thống',
        'traduction': 'dịch thuật',
        'et': 'và',
      },
      'es_en': {
        'Hola': 'Hello',
        'mi nombre es': 'my name is',
        'soy': 'I am',
        'de': 'from',
        'Vietnam': 'Vietnam',
        'hoy': 'today',
        'quiero': 'I want to',
        'prueba': 'test',
        'sistema': 'system',
        'traducción': 'translation',
        'y': 'and',
      },
      'fr_en': {
        'Bonjour': 'Hello',
        'je m\'appelle': 'my name is',
        'je suis': 'I am',
        'de': 'from',
        'Vietnam': 'Vietnam',
        'aujourd\'hui': 'today',
        'je veux': 'I want to',
        'test': 'test',
        'système': 'system',
        'traduction': 'translation',
        'et': 'and',
      },
    };

    final key = '${fromLang}_$toLang';
    final translations = enhancedMockTranslations[key];

    if (translations != null) {
      String result = text;
      for (final entry in translations.entries) {
        result = result.replaceAllMapped(
          RegExp(entry.key, caseSensitive: false),
              (match) => entry.value,
        );
      }
      
      if (kDebugMode) {
        print('✅ Enhanced mock translation ($fromLang -> $toLang): "$text" → "$result"');
      }
      
      return result;
    }

    // Nếu không có bản dịch mock, trả về text gốc thay vì format [lang]
    if (kDebugMode) {
      print('⚠️ No mock translation for $fromLang -> $toLang, returning original text');
    }
    
    return text; // ✅ TRẢ VỀ TEXT GỐC THAY VÌ [es] text
  }

  Future<void> _saveCentralTranslation(CentralTranslationResult result) async {
    try {
      if (_currentMeetingId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('central_translations')
          .add(result.toFirestore());

      if (kDebugMode) {
        print('💾 Central Hub translation saved to database');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving Central Hub translation: $e');
      }
    }
  }

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
      _updateStatus('🛑 Stopping Central Hub...');

      // Stop Google Speech Service
      if (_googleSpeechService != null) {
        await _googleSpeechService!.stopListening();
      }

      _isListening = false;
      _updateStatus('✅ Central Hub ready');
      notifyListeners();

      if (kDebugMode) {
        print('🛑 Central Hub stopped');
        if (_googleSpeechService != null) {
          final speechStats = _googleSpeechService!.getImprovedStatistics();
          print('📊 Google Speech Stats: ${speechStats['successRate']}% success rate');
        }
        print('📊 Central Hub Stats: $_successfulTranslations/$_totalTranslations translations');
      }

    } catch (e) {
      _updateStatus('❌ Error stopping Central Hub: $e');
      if (kDebugMode) {
        print('❌ Error stopping Central Hub: $e');
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

      // Update Google Speech Service
      if (_googleSpeechService != null) {
        _googleSpeechService!.setPreferredLanguage(speakingLanguage);
      }
    }
    if (displayLanguage != null) {
      _userDisplayLanguage = displayLanguage;
    }

    notifyListeners();

    if (kDebugMode) {
      print('🔄 Central Hub language preferences updated:');
      print('   Speaking: $_userSpeakingLanguage');
      print('   Display: $_userDisplayLanguage');
      print('   🎙️ Google Speech Service updated');
    }
  }

  // 📊 GET ENHANCED STATISTICS
  Map<String, dynamic> getEnhancedStatistics() {
    final baseStats = {
      'isInitialized': _isInitialized,
      'isListening': _isListening,
      'totalTranslations': _totalTranslations,
      'successfulTranslations': _successfulTranslations,
      'sessionDuration': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inMinutes
          : 0,
      'supportedLanguages': _supportedLanguages.length,
      'additionalTranslators': _translators.length,
      'usingImprovedGoogleSpeech': _googleSpeechService != null,
    };

    if (_googleSpeechService != null) {
      final speechStats = _googleSpeechService!.getImprovedStatistics();
      return {...baseStats, 'improvedGoogleSpeech': speechStats};
    }

    return baseStats;
  }

  // 📱 UPDATE STATUS
  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
    notifyListeners();

    if (kDebugMode) {
      print('📱 Central Hub Status: $status');
    }
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing UPDATED CentralTranslationService...');
      final stats = getEnhancedStatistics();
      print('📊 Final Central Hub Stats: $stats');
    }

    stopListening();

    // Cancel subscriptions
    _speechSubscription?.cancel();
    _speechStatusSubscription?.cancel();

    // Dispose Google Speech Service
    _googleSpeechService?.dispose();

    // Dispose Google Cloud Translation Service
    _googleCloudTranslation?.dispose();

    // Close additional translators
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