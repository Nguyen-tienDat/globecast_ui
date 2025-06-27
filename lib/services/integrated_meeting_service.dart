// lib/services/integrated_meeting_service.dart - COMPLETE INTEGRATION
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_mesh_meeting_service.dart';
import 'google_speech_translation_service.dart';

// 🎯 INTEGRATED SPEECH RESULT FOR MEETING
class MeetingSpeechResult {
  final String id;
  final String meetingId;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations; // langCode -> translated text
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;
  final Duration audioLength;

  MeetingSpeechResult({
    required this.id,
    required this.meetingId,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.confidence,
    required this.timestamp,
    required this.isFinal,
    required this.audioLength,
  });

  // Get text for specific user's target language
  String getTextForUser(String userTargetLanguage, String currentUserId) {
    // If this is the current user's own speech, show original
    if (speakerId == currentUserId) {
      return originalText;
    }

    // If detected language matches user's target language, show original
    if (detectedLanguage == userTargetLanguage) {
      return originalText;
    }

    // Otherwise, show translation to user's target language
    return translations[userTargetLanguage] ?? originalText;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meetingId': meetingId,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'detectedLanguage': detectedLanguage,
      'translations': translations,
      'confidence': confidence,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFinal': isFinal,
      'audioLength': audioLength.inMilliseconds,
    };
  }

  factory MeetingSpeechResult.fromJson(Map<String, dynamic> json) {
    return MeetingSpeechResult(
      id: json['id'] ?? '',
      meetingId: json['meetingId'] ?? '',
      speakerId: json['speakerId'] ?? '',
      speakerName: json['speakerName'] ?? '',
      originalText: json['originalText'] ?? '',
      detectedLanguage: json['detectedLanguage'] ?? 'unknown',
      translations: Map<String, String>.from(json['translations'] ?? {}),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFinal: json['isFinal'] ?? false,
      audioLength: Duration(milliseconds: json['audioLength'] ?? 0),
    );
  }
}

// 🎯 PARTICIPANT LANGUAGE PREFERENCE
class ParticipantLanguagePreference {
  final String userId;
  final String userName;
  final String targetLanguage; // Language they want to see
  final DateTime lastUpdated;

