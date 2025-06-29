// lib/services/multilingual_speech_service.dart - ENHANCED FOR PERSONAL TRANSLATION
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// 🎯 ENHANCED SPEECH RESULT MODEL FOR PERSONAL TRANSLATION
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

  // Get text for specific user's display language
  String getTextForUser(String userDisplayLanguage, String currentUserId) {
    // If this is the current user's own speech, show original
    if (userId == currentUserId) {
      return originalText;
    }

    // If the detected language matches user's display language, show original
    if (detectedLanguage == userDisplayLanguage) {
      return originalText;
    }

    // Otherwise, show translation to user's display language
    return translations[userDisplayLanguage] ?? originalText;
  }

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

// 🎯 USER LANGUAGE PREFERENCES MODEL
class UserLanguagePreferences {
  final String userId;
  final String userName;
  final String speakingLanguage;
  final String displayLanguage;
  final DateTime lastUpdated;

  UserLanguagePreferences({
    required this.userId,
    required this.userName,
    required this.speakingLanguage,
    required this.displayLanguage,
    required this.lastUpdated,
  });

  factory UserLanguagePreferences.fromJson(Map<String, dynamic> json) {
    return UserLanguagePreferences(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      speakingLanguage: json['speakingLanguage'] ?? 'vi',
      displayLanguage: json['displayLanguage'] ?? 'vi',
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'speakingLanguage': speakingLanguage,
      'displayLanguage': displayLanguage,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
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

  // 🎯 USER CONTEXT AND PREFERENCES
  String _currentUserId = '';
  String _currentUserName = '';
  String _meetingId = '';
  String _mySpeakingLanguage = 'vi';    // Language I speak
  String _myDisplayLanguage = 'vi';     // Language I want to see

  // 👥 PARTICIPANTS' LANGUAGE PREFERENCES
  final Map<String, UserLanguagePreferences> _participantPreferences = {};

  // 📡 RESULT STREAM
  final StreamController<SpeechResult> _speechResultController = StreamController<SpeechResult>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  // 🧠 PROCESSING STATE
  String _currentStatus = 'Initializing...';
  String _lastProcessedText = '';

  // 🌐 SUPPORTED LANGUAGES
  final List<String> _supportedLanguages = [
    'vi', 'en', 'zh', 'ja', 'ko', 'th', 'id', 'ms', 'es', 'fr', 'de', 'ar', 'hi'
  ];

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
  String get mySpeakingLanguage => _mySpeakingLanguage;
  String get myDisplayLanguage => _myDisplayLanguage;
  Stream<SpeechResult> get speechResultStream => _speechResultController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Map<String, UserLanguagePreferences> get participantPreferences => Map.unmodifiable(_participantPreferences);

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

      _updateStatus('Loading personal language preferences...');

      // Load personal language preferences
      await _loadPersonalPreferences();

      _updateStatus('Testing Google Cloud APIs...');

      // Test APIs
      await _testSpeechAPI();
      await _testTranslationAPI();

      // Setup audio capture listeners
      _setupAudioListeners();

      _isInitialized = true;
      _updateStatus('✅ Personal translation ready');

      if (kDebugMode) {
        print('✅ MultilingualSpeechService initialized with personal translation');
        print('   Project ID: $_projectId');
        print('   My Speaking Language: $_mySpeakingLanguage');
        print('   My Display Language: $_myDisplayLanguage');
        print('   Supported Languages: $_supportedLanguages');
      }

    } catch (e) {
      _updateStatus('❌ Initialization failed: $e');
      if (kDebugMode) {
        print('❌ Failed to initialize speech service: $e');
      }
      rethrow;
    }
  }

  // 📱 LOAD PERSONAL LANGUAGE PREFERENCES
  Future<void> _loadPersonalPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mySpeakingLanguage = prefs.getString('speaking_language') ?? 'vi';
      _myDisplayLanguage = prefs.getString('display_language') ?? 'vi';

