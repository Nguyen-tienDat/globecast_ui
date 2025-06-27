// lib/services/integrated_meeting_translation_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'webrtc_mesh_meeting_service.dart';
import 'multilingual_speech_service.dart';
import 'realtime_meeting_sync_service.dart';

// 🎯 INTEGRATED TRANSLATION RESULT
class IntegratedTranslationResult {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations; // languageCode -> translatedText
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;
  final Duration speechDuration;

  IntegratedTranslationResult({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.confidence,
    required this.timestamp,
    required this.isFinal,
    required this.speechDuration,
  });

  // Get translation for specific user's target language
  String getTranslationForUser(String userTargetLanguage) {
    if (userTargetLanguage == detectedLanguage) {
      return originalText;
    }
    return translations[userTargetLanguage] ?? originalText;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'speakerId': speakerId,
    'speakerName': speakerName,
    'originalText': originalText,
    'detectedLanguage': detectedLanguage,
    'translations': translations,
    'confidence': confidence,
    'timestamp': timestamp.toIso8601String(),
    'isFinal': isFinal,
    'speechDuration': speechDuration.inMilliseconds,
  };
}

// 🎯 USER LANGUAGE PREFERENCE
class UserLanguagePreference {
  final String userId;
  final String displayName;
  final String targetLanguage; // Language user wants to see
  final String speakingLanguage; // Language user speaks (optional)

  UserLanguagePreference({
    required this.userId,
    required this.displayName,
    required this.targetLanguage,
    this.speakingLanguage = 'auto',
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'targetLanguage': targetLanguage,
    'speakingLanguage': speakingLanguage,
  };

  factory UserLanguagePreference.fromJson(Map<String, dynamic> json) =>
      UserLanguagePreference(
        userId: json['userId'] ?? '',
        displayName: json['displayName'] ?? '',
        targetLanguage: json['targetLanguage'] ?? 'en',
        speakingLanguage: json['speakingLanguage'] ?? 'auto',
      );
}

class IntegratedMeetingTranslationService extends ChangeNotifier {
  // 🎯 SERVICE DEPENDENCIES
  WebRTCMeshMeetingService? _webrtcService;
  MultilingualSpeechService? _speechService;
  RealtimeMeetingSyncService? _syncService;

  // 🎯 MEETING STATE
  String _meetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  UserLanguagePreference? _currentUserPreference;
  final Map<String, UserLanguagePreference> _participantPreferences = {};

  // 🎯 TRANSLATION STATE
  bool _isTranslationActive = false;
  bool _isCurrentUserSpeaking = false;
  String? _currentSpeakerId;
  final List<IntegratedTranslationResult> _translationHistory = [];

  // 🎯 REAL-TIME PROCESSING
  Timer? _speechDetectionTimer;
  String _currentSpeechBuffer = '';
  DateTime? _speechStartTime;

  // 🎯 FIRESTORE COLLECTIONS
  CollectionReference? _meetingTranslationsCollection;
  CollectionReference? _userPreferencesCollection;
  StreamSubscription<QuerySnapshot>? _translationsSubscription;
  StreamSubscription<QuerySnapshot>? _preferencesSubscription;

  // 🎯 STREAM CONTROLLERS
  final StreamController<IntegratedTranslationResult> _newTranslationController =
  StreamController<IntegratedTranslationResult>.broadcast();
  final StreamController<UserLanguagePreference> _participantPreferenceController =
  StreamController<UserLanguagePreference>.broadcast();
  final StreamController<String> _currentSpeakerController =
  StreamController<String>.broadcast();

  // 🎯 GETTERS
  bool get isTranslationActive => _isTranslationActive;
  bool get isCurrentUserSpeaking => _isCurrentUserSpeaking;
  String? get currentSpeakerId => _currentSpeakerId;
  String get meetingId => _meetingId;
  UserLanguagePreference? get currentUserPreference => _currentUserPreference;
  List<UserLanguagePreference> get participantPreferences => _participantPreferences.values.toList();
  List<IntegratedTranslationResult> get translationHistory => List.unmodifiable(_translationHistory);

  // 🎯 STREAMS
  Stream<IntegratedTranslationResult> get newTranslationStream => _newTranslationController.stream;
  Stream<UserLanguagePreference> get participantPreferenceStream => _participantPreferenceController.stream;
  Stream<String> get currentSpeakerStream => _currentSpeakerController.stream;

  // 🚀 INITIALIZE INTEGRATED SERVICE
  Future<void> initialize({
    required WebRTCMeshMeetingService webrtcService,
    required MultilingualSpeechService speechService,
    required RealtimeMeetingSyncService syncService,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 Initializing Integrated Meeting Translation Service...');
      }

      _webrtcService = webrtcService;
      _speechService = speechService;
      _syncService = syncService;

      // Connect speech service to WebRTC
      if (_webrtcService!.localRenderer != null) {
        _speechService!.setWebRTCStream(_webrtcService!.localRenderer!.srcObject);
      }

      // Setup listeners
      _setupServiceListeners();

      if (kDebugMode) {
        print('✅ Integrated Meeting Translation Service initialized');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing integrated service: $e');
      }
      rethrow;
    }
  }

