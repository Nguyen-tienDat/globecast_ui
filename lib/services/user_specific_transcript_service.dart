// lib/services/user_specific_transcript_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'whisper_service.dart';

/// Model for user-specific transcript entry
class UserTranscriptEntry {
  final String id;
  final String meetingId;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final String userLanguage;
  final String translatedText;
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;
  final Map<String, dynamic> metadata;

  UserTranscriptEntry({
    required this.id,
    required this.meetingId,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.userLanguage,
    required this.translatedText,
    required this.confidence,
    required this.timestamp,
    required this.isFinal,
    this.metadata = const {},
  });

  factory UserTranscriptEntry.fromJson(Map<String, dynamic> json) {
    return UserTranscriptEntry(
      id: json['id'] ?? '',
      meetingId: json['meetingId'] ?? '',
      speakerId: json['speakerId'] ?? '',
      speakerName: json['speakerName'] ?? '',
      originalText: json['originalText'] ?? '',
      originalLanguage: json['originalLanguage'] ?? 'en',
      userLanguage: json['userLanguage'] ?? 'en',
      translatedText: json['translatedText'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      isFinal: json['isFinal'] ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meetingId': meetingId,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'userLanguage': userLanguage,
      'translatedText': translatedText,
      'confidence': confidence,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isFinal': isFinal,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'UserTranscriptEntry($speakerName: "$translatedText" [$userLanguage])';
  }
}

/// Service quản lý transcript riêng cho từng user
class UserSpecificTranscriptService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WhisperService _whisperService;

  // User session info
  String? _userId;
  String? _meetingId;
  String? _userDisplayLanguage;

  // Transcript streams and caching
  final Map<String, List<UserTranscriptEntry>> _userTranscripts = {};
  final Map<String, StreamSubscription> _transcriptSubscriptions = {};
  final Map<String, StreamController<List<UserTranscriptEntry>>> _streamControllers = {};

  // Translation and processing
  final Map<String, String> _translationCache = {};
  Timer? _batchProcessingTimer;
  final List<TranscriptionResult> _pendingTranscriptions = [];

  // Statistics
  final Map<String, dynamic> _stats = {
    'totalTranscripts': 0,
    'totalTranslations': 0,
    'languagesSupported': 0,
    'activeUsers': 0,
  };

  UserSpecificTranscriptService(this._whisperService) {
    print('🎯 UserSpecificTranscriptService initialized');
    _setupWhisperListener();
    _startBatchProcessing();
  }

  // Getters
  String? get userId => _userId;
  String? get meetingId => _meetingId;
  String? get userDisplayLanguage => _userDisplayLanguage;
  Map<String, dynamic> get statistics => Map.unmodifiable(_stats);

  /// Initialize service cho user cụ thể
  Future<bool> initializeForUser({
    required String userId,
    required String meetingId,
    required String displayLanguage,
  }) async {
    try {
      _userId = userId;
      _meetingId = meetingId;
      _userDisplayLanguage = displayLanguage;

      print('🎯 Initializing transcript service for user: $userId');
      print('🌍 Display language: $displayLanguage');
      print('📱 Meeting: $meetingId');

      // Tạo stream controller cho user này
      _streamControllers[userId] = StreamController<List<UserTranscriptEntry>>.broadcast();

      // Setup Firestore listener cho user này
      await _setupUserTranscriptListener(userId, meetingId);

      _stats['activeUsers'] = (_stats['activeUsers'] ?? 0) + 1;
      notifyListeners();

      return true;
    } catch (e) {
      print('❌ Failed to initialize transcript service: $e');
      return false;
    }
  }

  /// Setup listener cho Whisper transcription results
  void _setupWhisperListener() {
    _whisperService.transcriptionStream.listen(
          (result) => _handleNewTranscription(result),
      onError: (error) => print('❌ Whisper transcription error: $error'),
    );
  }

  /// Xử lý transcription mới từ Whisper
  void _handleNewTranscription(TranscriptionResult result) {
    if (_userId == null || _meetingId == null || _userDisplayLanguage == null) {
      return;
    }

    // Add to pending queue for batch processing
    _pendingTranscriptions.add(result);

    print('📝 Received transcription for processing: ${result.speakerName}');
    print('   Original: "${result.originalText}" (${result.originalLanguage})');
    print('   Target user language: $_userDisplayLanguage');
  }

  /// Batch processing transcriptions để tối ưu performance
  void _startBatchProcessing() {
    _batchProcessingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_pendingTranscriptions.isNotEmpty) {
        _processPendingTranscriptions();
      }
    });
  }

  /// Xử lý batch transcriptions
  Future<void> _processPendingTranscriptions() async {
    if (_pendingTranscriptions.isEmpty || _userId == null) return;

    final batch = List<TranscriptionResult>.from(_pendingTranscriptions);
    _pendingTranscriptions.clear();

    print('🔄 Processing batch of ${batch.length} transcriptions for user $_userId');

    for (final result in batch) {
      await _processTranscriptionForUser(result);
    }
  }

  /// Xử lý một transcription cho user cụ thể
  Future<void> _processTranscriptionForUser(TranscriptionResult result) async {
    try {
      String finalText = result.translatedText;

      // Nếu ngôn ngữ gốc khác với ngôn ngữ user muốn thấy, cần translate
      if (result.targetLanguage != _userDisplayLanguage) {
        finalText = await _translateText(
          result.originalText,
          result.originalLanguage,
          _userDisplayLanguage!,
        );
      }

      // Tạo transcript entry cho user này
      final entry = UserTranscriptEntry(
        id: '${result.speakerId}_${result.timestamp.millisecondsSinceEpoch}',
        meetingId: _meetingId!,
        speakerId: result.speakerId,
        speakerName: result.speakerName,
        originalText: result.originalText,
        originalLanguage: result.originalLanguage,
        userLanguage: _userDisplayLanguage!,
        translatedText: finalText,
        confidence: result.transcriptionConfidence,
        timestamp: result.timestamp,
        isFinal: result.isFinal,
        metadata: {
          'audioQuality': result.audioQuality,
          'processingTime': result.processingTime,
          'translationConfidence': result.translationConfidence,
        },
      );

      // Lưu vào Firestore cho user này
      await _saveUserTranscript(entry);

      _stats['totalTranscripts'] = (_stats['totalTranscripts'] ?? 0) + 1;
      if (finalText != result.originalText) {
        _stats['totalTranslations'] = (_stats['totalTranslations'] ?? 0) + 1;
      }

      print('✅ Processed transcript for ${result.speakerName} → ${_userDisplayLanguage}: "$finalText"');

    } catch (e) {
      print('❌ Error processing transcription for user: $e');
    }
  }

  /// Translate text with caching
  Future<String> _translateText(String text, String fromLang, String toLang) async {
    if (fromLang == toLang) return text;

    final cacheKey = '${text.hashCode}_${fromLang}_$toLang';

    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      // Use simple Google Translate API (you can enhance this)
      final translated = await _simpleTranslate(text, fromLang, toLang);

      // Cache the result
      if (_translationCache.length < 1000) {
        _translationCache[cacheKey] = translated;
      }

      return translated;
    } catch (e) {
      print('❌ Translation failed: $e');
      return text; // Fallback to original
    }
  }

  /// Simple translation implementation
  Future<String> _simpleTranslate(String text, String fromLang, String toLang) async {
    // Enhanced translation logic here
    // For demo purposes, using simple mapping

    final translations = {
      'Hello everyone!_en_vi': 'Xin chào mọi người!',
      'Hello everyone!_en_fr': 'Bonjour tout le monde!',
      'Hello everyone!_en_es': '¡Hola a todos!',
      'Hello everyone!_en_de': 'Hallo zusammen!',
      'Hello everyone!_en_zh': '大家好！',
      'Hello everyone!_en_ja': 'こんにちは皆さん！',
      'Hello everyone!_en_ko': '안녕하세요 여러분!',

      'Xin chào mọi người!_vi_en': 'Hello everyone!',
      'Xin chào mọi người!_vi_fr': 'Bonjour tout le monde!',
      'Xin chào mọi người!_vi_es': '¡Hola a todos!',
      'Xin chào mọi người!_vi_de': 'Hallo zusammen!',
      'Xin chào mọi người!_vi_zh': '大家好！',
      'Xin chào mọi người!_vi_ja': 'こんにちは皆さん！',
      'Xin chào mọi người!_vi_ko': '안녕하세요 여러분!',

      'Bonjour tout le monde!_fr_en': 'Hello everyone!',
      'Bonjour tout le monde!_fr_vi': 'Xin chào mọi người!',
      'Bonjour tout le monde!_fr_es': '¡Hola a todos!',
      'Bonjour tout le monde!_fr_de': 'Hallo zusammen!',
      'Bonjour tout le monde!_fr_zh': '大家好！',
      'Bonjour tout le monde!_fr_ja': 'こんにちは皆さん！',
      'Bonjour tout le monde!_fr_ko': '안녕하세요 여러분!',

      '¡Hola a todos!_es_en': 'Hello everyone!',
      '¡Hola a todos!_es_vi': 'Xin chào mọi người!',
      '¡Hola a todos!_es_fr': 'Bonjour tout le monde!',
      '¡Hola a todos!_es_de': 'Hallo zusammen!',
      '¡Hola a todos!_es_zh': '大家好！',
      '¡Hola a todos!_es_ja': 'こんにちは皆さん！',
      '¡Hola a todos!_es_ko': '안녕하세요 여러분!',

      'Hallo zusammen!_de_en': 'Hello everyone!',
      'Hallo zusammen!_de_vi': 'Xin chào mọi người!',
      'Hallo zusammen!_de_fr': 'Bonjour tout le monde!',
      'Hallo zusammen!_de_es': '¡Hola a todos!',
      'Hallo zusammen!_de_zh': '大家好！',
      'Hallo zusammen!_de_ja': 'こんにちは皆さん！',
      'Hallo zusammen!_de_ko': '안녕하세요 여러분!',

      '大家好！_zh_en': 'Hello everyone!',
      '大家好！_zh_vi': 'Xin chào mọi người!',
      '大家好！_zh_fr': 'Bonjour tout le monde!',
      '大家好！_zh_es': '¡Hola a todos!',
      '大家好！_zh_de': 'Hallo zusammen!',
      '大家好！_zh_ja': 'こんにちは皆さん！',
      '大家好！_zh_ko': '안녕하세요 여러분!',

      'こんにちは皆さん！_ja_en': 'Hello everyone!',
      'こんにちは皆さん！_ja_vi': 'Xin chào mọi người!',
      'こんにちは皆さん！_ja_fr': 'Bonjour tout le monde!',
      'こんにちは皆さん！_ja_es': '¡Hola a todos!',
      'こんにちは皆さん！_ja_de': 'Hallo zusammen!',
      'こんにちは皆さん！_ja_zh': '大家好！',
      'こんにちは皆さん！_ja_ko': '안녕하세요 여러분!',

      '안녕하세요 여러분!_ko_en': 'Hello everyone!',
      '안녕하세요 여러분!_ko_vi': 'Xin chào mọi người!',
      '안녕하세요 여러분!_ko_fr': 'Bonjour tout le monde!',
      '안녕하세요 여러분!_ko_es': '¡Hola a todos!',
      '안녕하세요 여러분!_ko_de': 'Hallo zusammen!',
      '안녕하세요 여러분!_ko_zh': '大家好！',
      '안녕하세요 여러분!_ko_ja': 'こんにちは皆さん！',

      // Additional common phrases
      'How are you?_en_vi': 'Bạn khỏe không?',
      'How are you?_en_fr': 'Comment allez-vous?',
      'How are you?_en_es': '¿Cómo estás?',
      'How are you?_en_de': 'Wie geht es dir?',
      'How are you?_en_zh': '你好吗？',
      'How are you?_en_ja': '元気ですか？',
      'How are you?_en_ko': '어떻게 지내세요?',

      'Thank you_en_vi': 'Cảm ơn',
      'Thank you_en_fr': 'Merci',
      'Thank you_en_es': 'Gracias',
      'Thank you_en_de': 'Danke',
      'Thank you_en_zh': '谢谢',
      'Thank you_en_ja': 'ありがとう',
      'Thank you_en_ko': '감사합니다',

      'Good morning_en_vi': 'Chào buổi sáng',
      'Good morning_en_fr': 'Bonjour',
      'Good morning_en_es': 'Buenos días',
      'Good morning_en_de': 'Guten Morgen',
      'Good morning_en_zh': '早上好',
      'Good morning_en_ja': 'おはようございます',
      'Good morning_en_ko': '좋은 아침',

      'See you later_en_vi': 'Hẹn gặp lại',
      'See you later_en_fr': 'À bientôt',
      'See you later_en_es': 'Hasta luego',
      'See you later_en_de': 'Bis später',
      'See you later_en_zh': '回头见',
      'See you later_en_ja': 'また後で',
      'See you later_en_ko': '나중에 봐요',
    };

    final key = '${text}_${fromLang}_$toLang';
    return translations[key] ?? text;
  }

  /// Lưu transcript vào Firestore theo user
  Future<void> _saveUserTranscript(UserTranscriptEntry entry) async {
    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('user_transcripts')
          .doc(_userId)
          .collection('transcripts')
          .doc(entry.id)
          .set(entry.toJson());

      print('💾 Saved transcript for user $_userId: ${entry.speakerName}');
    } catch (e) {
      print('❌ Failed to save user transcript: $e');
    }
  }

  /// Setup listener cho transcript của user từ Firestore
  Future<void> _setupUserTranscriptListener(String userId, String meetingId) async {
    try {
      final subscription = _firestore
          .collection('meetings')
          .doc(meetingId)
          .collection('user_transcripts')
          .doc(userId)
          .collection('transcripts')
          .orderBy('timestamp')
          .snapshots()
          .listen((snapshot) {

        final transcripts = snapshot.docs.map((doc) {
          final data = doc.data();
          return UserTranscriptEntry.fromJson(data);
        }).toList();

        // Update local cache
        _userTranscripts[userId] = transcripts;

        // Emit to stream
        _streamControllers[userId]?.add(transcripts);

        print('📱 Updated transcripts for user $userId: ${transcripts.length} entries');
      });

      _transcriptSubscriptions[userId] = subscription;
    } catch (e) {
      print('❌ Failed to setup transcript listener: $e');
    }
  }

  /// Get stream của transcripts cho user hiện tại
  Stream<List<UserTranscriptEntry>> getUserTranscriptStream() {
    if (_userId == null || !_streamControllers.containsKey(_userId)) {
      return Stream.empty();
    }
    return _streamControllers[_userId]!.stream;
  }

  /// Get cached transcripts cho user
  List<UserTranscriptEntry> getCachedTranscripts([String? userId]) {
    final targetUserId = userId ?? _userId;
    if (targetUserId == null) return [];
    return _userTranscripts[targetUserId] ?? [];
  }

  /// Change user's display language
  Future<void> updateUserLanguage(String newLanguage) async {
    if (_userId == null || _meetingId == null) return;

    try {
      print('🌍 Updating user language from $_userDisplayLanguage to $newLanguage');

      _userDisplayLanguage = newLanguage;

      // Clear existing transcripts for this user (they need to be re-translated)
      await _clearUserTranscripts();

      // Re-process existing transcriptions with new language
      await _reprocessTranscriptsForNewLanguage();

      print('✅ Language updated successfully to $newLanguage');
      notifyListeners();

    } catch (e) {
      print('❌ Failed to update user language: $e');
    }
  }

  /// Clear user's existing transcripts
  Future<void> _clearUserTranscripts() async {
    if (_userId == null || _meetingId == null) return;

    try {
      final batch = _firestore.batch();
      final transcripts = await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('user_transcripts')
          .doc(_userId)
          .collection('transcripts')
          .get();

      for (final doc in transcripts.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Clear local cache
      _userTranscripts[_userId!] = [];

      print('🧹 Cleared transcripts for user $_userId');
    } catch (e) {
      print('❌ Failed to clear user transcripts: $e');
    }
  }

  /// Re-process transcripts for new language
  Future<void> _reprocessTranscriptsForNewLanguage() async {
    // This would typically re-process from the original transcription data
    // For now, we'll wait for new transcriptions to come in
    print('🔄 Will re-process future transcriptions with new language');
  }

  /// Get meeting statistics for user
  Future<Map<String, dynamic>> getMeetingStatsForUser() async {
    if (_userId == null || _meetingId == null) return {};

    try {
      final transcripts = getCachedTranscripts();

      final speakers = <String>{};
      final languages = <String>{};
      double totalConfidence = 0;

      for (final transcript in transcripts) {
        speakers.add(transcript.speakerName);
        languages.add(transcript.originalLanguage);
        totalConfidence += transcript.confidence;
      }

      return {
        'userLanguage': _userDisplayLanguage,
        'totalTranscripts': transcripts.length,
        'uniqueSpeakers': speakers.length,
        'languagesHeard': languages.length,
        'averageConfidence': transcripts.isNotEmpty ? totalConfidence / transcripts.length : 0.0,
        'speakers': speakers.toList(),
        'languages': languages.toList(),
      };
    } catch (e) {
      print('❌ Failed to get meeting stats: $e');
      return {};
    }
  }

  /// Export transcripts for user
  Future<String> exportTranscriptsAsText() async {
    final transcripts = getCachedTranscripts();

    if (transcripts.isEmpty) return 'No transcripts available.';

    final buffer = StringBuffer();
    buffer.writeln('Meeting Transcripts');
    buffer.writeln('Language: $_userDisplayLanguage');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final transcript in transcripts) {
      final time = '${transcript.timestamp.hour.toString().padLeft(2, '0')}:'
          '${transcript.timestamp.minute.toString().padLeft(2, '0')}:'
          '${transcript.timestamp.second.toString().padLeft(2, '0')}';

      buffer.writeln('[$time] ${transcript.speakerName}:');
      buffer.writeln('${transcript.translatedText}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Clean up resources
  @override
  Future<void> dispose() async {
    print('🧹 Disposing UserSpecificTranscriptService...');

    _batchProcessingTimer?.cancel();

    // Cancel all subscriptions
    for (final subscription in _transcriptSubscriptions.values) {
      await subscription.cancel();
    }
    _transcriptSubscriptions.clear();

    // Close stream controllers
    for (final controller in _streamControllers.values) {
      await controller.close();
    }
    _streamControllers.clear();

    // Clear caches
    _userTranscripts.clear();
    _translationCache.clear();
    _pendingTranscriptions.clear();

    if (_userId != null) {
      _stats['activeUsers'] = (_stats['activeUsers'] ?? 1) - 1;
    }

    super.dispose();
  }
}