  ParticipantLanguagePreference({
    required this.userId,
    required this.userName,
    required this.targetLanguage,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'targetLanguage': targetLanguage,
    'lastUpdated': FieldValue.serverTimestamp(),
  };

  factory ParticipantLanguagePreference.fromJson(Map<String, dynamic> json) {
    return ParticipantLanguagePreference(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      targetLanguage: json['targetLanguage'] ?? 'en',
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class IntegratedMeetingService extends ChangeNotifier {
  // 🔗 CONNECTED SERVICES
  WebRTCMeshMeetingService? _webrtcService;
  GoogleSpeechTranslationService? _speechService;

  // 📊 STATE
  bool _isInitialized = false;
  bool _isActive = false;
  String _currentMeetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  String _myTargetLanguage = 'vi'; // Language I want to see

  // 👥 PARTICIPANTS & THEIR LANGUAGE PREFERENCES
  final Map<String, ParticipantLanguagePreference> _participantPreferences = {};

  // 📝 MEETING SPEECH RESULTS (Real-time)
  final List<MeetingSpeechResult> _meetingSpeechResults = [];

  // 📡 FIRESTORE LISTENERS
  final List<StreamSubscription> _firestoreSubscriptions = [];

  // 🎤 SPEECH PROCESSING STATE
  bool _isListeningToSpeech = false;
  StreamSubscription<SpeechTranslationResult>? _speechSubscription;
  StreamSubscription<String>? _speechStatusSubscription;

  // 📡 RESULT STREAMS
  final StreamController<MeetingSpeechResult> _speechResultController =
  StreamController<MeetingSpeechResult>.broadcast();
  final StreamController<String> _statusController =
  StreamController<String>.broadcast();
  final StreamController<ParticipantLanguagePreference> _participantUpdateController =
  StreamController<ParticipantLanguagePreference>.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isActive => _isActive;
  String get currentMeetingId => _currentMeetingId;
  String get myTargetLanguage => _myTargetLanguage;
  List<MeetingSpeechResult> get speechResults => List.unmodifiable(_meetingSpeechResults);
  Map<String, ParticipantLanguagePreference> get participantPreferences =>
      Map.unmodifiable(_participantPreferences);

  Stream<MeetingSpeechResult> get speechResultStream => _speechResultController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<ParticipantLanguagePreference> get participantUpdateStream =>
      _participantUpdateController.stream;

  // 🚀 INITIALIZE INTEGRATION
  Future<void> initialize(
      WebRTCMeshMeetingService webrtcService,
      GoogleSpeechTranslationService speechService,
      ) async {
    try {
      if (_isInitialized) return;

      _updateStatus('Connecting WebRTC and Speech services...');

      _webrtcService = webrtcService;
      _speechService = speechService;

      // Setup speech service listeners
      _setupSpeechServiceListeners();

      _isInitialized = true;
      _updateStatus('✅ Integration ready');

      if (kDebugMode) {
        debugPrint('✅ IntegratedMeetingService initialized');
      }

    } catch (e) {
      _updateStatus('❌ Integration failed: $e');
      if (kDebugMode) {
        debugPrint('❌ Error initializing integration: $e');
      }
      rethrow;
    }
  }

  // 🎧 SETUP SPEECH SERVICE LISTENERS
  void _setupSpeechServiceListeners() {
    if (_speechService == null) return;

    // Listen to speech results from GoogleSpeechTranslationService
    _speechSubscription = _speechService!.resultStream.listen(
          (speechResult) async {
        await _handleSpeechResult(speechResult);
      },
      onError: (error) {
        _updateStatus('❌ Speech error: $error');
        if (kDebugMode) {
          debugPrint('❌ Speech result error: $error');
        }
      },
    );

    // Listen to speech status updates
    _speechStatusSubscription = _speechService!.statusStream.listen(
          (status) {
        _updateStatus('🎤 $status');
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ Speech status error: $error');
        }
      },
    );

    if (kDebugMode) {
      debugPrint('🎧 Speech service listeners setup complete');
    }
  }

  // 🏗️ START INTEGRATED MEETING
  Future<void> startIntegratedMeeting({
    required String meetingId,
    required String userId,
    required String userName,
    required String targetLanguage,
  }) async {
    try {
      if (!_isInitialized) {
        throw Exception('Service not initialized');
      }

      _updateStatus('Starting integrated meeting...');

      _currentMeetingId = meetingId;
      _currentUserId = userId;
      _currentUserName = userName;
      _myTargetLanguage = targetLanguage;

      // Setup user context for speech service
      _speechService!.setUserContext(userId, userName);
      _speechService!.setTranslationContext(meetingId);
      _speechService!.setPreferredLanguage(targetLanguage);

      // Set all supported languages as targets for comprehensive translation
      _speechService!.setTargetLanguages([
        'en', 'vi', 'zh', 'ja', 'ko', 'th', 'id', 'ms', 'es', 'fr', 'de', 'ar', 'hi'
      ]);

      // Save my language preference to Firestore
      await _saveMyLanguagePreference();

      // Setup Firestore listeners for real-time updates
      _setupFirestoreListeners();

      _isActive = true;
      _updateStatus('✅ Integrated meeting active');

      if (kDebugMode) {
        debugPrint('✅ Integrated meeting started:');
        debugPrint('   Meeting: $meetingId');
        debugPrint('   User: $userName ($userId)');
        debugPrint('   Target Language: $targetLanguage');
      }

      notifyListeners();

    } catch (e) {
      _updateStatus('❌ Failed to start meeting: $e');
      if (kDebugMode) {
        debugPrint('❌ Error starting integrated meeting: $e');
      }
      rethrow;
    }
  }

  // 🎤 START SPEECH LISTENING (Connected to WebRTC audio)
  Future<void> startSpeechListening() async {
    if (!_isActive || _isListeningToSpeech) return;

    try {
      _updateStatus('🎤 Starting speech recognition...');

      // Start speech service with meeting context
      await _speechService!.startListening(
        meetingId: _currentMeetingId,
        userId: _currentUserId,
        preferredLanguage: _myTargetLanguage,
      );

      _isListeningToSpeech = true;
      _updateStatus('🎤 Listening for speech...');

      if (kDebugMode) {
        debugPrint('🎤 Speech listening started for meeting: $_currentMeetingId');
      }

      notifyListeners();

    } catch (e) {
      _updateStatus('❌ Speech start failed: $e');
      if (kDebugMode) {
        debugPrint('❌ Error starting speech listening: $e');
      }
      rethrow;
    }
  }

  // 🛑 STOP SPEECH LISTENING
  Future<void> stopSpeechListening() async {
    if (!_isListeningToSpeech) return;

    try {
      _updateStatus('🛑 Stopping speech recognition...');

      await _speechService!.stopListening();

      _isListeningToSpeech = false;
      _updateStatus('✅ Speech stopped');

      if (kDebugMode) {
        debugPrint('🛑 Speech listening stopped');
      }

      notifyListeners();

    } catch (e) {
      _updateStatus('❌ Stop speech failed: $e');
      if (kDebugMode) {
        debugPrint('❌ Error stopping speech: $e');
      }
    }
  }

  // 📝 HANDLE SPEECH RESULT FROM GOOGLE SPEECH SERVICE
  Future<void> _handleSpeechResult(SpeechTranslationResult speechResult) async {
    try {
      if (!_isActive || _currentMeetingId.isEmpty) return;

      // Convert to meeting speech result
      final meetingResult = MeetingSpeechResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        meetingId: _currentMeetingId,
        speakerId: speechResult.userId,
        speakerName: speechResult.userName,
        originalText: speechResult.originalText,
        detectedLanguage: speechResult.detectedLanguage,
        translations: speechResult.translations,
        confidence: speechResult.confidence,
        timestamp: speechResult.timestamp,
        isFinal: speechResult.isFinal,
        audioLength: const Duration(seconds: 3), // Estimated
      );

      // Add to local results
      _meetingSpeechResults.insert(0, meetingResult);

      // Keep only last 50 results for performance
      if (_meetingSpeechResults.length > 50) {
        _meetingSpeechResults.removeRange(50, _meetingSpeechResults.length);
      }

      // Broadcast to all participants via Firestore
      await _broadcastSpeechResult(meetingResult);

      // Emit to local listeners
      _speechResultController.add(meetingResult);

      if (kDebugMode) {
        debugPrint('📝 Speech result processed and broadcasted:');
        debugPrint('   Speaker: ${meetingResult.speakerName}');
        debugPrint('   Original: "${meetingResult.originalText}"');
        debugPrint('   Language: ${meetingResult.detectedLanguage}');
        debugPrint('   Translations: ${meetingResult.translations.length}');
      }

      notifyListeners();

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error handling speech result: $e');
      }
    }
  }

  // 📡 BROADCAST SPEECH RESULT TO ALL PARTICIPANTS
  Future<void> _broadcastSpeechResult(MeetingSpeechResult result) async {
    try {
      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('real_time_speech')
          .doc(result.id)
          .set(result.toJson());

      if (kDebugMode) {
        debugPrint('📡 Speech result broadcasted via Firestore');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error broadcasting speech result: $e');
      }
    }
  }

  // 💾 SAVE MY LANGUAGE PREFERENCE
  Future<void> _saveMyLanguagePreference() async {
    try {
      final preference = ParticipantLanguagePreference(
        userId: _currentUserId,
        userName: _currentUserName,
        targetLanguage: _myTargetLanguage,
        lastUpdated: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('language_preferences')
          .doc(_currentUserId)
          .set(preference.toJson());

      if (kDebugMode) {
        debugPrint('💾 Language preference saved: $_myTargetLanguage');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving language preference: $e');
      }
    }
  }

  // 👂 SETUP FIRESTORE LISTENERS
  void _setupFirestoreListeners() {
    if (_currentMeetingId.isEmpty) return;

    // Listen to real-time speech results from other participants
    final speechSubscription = FirebaseFirestore.instance
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('real_time_speech')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final result = MeetingSpeechResult.fromJson(data);

              // Only add if not from current user (avoid duplicates)
              if (result.speakerId != _currentUserId) {
                _meetingSpeechResults.insert(0, result);
                _speechResultController.add(result);
              }
            }
          }
        }