  // 🎯 JOIN MEETING WITH TRANSLATION
  Future<void> joinMeetingWithTranslation({
    required String meetingId,
    required String userId,
    required String userName,
    required String targetLanguage,
    String speakingLanguage = 'auto',
  }) async {
    try {
      if (kDebugMode) {
        print('🎯 Joining meeting with translation...');
        print('   Meeting: $meetingId');
        print('   User: $userName ($userId)');
        print('   Target Language: $targetLanguage');
      }

      _meetingId = meetingId;
      _currentUserId = userId;
      _currentUserName = userName;

      // Create user language preference
      _currentUserPreference = UserLanguagePreference(
        userId: userId,
        displayName: userName,
        targetLanguage: targetLanguage,
        speakingLanguage: speakingLanguage,
      );

      // Setup Firestore collections
      _setupFirestoreCollections();

      // Save user preference to Firestore
      await _saveUserPreference();

      // Setup real-time listeners
      _setupRealtimeListeners();

      // Configure speech service
      await _configureSpeechService();

      if (kDebugMode) {
        print('✅ Joined meeting with translation successfully');
      }

      notifyListeners();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error joining meeting with translation: $e');
      }
      rethrow;
    }
  }

  // 🔧 SETUP FIRESTORE COLLECTIONS
  void _setupFirestoreCollections() {
    final firestore = FirebaseFirestore.instance;
    _meetingTranslationsCollection = firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('translations');

    _userPreferencesCollection = firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('userPreferences');
  }

  // 💾 SAVE USER PREFERENCE
  Future<void> _saveUserPreference() async {
    if (_userPreferencesCollection == null || _currentUserPreference == null) return;

    try {
      await _userPreferencesCollection!.doc(_currentUserId).set({
        ..._currentUserPreference!.toJson(),
        'isActive': true,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('💾 User preference saved: ${_currentUserPreference!.targetLanguage}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving user preference: $e');
      }
    }
  }

  // 👂 SETUP REAL-TIME LISTENERS
  void _setupRealtimeListeners() {
    // Listen for translation results
    _translationsSubscription = _meetingTranslationsCollection!
        .orderBy('timestamp', descending: false)
        .limit(50)
        .snapshots()
        .listen(_onTranslationsChanged);

    // Listen for user preferences
    _preferencesSubscription = _userPreferencesCollection!
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(_onUserPreferencesChanged);
  }

  // 📝 HANDLE TRANSLATIONS CHANGED
  void _onTranslationsChanged(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>;
        final result = _createTranslationResultFromFirestore(change.doc.id, data);

        // Add to history if not already exists
        if (!_translationHistory.any((t) => t.id == result.id)) {
          _translationHistory.add(result);

          // Limit history size
          if (_translationHistory.length > 100) {
            _translationHistory.removeAt(0);
          }

          // Broadcast new translation
          _newTranslationController.add(result);

          if (kDebugMode) {
            print('📝 New translation received: ${result.originalText} (${result.detectedLanguage})');
          }
        }
      }
    }

    notifyListeners();
  }

  // 👥 HANDLE USER PREFERENCES CHANGED
  void _onUserPreferencesChanged(QuerySnapshot snapshot) {
    _participantPreferences.clear();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final preference = UserLanguagePreference.fromJson(data);
      _participantPreferences[preference.userId] = preference;

      _participantPreferenceController.add(preference);
    }

    if (kDebugMode) {
      print('👥 Updated participant preferences: ${_participantPreferences.length}');
    }

    notifyListeners();
  }

  // 🔧 SETUP SERVICE LISTENERS
  void _setupServiceListeners() {
    // Listen to WebRTC participant changes
    _webrtcService?.addListener(_onWebRTCStateChanged);

    // Listen to speech recognition results
    _speechService?.speechResultStream.listen(_onSpeechResult);

    // Listen to sync service speaker changes
    _syncService?.speakerChangeStream.listen(_onSpeakerChanged);
  }

  // 🎥 HANDLE WEBRTC STATE CHANGES
  void _onWebRTCStateChanged() {
    // Update current speaker based on WebRTC participants
    final currentSpeaker = _webrtcService?.participants
        .where((p) => p.isAudioEnabled)
        .firstWhere((p) => p.isLocal, orElse: () => _webrtcService!.participants.first);

    if (currentSpeaker != null && currentSpeaker.id != _currentSpeakerId) {
      _setCurrentSpeaker(currentSpeaker.id);
    }
  }

  // 🗣️ HANDLE SPEECH RESULT
  void _onSpeechResult(SpeechResult speechResult) async {
    if (speechResult.userId != _currentUserId) return; // Only process own speech

    try {
      if (kDebugMode) {
        print('🗣️ Processing speech result: ${speechResult.originalText}');
      }

      // Create integrated result with all target languages
      final targetLanguages = _getActiveTargetLanguages();
      final allTranslations = <String, String>{};

      // Include original language
      allTranslations[speechResult.detectedLanguage] = speechResult.originalText;

      // Add existing translations
      allTranslations.addAll(speechResult.translations);

      // Ensure all target languages are covered
      for (final targetLang in targetLanguages) {
        if (!allTranslations.containsKey(targetLang) && targetLang != speechResult.detectedLanguage) {
          // Translation should already be in speechResult.translations from MultilingualSpeechService
          allTranslations[targetLang] = speechResult.translations[targetLang] ?? speechResult.originalText;
        }
      }

      final integratedResult = IntegratedTranslationResult(
        id: 'trans_${DateTime.now().millisecondsSinceEpoch}',
        speakerId: speechResult.userId,
        speakerName: speechResult.userName,
        originalText: speechResult.originalText,
        detectedLanguage: speechResult.detectedLanguage,
        translations: allTranslations,
        confidence: speechResult.confidence,
        timestamp: speechResult.timestamp,
        isFinal: speechResult.isFinal,
        speechDuration: _calculateSpeechDuration(),
      );

      // Save to Firestore for real-time sync
      await _saveTranslationResult(integratedResult);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing speech result: $e');
      }
    }
  }

  // 🎤 HANDLE SPEAKER CHANGED
  void _onSpeakerChanged(String newSpeakerId) {
    _setCurrentSpeaker(newSpeakerId);
  }

  // 🎯 SET CURRENT SPEAKER
  void _setCurrentSpeaker(String speakerId) {
    if (_currentSpeakerId != speakerId) {
      _currentSpeakerId = speakerId;
      _isCurrentUserSpeaking = speakerId == _currentUserId;

      if (_isCurrentUserSpeaking) {
        _speechStartTime = DateTime.now();
      }

      _currentSpeakerController.add(speakerId);

      if (kDebugMode) {
        print('🎤 Speaker changed: $speakerId (isMe: $_isCurrentUserSpeaking)');
      }

      notifyListeners();
    }
  }

  // 🔧 CONFIGURE SPEECH SERVICE
  Future<void> _configureSpeechService() async {
    if (_speechService == null || _currentUserPreference == null) return;

    try {
      // Set user context
      _speechService!.setUserContext(_currentUserId, _currentUserName);
      _speechService!.setTranslationContext(_meetingId);

      // Set preferred language (what user speaks)
      final speakingLanguage = _currentUserPreference!.speakingLanguage == 'auto'
          ? _currentUserPreference!.targetLanguage
          : _currentUserPreference!.speakingLanguage;

      _speechService!.setPreferredLanguage(speakingLanguage);

      // Set all target languages from participants
      final targetLanguages = _getActiveTargetLanguages();
      _speechService!.setTargetLanguages(targetLanguages);

      if (kDebugMode) {
        print('🔧 Speech service configured:');
        print('   Speaking: $speakingLanguage');
        print('   Targets: $targetLanguages');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error configuring speech service: $e');
      }
    }
  }

  // 📊 GET ACTIVE TARGET LANGUAGES
  List<String> _getActiveTargetLanguages() {
    final targetLanguages = <String>{};

    // Add current user's target language
    if (_currentUserPreference != null) {
      targetLanguages.add(_currentUserPreference!.targetLanguage);
    }

    // Add all participants' target languages
    for (final preference in _participantPreferences.values) {
      targetLanguages.add(preference.targetLanguage);
    }

    // Ensure common languages are included
    targetLanguages.addAll(['en', 'vi', 'zh', 'ja', 'ko']);

    return targetLanguages.toList();
  }

  // 💾 SAVE TRANSLATION RESULT
  Future<void> _saveTranslationResult(IntegratedTranslationResult result) async {
    if (_meetingTranslationsCollection == null) return;

    try {
      await _meetingTranslationsCollection!.doc(result.id).set({
        'speakerId': result.speakerId,
        'speakerName': result.speakerName,
        'originalText': result.originalText,
        'detectedLanguage': result.detectedLanguage,
        'translations': result.translations,
        'confidence': result.confidence,
        'timestamp': Timestamp.fromDate(result.timestamp),
        'isFinal': result.isFinal,
        'speechDuration': result.speechDuration.inMilliseconds,
        'meetingId': _meetingId,
      });

      if (kDebugMode) {
        print('💾 Translation result saved: ${result.id}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving translation result: $e');
      }
    }
  }

  // 📈 CREATE TRANSLATION RESULT FROM FIRESTORE
  IntegratedTranslationResult _createTranslationResultFromFirestore(String id, Map<String, dynamic> data) {
    return IntegratedTranslationResult(
      id: id,
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? '',
      originalText: data['originalText'] ?? '',
      detectedLanguage: data['detectedLanguage'] ?? 'unknown',
      translations: Map<String, String>.from(data['translations'] ?? {}),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFinal: data['isFinal'] ?? false,
      speechDuration: Duration(milliseconds: data['speechDuration'] ?? 0),
    );
  }

  // ⏱️ CALCULATE SPEECH DURATION
  Duration _calculateSpeechDuration() {
    if (_speechStartTime == null) return Duration.zero;
    return DateTime.now().difference(_speechStartTime!);
  }

  // 🎤 START TRANSLATION
  Future<void> startTranslation() async {
    if (_isTranslationActive) return;

    try {
      if (kDebugMode) {
        print('🎤 Starting translation...');
      }

      // Start speech recognition
      await _speechService?.startListening(
        meetingId: _meetingId,
        userId: _currentUserId,
        preferredLanguage: _currentUserPreference?.speakingLanguage ?? 'auto',
      );

      _isTranslationActive = true;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Translation started successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting translation: $e');
      }
      rethrow;
    }
  }

  // 🛑 STOP TRANSLATION
  Future<void> stopTranslation() async {
    if (!_isTranslationActive) return;

    try {
      if (kDebugMode) {
        print('🛑 Stopping translation...');
      }

      await _speechService?.stopListening();

      _isTranslationActive = false;
      _speechStartTime = null;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Translation stopped successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping translation: $e');
      }
    }
  }

  // 🔄 UPDATE USER TARGET LANGUAGE
  Future<void> updateUserTargetLanguage(String newTargetLanguage) async {
    if (_currentUserPreference?.targetLanguage == newTargetLanguage) return;

    try {
      _currentUserPreference = UserLanguagePreference(
        userId: _currentUserId,
        displayName: _currentUserName,
        targetLanguage: newTargetLanguage,
        speakingLanguage: _currentUserPreference?.speakingLanguage ?? 'auto',
      );

      // Update in Firestore
      await _saveUserPreference();

      // Reconfigure speech service
      await _configureSpeechService();

      if (kDebugMode) {
        print('🔄 Updated target language: $newTargetLanguage');
      }

      notifyListeners();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating target language: $e');
      }
    }
  }

  // 🎯 GET TRANSLATION FOR USER
  String getTranslationForUser(IntegratedTranslationResult result, String? userId) {
    final userPreference = userId != null ? _participantPreferences[userId] : _currentUserPreference;
    final targetLanguage = userPreference?.targetLanguage ?? 'en';
    return result.getTranslationForUser(targetLanguage);
  }

  // 📊 GET TRANSLATION STATISTICS
  Map<String, dynamic> getTranslationStatistics() {
    final totalTranslations = _translationHistory.length;
    final languageCount = <String, int>{};

    for (final result in _translationHistory) {
      languageCount[result.detectedLanguage] = (languageCount[result.detectedLanguage] ?? 0) + 1;
    }

    return {
      'totalTranslations': totalTranslations,
      'languageDistribution': languageCount,
      'participantCount': _participantPreferences.length,
      'activeTargetLanguages': _getActiveTargetLanguages(),
    };
  }

  // 🚪 LEAVE MEETING
  Future<void> leaveMeeting() async {
    try {
      if (kDebugMode) {
        print('🚪 Leaving meeting with translation...');
      }

      // Stop translation
      await stopTranslation();

      // Update user preference to inactive
      if (_userPreferencesCollection != null) {
        await _userPreferencesCollection!.doc(_currentUserId).update({
          'isActive': false,
          'leftAt': FieldValue.serverTimestamp(),
        });
      }

      await _cleanup();

      if (kDebugMode) {
        print('✅ Left meeting successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error leaving meeting: $e');
      }
    }
  }

  // 🧹 CLEANUP
  Future<void> _cleanup() async {
    // Cancel subscriptions
    await _translationsSubscription?.cancel();
    await _preferencesSubscription?.cancel();

    // Remove listeners
    _webrtcService?.removeListener(_onWebRTCStateChanged);

    // Cancel timers
    _speechDetectionTimer?.cancel();

    // Clear state
    _participantPreferences.clear();
    _translationHistory.clear();
    _isTranslationActive = false;
    _isCurrentUserSpeaking = false;
    _currentSpeakerId = null;
    _speechStartTime = null;

    notifyListeners();
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing Integrated Meeting Translation Service...');
    }

    _cleanup();
    _newTranslationController.close();
    _participantPreferenceController.close();
    _currentSpeakerController.close();

    super.dispose();
  }
}