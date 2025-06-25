// lib/services/multilingual_speech_service.dart - FIXED ALL ERRORS
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

// 🎯 SPEECH RESULT MODEL - DEFINED HERE
class SpeechResult {
  final String userId;
  final String userName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations;
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;

  SpeechResult({
    required this.userId,
    required this.userName,
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.confidence,
    required this.timestamp,
    required this.isFinal,
  });

  @override
  String toString() {
    return 'SpeechResult(user: $userName, text: "$originalText", lang: $detectedLanguage, confidence: $confidence)';
  }

  // Create a copy with updated values
  SpeechResult copyWith({
    String? userId,
    String? userName,
    String? originalText,
    String? detectedLanguage,
    Map<String, String>? translations,
    double? confidence,
    DateTime? timestamp,
    bool? isFinal,
  }) {
    return SpeechResult(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      originalText: originalText ?? this.originalText,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      translations: translations ?? this.translations,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'originalText': originalText,
      'detectedLanguage': detectedLanguage,
      'translations': translations,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'isFinal': isFinal,
    };
  }

  // Create from JSON
  factory SpeechResult.fromJson(Map<String, dynamic> json) {
    return SpeechResult(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      originalText: json['originalText'] ?? '',
      detectedLanguage: json['detectedLanguage'] ?? 'unknown',
      translations: Map<String, String>.from(json['translations'] ?? {}),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isFinal: json['isFinal'] ?? false,
    );
  }
}

class MultilingualSpeechService extends ChangeNotifier {
  // 🔑 GOOGLE CLOUD AUTHENTICATION
  http.Client? _authenticatedClient;
  String? _projectId;
  bool _isInitialized = false;

  // 🎤 AUDIO PROCESSING
  static const MethodChannel _audioChannel = MethodChannel('audio_capture_plugin');
  static const EventChannel _audioEventChannel = EventChannel('audio_capture_stream');

  MediaStream? _webrtcStream;
  bool _isListening = false;
  StreamSubscription<dynamic>? _audioSubscription;

  // 📊 AUDIO BUFFER
  final List<Uint8List> _audioBuffer = [];
  Timer? _processingTimer;
  static const int PROCESSING_INTERVAL_MS = 2000; // Process every 2 seconds

  // 🎯 USER CONTEXT
  String _currentUserId = '';
  String _currentUserName = '';
  String _meetingId = '';
  String _preferredLanguage = 'en';
  List<String> _targetLanguages = ['en', 'vi', 'zh', 'ja', 'ko', 'th', 'id', 'ms'];

  // 📡 RESULT STREAM
  final StreamController<SpeechResult> _speechResultController = StreamController<SpeechResult>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  // 🧠 PROCESSING STATE
  String _currentStatus = 'Initializing...';
  String _lastProcessedText = '';

  // 🌐 LANGUAGE MAPPING FOR GOOGLE CLOUD
  static const Map<String, String> _languageCodes = {
    'en': 'en-US',
    'vi': 'vi-VN',
    'zh': 'zh-CN',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'th': 'th-TH',
    'id': 'id-ID',
    'ms': 'ms-MY',
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
  };

  // Getters
  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized && _authenticatedClient != null;
  String get currentStatus => _currentStatus;
  String get preferredLanguage => _preferredLanguage;
  Stream<SpeechResult> get speechResultStream => _speechResultController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // 🚀 INITIALIZE WITH GOOGLE CLOUD CREDENTIALS
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _updateStatus('Loading Google Cloud credentials...');

      // Load credentials from assets
      final credentialsString = await rootBundle.loadString('assets/credentials/google-cloud-credentials.json');
      final credentialsJson = json.decode(credentialsString);

      _projectId = credentialsJson['project_id'];

      _updateStatus('Authenticating with Google Cloud...');

      // Create authenticated client
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      _authenticatedClient = await clientViaServiceAccount(
        credentials,
        [
          'https://www.googleapis.com/auth/cloud-platform',
          'https://www.googleapis.com/auth/cloud-translation',
        ],
      );

      _updateStatus('Testing Google Cloud APIs...');

      // Test Speech API
      await _testSpeechAPI();

      // Test Translation API
      await _testTranslationAPI();