      if (kDebugMode) {
        print('📱 Loaded personal preferences:');
        print('   Speaking: $_mySpeakingLanguage');
        print('   Display: $_myDisplayLanguage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load preferences, using defaults: $e');
      }
    }
  }

  // 💾 SAVE PERSONAL LANGUAGE PREFERENCES
  Future<void> savePersonalPreferences(String speakingLanguage, String displayLanguage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('speaking_language', speakingLanguage);
      await prefs.setString('display_language', displayLanguage);

      _mySpeakingLanguage = speakingLanguage;
      _myDisplayLanguage = displayLanguage;

      // Update in Firestore if in meeting
      if (_meetingId.isNotEmpty && _currentUserId.isNotEmpty) {
        await _saveMyPreferencesToFirestore();
      }

      if (kDebugMode) {
        print('💾 Saved personal preferences:');
        print('   Speaking: $_mySpeakingLanguage');
        print('   Display: $_myDisplayLanguage');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving preferences: $e');
      }
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

    // Setup Firestore listeners for participant preferences
    if (meetingId.isNotEmpty) {
      _listenToParticipantPreferences();

      // Save my preferences to Firestore
      if (_currentUserId.isNotEmpty) {
        _saveMyPreferencesToFirestore();
      }
    }

    if (kDebugMode) {
      print('🎯 Meeting context: $meetingId');
    }
  }

  // 👂 LISTEN TO PARTICIPANT LANGUAGE PREFERENCES
  void _listenToParticipantPreferences() {
    if (_meetingId.isEmpty) return;

    FirebaseFirestore.instance
        .collection('meetings')
        .doc(_meetingId)
        .collection('language_preferences')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final prefs = UserLanguagePreferences.fromJson(data);
        _participantPreferences[prefs.userId] = prefs;
      }

      if (kDebugMode) {
        print('👂 Updated participant preferences: ${_participantPreferences.length} participants');
      }

      notifyListeners();
    });
  }

  // 💾 SAVE MY PREFERENCES TO FIRESTORE
  Future<void> _saveMyPreferencesToFirestore() async {
    if (_meetingId.isEmpty || _currentUserId.isEmpty) return;

    try {
      final prefs = UserLanguagePreferences(
        userId: _currentUserId,
        userName: _currentUserName,
        speakingLanguage: _mySpeakingLanguage,
        displayLanguage: _myDisplayLanguage,
        lastUpdated: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_meetingId)
          .collection('language_preferences')
          .doc(_currentUserId)
          .set(prefs.toJson());

      if (kDebugMode) {
        print('💾 Saved my preferences to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving preferences to Firestore: $e');
      }
    }
  }

  // 🌐 SET PREFERRED LANGUAGE (for backward compatibility)
  void setPreferredLanguage(String languageCode) {
    _mySpeakingLanguage = languageCode;
    if (kDebugMode) {
      print('🌐 Speaking language: $languageCode');
    }
  }

  // 🎯 SET TARGET LANGUAGES (for backward compatibility)
  void setTargetLanguages(List<String> languages) {
    // All supported languages are always target languages for personal translation
    if (kDebugMode) {
      print('🎯 All supported languages are targets: $_supportedLanguages');
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
      if (meetingId != null) setTranslationContext(meetingId);
      if (userId != null && _currentUserName.isNotEmpty) setUserContext(userId, _currentUserName);
      if (preferredLanguage != null) _mySpeakingLanguage = preferredLanguage;

      _updateStatus('🎤 Starting personal translation...');

      // Start native audio recording
      final result = await _audioChannel.invokeMethod('startRecording');

      if (kDebugMode) {
        print('🎤 Audio recording started: $result');
      }

      // Start audio processing timer
      _startProcessingTimer();

      _isListening = true;
      _updateStatus('🎤 Listening with personal translation...');
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
      _updateStatus('🛑 Stopping personal translation...');

      // Stop processing timer
      _processingTimer?.cancel();
      _processingTimer = null;

      // Process remaining audio
      await _processRemainingAudio();

      // Stop native audio recording
      await _audioChannel.invokeMethod('stopRecording');

      _isListening = false;
      _updateStatus('✅ Ready for personal translation');
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
          'languageCode': _languageCodes[_mySpeakingLanguage] ?? 'vi-VN',
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

              await _processTranscriptWithPersonalTranslation(transcriptText, confidence);
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

  // 🌐 PROCESS TRANSCRIPT WITH PERSONAL TRANSLATION
  Future<void> _processTranscriptWithPersonalTranslation(String transcript, double confidence) async {
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

      String detectedLanguage = _mySpeakingLanguage;

      if (detectResponse.statusCode == 200) {
        final detectResult = json.decode(detectResponse.body);
        if (detectResult['languages'] != null && detectResult['languages'].isNotEmpty) {
          String fullLanguageCode = detectResult['languages'][0]['languageCode'];
          // Convert from full code (e.g., 'vi-VN') to short code (e.g., 'vi')
          detectedLanguage = fullLanguageCode.split('-')[0];
        }
      }

      _updateStatus('🌐 Creating personal translations...');

      // Get all unique display languages from participants
      final Set<String> targetLanguages = <String>{_myDisplayLanguage};
      for (final prefs in _participantPreferences.values) {
        targetLanguages.add(prefs.displayLanguage);
      }

      if (kDebugMode) {
        print('🎯 Target languages for translation: $targetLanguages');
      }

      // Translate to all target languages
      final Map<String, String> translations = {};

      for (final targetLang in targetLanguages) {
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

      _updateStatus('✅ Personal translation completed');

      if (kDebugMode) {
        print('✅ Personal speech result processed:');
        print('   Original: "$transcript"');
        print('   Language: $detectedLanguage');
        print('   Translations: ${translations.length} languages');
        print('   For participants with display languages: $targetLanguages');
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
        'speakerDisplayLanguage': _myDisplayLanguage,
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

  // 🎯 GET PARTICIPANT DISPLAY LANGUAGE
  String getParticipantDisplayLanguage(String userId) {
    return _participantPreferences[userId]?.displayLanguage ?? 'en';
  }

  // 🎯 GET TEXT FOR CURRENT USER
  String getTextForCurrentUser(SpeechResult result) {
    return result.getTextForUser(_myDisplayLanguage, _currentUserId);
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