// lib/services/meeting_transcription_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'multilingual_speech_service.dart';

// 🎯 REAL-TIME TRANSCRIPTION MODEL FOR ALL PARTICIPANTS
class MeetingTranscription {
  final String id;
  final String meetingId;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations;
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;
  final bool isActive; // Currently speaking

  MeetingTranscription({
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
    required this.isActive,
  });

  factory MeetingTranscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetingTranscription(
      id: doc.id,
      meetingId: data['meetingId'] ?? '',
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? '',
      originalText: data['originalText'] ?? '',
      detectedLanguage: data['detectedLanguage'] ?? 'en',
      translations: Map<String, String>.from(data['translations'] ?? {}),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isFinal: data['isFinal'] ?? false,
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'detectedLanguage': detectedLanguage,
      'translations': translations,
      'confidence': confidence,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFinal': isFinal,
      'isActive': isActive,
    };
  }

  String getTextForLanguage(String languageCode) {
    if (languageCode == detectedLanguage) {
      return originalText;
    }
    return translations[languageCode] ?? originalText;
  }

  @override
  String toString() {
    return 'MeetingTranscription(speaker: $speakerName, text: "$originalText", lang: $detectedLanguage, final: $isFinal)';
  }
}

class MeetingTranscriptionSyncService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎯 CURRENT STATE
  String _meetingId = '';
  String _currentUserId = '';
  String _currentUserName = '';
  String _targetLanguage = 'en';

  // 📝 TRANSCRIPTION DATA
  final List<MeetingTranscription> _allTranscriptions = [];
  String? _currentSpeakerId;
  String? _activeTranscriptionId;

  // 📡 REAL-TIME LISTENERS
  StreamSubscription<QuerySnapshot>? _transcriptionsSubscription;
  final StreamController<MeetingTranscription> _newTranscriptionController =
  StreamController<MeetingTranscription>.broadcast();
  final StreamController<MeetingTranscription> _transcriptionUpdateController =
  StreamController<MeetingTranscription>.broadcast();
  final StreamController<String> _speakerChangeController =
  StreamController<String>.broadcast();

  // 🔄 PROCESSING STATE
  Timer? _cleanupTimer;

  // Getters
  String get meetingId => _meetingId;
  String get currentUserId => _currentUserId;
  String get targetLanguage => _targetLanguage;
  List<MeetingTranscription> get allTranscriptions => List.unmodifiable(_allTranscriptions);
  String? get currentSpeakerId => _currentSpeakerId;
  bool get isCurrentUserSpeaking => _currentSpeakerId == _currentUserId;

  // Streams
  Stream<MeetingTranscription> get newTranscriptionStream => _newTranscriptionController.stream;
  Stream<MeetingTranscription> get transcriptionUpdateStream => _transcriptionUpdateController.stream;
  Stream<String> get speakerChangeStream => _speakerChangeController.stream;

  // 🚀 INITIALIZE FOR MEETING
  Future<void> initializeForMeeting({
    required String meetingId,
    required String userId,
    required String userName,
    required String targetLanguage,
  }) async {
    try {
      _meetingId = meetingId;
      _currentUserId = userId;
      _currentUserName = userName;
      _targetLanguage = targetLanguage;

      if (kDebugMode) {
        print('🚀 Initializing transcription sync for meeting: $meetingId');
        print('   User: $userName ($userId)');
        print('   Target Language: $targetLanguage');
      }

      // Setup real-time listener for transcriptions
      _setupTranscriptionListener();

      // Start cleanup timer
      _startCleanupTimer();

      if (kDebugMode) {
        print('✅ Transcription sync initialized');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing transcription sync: $e');
      }
      rethrow;
    }
  }

  // 👂 SETUP REAL-TIME TRANSCRIPTION LISTENER
  void _setupTranscriptionListener() {
    if (_meetingId.isEmpty) return;

    if (kDebugMode) {
      print('👂 Setting up real-time transcription listener...');
    }

    _transcriptionsSubscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('transcriptions')
        .orderBy('timestamp', descending: false)
        .limit(50) // Keep last 50 transcriptions
        .snapshots()
        .listen(
          (snapshot) => _handleTranscriptionChanges(snapshot),
      onError: (error) {
        if (kDebugMode) {
          print('❌ Error in transcription listener: $error');
        }
      },
    );
  }

  // 📝 HANDLE TRANSCRIPTION CHANGES
  void _handleTranscriptionChanges(QuerySnapshot snapshot) {
    final previousTranscriptions = Map.fromIterable(
      _allTranscriptions,
      key: (t) => t.id,
      value: (t) => t,
    );

    _allTranscriptions.clear();

    String? newCurrentSpeaker;

    for (final doc in snapshot.docs) {
      final transcription = MeetingTranscription.fromFirestore(doc);
      _allTranscriptions.add(transcription);

      // Track current speaker
      if (transcription.isActive) {
        newCurrentSpeaker = transcription.speakerId;
      }

      // Check if this is new or updated
      if (!previousTranscriptions.containsKey(transcription.id)) {
        // New transcription
        _newTranscriptionController.add(transcription);
        if (kDebugMode) {
          print('📝 New transcription from ${transcription.speakerName}: "${transcription.originalText}"');
        }
      } else if (previousTranscriptions[transcription.id]!.timestamp != transcription.timestamp) {
        // Updated transcription
        _transcriptionUpdateController.add(transcription);
        if (kDebugMode) {
          print('🔄 Updated transcription from ${transcription.speakerName}');
        }
      }
    }

    // Handle speaker changes
    if (newCurrentSpeaker != _currentSpeakerId) {
      final previousSpeaker = _currentSpeakerId;
      _currentSpeakerId = newCurrentSpeaker;

      if (_currentSpeakerId != null) {
        _speakerChangeController.add(_currentSpeakerId!);
        if (kDebugMode) {
          print('🗣️ Speaker changed: $previousSpeaker → $_currentSpeakerId');
        }
      }
    }

    notifyListeners();
  }

  // 🎤 START SPEAKING (called when user starts speaking)
  Future<String> startSpeaking() async {
    if (_currentSpeakerId != null && _currentSpeakerId != _currentUserId) {
      throw Exception('Someone else is currently speaking');
    }

    try {
      // Create new active transcription document
      final transcriptionRef = _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('transcriptions')
          .doc();

      _activeTranscriptionId = transcriptionRef.id;

      await transcriptionRef.set({
        'meetingId': _meetingId,
        'speakerId': _currentUserId,
        'speakerName': _currentUserName,
        'originalText': '',
        'detectedLanguage': 'auto',
        'translations': <String, String>{},
        'confidence': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
        'isFinal': false,
        'isActive': true,
      });

      if (kDebugMode) {
        print('🎤 Started speaking: $_activeTranscriptionId');
      }

      return _activeTranscriptionId!;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting speaking: $e');
      }
      rethrow;
    }
  }

  // 📝 UPDATE TRANSCRIPTION (called during speech recognition)
  Future<void> updateTranscription({
    required String transcriptionId,
    required String partialText,
    required String detectedLanguage,
    required Map<String, String> translations,
    required double confidence,
  }) async {
    if (transcriptionId != _activeTranscriptionId) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('transcriptions')
          .doc(transcriptionId)
          .update({
        'originalText': partialText,
        'detectedLanguage': detectedLanguage,
        'translations': translations,
        'confidence': confidence,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (kDebugMode && partialText.length > 10) {
        print('📝 Updated transcription: "${partialText.substring(0, 20)}..."');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating transcription: $e');
      }
    }
  }

  // 🛑 FINISH SPEAKING (called when user stops speaking)
  Future<void> finishSpeaking({
    required String transcriptionId,
    required String finalText,
    required String detectedLanguage,
    required Map<String, String> finalTranslations,
    required double finalConfidence,
  }) async {
    if (transcriptionId != _activeTranscriptionId) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('transcriptions')
          .doc(transcriptionId)
          .update({
        'originalText': finalText,
        'detectedLanguage': detectedLanguage,
        'translations': finalTranslations,
        'confidence': finalConfidence,
        'timestamp': FieldValue.serverTimestamp(),
        'isFinal': true,
        'isActive': false,
      });

      _activeTranscriptionId = null;

      if (kDebugMode) {
        print('🛑 Finished speaking: "$finalText"');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finishing speaking: $e');
      }
    }
  }

  // 🔄 CONNECT WITH SPEECH SERVICE
  void connectWithSpeechService(MultilingualSpeechService speechService) {
    // Listen to speech results and sync to Firestore
    speechService.speechResultStream.listen(
          (result) async {
        try {
          if (result.userId == _currentUserId) {
            // This is our own speech result, update the active transcription
            if (_activeTranscriptionId != null) {
              await updateTranscription(
                transcriptionId: _activeTranscriptionId!,
                partialText: result.originalText,
                detectedLanguage: result.detectedLanguage,
                translations: result.translations,
                confidence: result.confidence,
              );

              // If it's final, finish speaking
              if (result.isFinal) {
                await finishSpeaking(
                  transcriptionId: _activeTranscriptionId!,
                  finalText: result.originalText,
                  detectedLanguage: result.detectedLanguage,
                  finalTranslations: result.translations,
                  finalConfidence: result.confidence,
                );
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error syncing speech result: $e');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Speech service stream error: $error');
        }
      },
    );

    if (kDebugMode) {
      print('🔗 Connected with speech service');
    }
  }

  // 🎯 GET TRANSCRIPTIONS FOR USER'S TARGET LANGUAGE
  List<MeetingTranscription> getTranscriptionsForLanguage(String languageCode) {
    return _allTranscriptions.where((t) =>
    t.detectedLanguage == languageCode ||
        t.translations.containsKey(languageCode)
    ).toList();
  }

  // 🎯 GET DISPLAY TEXT FOR USER
  String getDisplayText(MeetingTranscription transcription) {
    return transcription.getTextForLanguage(_targetLanguage);
  }

  // 📊 GET RECENT TRANSCRIPTIONS (last 10)
  List<MeetingTranscription> getRecentTranscriptions() {
    final sorted = List<MeetingTranscription>.from(_allTranscriptions);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(10).toList();
  }

  // 🔍 GET TRANSCRIPTIONS BY SPEAKER
  List<MeetingTranscription> getTranscriptionsBySpeaker(String speakerId) {
    return _allTranscriptions.where((t) => t.speakerId == speakerId).toList();
  }

  // ⏰ START CLEANUP TIMER
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _cleanupOldTranscriptions();
    });
  }

  // 🧹 CLEANUP OLD TRANSCRIPTIONS
  Future<void> _cleanupOldTranscriptions() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));

      final oldDocs = await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('transcriptions')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffTime))
          .limit(10)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldDocs.docs) {
        batch.delete(doc.reference);
      }

      if (oldDocs.docs.isNotEmpty) {
        await batch.commit();
        if (kDebugMode) {
          print('🧹 Cleaned up ${oldDocs.docs.length} old transcriptions');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cleaning up transcriptions: $e');
      }
    }
  }

  // 🚪 LEAVE MEETING
  Future<void> leaveMeeting() async {
    try {
      // Mark any active transcription as finished
      if (_activeTranscriptionId != null) {
        await _firestore
            .collection('meetings')
            .doc(_meetingId)
            .collection('transcriptions')
            .doc(_activeTranscriptionId)
            .update({
          'isActive': false,
          'isFinal': true,
        });
      }

      // Cancel subscriptions
      await _transcriptionsSubscription?.cancel();
      _transcriptionsSubscription = null;

      // Cancel cleanup timer
      _cleanupTimer?.cancel();
      _cleanupTimer = null;

      // Clear state
      _allTranscriptions.clear();
      _currentSpeakerId = null;
      _activeTranscriptionId = null;

      if (kDebugMode) {
        print('🚪 Left meeting transcription sync');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error leaving transcription sync: $e');
      }
    }
  }

  // 🗑️ DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing transcription sync service');
    }

    leaveMeeting();
    _newTranscriptionController.close();
    _transcriptionUpdateController.close();
    _speakerChangeController.close();
    super.dispose();
  }
}