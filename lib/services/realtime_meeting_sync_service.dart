// lib/services/realtime_meeting_sync_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class MeetingEvent {
  final String id;
  final String type; // 'speech_start', 'speech_update', 'speech_end', 'participant_join', 'participant_leave'
  final String meetingId;
  final String participantId;
  final String participantName;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  MeetingEvent({
    required this.id,
    required this.type,
    required this.meetingId,
    required this.participantId,
    required this.participantName,
    required this.timestamp,
    required this.data,
  });

  factory MeetingEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetingEvent(
      id: doc.id,
      type: data['type'] ?? '',
      meetingId: data['meetingId'] ?? '',
      participantId: data['participantId'] ?? '',
      participantName: data['participantName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      data: data['data'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() => {
    'type': type,
    'meetingId': meetingId,
    'participantId': participantId,
    'participantName': participantName,
    'timestamp': Timestamp.fromDate(timestamp),
    'data': data,
  };
}

class LiveTranscript {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final Map<String, String> translations; // languageCode -> translatedText
  final DateTime startTime;
  final DateTime lastUpdateTime;
  final double confidence;
  final bool isComplete;
  final bool isActive; // đang nói
  final Duration estimatedDuration;

  LiveTranscript({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.translations,
    required this.startTime,
    required this.lastUpdateTime,
    required this.confidence,
    required this.isComplete,
    required this.isActive,
    required this.estimatedDuration,
  });

  factory LiveTranscript.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveTranscript(
      id: doc.id,
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? '',
      originalText: data['originalText'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'vi',
      translations: Map<String, String>.from(data['translations'] ?? {}),
      startTime: (data['startTime'] as Timestamp).toDate(),
      lastUpdateTime: (data['lastUpdateTime'] as Timestamp).toDate(),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      isComplete: data['isComplete'] ?? false,
      isActive: data['isActive'] ?? false,
      estimatedDuration: Duration(milliseconds: data['estimatedDuration'] ?? 0),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'speakerId': speakerId,
    'speakerName': speakerName,
    'originalText': originalText,
    'originalLanguage': originalLanguage,
    'translations': translations,
    'startTime': Timestamp.fromDate(startTime),
    'lastUpdateTime': Timestamp.fromDate(lastUpdateTime),
    'confidence': confidence,
    'isComplete': isComplete,
    'isActive': isActive,
    'estimatedDuration': estimatedDuration.inMilliseconds,
  };

  // Lấy text theo ngôn ngữ user
  String getTextForLanguage(String languageCode) {
    if (languageCode == originalLanguage) {
      return originalText;
    }
    return translations[languageCode] ?? originalText;
  }
}

class ParticipantStatus {
  final String id;
  final String name;
  final String avatar;
  final String preferredLanguage;
  final bool isOnline;
  final bool isCurrentlySpeaking;
  final bool isMuted;
  final DateTime lastSeen;
  final String deviceInfo;

  ParticipantStatus({
    required this.id,
    required this.name,
    required this.avatar,
    required this.preferredLanguage,
    required this.isOnline,
    required this.isCurrentlySpeaking,
    required this.isMuted,
    required this.lastSeen,
    required this.deviceInfo,
  });

