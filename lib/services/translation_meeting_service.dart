// lib/services/translation_meeting_service.dart - COMPLETE INTEGRATION
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'webrtc_mesh_meeting_service.dart';
import 'multilingual_speech_service.dart';

// 🎯 REAL-TIME TRANSLATION MESSAGE MODEL
class TranslationMessage {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations;
  final DateTime timestamp;
  final double confidence;
  final bool isFinal;
  final int sequenceNumber;

  TranslationMessage({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.timestamp,
    required this.confidence,
    required this.isFinal,
    required this.sequenceNumber,
  });

  // Get text for specific language
  String getTextForLanguage(String languageCode) {
    if (languageCode == detectedLanguage) {
      return originalText;
    }
    return translations[languageCode] ?? originalText;
  }

  factory TranslationMessage.fromFirestore(Map<String, dynamic> data) {
    return TranslationMessage(
      id: data['id'] ?? '',
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? '',
      originalText: data['originalText'] ?? '',
      detectedLanguage: data['detectedLanguage'] ?? 'en',
      translations: Map<String, String>.from(data['translations'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      isFinal: data['isFinal'] ?? false,
      sequenceNumber: data['sequenceNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'detectedLanguage': detectedLanguage,
      'translations': translations,
      'timestamp': Timestamp.fromDate(timestamp),
      'confidence': confidence,
      'isFinal': isFinal,
      'sequenceNumber': sequenceNumber,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// 🎯 USER LANGUAGE PREFERENCE MODEL
class UserLanguagePreference {
  final String userId;
  final String speakingLanguage;
  final String displayLanguage;
  final String userName;

  UserLanguagePreference({
    required this.userId,
    required this.speakingLanguage,
    required this.displayLanguage,
    required this.userName,
  });

  factory UserLanguagePreference.fromFirestore(Map<String, dynamic> data) {
    return UserLanguagePreference(
      userId: data['userId'] ?? '',
      speakingLanguage: data['speakingLanguage'] ?? 'en',
      displayLanguage: data['displayLanguage'] ?? 'en',
      userName: data['userName'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'speakingLanguage': speakingLanguage,
      'displayLanguage': displayLanguage,
      'userName': userName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

// 🎯 COMPLETE TRANSLATION MEETING SERVICE
class TranslationMeetingService extends ChangeNotifier {
  // 🔗 INTEGRATED SERVICES
  final WebRTCMeshMeetingService _webrtcService;
  final MultilingualSpeechService _speechService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎯 MEETING STATE
  String _meetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  UserLanguagePreference? _currentUserPreference;

  // 🗣️ REAL-TIME TRANSLATION STATE
  final List<TranslationMessage> _translationMessages = [];
  String? _currentSpeakerId;
  int _messageSequence = 0;
  bool _isTranslationActive = false;

  // 👥 PARTICIPANTS LANGUAGE PREFERENCES
  final Map<String, UserLanguagePreference> _participantPreferences = {};

  // 📡 STREAM SUBSCRIPTIONS
  StreamSubscription<QuerySnapshot>? _translationSubscription;
  StreamSubscription<QuerySnapshot>? _preferencesSubscription;
  StreamSubscription<SpeechResult>? _speechSubscription;

  // 📊 STREAM CONTROLLERS
  final StreamController<TranslationMessage> _newMessageController =
  StreamController<TranslationMessage>.broadcast();
  final StreamController<String> _speakerChangeController =
  StreamController<String>.broadcast();
  final StreamController<Map<String, UserLanguagePreference>> _preferencesController =
  StreamController<Map<String, UserLanguagePreference>>.broadcast();

  // 🎯 CONSTRUCTOR
  TranslationMeetingService({
    required WebRTCMeshMeetingService webrtcService,
    required MultilingualSpeechService speechService,
  }) : _webrtcService = webrtcService,
        _speechService = speechService {

    // Connect services
    _webrtcService.setSpeechService(_speechService);

    if (kDebugMode) {
      print('🔗 TranslationMeetingService created with integrated services');
    }
  }

  // 🎯 GETTERS
  String get meetingId => _meetingId;
  String get currentUserId => _currentUserId;
  UserLanguagePreference? get currentUserPreference => _currentUserPreference;
  List<TranslationMessage> get translationMessages => List.unmodifiable(_translationMessages);
  String? get currentSpeakerId => _currentSpeakerId;
  bool get isTranslationActive => _isTranslationActive;
  Map<String, UserLanguagePreference> get participantPreferences =>
      Map.unmodifiable(_participantPreferences);

  // Streams
  Stream<TranslationMessage> get newMessageStream => _newMessageController.stream;
  Stream<String> get speakerChangeStream => _speakerChangeController.stream;
  Stream<Map<String, UserLanguagePreference>> get preferencesStream =>
      _preferencesController.stream;

  // 🚀 INITIALIZE INTEGRATED MEETING
  Future<void> initializeTranslationMeeting({
    required String meetingId,
    required String userId,
    required String userName,
    required String speakingLanguage,
    required String displayLanguage,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 Initializing complete translation meeting...');
        print('   Meeting: $meetingId');
        print('   User: $userName ($userId)');
        print('   Speaking: $speakingLanguage');
        print('   Display: $displayLanguage');
      }

      _meetingId = meetingId;
      _currentUserId = userId;
      _currentUserName = userName;

      // Create user language preference
      _currentUserPreference = UserLanguagePreference(
        userId: userId,
        speakingLanguage: speakingLanguage,
        displayLanguage: displayLanguage,
        userName: userName,
      );

      // ✅ STEP 1: Initialize WebRTC Service
      if (!_webrtcService.isInitialized) {
        await _webrtcService.initialize();
      }
      _webrtcService.setUserDetails(displayName: userName, userId: userId);

      // ✅ STEP 2: Initialize Speech Service
      if (!_speechService.isAvailable) {
        await _speechService.initialize();
      }
      _speechService.setUserContext(userId, userName);
      _speechService.setTranslationContext(meetingId);
      _speechService.setPreferredLanguage(speakingLanguage);
      _speechService.setTargetLanguages(_getAllRequiredLanguages());

      // ✅ STEP 3: Save user language preferences
      await _saveUserLanguagePreferences();

      // ✅ STEP 4: Setup real-time listeners
      _setupTranslationListeners();
      _setupSpeechIntegration();

      // ✅ STEP 5: Join WebRTC meeting
      if (meetingId.startsWith('GCM')) {
        // Join existing meeting
        await _webrtcService.joinMeeting(meetingId: meetingId);
      } else {
        // Create new meeting
        final newMeetingId = await _webrtcService.createMeeting(topic: 'Translation Meeting');
        _meetingId = newMeetingId;
      }

      _isTranslationActive = true;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Translation meeting initialized successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing translation meeting: $e');
      }
      rethrow;
    }
  }

  // 💾 SAVE USER LANGUAGE PREFERENCES
  Future<void> _saveUserLanguagePreferences() async {
    if (_currentUserPreference == null) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('language_preferences')
          .doc(_currentUserId)
          .set(_currentUserPreference!.toFirestore());

      if (kDebugMode) {
        print('💾 User language preferences saved');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving language preferences: $e');
      }
    }
  }

  // 📡 SETUP TRANSLATION LISTENERS
  void _setupTranslationListeners() {
    if (kDebugMode) {
      print('📡 Setting up translation listeners...');
    }

    // Listen to translation messages
    _translationSubscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('translations')
        .orderBy('sequenceNumber', descending: false)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(_onTranslationMessagesChanged);

    // Listen to language preferences
    _preferencesSubscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('language_preferences')
        .snapshots()
        .listen(_onLanguagePreferencesChanged);
  }

  // 🎧 SETUP SPEECH INTEGRATION
  void _setupSpeechIntegration() {
    if (kDebugMode) {
      print('🎧 Setting up speech integration...');
    }

    // Listen to speech results and broadcast as translation messages
    _speechSubscription = _speechService.speechResultStream.listen(
          (speechResult) async {
        await _broadcastTranslationMessage(speechResult);
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Speech integration error: $error');
        }
      },
    );
  }

  // 📡 HANDLE TRANSLATION MESSAGES CHANGES
  void _onTranslationMessagesChanged(QuerySnapshot snapshot) {
    if (kDebugMode) {
      print('📡 Translation messages changed: ${snapshot.docs.length} messages');
    }

    final previousMessageIds = _translationMessages.map((m) => m.id).toSet();
    _translationMessages.clear();

    String? newCurrentSpeaker;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final message = TranslationMessage.fromFirestore(data);
      _translationMessages.add(message);

      // Track current speaker
      if (message.isFinal && message.timestamp.isAfter(
          DateTime.now().subtract(const Duration(seconds: 10)))) {
        newCurrentSpeaker = message.speakerId;
      }

      // Broadcast new messages
      if (!previousMessageIds.contains(message.id)) {
        _newMessageController.add(message);
      }
    }

    // Update current speaker
    if (newCurrentSpeaker != _currentSpeakerId) {
      _currentSpeakerId = newCurrentSpeaker;
      if (newCurrentSpeaker != null) {
        _speakerChangeController.add(newCurrentSpeaker);
      }
    }

    notifyListeners();
  }

  // 👥 HANDLE LANGUAGE PREFERENCES CHANGES
  void _onLanguagePreferencesChanged(QuerySnapshot snapshot) {
    if (kDebugMode) {
      print('👥 Language preferences changed: ${snapshot.docs.length} participants');
    }

    _participantPreferences.clear();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final preference = UserLanguagePreference.fromFirestore(data);
      _participantPreferences[preference.userId] = preference;
    }

    // Update speech service with all required languages
    _speechService.setTargetLanguages(_getAllRequiredLanguages());

    _preferencesController.add(Map.from(_participantPreferences));
    notifyListeners();
  }

  // 🌐 GET ALL REQUIRED LANGUAGES
  List<String> _getAllRequiredLanguages() {
    final allLanguages = <String>{};

    // Add current user's languages
    if (_currentUserPreference != null) {
      allLanguages.add(_currentUserPreference!.speakingLanguage);
      allLanguages.add(_currentUserPreference!.displayLanguage);
    }

    // Add other participants' languages
    for (final preference in _participantPreferences.values) {
      allLanguages.add(preference.speakingLanguage);
      allLanguages.add(preference.displayLanguage);
    }

    // Add default supported languages
    allLanguages.addAll(['en', 'vi', 'zh', 'ja', 'ko', 'th', 'es', 'fr', 'de', 'ar', 'hi']);

    final result = allLanguages.toList();
    if (kDebugMode) {
      print('🌐 Required languages: $result');
    }
    return result;
  }

  // 📤 BROADCAST TRANSLATION MESSAGE
  Future<void> _broadcastTranslationMessage(SpeechResult speechResult) async {
    try {
      _messageSequence++;

      final translationMessage = TranslationMessage(
        id: '${_currentUserId}_${_messageSequence}_${DateTime.now().millisecondsSinceEpoch}',
        speakerId: speechResult.userId,
        speakerName: speechResult.userName,
        originalText: speechResult.originalText,
        detectedLanguage: speechResult.detectedLanguage,
        translations: speechResult.translations,
        timestamp: speechResult.timestamp,
        confidence: speechResult.confidence,
        isFinal: speechResult.isFinal,
        sequenceNumber: _messageSequence,
      );

      // Save to Firestore for real-time sync
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('translations')
          .doc(translationMessage.id)
          .set(translationMessage.toFirestore());

      if (kDebugMode) {
        print('📤 Translation message broadcasted:');
        print('   Speaker: ${translationMessage.speakerName}');
        print('   Original: "${translationMessage.originalText}"');
        print('   Language: ${translationMessage.detectedLanguage}');
        print('   Translations: ${translationMessage.translations.length}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error broadcasting translation message: $e');
      }
    }
  }

  // 🎤 START SPEECH TRANSLATION
  Future<void> startSpeechTranslation() async {
    try {
      if (kDebugMode) {
        print('🎤 Starting speech translation...');
      }

      await _speechService.startListening(
        meetingId: _meetingId,
        userId: _currentUserId,
        preferredLanguage: _currentUserPreference?.speakingLanguage ?? 'en',
      );

      if (kDebugMode) {
        print('✅ Speech translation started');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting speech translation: $e');
      }
      rethrow;
    }
  }

  // 🛑 STOP SPEECH TRANSLATION
  Future<void> stopSpeechTranslation() async {
    try {
      if (kDebugMode) {
        print('🛑 Stopping speech translation...');
      }

      await _speechService.stopListening();

      if (kDebugMode) {
        print('✅ Speech translation stopped');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping speech translation: $e');
      }
    }
  }

  // 🔄 UPDATE USER LANGUAGE PREFERENCES
  Future<void> updateLanguagePreferences({
    String? speakingLanguage,
    String? displayLanguage,
  }) async {
    if (_currentUserPreference == null) return;

    try {
      final updatedPreference = UserLanguagePreference(
        userId: _currentUserPreference!.userId,
        speakingLanguage: speakingLanguage ?? _currentUserPreference!.speakingLanguage,
        displayLanguage: displayLanguage ?? _currentUserPreference!.displayLanguage,
        userName: _currentUserPreference!.userName,
      );

      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('language_preferences')
          .doc(_currentUserId)
          .update(updatedPreference.toFirestore());

      _currentUserPreference = updatedPreference;

      // Update speech service
      if (speakingLanguage != null) {
        _speechService.setPreferredLanguage(speakingLanguage);
      }

      notifyListeners();

      if (kDebugMode) {
        print('🔄 Language preferences updated');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating language preferences: $e');
      }
    }
  }

  // 📊 GET MESSAGES FOR USER
  List<TranslationMessage> getMessagesForUser(String userId) {
    final userPreference = _participantPreferences[userId] ?? _currentUserPreference;
    if (userPreference == null) return [];

    return _translationMessages.map((message) {
      // If this user is the speaker, show original text
      if (message.speakerId == userId) {
        return message;
      }

      // Otherwise, show translated text in user's display language
      return TranslationMessage(
        id: message.id,
        speakerId: message.speakerId,
        speakerName: message.speakerName,
        originalText: message.getTextForLanguage(userPreference.displayLanguage),
        detectedLanguage: userPreference.displayLanguage,
        translations: message.translations,
        timestamp: message.timestamp,
        confidence: message.confidence,
        isFinal: message.isFinal,
        sequenceNumber: message.sequenceNumber,
      );
    }).toList();
  }

  // 📊 GET CURRENT USER MESSAGES (what current user should see)
  List<TranslationMessage> getCurrentUserMessages() {
    return getMessagesForUser(_currentUserId);
  }

  // 🚪 LEAVE TRANSLATION MEETING
  Future<void> leaveTranslationMeeting() async {
    try {
      if (kDebugMode) {
        print('🚪 Leaving translation meeting...');
      }

      // Stop speech translation
      await stopSpeechTranslation();

      // Cancel subscriptions
      await _translationSubscription?.cancel();
      await _preferencesSubscription?.cancel();
      await _speechSubscription?.cancel();

      // Remove language preferences
      if (_meetingId.isNotEmpty && _currentUserId.isNotEmpty) {
        try {
          await _firestore
              .collection('meetings')
              .doc(_meetingId)
              .collection('language_preferences')
              .doc(_currentUserId)
              .delete();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error removing language preferences: $e');
          }
        }
      }

      // Leave WebRTC meeting
      await _webrtcService.leaveMeeting();

      // Reset state
      _meetingId = '';
      _currentUserId = '';
      _currentUserName = '';
      _currentUserPreference = null;
      _translationMessages.clear();
      _participantPreferences.clear();
      _currentSpeakerId = null;
      _messageSequence = 0;
      _isTranslationActive = false;

      notifyListeners();

      if (kDebugMode) {
        print('✅ Left translation meeting');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error leaving translation meeting: $e');
      }
    }
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing TranslationMeetingService...');
    }

    leaveTranslationMeeting();

    _newMessageController.close();
    _speakerChangeController.close();
    _preferencesController.close();

    super.dispose();
  }

  // 🎯 UTILITY METHODS

  // Get participant by ID
  UserLanguagePreference? getParticipantPreference(String userId) {
    return _participantPreferences[userId];
  }

  // Get all participants
  List<UserLanguagePreference> getAllParticipants() {
    return _participantPreferences.values.toList();
  }

  // Check if user is currently speaking
  bool isUserSpeaking(String userId) {
    return _currentSpeakerId == userId;
  }

  // Get latest message from speaker
  TranslationMessage? getLatestMessageFromSpeaker(String speakerId) {
    final messages = _translationMessages
        .where((m) => m.speakerId == speakerId)
        .toList();

    if (messages.isEmpty) return null;

    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages.first;
  }

  // Get translation statistics
  Map<String, dynamic> getTranslationStats() {
    final stats = <String, int>{};

    for (final message in _translationMessages) {
      final lang = message.detectedLanguage;
      stats[lang] = (stats[lang] ?? 0) + 1;
    }

    return {
      'totalMessages': _translationMessages.length,
      'languageBreakdown': stats,
      'participantCount': _participantPreferences.length,
      'activeTranslation': _isTranslationActive,
    };
  }
}