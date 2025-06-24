// lib/services/multilingual_speech_service.dart - ENHANCED WITH AUDIO CAPTURE
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'google_cloud_speech_service.dart';
import 'google_cloud_translation_service.dart';
import 'audio_capture_service.dart';

class SpeechResult {
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations;
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;
  final String userId;
  final String userName;

  SpeechResult({
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.confidence,
    required this.timestamp,
    required this.isFinal,
    required this.userId,
    required this.userName,
  });

  Map<String, dynamic> toJson() => {
    'originalText': originalText,
    'detectedLanguage': detectedLanguage,
    'translations': translations,
    'confidence': confidence,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'isFinal': isFinal,
    'userId': userId,
    'userName': userName,
  };

  factory SpeechResult.fromJson(Map<String, dynamic> json) => SpeechResult(
    originalText: json['originalText'] ?? '',
    detectedLanguage: json['detectedLanguage'] ?? 'unknown',
    translations: Map<String, String>.from(json['translations'] ?? {}),
    confidence: (json['confidence'] ?? 0.0).toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
    isFinal: json['isFinal'] ?? false,
    userId: json['userId'] ?? '',
    userName: json['userName'] ?? '',
  );
}

class MultilingualSpeechService extends ChangeNotifier {
  // 🚀 GOOGLE CLOUD SERVICES
  final GoogleCloudSpeechService _speechService = GoogleCloudSpeechService.instance;
  final GoogleCloudTranslationService _translationService = GoogleCloudTranslationService.instance;

  // 🎤 AUDIO CAPTURE SERVICE
  final AudioCaptureService _audioCapture = AudioCaptureService();

  // Service state
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentMeetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  String _preferredLanguage = 'en';

  // Translation context
  String? _translationContext;

  // Target languages for translation
  final List<String> _targetLanguages = ['en', 'vi', 'zh', 'ja', 'ko', 'th', 'id', 'ms'];

  // Current speech state
  String _currentText = '';
  String _speechStatus = 'ready';

  // Streams
  final StreamController<SpeechResult> _speechResultController = StreamController<SpeechResult>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  // Audio processing
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Map<String, dynamic>>? _audioStatusSubscription;
  final List<Uint8List> _audioBuffer = [];
  Timer? _processingTimer;
  static const int AUDIO_CHUNK_DURATION_MS = 2000; // Process every 2 seconds

  // Getters for UI integration
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized && _speechService.isReady && _translationService.isReady;
  String get preferredLanguage => _preferredLanguage;
  String get text => _currentText;
  String get speechStatus => _speechStatus;
  Stream<SpeechResult> get speechResultStream => _speechResultController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // Compatibility getters for existing UI
  bool get isSTTEnabled => isAvailable;
  String getSpeechStatus() => _speechStatus;
  String get translatedText => ''; // Not used in new implementation

  // 🚀 INITIALIZE SERVICE
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _updateStatus('Initializing services...');

      // Initialize Google Cloud services
      await _speechService.initialize();
      await _translationService.initialize();

      // Initialize audio capture service
      await _audioCapture.initialize();

      if (!_speechService.isReady || !_translationService.isReady) {
        throw Exception('Google Cloud services not ready');
      }

      // Setup audio capture listeners
      _setupAudioListeners();

      _isInitialized = true;
      _speechStatus = 'ready';
      _updateStatus('Ready');
      notifyListeners();