  factory ParticipantStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParticipantStatus(
      id: doc.id,
      name: data['name'] ?? '',
      avatar: data['avatar'] ?? '👤',
      preferredLanguage: data['preferredLanguage'] ?? 'vi',
      isOnline: data['isOnline'] ?? false,
      isCurrentlySpeaking: data['isCurrentlySpeaking'] ?? false,
      isMuted: data['isMuted'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
      deviceInfo: data['deviceInfo'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'avatar': avatar,
    'preferredLanguage': preferredLanguage,
    'isOnline': isOnline,
    'isCurrentlySpeaking': isCurrentlySpeaking,
    'isMuted': isMuted,
    'lastSeen': Timestamp.fromDate(lastSeen),
    'deviceInfo': deviceInfo,
  };
}

class RealtimeMeetingSyncService extends ChangeNotifier {
  // 🔥 Firestore Collections
  late CollectionReference _meetingsCollection;
  late CollectionReference _participantsCollection;
  late CollectionReference _transcriptsCollection;
  late CollectionReference _eventsCollection;

  // 📊 State Management
  String _meetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  final List<ParticipantStatus> _participants = [];
  final List<LiveTranscript> _liveTranscripts = [];
  final List<MeetingEvent> _meetingEvents = [];

  // 🎯 Current Speaking State
  String? _currentSpeakerId;
  String? _activeTranscriptId;

  // 📱 Real-time Subscriptions
  StreamSubscription<QuerySnapshot>? _participantsSubscription;
  StreamSubscription<QuerySnapshot>? _transcriptsSubscription;
  StreamSubscription<QuerySnapshot>? _eventsSubscription;

  // ⏱️ Heartbeat untuk online status
  Timer? _heartbeatTimer;

  // 🎯 UUID Generator
  final Uuid _uuid = const Uuid();

  // 📊 Getters
  String get meetingId => _meetingId;
  String get currentUserId => _currentUserId;
  List<ParticipantStatus> get participants => List.unmodifiable(_participants);
  List<LiveTranscript> get liveTranscripts => List.unmodifiable(_liveTranscripts);
  ParticipantStatus? get currentSpeaker =>
      _participants.where((p) => p.isCurrentlySpeaking).firstOrNull;
  bool get isCurrentUserSpeaking => _currentSpeakerId == _currentUserId;

  // 🎯 Events
  final StreamController<LiveTranscript> _newTranscriptController =
  StreamController<LiveTranscript>.broadcast();
  final StreamController<LiveTranscript> _transcriptUpdateController =
  StreamController<LiveTranscript>.broadcast();
  final StreamController<ParticipantStatus> _participantUpdateController =
  StreamController<ParticipantStatus>.broadcast();
  final StreamController<String> _speakerChangeController =
  StreamController<String>.broadcast();

  Stream<LiveTranscript> get newTranscriptStream => _newTranscriptController.stream;
  Stream<LiveTranscript> get transcriptUpdateStream => _transcriptUpdateController.stream;
  Stream<ParticipantStatus> get participantUpdateStream => _participantUpdateController.stream;
  Stream<String> get speakerChangeStream => _speakerChangeController.stream;

  // 🚀 Initialize Meeting
  Future<void> initializeMeeting({
    required String meetingId,
    required String userId,
    required String userName,
    String? userAvatar,
    String preferredLanguage = 'vi',
  }) async {
    try {
      _meetingId = meetingId;
      _currentUserId = userId;
      _currentUserName = userName;

      // Initialize Firestore collections
      final firestore = FirebaseFirestore.instance;
      _meetingsCollection = firestore.collection('meetings');
      _participantsCollection = _meetingsCollection.doc(meetingId).collection('participants');
      _transcriptsCollection = _meetingsCollection.doc(meetingId).collection('transcripts');
      _eventsCollection = _meetingsCollection.doc(meetingId).collection('events');

      // Join meeting as participant
      await _joinMeeting(userAvatar ?? '👤', preferredLanguage);

      // Setup real-time listeners
      _setupRealtimeListeners();

      // Start heartbeat
      _startHeartbeat();

      debugPrint('✅ Meeting sync initialized: $meetingId');
      notifyListeners();

    } catch (e) {
      debugPrint('❌ Error initializing meeting: $e');
      rethrow;
    }
  }

  // 👥 Join Meeting
  Future<void> _joinMeeting(String avatar, String preferredLanguage) async {
    try {
      await _participantsCollection.doc(_currentUserId).set({
        'name': _currentUserName,
        'avatar': avatar,
        'preferredLanguage': preferredLanguage,
        'isOnline': true,
        'isCurrentlySpeaking': false,
        'isMuted': false,
        'lastSeen': Timestamp.now(),
        'deviceInfo': await _getDeviceInfo(),
        'joinedAt': Timestamp.now(),
      });

      // Send join event
      await _sendMeetingEvent('participant_join', {
        'participantName': _currentUserName,
        'avatar': avatar,
        'preferredLanguage': preferredLanguage,
      });

    } catch (e) {
      debugPrint('❌ Error joining meeting: $e');
      rethrow;
    }
  }

  // 📱 Setup Real-time Listeners
  void _setupRealtimeListeners() {
    // Listen to participants changes
    _participantsSubscription = _participantsCollection
        .snapshots()
        .listen(_onParticipantsChanged);

    // Listen to transcripts changes (ordered by time)
    _transcriptsSubscription = _transcriptsCollection
        .orderBy('startTime', descending: false)
        .limit(50) // Latest 50 transcripts
        .snapshots()
        .listen(_onTranscriptsChanged);

    // Listen to meeting events
    _eventsSubscription = _eventsCollection
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen(_onEventsChanged);
  }

  // 👥 Handle Participants Changes
  void _onParticipantsChanged(QuerySnapshot snapshot) {
    _participants.clear();

    for (final doc in snapshot.docs) {
      final participant = ParticipantStatus.fromFirestore(doc);
      _participants.add(participant);

      // Check for speaker changes
      if (participant.isCurrentlySpeaking && participant.id != _currentSpeakerId) {
        _currentSpeakerId = participant.id;
        _speakerChangeController.add(participant.id);
      }
    }

    // If no one is speaking, clear current speaker
    if (!_participants.any((p) => p.isCurrentlySpeaking)) {
      _currentSpeakerId = null;
    }

    notifyListeners();
  }

  // 📝 Handle Transcripts Changes
  void _onTranscriptsChanged(QuerySnapshot snapshot) {
    final previousTranscripts = Map.fromIterable(
      _liveTranscripts,
      key: (t) => t.id,
      value: (t) => t,
    );

    _liveTranscripts.clear();

    for (final doc in snapshot.docs) {
      final transcript = LiveTranscript.fromFirestore(doc);
      _liveTranscripts.add(transcript);

      // Check if this is new or updated
      if (!previousTranscripts.containsKey(transcript.id)) {
        // New transcript
        _newTranscriptController.add(transcript);
      } else if (previousTranscripts[transcript.id]!.lastUpdateTime != transcript.lastUpdateTime) {
        // Updated transcript
        _transcriptUpdateController.add(transcript);
      }
    }

    notifyListeners();
  }

  // 📅 Handle Events Changes
  void _onEventsChanged(QuerySnapshot snapshot) {
    _meetingEvents.clear();

    for (final doc in snapshot.docs) {
      final event = MeetingEvent.fromFirestore(doc);
      _meetingEvents.add(event);
    }

    notifyListeners();
  }

  // 🎤 Start Speaking (Push-to-Talk pressed)
  Future<void> startSpeaking() async {
    if (_currentSpeakerId != null && _currentSpeakerId != _currentUserId) {
      throw Exception('Someone else is currently speaking');
    }

    try {
      // Update participant status
      await _participantsCollection.doc(_currentUserId).update({
        'isCurrentlySpeaking': true,
        'lastSeen': Timestamp.now(),
      });

      // Create new active transcript
      _activeTranscriptId = _uuid.v4();
      await _transcriptsCollection.doc(_activeTranscriptId).set({
        'speakerId': _currentUserId,
        'speakerName': _currentUserName,
        'originalText': '',
        'originalLanguage': 'vi', // Will be detected
        'translations': <String, String>{},
        'startTime': Timestamp.now(),
        'lastUpdateTime': Timestamp.now(),
        'confidence': 0.0,
        'isComplete': false,
        'isActive': true,
        'estimatedDuration': 0,
      });

      // Send speech start event
      await _sendMeetingEvent('speech_start', {
        'transcriptId': _activeTranscriptId,
      });

      debugPrint('🎤 Started speaking: $_currentUserId');

    } catch (e) {
      debugPrint('❌ Error starting speech: $e');
      rethrow;
    }
  }

  // 📝 Update Speech (Real-time transcript updates)
  Future<void> updateSpeech({
    required String partialText,
    required double confidence,
    String? detectedLanguage,
    Map<String, String>? translations,
  }) async {
    if (_activeTranscriptId == null || _currentSpeakerId != _currentUserId) {
      return;
    }

    try {
      await _transcriptsCollection.doc(_activeTranscriptId).update({
        'originalText': partialText,
        'originalLanguage': detectedLanguage ?? 'vi',
        'translations': translations ?? {},
        'lastUpdateTime': Timestamp.now(),
        'confidence': confidence,
        'estimatedDuration': DateTime.now().difference(
            DateTime.now() // This would be stored start time
        ).inMilliseconds,
      });

      // Send update event for real-time sync
      await _sendMeetingEvent('speech_update', {
        'transcriptId': _activeTranscriptId,
        'partialText': partialText,
        'confidence': confidence,
      });

    } catch (e) {
      debugPrint('❌ Error updating speech: $e');
    }
  }

  // 🛑 Stop Speaking (Push-to-Talk released)
  Future<void> stopSpeaking({
    required String finalText,
    required Map<String, String> finalTranslations,
    required double finalConfidence,
  }) async {
    if (_activeTranscriptId == null || _currentSpeakerId != _currentUserId) {
      return;
    }

    try {
      final now = Timestamp.now();

      // Finalize transcript
      await _transcriptsCollection.doc(_activeTranscriptId).update({
        'originalText': finalText,
        'translations': finalTranslations,
        'lastUpdateTime': now,
        'confidence': finalConfidence,
        'isComplete': true,
        'isActive': false,
      });

      // Update participant status
      await _participantsCollection.doc(_currentUserId).update({
        'isCurrentlySpeaking': false,
        'lastSeen': now,
      });

      // Send speech end event
      await _sendMeetingEvent('speech_end', {
        'transcriptId': _activeTranscriptId,
        'finalText': finalText,
        'confidence': finalConfidence,
      });

      _activeTranscriptId = null;
      debugPrint('🛑 Stopped speaking: $_currentUserId');

    } catch (e) {
      debugPrint('❌ Error stopping speech: $e');
      rethrow;
    }
  }

  // 📨 Send Meeting Event
  Future<void> _sendMeetingEvent(String type, Map<String, dynamic> data) async {
    try {
      await _eventsCollection.add({
        'type': type,
        'meetingId': _meetingId,
        'participantId': _currentUserId,
        'participantName': _currentUserName,
        'timestamp': Timestamp.now(),
        'data': data,
      });
    } catch (e) {
      debugPrint('❌ Error sending event: $e');
    }
  }

  // ❤️ Start Heartbeat (Online Status)
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        await _participantsCollection.doc(_currentUserId).update({
          'lastSeen': Timestamp.now(),
          'isOnline': true,
        });
      } catch (e) {
        debugPrint('❌ Heartbeat error: $e');
      }
    });
  }

  // 📱 Get Device Info
  Future<String> _getDeviceInfo() async {
    // You can implement device info detection here
    return 'Flutter App';
  }

  // 🚪 Leave Meeting
  Future<void> leaveMeeting() async {
    try {
      // Stop speaking if currently speaking
      if (_currentSpeakerId == _currentUserId) {
        await stopSpeaking(
          finalText: '',
          finalTranslations: {},
          finalConfidence: 0.0,
        );
      }

      // Update status to offline
      await _participantsCollection.doc(_currentUserId).update({
        'isOnline': false,
        'isCurrentlySpeaking': false,
        'lastSeen': Timestamp.now(),
      });

      // Send leave event
      await _sendMeetingEvent('participant_leave', {
        'participantName': _currentUserName,
      });

      // Cancel subscriptions
      await _participantsSubscription?.cancel();
      await _transcriptsSubscription?.cancel();
      await _eventsSubscription?.cancel();

      // Cancel heartbeat
      _heartbeatTimer?.cancel();

      // Clear state
      _participants.clear();
      _liveTranscripts.clear();
      _meetingEvents.clear();
      _currentSpeakerId = null;
      _activeTranscriptId = null;

      debugPrint('🚪 Left meeting: $_meetingId');
      notifyListeners();

    } catch (e) {
      debugPrint('❌ Error leaving meeting: $e');
    }
  }

  // 🗑️ Dispose
  @override
  void dispose() {
    leaveMeeting();
    _newTranscriptController.close();
    _transcriptUpdateController.close();
    _participantUpdateController.close();
    _speakerChangeController.close();
    super.dispose();
  }

  // 🎯 Helper Methods
  LiveTranscript? getTranscriptById(String id) {
    return _liveTranscripts.where((t) => t.id == id).firstOrNull;
  }

  ParticipantStatus? getParticipantById(String id) {
    return _participants.where((p) => p.id == id).firstOrNull;
  }

  List<LiveTranscript> getTranscriptsForLanguage(String languageCode) {
    return _liveTranscripts.where((t) =>
    t.originalLanguage == languageCode ||
        t.translations.containsKey(languageCode)
    ).toList();
  }

  String getDisplayTextForUser(LiveTranscript transcript, String userLanguage) {
    return transcript.getTextForLanguage(userLanguage);
  }
}