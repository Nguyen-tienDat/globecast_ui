// lib/services/firebase_transcription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:globecast_ui/services/whisper_service.dart';

/// Firebase service for storing and retrieving transcription history
class FirebaseTranscriptionService {
  static const String _collection = 'meeting_transcriptions';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Store a transcription result in Firebase
  Future<void> storeTranscription({
    required String meetingId,
    required TranscriptionResult result,
  }) async {
    try {
      final docData = {
        'meetingId': meetingId,
        'speakerId': result.speakerId,
        'speakerName': result.speakerName,
        'originalText': result.originalText,
        'originalLanguage': result.originalLanguage,
        'originalLanguageConfidence': result.originalLanguageConfidence,
        'translatedText': result.translatedText,
        'targetLanguage': result.targetLanguage,
        'transcriptionConfidence': result.transcriptionConfidence,
        'translationConfidence': result.translationConfidence,
        'isFinal': result.isFinal,
        'timestamp': result.timestamp,
        'audioDuration': result.audioDuration,
        'processingTime': result.processingTime,
        'isVoice': result.isVoice,
        'audioQuality': result.audioQuality,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_collection).add(docData);

      print('📦 [FIREBASE] Transcription stored: ${result.speakerName}: "${result.translatedText}"');

    } catch (e) {
      print('❌ [FIREBASE] Failed to store transcription: $e');
      // Don't throw - we don't want storage issues to break the meeting
    }
  }

  /// Get transcription history for a meeting
  Stream<List<TranscriptionResult>> getTranscriptionHistory(String meetingId) {
    return _firestore
        .collection(_collection)
        .where('meetingId', isEqualTo: meetingId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TranscriptionResult(
          speakerId: data['speakerId'] ?? '',
          speakerName: data['speakerName'] ?? '',
          originalText: data['originalText'] ?? '',
          originalLanguage: data['originalLanguage'] ?? 'en',
          originalLanguageConfidence: (data['originalLanguageConfidence'] ?? 0.0).toDouble(),
          translatedText: data['translatedText'] ?? '',
          targetLanguage: data['targetLanguage'] ?? 'en',
          transcriptionConfidence: (data['transcriptionConfidence'] ?? 0.0).toDouble(),
          translationConfidence: (data['translationConfidence'] ?? 0.0).toDouble(),
          isFinal: data['isFinal'] ?? true,
          timestamp: data['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
            ((data['timestamp'] as num) * 1000).round(),
          )
              : DateTime.now(),
          audioDuration: (data['audioDuration'] ?? 0.0).toDouble(),
          processingTime: (data['processingTime'] ?? 0.0).toDouble(),
          isVoice: data['isVoice'] ?? true,
          audioQuality: (data['audioQuality'] ?? 0.0).toDouble(),
        );
      }).toList();
    });
  }

  /// Get recent transcriptions across all meetings for a user
  Stream<List<TranscriptionResult>> getRecentTranscriptions({
    String? userId,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (userId != null) {
      query = query.where('speakerId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return TranscriptionResult(
          speakerId: data['speakerId'] ?? '',
          speakerName: data['speakerName'] ?? '',
          originalText: data['originalText'] ?? '',
          originalLanguage: data['originalLanguage'] ?? 'en',
          originalLanguageConfidence: (data['originalLanguageConfidence'] ?? 0.0).toDouble(),
          translatedText: data['translatedText'] ?? '',
          targetLanguage: data['targetLanguage'] ?? 'en',
          transcriptionConfidence: (data['transcriptionConfidence'] ?? 0.0).toDouble(),
          translationConfidence: (data['translationConfidence'] ?? 0.0).toDouble(),
          isFinal: data['isFinal'] ?? true,
          timestamp: data['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
            ((data['timestamp'] as num) * 1000).round(),
          )
              : DateTime.now(),
          audioDuration: (data['audioDuration'] ?? 0.0).toDouble(),
          processingTime: (data['processingTime'] ?? 0.0).toDouble(),
          isVoice: data['isVoice'] ?? true,
          audioQuality: (data['audioQuality'] ?? 0.0).toDouble(),
        );
      }).toList();
    });
  }

  /// Delete transcriptions for a meeting (cleanup)
  Future<void> deleteTranscriptionsForMeeting(String meetingId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('🗑️ [FIREBASE] Deleted transcriptions for meeting: $meetingId');

    } catch (e) {
      print('❌ [FIREBASE] Failed to delete transcriptions: $e');
    }
  }

  /// Get transcription statistics for a meeting
  Future<Map<String, dynamic>> getMeetingStats(String meetingId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      final transcriptions = snapshot.docs.map((doc) => doc.data()).toList();

      if (transcriptions.isEmpty) {
        return {
          'totalTranscriptions': 0,
          'totalSpeakers': 0,
          'averageConfidence': 0.0,
          'totalDuration': 0.0,
          'languagesDetected': <String>[],
        };
      }

      final speakers = <String>{};
      final languages = <String>{};
      double totalConfidence = 0;
      double totalDuration = 0;

      for (final trans in transcriptions) {
        speakers.add(trans['speakerName'] ?? '');
        languages.add(trans['originalLanguage'] ?? '');
        totalConfidence += (trans['transcriptionConfidence'] ?? 0.0);
        totalDuration += (trans['audioDuration'] ?? 0.0);
      }

      return {
        'totalTranscriptions': transcriptions.length,
        'totalSpeakers': speakers.length,
        'averageConfidence': totalConfidence / transcriptions.length,
        'totalDuration': totalDuration,
        'languagesDetected': languages.toList(),
        'speakers': speakers.toList(),
      };

    } catch (e) {
      print('❌ [FIREBASE] Failed to get meeting stats: $e');
      return {};
    }
  }
}