      // Setup audio capture listeners
      _setupAudioListeners();

      _isInitialized = true;
      _updateStatus('✅ Google Cloud services ready');

      if (kDebugMode) {
        print('✅ MultilingualSpeechService initialized with Google Cloud');
        print('   Project ID: $_projectId');
        print('   Target Languages: $_targetLanguages');
      }

    } catch (e) {
      _updateStatus('❌ Initialization failed: $e');
      if (kDebugMode) {
        print('❌ Failed to initialize speech service: $e');
      }
      rethrow;
    }
  }

  // 🧪 TEST SPEECH API
  Future<void> _testSpeechAPI() async {
    if (_authenticatedClient == null) {
      throw Exception('Authenticated client is null');
    }

    try {
      final response = await _authenticatedClient!.get(
        Uri.parse('https://speech.googleapis.com/v1/operations'),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Speech API connection verified');
        }
      } else {
        throw Exception('Speech API test failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Speech API test error: $e');
    }
  }

  // 🧪 TEST TRANSLATION API
  Future<void> _testTranslationAPI() async {
    if (_authenticatedClient == null || _projectId == null) {
      throw Exception('Authenticated client or project ID is null');
    }

    try {
      final response = await _authenticatedClient!.get(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global/supportedLanguages'),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Translation API connection verified');
        }
      } else {
        throw Exception('Translation API test failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Translation API test error: $e');
    }
  }

  // 🎧 SETUP AUDIO LISTENERS
  void _setupAudioListeners() {
    _audioSubscription = _audioEventChannel.receiveBroadcastStream().listen(
          (event) => _handleAudioEvent(event),
      onError: (error) {
        _updateStatus('❌ Audio error: $error');
        if (kDebugMode) {
          print('❌ Audio stream error: $error');
        }
      },
    );

    if (kDebugMode) {
      print('🎧 Audio listeners setup complete');
    }
  }

  // 🎵 HANDLE AUDIO EVENTS
  void _handleAudioEvent(dynamic event) {
    if (event is Map<String, dynamic>) {
      final String type = event['type'] ?? '';

      switch (type) {
        case 'audio_data':
          _handleAudioData(event);
          break;
        case 'recording_stopped':
          _handleRecordingStopped();
          break;
        case 'error':
          _updateStatus('❌ Audio error: ${event['error']}');
          break;
      }
    }
  }

  // 🎵 HANDLE AUDIO DATA
  void _handleAudioData(Map<String, dynamic> event) {
    try {
      final String base64Data = event['data'] ?? '';
      if (base64Data.isNotEmpty) {
        final Uint8List audioData = base64.decode(base64Data);
        _audioBuffer.add(audioData);

        if (kDebugMode && _audioBuffer.length % 10 == 0) {
          print('🎵 Audio buffer: ${_audioBuffer.length} chunks');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling audio data: $e');
      }
    }
  }

  // 🏁 HANDLE RECORDING STOPPED
  void _handleRecordingStopped() {
    _processRemainingAudio();
  }

  // 🎯 SET USER CONTEXT
  void setUserContext(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
    if (kDebugMode) {
      print('👤 User context: $userName ($userId)');
    }
  }

  // 🎯 SET TRANSLATION CONTEXT
  void setTranslationContext(String meetingId) {
    _meetingId = meetingId;
    if (kDebugMode) {
      print('🎯 Meeting context: $meetingId');
    }
  }

  // 🌐 SET PREFERRED LANGUAGE
  void setPreferredLanguage(String languageCode) {
    _preferredLanguage = languageCode;
    if (kDebugMode) {
      print('🌐 Preferred language: $languageCode');
    }
  }

  // 🎯 SET TARGET LANGUAGES
  void setTargetLanguages(List<String> languages) {
    _targetLanguages = languages;
    if (kDebugMode) {
      print('🎯 Target languages: $languages');
    }
  }

  // 🔗 SET WEBRTC STREAM (for compatibility)
  void setWebRTCStream(MediaStream? stream) {
    _webrtcStream = stream;
    if (kDebugMode) {
      print('🔗 WebRTC stream ${stream != null ? "connected" : "disconnected"}');
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
        print('⚠️ Already listening');
      }
      return;
    }

    try {
      // Update context
      if (meetingId != null) _meetingId = meetingId;
      if (userId != null) _currentUserId = userId;
      if (preferredLanguage != null) _preferredLanguage = preferredLanguage;

      _updateStatus('🎤 Starting audio capture...');

      // Start native audio recording
      final result = await _audioChannel.invokeMethod('startRecording');

      if (kDebugMode) {
        print('🎤 Audio recording started: $result');
      }

      // Start audio processing timer
      _startProcessingTimer();

      _isListening = true;
      _updateStatus('🎤 Listening for speech...');
      notifyListeners();

    } catch (e) {
      _updateStatus('❌ Failed to start listening: $e');
      if (kDebugMode) {
        print('❌ Error starting listening: $e');
      }
      rethrow;
    }
  }

  // 🛑 STOP LISTENING
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      _updateStatus('🛑 Stopping audio capture...');

      // Stop processing timer
      _processingTimer?.cancel();
      _processingTimer = null;

      // Process remaining audio
      await _processRemainingAudio();

      // Stop native audio recording
      await _audioChannel.invokeMethod('stopRecording');

      _isListening = false;
      _updateStatus('✅ Ready');
      notifyListeners();

      if (kDebugMode) {
        print('🛑 Stopped listening');
      }

    } catch (e) {
      _updateStatus('❌ Error stopping: $e');
      if (kDebugMode) {
        print('❌ Error stopping listening: $e');
      }
    }
  }

  // ⏰ START PROCESSING TIMER
  void _startProcessingTimer() {
    _processingTimer = Timer.periodic(
      Duration(milliseconds: PROCESSING_INTERVAL_MS),
          (timer) async {
        if (_isListening && _audioBuffer.isNotEmpty) {
          await _processBufferedAudio();
        }
      },
    );
  }

  // 🔄 PROCESS BUFFERED AUDIO
  Future<void> _processBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;

    try {
      // Combine audio chunks
      final int totalSize = _audioBuffer.fold(0, (sum, chunk) => sum + chunk.length);
      final Uint8List combinedAudio = Uint8List(totalSize);

      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Clear buffer
      _audioBuffer.clear();

      _updateStatus('☁️ Processing with Google Cloud...');

      // Send to Google Cloud Speech-to-Text
      await _processWithGoogleCloud(combinedAudio);

    } catch (e) {
      _updateStatus('❌ Processing error: $e');
      if (kDebugMode) {
        print('❌ Error processing audio: $e');
      }
    }
  }

  // 🏁 PROCESS REMAINING AUDIO
  Future<void> _processRemainingAudio() async {
    if (_audioBuffer.isNotEmpty) {
      await _processBufferedAudio();
    }
  }

  // ☁️ PROCESS WITH GOOGLE CLOUD SPEECH-TO-TEXT
  Future<void> _processWithGoogleCloud(Uint8List audioData) async {
    if (_authenticatedClient == null) {
      _updateStatus('❌ No authenticated client');
      return;
    }

    try {
      if (audioData.length < 1000) {
        // Skip very short audio clips
        return;
      }

      _updateStatus('🗣️ Converting speech to text...');

      // Prepare Speech-to-Text request
      final requestBody = {
        'config': {
          'encoding': 'LINEAR16',
          'sampleRateHertz': 16000,
          'languageCode': _languageCodes[_preferredLanguage] ?? 'en-US',
          'enableAutomaticPunctuation': true,
          'enableWordTimeOffsets': false,
          'model': 'latest_long',
          'useEnhanced': true,
        },
        'audio': {
          'content': base64.encode(audioData),
        },
      };

      final response = await _authenticatedClient!.post(
        Uri.parse('https://speech.googleapis.com/v1/speech:recognize'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['results'] != null && result['results'].isNotEmpty) {
          final transcript = result['results'][0]['alternatives'][0]['transcript'];
          final confidence = result['results'][0]['alternatives'][0]['confidence'] ?? 0.0;

          if (transcript != null && transcript.toString().trim().isNotEmpty) {
            final transcriptText = transcript.toString().trim();

            if (transcriptText != _lastProcessedText) {
              _lastProcessedText = transcriptText;

              if (kDebugMode) {
                print('📝 Transcript: "$transcriptText" (confidence: ${(confidence * 100).toInt()}%)');
              }

              await _processTranscript(transcriptText, confidence);
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ Speech API error: ${response.statusCode}');
          print('Response: ${response.body}');
        }
      }

    } catch (e) {
      _updateStatus('❌ Speech processing error: $e');
      if (kDebugMode) {
        print('❌ Error with Google Cloud Speech: $e');
      }
    }
  }

  // 🌐 PROCESS TRANSCRIPT WITH TRANSLATION
  Future<void> _processTranscript(String transcript, double confidence) async {
    if (_authenticatedClient == null || _projectId == null) {
      _updateStatus('❌ Missing authentication or project ID');
      return;
    }

    try {
      _updateStatus('🔍 Detecting language...');

      // Detect language using Google Cloud Translation
      final detectRequestBody = {
        'parent': 'projects/$_projectId/locations/global',
        'content': transcript,
        'mimeType': 'text/plain',
      };

      final detectResponse = await _authenticatedClient!.post(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global:detectLanguage'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(detectRequestBody),
      );

      String detectedLanguage = _preferredLanguage;

      if (detectResponse.statusCode == 200) {
        final detectResult = json.decode(detectResponse.body);
        if (detectResult['languages'] != null && detectResult['languages'].isNotEmpty) {
          detectedLanguage = detectResult['languages'][0]['languageCode'];
        }
      }

      _updateStatus('🌐 Translating to ${_targetLanguages.length} languages...');

      // Translate to all target languages
      final Map<String, String> translations = {};

      for (final targetLang in _targetLanguages) {
        if (targetLang == detectedLanguage) {
          translations[targetLang] = transcript;
        } else {
          final translated = await _translateText(transcript, detectedLanguage, targetLang);
          translations[targetLang] = translated;
        }
      }

      // Create speech result
      final speechResult = SpeechResult(
        userId: _currentUserId,
        userName: _currentUserName,
        originalText: transcript,
        detectedLanguage: detectedLanguage,
        translations: translations,
        confidence: confidence,
        timestamp: DateTime.now(),
        isFinal: true,
      );

      // Broadcast result
      _speechResultController.add(speechResult);

      // Save to database if in meeting
      if (_meetingId.isNotEmpty) {
        await _saveToFirestore(speechResult);
      }

      _updateStatus('✅ Translation completed');

      if (kDebugMode) {
        print('✅ Speech result processed:');
        print('   Original: "$transcript"');
        print('   Language: $detectedLanguage');
        print('   Translations: ${translations.length} languages');
      }

    } catch (e) {
      _updateStatus('❌ Translation error: $e');
      if (kDebugMode) {
        print('❌ Error processing transcript: $e');
      }
    }
  }

  // 🌐 TRANSLATE TEXT
  Future<String> _translateText(String text, String fromLang, String toLang) async {
    if (_authenticatedClient == null || _projectId == null) {
      return text;
    }

    try {
      final requestBody = {
        'parent': 'projects/$_projectId/locations/global',
        'contents': [text],
        'mimeType': 'text/plain',
        'sourceLanguageCode': fromLang,
        'targetLanguageCode': toLang,
      };

      final response = await _authenticatedClient!.post(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global:translateText'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['translations'] != null && result['translations'].isNotEmpty) {
          return result['translations'][0]['translatedText'];
        }
      }

      return text; // Return original if translation fails
    } catch (e) {
      if (kDebugMode) {
        print('❌ Translation error: $e');
      }
      return text;
    }
  }

  // 💾 SAVE TO FIRESTORE
  Future<void> _saveToFirestore(SpeechResult result) async {
    try {
      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_meetingId)
          .collection('transcriptions')
          .add({
        ...result.toJson(),
        'meetingId': _meetingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('💾 Result saved to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving to Firestore: $e');
      }
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
      print('🧹 Disposing MultilingualSpeechService...');
    }

    stopListening();

    _processingTimer?.cancel();
    _audioSubscription?.cancel();

    _speechResultController.close();
    _statusController.close();

    _authenticatedClient?.close();

    super.dispose();
  }
}