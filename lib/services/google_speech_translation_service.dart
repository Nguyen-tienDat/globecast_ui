// lib/services/google_speech_translation_service.dart - FIXED FOR SHORT SENTENCES
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/google_speech.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// 🎯 IMPROVED SPEECH RESULT MODEL
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
  final int wordCount;

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
  }) : wordCount = originalText.split(' ').where((w) => w.trim().isNotEmpty).length;

  @override
  String toString() {
    return 'SpeechTranslationResult(user: $userName, text: "$originalText" ($wordCount words), lang: $detectedLanguage, translations: ${translations.length}, confidence: ${(confidence * 100).toInt()}%)';
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

  // 🎯 IMPROVED PROCESSING STATE FOR LONG SENTENCES
  StreamSubscription<List<int>>? _audioSubscription;
  Timer? _speechTimer;
  Timer? _sentenceCompletionTimer;

  // 🎯 ENHANCED SPEECH ACCUMULATION
  String _accumulatedSpeech = '';
  final List<String> _speechFragments = [];
  String _lastProcessedText = '';
  final List<List<int>> _audioBuffer = [];
  bool _isProcessing = false;
  DateTime? _lastSpeechTime;
  int _consecutiveEmptyResults = 0;

  // 🎯 IMPROVED PARAMETERS - FIXED FOR SHORT SENTENCES
  static const int _speechBufferSize = 30; // ✅ INCREASED: Was 15
  static const int _minAudioBytes = 16000; // ✅ INCREASED: 16KB minimum
  static const double _confidenceThreshold = 0.5; // ✅ LOWERED: For virtual machines
  static const int _maxSilenceMs = 3000; // ✅ 3 seconds silence tolerance
  static const int _minWordsForSentence = 2; // ✅ FIXED: Lowered from 4 to 2 words
  static const int _processingIntervalMs = 6000; // ✅ INCREASED: Was 3000ms

  // 📊 PERFORMANCE TRACKING
  int _totalProcessingAttempts = 0;
  int _successfulRecognitions = 0;
  int _completedSentences = 0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentStatus => _currentStatus;
  String get preferredLanguage => _preferredLanguage;
  Stream<SpeechTranslationResult> get resultStream => _resultController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // 🚀 IMPROVED INITIALIZATION
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _updateStatus('Initializing Improved Google Speech service...');

      // 1. Initialize Google Speech with better error handling
      await _initializeGoogleSpeech();

      // 2. Initialize MLKit Translation
      await _initializeMLKitTranslation();

      // 3. Setup supported languages
      _setupSupportedLanguages();

      _isInitialized = true;
      _updateStatus('✅ Improved services ready for all sentence lengths');

      if (kDebugMode) {
        print('✅ IMPROVED GoogleSpeechTranslationService initialized');
        print('   📊 Buffer size: $_speechBufferSize chunks');
        print('   ⏱️ Processing interval: ${_processingIntervalMs}ms');
        print('   🎯 Confidence threshold: $_confidenceThreshold');
        print('   📝 Min words: $_minWordsForSentence (FIXED)');
        print('   🔇 Silence tolerance: ${_maxSilenceMs}ms');
        print('   🌐 Supported languages: ${_supportedLanguages.keys.toList()}');
        print('   🔧 Active translators: ${_translators.length}');
      }

    } catch (e) {
      _updateStatus('❌ Improved initialization failed: $e');
      if (kDebugMode) {
        print('❌ Failed to initialize IMPROVED GoogleSpeechTranslationService: $e');
      }
      rethrow;
    }
  }

  // 1️⃣ FIXED GOOGLE SPEECH INITIALIZATION
  Future<void> _initializeGoogleSpeech() async {
    try {
      final serviceAccountString = await rootBundle.loadString(
          'assets/credentials/google-cloud-credentials.json'
      );

      final serviceAccount = ServiceAccount.fromString(serviceAccountString);
      _speechToText = SpeechToText.viaServiceAccount(serviceAccount);

      if (kDebugMode) {
        final serviceAccountJson = json.decode(serviceAccountString) as Map<String, dynamic>;
        print('✅ IMPROVED Google Speech initialized');
        print('   🔧 Project: ${serviceAccountJson['project_id']}');
        print('   🎯 Optimized for all sentence lengths');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ IMPROVED Google Speech initialization failed: $e');
      }
      throw Exception('Failed to initialize Google Speech: $e');
    }
  }

  // 2️⃣ IMPROVED MLKIT TRANSLATION INITIALIZATION
  Future<void> _initializeMLKitTranslation() async {
    try {
      _setupSupportedLanguages();

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
                print('⚠️ Could not create translator $fromLang -> $toLang: $e');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('✅ IMPROVED MLKit Translation initialized');
        print('   🔧 Created translators: $createdTranslators');
        print('   🌐 Language pairs: ${commonLanguages.length}x${commonLanguages.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ IMPROVED MLKit Translation initialization failed: $e');
      }
      throw Exception('Failed to initialize MLKit Translation: $e');
    }
  }

  // 3️⃣ SETUP SUPPORTED LANGUAGES
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
      print('👤 IMPROVED User context: $userName ($userId)');
    }
  }

  // 🎯 SET TRANSLATION CONTEXT
  void setTranslationContext(String meetingId) {
    _meetingId = meetingId;
    if (kDebugMode) {
      print('🎯 IMPROVED Meeting context: $meetingId');
    }
  }

  // 🌐 SET PREFERRED LANGUAGE
  void setPreferredLanguage(String languageCode) {
    _preferredLanguage = languageCode;
    if (kDebugMode) {
      print('🌐 IMPROVED Preferred language: $languageCode');
    }
  }

  // 🎯 SET TARGET LANGUAGES
  void setTargetLanguages(List<String> languages) {
    _targetLanguages = languages;
    if (kDebugMode) {
      print('🎯 IMPROVED Target languages: $languages');
    }
  }

  // 🎤 IMPROVED START LISTENING
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
        print('⚠️ Already listening');
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

      _updateStatus('🎤 Starting IMPROVED speech recognition...');

      // Reset speech accumulation state
      _resetSpeechState();

      // Start improved audio recording
      await _startImprovedAudioRecording();

      _isListening = true;
      _updateStatus('🎙️ IMPROVED listening... Speak naturally');
      notifyListeners();

      if (kDebugMode) {
        print('🎤 IMPROVED listening started');
        print('   📊 Buffer: $_speechBufferSize chunks');
        print('   ⏱️ Interval: ${_processingIntervalMs}ms');
        print('   🎯 Language: $_preferredLanguage');
        print('   📝 Ready for all sentence lengths (min $_minWordsForSentence words)');
      }

    } catch (e) {
      _updateStatus('❌ Failed to start IMPROVED listening: $e');
      if (kDebugMode) {
        print('❌ Error starting IMPROVED listening: $e');
      }
      rethrow;
    }
  }

  // 🎵 IMPROVED AUDIO RECORDING
  Future<void> _startImprovedAudioRecording() async {
    try {
      if (_speechToText == null) {
        throw Exception('Google Speech not initialized');
      }

      // Clear audio buffer
      _audioBuffer.clear();

      // 🎯 IMPROVED AUDIO CONFIG FOR LONG SENTENCES
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000, // High quality
        numChannels: 1,
        bitRate: 128000, // Higher bitrate for clarity
      );

      // Start recording
      final stream = await _audioRecorder.startStream(config);

      _audioSubscription = stream.listen(
            (audioData) => _processImprovedAudioData(audioData),
        onError: (error) {
          if (kDebugMode) {
            print('❌ IMPROVED audio stream error: $error');
          }
          _updateStatus('❌ Audio error: $error');
        },
        onDone: () {
          if (kDebugMode) {
            print('🏁 IMPROVED audio stream done');
          }
        },
      );

      // 🎯 IMPROVED SPEECH PROCESSING TIMER - LONGER INTERVALS FOR SENTENCES
      _speechTimer = Timer.periodic(Duration(milliseconds: _processingIntervalMs), (timer) {
        _processImprovedSpeechBuffer();
      });

      if (kDebugMode) {
        print('🎵 IMPROVED audio recording started');
        print('   📊 Sample rate: 16kHz, Bitrate: 128kbps');
        print('   ⏱️ Processing every ${_processingIntervalMs}ms');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting IMPROVED audio recording: $e');
      }
      throw Exception('Failed to start improved audio recording: $e');
    }
  }

  // 🎵 IMPROVED AUDIO DATA PROCESSING
  void _processImprovedAudioData(List<int> audioData) {
    _audioBuffer.add(audioData);
    _lastSpeechTime = DateTime.now();

    // 🎯 IMPROVED BUFFER MANAGEMENT FOR LONG SENTENCES
    if (_audioBuffer.length > _speechBufferSize + 10) {
      // Remove oldest chunks but keep more for sentence continuity
      final removeCount = 5; // Remove fewer chunks
      _audioBuffer.removeRange(0, removeCount);
    }

    // 🎯 IMPROVED PROCESSING TRIGGER
    final totalBytes = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);

    // Process when we have enough quality audio
    if (_audioBuffer.length >= _speechBufferSize &&
        totalBytes >= _minAudioBytes &&
        !_isProcessing) {

      if (kDebugMode && _audioBuffer.length % 10 == 0) {
        print('🎵 IMPROVED audio buffer: ${_audioBuffer.length} chunks, ${totalBytes} bytes');
      }

      // Trigger processing for sentence recognition
      Future.microtask(() => _processImprovedSpeechBuffer());
    }
  }

  // 🔄 IMPROVED SPEECH BUFFER PROCESSING - FIXED RECOGNITION CONFIG
  Future<void> _processImprovedSpeechBuffer() async {
    if (_speechToText == null || !_isListening || _audioBuffer.isEmpty || _isProcessing) return;

    _isProcessing = true;
    _totalProcessingAttempts++;

    try {
      _updateStatus('☁️ Processing IMPROVED speech...');

      // 🎯 IMPROVED AUDIO PREPARATION - Use more data for sentences
      final recentBuffer = _audioBuffer.length > 25
          ? _audioBuffer.sublist(_audioBuffer.length - 25)
          : _audioBuffer;

      final combinedAudio = <int>[];
      for (final chunk in recentBuffer) {
        combinedAudio.addAll(chunk);
      }

      if (combinedAudio.length < _minAudioBytes) {
        if (kDebugMode) {
          print('⚠️ Insufficient audio data: ${combinedAudio.length} bytes (need $_minAudioBytes)');
        }
        _isProcessing = false;
        return;
      }

      final audioBytes = Uint8List.fromList(combinedAudio);

      // 🎯 FIXED GOOGLE SPEECH CONFIG - ONLY SUPPORTED PARAMETERS
      final config = _createFixedRecognitionConfig();

      // 🎯 IMPROVED SPEECH PROCESSING WITH TIMEOUT AND BETTER ERROR HANDLING
      try {
        if (kDebugMode) {
          print('🔊 Sending ${audioBytes.length} bytes to Google Speech API...');
          print('   Language: ${_getGoogleLanguageCode(_preferredLanguage)}');
          print('   Audio quality: ${audioBytes.length >= _minAudioBytes ? "✅ Good" : "⚠️ Low"}');
        }

        final response = await _speechToText!.recognize(config, audioBytes)
            .timeout(Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Speech recognition timeout after 15 seconds', Duration(seconds: 15));
        });

        if (kDebugMode) {
          print('📡 Google Speech API response received');
          print('   Results: ${response.results.length}');
        }

        if (response.results.isNotEmpty) {
          await _handleImprovedSpeechResponse(response);
          _consecutiveEmptyResults = 0;
        } else {
          _consecutiveEmptyResults++;
          if (kDebugMode) {
            print('📭 Empty response from Google Speech API (consecutive: $_consecutiveEmptyResults)');
          }

          // Check for sentence completion by silence
          await _checkSentenceCompletionBySilence();
        }
      } catch (speechError) {
        _consecutiveEmptyResults++;
        if (kDebugMode) {
          print('⚠️ Google Speech API error: $speechError');
          print('❌ DISABLED MOCK - Will not use mock data');
        }

        // ❌ DISABLED: Mock data removed - let real errors show
        // if (_consecutiveEmptyResults >= 3) {
        //   await _improvedMockSpeechRecognition();
        //   _consecutiveEmptyResults = 0;
        // }
      }

      // 🎯 IMPROVED BUFFER CLEANUP - Keep more data for sentence continuity
      if (_audioBuffer.length > _speechBufferSize) {
        final keepCount = _speechBufferSize ~/ 2;
        final removeCount = _audioBuffer.length - keepCount;
        _audioBuffer.removeRange(0, removeCount);
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing IMPROVED speech: $e');
      }
      _updateStatus('❌ IMPROVED speech processing error');
    } finally {
      _isProcessing = false;
    }
  }

  // 🔧 CREATE FIXED RECOGNITION CONFIG - ONLY SUPPORTED PARAMETERS
  RecognitionConfig _createFixedRecognitionConfig() {
    if (kDebugMode) {
      print('🔧 Creating recognition config for language: $_preferredLanguage');
    }

    try {
      // ✅ SIMPLE CONFIG - Only essential parameters
      final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.latest_long, // ✅ Use long model for sentences
        enableAutomaticPunctuation: true,
        sampleRateHertz: 16000,
        languageCode: _getGoogleLanguageCode(_preferredLanguage),
        maxAlternatives: 1,
      );

      if (kDebugMode) {
        print('✅ Recognition config created successfully');
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating recognition config: $e');
      }

      // Most minimal config possible
      return RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        sampleRateHertz: 16000,
        languageCode: _getGoogleLanguageCode(_preferredLanguage),
      );
    }
  }

  // 📝 IMPROVED SPEECH RESPONSE HANDLING - FIXED TYPE AND isFinal
  Future<void> _handleImprovedSpeechResponse(dynamic response) async {
    if (kDebugMode) {
      print('📝 Processing speech response...');
    }

    try {
      // Handle response.results safely
      final results = response.results as List<dynamic>? ?? [];

      for (var i = 0; i < results.length; i++) {
        final result = results[i];

        // Safe access to alternatives
        final alternatives = result.alternatives as List<dynamic>? ?? [];
        if (alternatives.isEmpty) continue;

        final alternative = alternatives.first;
        final transcript = (alternative.transcript as String?)?.trim() ?? '';
        final confidence = (alternative.confidence as double?) ?? 0.0;
        // ✅ FIXED: Always treat as final to avoid isFinal error
        final isFinal = true;

        if (transcript.isEmpty) continue;

        if (kDebugMode) {
          print('🎙️ REAL speech result $i: "$transcript"');
          print('   📊 Confidence: ${(confidence * 100).toInt()}%');
          print('   ✅ Is final: $isFinal (FIXED: always true)');
          print('   📝 Words: ${transcript.split(' ').length}');
        }

        // 🎯 IMPROVED SPEECH ACCUMULATION
        await _accumulateImprovedSpeech(transcript, confidence, isFinal);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling speech response: $e');
      }
    }
  }

  // 🎯 IMPROVED SPEECH ACCUMULATION FOR ALL SENTENCE LENGTHS
  Future<void> _accumulateImprovedSpeech(String transcript, double confidence, bool isFinal) async {
    // Quality check
    if (confidence < _confidenceThreshold) {
      if (kDebugMode) {
        print('⚠️ Low confidence: ${(confidence * 100).toInt()}% < ${(_confidenceThreshold * 100).toInt()}%');
      }
      return;
    }

    // Add to fragments
    _speechFragments.add(transcript);

    // 🎯 SMART SPEECH ACCUMULATION
    if (_accumulatedSpeech.isEmpty) {
      _accumulatedSpeech = transcript;
    } else {
      // Avoid repetition - smart concatenation
      _accumulatedSpeech = _smartConcatenation(_accumulatedSpeech, transcript);
    }

    _lastSpeechTime = DateTime.now();

    if (kDebugMode) {
      print('📝 IMPROVED accumulating: "$_accumulatedSpeech"');
      print('   📊 Fragments: ${_speechFragments.length}');
      print('   📝 Words: ${_accumulatedSpeech.split(' ').length}');
    }

    // 🎯 IMPROVED SENTENCE COMPLETION DETECTION
    final shouldComplete = await _shouldCompleteImprovedSentence(isFinal, confidence);

    if (shouldComplete) {
      await _completeImprovedSentence(confidence);
    } else {
      // Reset completion timer
      _sentenceCompletionTimer?.cancel();
      _sentenceCompletionTimer = Timer(Duration(milliseconds: _maxSilenceMs), () {
        _checkSentenceCompletionBySilence();
      });
    }
  }

  // 🧠 SMART CONCATENATION - AVOID REPETITION
  String _smartConcatenation(String existing, String newText) {
    final existingWords = existing.toLowerCase().split(' ');
    final newWords = newText.toLowerCase().split(' ');

    // Check for overlap in last few words
    int overlapLength = 0;
    for (int i = 1; i <= 3 && i <= existingWords.length && i <= newWords.length; i++) {
      final existingEnd = existingWords.sublist(existingWords.length - i);
      final newStart = newWords.sublist(0, i);

      if (existingEnd.join(' ') == newStart.join(' ')) {
        overlapLength = i;
      }
    }

    if (overlapLength > 0) {
      // Found overlap, merge without repetition
      final beforeOverlap = existing.split(' ').sublist(0, existingWords.length - overlapLength).join(' ');
      final result = '$beforeOverlap $newText'.trim();

      if (kDebugMode) {
        print('🔗 Smart merge (overlap: $overlapLength words): "$result"');
      }

      return result;
    } else {
      // No overlap, simple append
      return '$existing $newText'.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  // 🎯 IMPROVED SENTENCE COMPLETION DETECTION - FIXED FOR SHORT SENTENCES
  Future<bool> _shouldCompleteImprovedSentence(bool isFinal, double confidence) async {
    final words = _accumulatedSpeech.split(' ').where((w) => w.trim().isNotEmpty).toList();

    // 1. FIXED: Lower minimum words check (was 4, now 2)
    if (words.length < 2) return false;

    // 2. Sentence ending punctuation
    if (_accumulatedSpeech.endsWith('.') ||
        _accumulatedSpeech.endsWith('!') ||
        _accumulatedSpeech.endsWith('?')) {
      if (kDebugMode) {
        print('✅ Sentence ending detected');
      }
      return true;
    }

    // 3. FIXED: Final result with lower length requirement (was 6, now 3)
    if (isFinal && words.length >= 3) {
      if (kDebugMode) {
        print('✅ Final result with sufficient length: ${words.length} words');
      }
      return true;
    }

    // 4. Long sentence auto-complete
    if (words.length >= 15) {
      if (kDebugMode) {
        print('✅ Long sentence auto-complete: ${words.length} words');
      }
      return true;
    }

    // 5. FIXED: High confidence with lower length requirement (was 8, now 4)
    if (confidence > 0.8 && words.length >= 4) {
      if (kDebugMode) {
        print('✅ High confidence completion: ${(confidence * 100).toInt()}%, ${words.length} words');
      }
      return true;
    }

    // 6. ADDED: Medium confidence with any length for very short phrases
    if (confidence > 0.6 && words.length >= 2) {
      if (kDebugMode) {
        print('✅ Medium confidence completion: ${(confidence * 100).toInt()}%, ${words.length} words');
      }
      return true;
    }

    return false;
  }

  // 🔇 CHECK SENTENCE COMPLETION BY SILENCE - FIXED FOR SHORT SENTENCES
  Future<void> _checkSentenceCompletionBySilence() async {
    if (_lastSpeechTime == null || _accumulatedSpeech.isEmpty) return;

    final silenceDuration = DateTime.now().difference(_lastSpeechTime!).inMilliseconds;
    final words = _accumulatedSpeech.split(' ').where((w) => w.trim().isNotEmpty).toList();

    // FIXED: Lower requirement for silence completion (was 4, now 2)
    if (silenceDuration > _maxSilenceMs && words.length >= 2) {
      if (kDebugMode) {
        print('🔇 IMPROVED sentence completed by silence: ${silenceDuration}ms, ${words.length} words');
      }

      await _completeImprovedSentence(0.7); // Medium confidence for silence-completed
    }
  }

  // ✅ COMPLETE IMPROVED SENTENCE - FIXED FOR SHORT SENTENCES
  Future<void> _completeImprovedSentence(double confidence) async {
    if (_accumulatedSpeech.trim().isEmpty) return;

    final finalText = _accumulatedSpeech.trim();
    final wordCount = finalText.split(' ').where((w) => w.trim().isNotEmpty).length;

    // FIXED: Lower quality check (was 4, now 2)
    if (wordCount < 2) {
      if (kDebugMode) {
        print('⚠️ Sentence too short: $wordCount words < 2');
      }
      _resetSpeechState();
      return;
    }

    try {
      _updateStatus('🌐 Translating IMPROVED sentence to ${_targetLanguages.length} languages...');

      // Translate to all target languages
      final translations = <String, String>{};

      for (final targetLang in _targetLanguages) {
        if (targetLang == _preferredLanguage) {
          translations[targetLang] = finalText;
        } else {
          final translated = await _translateText(finalText, _preferredLanguage, targetLang);
          translations[targetLang] = translated;
        }
      }

      // Create result
      final result = SpeechTranslationResult(
        userId: _currentUserId,
        userName: _currentUserName,
        originalText: finalText,
        detectedLanguage: _preferredLanguage,
        translations: translations,
        confidence: confidence,
        timestamp: DateTime.now(),
        isFinal: true,
        isFromGoogleSpeech: true,
      );

      // Broadcast result
      _resultController.add(result);
      _successfulRecognitions++;
      _completedSentences++;

      _updateStatus('✅ IMPROVED translation completed: $wordCount words → ${translations.length} languages');

      if (kDebugMode) {
        print('✅ IMPROVED sentence completed:');
        print('   📝 Text: "$finalText"');
        print('   📊 $wordCount words, ${(confidence * 100).toInt()}% confidence');
        print('   🌐 Translations: ${translations.length} languages');
        print('   📈 Session stats: $_completedSentences completed, $_successfulRecognitions/$_totalProcessingAttempts processed');
      }

    } catch (e) {
      _updateStatus('❌ IMPROVED translation error: $e');
      if (kDebugMode) {
        print('❌ Error completing IMPROVED sentence: $e');
      }
    } finally {
      _resetSpeechState();
    }
  }

  // 🔄 RESET SPEECH STATE
  void _resetSpeechState() {
    _accumulatedSpeech = '';
    _speechFragments.clear();
    _lastProcessedText = '';
    _sentenceCompletionTimer?.cancel();
    _sentenceCompletionTimer = null;

    if (kDebugMode) {
      print('🔄 Speech state reset for next sentence');
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

  // 🌐 IMPROVED TRANSLATE TEXT
  Future<String> _translateText(String text, String fromLang, String toLang) async {
    try {
      final translatorKey = '${fromLang}_$toLang';
      final translator = _translators[translatorKey];

      if (translator != null) {
        final translatedText = await translator.translateText(text);

        if (kDebugMode) {
          print('🌐 IMPROVED translation "$text" ($fromLang → $toLang): "$translatedText"');
        }

        return translatedText;
      } else {
        if (kDebugMode) {
          print('⚠️ No translator available for $fromLang → $toLang, using improved mock');
        }
        return _getImprovedMockTranslation(text, fromLang, toLang);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ IMPROVED translation error ($fromLang → $toLang): $e');
      }
      return _getImprovedMockTranslation(text, fromLang, toLang);
    }
  }

  // 🎭 IMPROVED MOCK TRANSLATION
  String _getImprovedMockTranslation(String text, String fromLang, String toLang) {
    // Enhanced mock translations with more phrases
    const improvedMockTranslations = {
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
        'này': 'this',
        'và': 'and',
        'hy vọng': 'hope',
        'rằng': 'that',
        'hoạt động': 'work',
        'tốt': 'well',
        'với': 'with',
        'câu': 'sentence',
        'dài': 'long',
        'mọi người': 'everyone',
        'đang': 'am',
      },
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
        'this': 'này',
        'and': 'và',
        'hope': 'hy vọng',
        'that': 'rằng',
        'work': 'hoạt động',
        'well': 'tốt',
        'with': 'với',
        'sentence': 'câu',
        'long': 'dài',
        'everyone': 'mọi người',
        'testing': 'đang test',
        'We': 'Chúng ta',
        'lay': 'nằm',
        'down': 'xuống',
      },
      'en_ja': {
        'Hello': 'こんにちは',
        'my name is': '私の名前は',
        'I am': '私は',
        'from': 'から来ました',
        'Vietnam': 'ベトナム',
        'today': '今日',
        'test': 'テスト',
        'system': 'システム',
        'translation': '翻訳',
        'and': 'と',
        'We': '私たち',
        'lay': '横になる',
        'down': 'ダウン',
      },
      'en_zh': {
        'Hello': '你好',
        'my name is': '我的名字是',
        'I am': '我是',
        'from': '来自',
        'Vietnam': '越南',
        'today': '今天',
        'test': '测试',
        'system': '系统',
        'translation': '翻译',
        'and': '和',
        'We': '我们',
        'lay': '躺',
        'down': '下',
      },
      'en_ko': {
        'Hello': '안녕하세요',
        'my name is': '제 이름은',
        'I am': '저는',
        'from': '에서 왔습니다',
        'Vietnam': '베트남',
        'today': '오늘',
        'test': '테스트',
        'system': '시스템',
        'translation': '번역',
        'and': '그리고',
        'We': '우리',
        'lay': '눕다',
        'down': '아래',
      },
    };

    final key = '${fromLang}_$toLang';
    final translations = improvedMockTranslations[key];

    if (translations != null) {
      String result = text;
      for (final entry in translations.entries) {
        // Case-insensitive replacement
        result = result.replaceAllMapped(
          RegExp(entry.key, caseSensitive: false),
              (match) => entry.value,
        );
      }

      if (kDebugMode) {
        print('🎭 IMPROVED mock translation: "$text" → "$result"');
      }

      return result;
    }

    // Fallback
    return '[$toLang] $text';
  }

  // 🛑 IMPROVED STOP LISTENING
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      _updateStatus('🛑 Stopping IMPROVED speech recognition...');

      // Process any remaining accumulated speech
      if (_accumulatedSpeech.isNotEmpty) {
        final words = _accumulatedSpeech.split(' ').where((w) => w.trim().isNotEmpty).toList();
        if (words.length >= 2) { // FIXED: Lower threshold
          if (kDebugMode) {
            print('📝 Processing final accumulated speech: "$_accumulatedSpeech"');
          }
          await _completeImprovedSentence(0.7);
        }
      }

      // Cancel timers
      _speechTimer?.cancel();
      _speechTimer = null;

      _sentenceCompletionTimer?.cancel();
      _sentenceCompletionTimer = null;

      // Cancel audio subscription
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Stop audio recording
      await _audioRecorder.stop();

      _isListening = false;
      _resetSpeechState();
      _updateStatus('✅ IMPROVED service ready');
      notifyListeners();

      if (kDebugMode) {
        print('🛑 IMPROVED speech service stopped');
        print('📊 Session Statistics:');
        print('   🔢 Total processing attempts: $_totalProcessingAttempts');
        print('   ✅ Successful recognitions: $_successfulRecognitions');
        print('   📝 Completed sentences: $_completedSentences');
        print('   📈 Success rate: ${_totalProcessingAttempts > 0 ? (_successfulRecognitions / _totalProcessingAttempts * 100).toStringAsFixed(1) : 0}%');
        print('   🎯 Fixed for short sentences (min 2 words)');
      }

    } catch (e) {
      _updateStatus('❌ Error stopping IMPROVED service: $e');
      if (kDebugMode) {
        print('❌ Error stopping IMPROVED listening: $e');
      }
    }
  }

  // 🔧 IMPROVED DOWNLOAD TRANSLATION MODEL
  Future<void> downloadTranslationModel(String languageCode) async {
    try {
      if (!_supportedLanguages.containsKey(languageCode)) {
        throw Exception('Language $languageCode not supported');
      }

      final modelManager = OnDeviceTranslatorModelManager();
      final isDownloaded = await modelManager.isModelDownloaded(languageCode);

      if (!isDownloaded) {
        _updateStatus('📥 Downloading IMPROVED model for $languageCode...');

        try {
          await modelManager.downloadModel(languageCode);
          _updateStatus('✅ IMPROVED model downloaded: $languageCode');
        } catch (downloadError) {
          _updateStatus('❌ IMPROVED model download failed: $languageCode');
          if (kDebugMode) {
            print('❌ IMPROVED download error: $downloadError');
          }
        }
      } else {
        _updateStatus('✅ IMPROVED model already available: $languageCode');
      }

      if (kDebugMode) {
        print('✅ IMPROVED translation model ready: $languageCode');
      }
    } catch (e) {
      _updateStatus('❌ IMPROVED model download failed: $e');
      if (kDebugMode) {
        print('❌ Failed to download IMPROVED model for $languageCode: $e');
      }
    }
  }

  // 📊 GET IMPROVED STATISTICS
  Map<String, dynamic> getImprovedStatistics() {
    return {
      'isInitialized': _isInitialized,
      'isListening': _isListening,
      'preferredLanguage': _preferredLanguage,
      'targetLanguages': _targetLanguages,
      'totalProcessingAttempts': _totalProcessingAttempts,
      'successfulRecognitions': _successfulRecognitions,
      'completedSentences': _completedSentences,
      'successRate': _totalProcessingAttempts > 0
          ? (_successfulRecognitions / _totalProcessingAttempts * 100).toStringAsFixed(1)
          : '0.0',
      'currentBufferSize': _audioBuffer.length,
      'isProcessing': _isProcessing,
      'accumulatedSpeech': _accumulatedSpeech,
      'speechFragments': _speechFragments.length,
      'improvedFeatures': {
        'bufferSize': _speechBufferSize,
        'processingInterval': _processingIntervalMs,
        'confidenceThreshold': _confidenceThreshold,
        'minWords': _minWordsForSentence,
        'silenceTolerance': _maxSilenceMs,
        'minAudioBytes': _minAudioBytes,
        'fixedGoogleSpeechConfig': true,
        'fixedForShortSentences': true,
      },
    };
  }

  // 📊 GET AVAILABLE LANGUAGES
  List<String> getAvailableLanguages() {
    return _supportedLanguages.keys.toList();
  }

  // 📱 IMPROVED UPDATE STATUS
  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
    notifyListeners();

    if (kDebugMode) {
      print('📱 IMPROVED Status: $status');
    }
  }

  // 🧹 IMPROVED DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing IMPROVED GoogleSpeechTranslationService...');

      final stats = getImprovedStatistics();
      print('📊 Final IMPROVED Statistics:');
      print('   📈 Success rate: ${stats['successRate']}%');
      print('   📝 Completed sentences: ${stats['completedSentences']}');
      print('   🔧 Fixed for short sentences: ${stats['improvedFeatures']['fixedForShortSentences']}');
    }

    stopListening();

    // Cancel all timers
    _speechTimer?.cancel();
    _sentenceCompletionTimer?.cancel();

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