        // Keep only last 50 results
        if (_meetingSpeechResults.length > 50) {
          _meetingSpeechResults.removeRange(50, _meetingSpeechResults.length);
        }

        notifyListeners();
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ Speech results listener error: $error');
        }
      },
    );

    // Listen to participant language preferences
    final preferencesSubscription = FirebaseFirestore.instance
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('language_preferences')
        .snapshots()
        .listen(
          (snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final preference = ParticipantLanguagePreference.fromJson(data);
          _participantPreferences[preference.userId] = preference;
          _participantUpdateController.add(preference);
        }
        notifyListeners();
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ Preferences listener error: $error');
        }
      },
    );

    _firestoreSubscriptions.addAll([speechSubscription, preferencesSubscription]);

    if (kDebugMode) {
      debugPrint('👂 Firestore listeners setup complete');
    }
  }

  // 🌐 CHANGE MY TARGET LANGUAGE
  Future<void> changeMyTargetLanguage(String newLanguage) async {
    if (newLanguage == _myTargetLanguage) return;

    try {
      _myTargetLanguage = newLanguage;

      // Update speech service
      _speechService!.setPreferredLanguage(newLanguage);

      // Save to Firestore
      await _saveMyLanguagePreference();

      _updateStatus('🌐 Language changed to $newLanguage');

      if (kDebugMode) {
        debugPrint('🌐 Target language changed to: $newLanguage');
      }

      notifyListeners();

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error changing language: $e');
      }
    }
  }

  // 🎯 GET TEXT FOR CURRENT USER
  String getTextForCurrentUser(MeetingSpeechResult result) {
    return result.getTextForUser(_myTargetLanguage, _currentUserId);
  }

  // 👥 GET PARTICIPANT TARGET LANGUAGE
  String getParticipantTargetLanguage(String userId) {
    return _participantPreferences[userId]?.targetLanguage ?? 'en';
  }

  // 🏁 STOP INTEGRATED MEETING
  Future<void> stopIntegratedMeeting() async {
    try {
      _updateStatus('Stopping integrated meeting...');

      // Stop speech listening
      if (_isListeningToSpeech) {
        await stopSpeechListening();
      }

      // Cancel Firestore subscriptions
      for (var subscription in _firestoreSubscriptions) {
        await subscription.cancel();
      }
      _firestoreSubscriptions.clear();

      // Cancel speech subscriptions
      await _speechSubscription?.cancel();
      await _speechStatusSubscription?.cancel();

      // Clear state
      _isActive = false;
      _currentMeetingId = '';
      _currentUserId = '';
      _currentUserName = '';
      _meetingSpeechResults.clear();
      _participantPreferences.clear();

      _updateStatus('✅ Meeting stopped');

      if (kDebugMode) {
        debugPrint('🏁 Integrated meeting stopped');
      }

      notifyListeners();

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error stopping meeting: $e');
      }
    }
  }

  // 📱 UPDATE STATUS
  void _updateStatus(String status) {
    _statusController.add(status);
    if (kDebugMode) {
      debugPrint('📱 Status: $status');
    }
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint('🧹 Disposing IntegratedMeetingService...');
    }

    stopIntegratedMeeting();

    _speechResultController.close();
    _statusController.close();
    _participantUpdateController.close();

    super.dispose();
  }
}