      if (kDebugMode) {
        print('✅ MultilingualSpeechService initialized with Google Cloud + Audio Capture');
      }
    } catch (e) {
      _speechStatus = 'error';
      _updateStatus('Initialization failed: $e');
      if (kDebugMode) {
        print('❌ Failed to initialize MultilingualSpeechService: $e');
      }
      rethrow;
    }
  }

  // 🎯 SETUP AUDIO LISTENERS
  void _setupAudioListeners() {
    // Listen to audio chunks for Google Cloud processing
    _audioSubscription = _audioCapture.getAudioChunksForGoogleCloud().listen(
          (audioData) => _processAudioChunk(audioData),
      onError: (error) {
        if (kDebugMode) {
          print('❌ Audio chunk error: $error');
        }
        _updateStatus('Audio processing error: $error');
      },
    );

    // Listen to audio capture status
    _audioStatusSubscription = _audioCapture.statusStream.listen(
          (status) => _handleAudioStatus(status),
      onError: (error) {
        if (kDebugMode) {
          print('❌ Audio status error: $error');
        }
      },
    );

    if (kDebugMode) {
      print('🎧 Audio listeners setup complete');
    }
  }

  // 🎯 HANDLE AUDIO STATUS CHANGES
  void _handleAudioStatus(Map<String, dynamic> status) {
    final String type = status['type'] ?? '';

    switch (type) {
      case 'status_change':
        if (status['isRecording'] == true && !status['isPaused']) {
          _speechStatus = 'listening';
        } else if (status['isRecording'] == false) {
          _speechStatus = 'ready';
        }
        notifyListeners();
        break;

      case 'error':
        _speechStatus = 'error';
        _updateStatus('Audio error: ${status['error']}');
        notifyListeners();
        break;
    }
  }

  // 🎯 SET USER CONTEXT
  void setUserContext(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
    if (kDebugMode) {
      print('👤 User context set: $userName ($userId)');
    }
  }

  // 🎯 SET TRANSLATION CONTEXT
  void setTranslationContext(String? context) {
    _translationContext = context;
    if (kDebugMode) {
      print('🌐 Translation context set');
    }
  }

  // 🎯 SET WEBRTC STREAM (for compatibility)
  void setWebRTCStream(dynamic stream) {
    // This integration uses native audio capture instead of WebRTC stream
    if (kDebugMode) {
      print('🔗 WebRTC stream reference set (using native audio capture)');
    }
  }

  // 🎯 ENABLE STT (compatibility method)
  Future<void> enableSTT() async {
    if (!_isInitialized) {
      await initialize();
    }
    _speechStatus = isAvailable ? 'ready' : 'error';
    notifyListeners();
  }

  // 🎯 DISABLE STT (compatibility method)
  Future<void> disableSTT() async {
    await stopListening();
    _speechStatus = 'disabled';
    notifyListeners();
  }

  // 🎯 RESET ERROR STATE
  void resetErrorState() {
    _speechStatus = 'ready';
    _currentText = '';
    notifyListeners();
  }

  // 🎤 START LISTENING - ENHANCED WITH NATIVE AUDIO CAPTURE
  Future<void> startListening({
    String? meetingId,
    String? userId,
    String? preferredLanguage,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_isListening) {
        if (kDebugMode) {
          print('⚠️ Already listening');
        }
        return;
      }

      // Update context if provided
      _currentMeetingId = meetingId ?? _currentMeetingId;
      _currentUserId = userId ?? _currentUserId;
      _preferredLanguage = preferredLanguage ?? _preferredLanguage;

      _updateStatus('Starting audio capture...');

      // Start native audio recording
      await _audioCapture.startRecording();

      // Start audio processing timer
      _startAudioProcessingTimer();

      _isListening = true;
      _speechStatus = 'listening';
      notifyListeners();

      _updateStatus('Listening with native audio capture...');
      if (kDebugMode) {
        print('🎤 Started listening with native audio capture (language: $_preferredLanguage)');
      }

    } catch (e) {
      _speechStatus = 'error';
      _updateStatus('Failed to start listening: $e');
      if (kDebugMode) {
        print('❌ Failed to start listening: $e');
      }
      rethrow;
    }
  }

  // 🛑 STOP LISTENING
  Future<void> stopListening() async {
    try {
      if (!_isListening) return;

      _updateStatus('Stopping audio capture...');

      // Stop audio processing timer
      _processingTimer?.cancel();
      _processingTimer = null;

      // Process any remaining audio buffer
      await _processRemainingAudio();

      // Stop native audio recording
      await _audioCapture.stopRecording();

      _isListening = false;
      _speechStatus = 'ready';
      notifyListeners();

      _updateStatus('Ready');
      if (kDebugMode) {
        print('🛑 Stopped listening');
      }

    } catch (e) {
      _speechStatus = 'error';
      _updateStatus('Error stopping: $e');
      if (kDebugMode) {
        print('❌ Error stopping listening: $e');
      }
    }
  }

  // ⏰ START AUDIO PROCESSING TIMER
  void _startAudioProcessingTimer() {
    _processingTimer = Timer.periodic(
      Duration(milliseconds: AUDIO_CHUNK_DURATION_MS),
          (timer) async {
        if (_isListening && _audioBuffer.isNotEmpty) {
          await _processBufferedAudio();
        }
      },
    );
  }

  // 🎵 PROCESS AUDIO CHUNK
  Future<void> _processAudioChunk(Uint8List audioData) async {
    if (!_isListening) return;

    // Add to buffer for batch processing
    _audioBuffer.add(audioData);

    if (kDebugMode) {
      print('🎵 Audio chunk received: ${audioData.length} bytes');
    }
  }

  // 🔄 PROCESS BUFFERED AUDIO
  Future<void> _processBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;

    try {
      // Combine all buffered audio chunks
      final int totalSize = _audioBuffer.fold(0, (sum, chunk) => sum + chunk.length);
      final Uint8List combinedAudio = Uint8List(totalSize);

      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Clear buffer
      _audioBuffer.clear();

      if (kDebugMode) {
        print('🔄 Processing combined audio: $totalSize bytes');
      }

      // Send to Google Cloud Speech-to-Text
      await _processWithGoogleCloud(combinedAudio);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing buffered audio: $e');
      }
    }
  }

  // 🏁 PROCESS REMAINING AUDIO
  Future<void> _processRemainingAudio() async {
    if (_audioBuffer.isNotEmpty) {
      await _processBufferedAudio();
    }
  }

  // ☁️ PROCESS WITH GOOGLE CLOUD
  Future<void> _processWithGoogleCloud(Uint8List audioData) async {
    try {
      _updateStatus('Processing with Google Cloud Speech...');

      // Convert audio to text using Google Cloud Speech-to-Text
      final String transcript = await _speechService.speechToText(
        audioData: audioData,
        languageCode: _getLanguageCode(_preferredLanguage),
        sampleRateHertz: AudioCaptureService.SAMPLE_RATE,
      );

      if (transcript.isNotEmpty) {
        _currentText = transcript;
        notifyListeners();

        if (kDebugMode) {
          print('📝 Transcript: "$transcript"');
        }

        _updateStatus('Detecting language and translating...');

        // Detect language using Google Cloud Translation
        final String detectedLanguage = await _translationService.detectLanguage(transcript);

        // Translate to all target languages
        final Map<String, String> translations = {};

        for (final targetLang in _targetLanguages) {
          if (targetLang != detectedLanguage) {
            final translated = await _translationService.translateText(
              text: transcript,
              targetLanguage: targetLang,
              sourceLanguage: detectedLanguage,
            );
            translations[targetLang] = translated;
          } else {
            translations[targetLang] = transcript; // Original text
          }
        }

        // Create speech result
        final result = SpeechResult(
          originalText: transcript,
          detectedLanguage: detectedLanguage,
          translations: translations,
          confidence: 0.95, // Google Cloud provides confidence, using simulated for now
          timestamp: DateTime.now(),
          isFinal: true,
          userId: _currentUserId,
          userName: _currentUserName,
        );

        // Broadcast result
        _speechResultController.add(result);

        // Save to database if in meeting context
        if (_currentMeetingId.isNotEmpty && _translationContext != null) {
          await _saveToDatabase(result);
        }

        _updateStatus('Translation completed');

        if (kDebugMode) {
          print('✅ Speech result processed successfully');
          print('   🔍 Detected: $detectedLanguage');
          print('   🌐 Translations: ${translations.length} languages');
        }

      } else {
        if (kDebugMode) {
          print('⚠️ No transcript received from Google Cloud');
        }
      }

    } catch (e) {
      _speechStatus = 'error';
      _updateStatus('Google Cloud processing error: $e');
      if (kDebugMode) {
        print('❌ Error processing with Google Cloud: $e');
      }
    }
  }

  // 💾 SAVE TO DATABASE
  Future<void> _saveToDatabase(SpeechResult result) async {
    try {
      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('transcriptions')
          .add({
        ...result.toJson(),
        'meetingId': _currentMeetingId,
        'context': _translationContext,
      });

      if (kDebugMode) {
        print('💾 Result saved to database');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving to database: $e');
      }
    }
  }

  // 📱 LISTEN FOR REAL-TIME RESULTS
  Stream<List<SpeechResult>> listenForResults(String meetingId) {
    return FirebaseFirestore.instance
        .collection('meetings')
        .doc(meetingId)
        .collection('transcriptions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return SpeechResult.fromJson(data);
      }).toList();
    });
  }

  // 🔧 UTILITY METHODS
  String _getLanguageCode(String language) {
    final languageCodes = {
      'en': 'en-US',
      'vi': 'vi-VN',
      'zh': 'zh-CN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'th': 'th-TH',
      'id': 'id-ID',
      'ms': 'ms-MY',
    };
    return languageCodes[language] ?? 'en-US';
  }

  void _updateStatus(String status) {
    _statusController.add(status);
    if (kDebugMode) {
      print('📱 Status: $status');
    }
  }

  // 🔧 CONFIGURATION
  void setPreferredLanguage(String languageCode) {
    _preferredLanguage = languageCode;
    notifyListeners();
    if (kDebugMode) {
      print('🌐 Preferred language set to: $languageCode');
    }
  }

  void setSpeakingLanguage(String languageCode) {
    setPreferredLanguage(languageCode);
  }

  void setTargetLanguages(List<String> languages) {
    _targetLanguages.clear();
    _targetLanguages.addAll(languages);
    notifyListeners();
    if (kDebugMode) {
      print('🎯 Target languages set to: $languages');
    }
  }

  // 🎯 DIRECT TRANSLATION TEST
  Future<void> testTranslation(String text) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      await _processTestTranscript(text);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Test translation error: $e');
      }
    }
  }

  // 🧪 PROCESS TEST TRANSCRIPT (for testing without audio)
  Future<void> _processTestTranscript(String transcript) async {
    try {
      if (kDebugMode) {
        print('🧪 Processing test transcript: "$transcript"');
      }

      _currentText = transcript;
      notifyListeners();

      _updateStatus('Detecting language...');

      // Detect language using Google Cloud
      final detectedLanguage = await _translationService.detectLanguage(transcript);

      _updateStatus('Translating to target languages...');

      // Translate to all target languages
      final translations = <String, String>{};

      for (final targetLang in _targetLanguages) {
        if (targetLang != detectedLanguage) {
          final translated = await _translationService.translateText(
            text: transcript,
            targetLanguage: targetLang,
            sourceLanguage: detectedLanguage,
          );
          translations[targetLang] = translated;
        } else {
          translations[targetLang] = transcript; // Original text
        }
      }

      // Create speech result
      final result = SpeechResult(
        originalText: transcript,
        detectedLanguage: detectedLanguage,
        translations: translations,
        confidence: 0.95, // Simulated confidence for test
        timestamp: DateTime.now(),
        isFinal: true,
        userId: _currentUserId,
        userName: _currentUserName,
      );

      // Broadcast result
      _speechResultController.add(result);

      // Save to database if in meeting context
      if (_currentMeetingId.isNotEmpty && _translationContext != null) {
        await _saveToDatabase(result);
      }

      _updateStatus('Translation completed');

      if (kDebugMode) {
        print('✅ Processed test transcript successfully');
        print('   🔍 Detected: $detectedLanguage');
        print('   🌐 Translations: ${translations.length} languages');
      }

    } catch (e) {
      _speechStatus = 'error';
      _updateStatus('Processing error: $e');
      if (kDebugMode) {
        print('❌ Error processing test transcript: $e');
      }
    }
  }

  // 🧹 CLEANUP
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing MultilingualSpeechService...');
    }

    stopListening();

    // Cancel subscriptions
    _audioSubscription?.cancel();
    _audioStatusSubscription?.cancel();

    // Cancel timers
    _processingTimer?.cancel();

    // Close controllers
    _speechResultController.close();
    _statusController.close();

    // Dispose services
    _audioCapture.dispose();
    _speechService.dispose();
    _translationService.dispose();

    super.dispose();
  }
}