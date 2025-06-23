// lib/services/translation_service.dart - SYNTAX FIXED
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import '../models/translation_models.dart';

class TranslationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleTranslator _translator = GoogleTranslator();

  // Cache for translations
  final Map<String, String> _translationCache = {};
  final List<SpeechTranscription> _transcriptions = [];
  UserLanguagePreference? _userPreference;
  final List<StreamSubscription> _subscriptions = [];

  String? _currentMeetingId;
  String? _currentUserId;
  bool _isTranslating = false;

  // Translation queue
  final List<_TranslationTask> _pendingTranslations = [];
  Timer? _translationProcessor;

  // Multi-user participants data
  final Map<String, ParticipantLanguageInfo> _participantsLanguages = {};

  // Error handling
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;
  bool _isServiceHealthy = true;

  // Getters
  List<SpeechTranscription> get transcriptions => List.unmodifiable(_transcriptions);
  UserLanguagePreference? get userPreference => _userPreference;
  String? get currentMeetingId => _currentMeetingId;
  String? get currentUserId => _currentUserId;
  bool get isTranslating => _isTranslating;
  Map<String, ParticipantLanguageInfo> get allParticipants => Map.unmodifiable(_participantsLanguages);
  bool get isServiceHealthy => _isServiceHealthy;

  // Initialize service for meeting
  Future<void> initializeForMeeting(String meetingId, String userId) async {
    try {
      _currentMeetingId = meetingId;
      _currentUserId = userId;

      print('🌐 === TRANSLATION SERVICE INITIALIZATION ===');
      print('   Meeting: $meetingId');
      print('   User: $userId');

      // Reset error state
      _consecutiveErrors = 0;
      _isServiceHealthy = true;

      // Load user preference
      await _loadUserPreference(userId);

      // Listen for all participants' language preferences
      _listenForParticipantsLanguages();

      // Listen for transcriptions
      _listenForTranscriptions();

      // Start translation processor
      _startTranslationProcessor();

      print('✅ Translation Service initialized successfully');
    } catch (e) {
      print('❌ Error initializing Translation Service: $e');
      throw Exception('Failed to initialize translation service: $e');
    }
  }

  // Listen for all participants' language preferences
  void _listenForParticipantsLanguages() {
    if (_currentMeetingId == null) return;

    print('👂 === LISTENING FOR PARTICIPANTS LANGUAGES ===');

    final subscription = _firestore
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {

      print('📡 Participants update: ${snapshot.docs.length} active participants');

      // Clear old data
      _participantsLanguages.clear();

      // Process each participant
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participantId = doc.id;

        final participantInfo = ParticipantLanguageInfo(
          userId: participantId,
          displayName: data['displayName'] ?? 'Unknown',
          targetLanguage: data['targetLanguage'] ?? 'en',
          speakingLanguage: data['speakingLanguage'] ?? 'vi',
          isActive: data['isActive'] ?? true,
        );

        _participantsLanguages[participantId] = participantInfo;

        print('👤 ${participantInfo.displayName}: ${participantInfo.speakingLanguage} → ${participantInfo.targetLanguage}');
      }

      // Log all target languages
      final allTargetLanguages = getAllTargetLanguages();
      print('🌐 All target languages needed: $allTargetLanguages');

      // Retranslate for new participants
      if (_transcriptions.isNotEmpty) {
        _retranslateForNewParticipants();
      }

      notifyListeners();
    }, onError: (error) {
      print('❌ Error listening for participants: $error');
      _handleServiceError('Participants listening error');
    });

    _subscriptions.add(subscription);
  }

  // Get all unique target languages from participants
  List<String> getAllTargetLanguages() {
    final languages = <String>{};
    for (var participant in _participantsLanguages.values) {
      if (participant.isActive && participant.targetLanguage.isNotEmpty) {
        languages.add(participant.targetLanguage);
      }
    }
    return languages.toList();
  }

  // Get participant info by ID
  ParticipantLanguageInfo? getParticipantById(String participantId) {
    return _participantsLanguages[participantId];
  }

  // Load user preference from Firestore
  Future<void> _loadUserPreference(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_preferences')
          .doc(userId)
          .get();

      if (doc.exists) {
        _userPreference = UserLanguagePreference.fromFirestore(doc);
        print('📖 User preference loaded from Firestore');
      } else {
        // Create default preference
        _userPreference = UserLanguagePreference(
          userId: userId,
          displayLanguage: 'en',
          speakingLanguage: 'vi',
          autoDetectSpeaking: false,
          enableLiveTranslation: true,
          updatedAt: DateTime.now(),
        );
        await _saveUserPreference();
        print('🆕 Created default user preference');
      }

      print('👤 User Preference: ${_userPreference!.speakingLanguage} → ${_userPreference!.displayLanguage}');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading user preference: $e');
      // Fallback to default
      _userPreference = UserLanguagePreference(
        userId: userId,
        displayLanguage: 'en',
        speakingLanguage: 'vi',
        autoDetectSpeaking: false,
        enableLiveTranslation: true,
        updatedAt: DateTime.now(),
      );
    }
  }

  // Save user preference to Firestore
  Future<void> _saveUserPreference() async {
    if (_userPreference == null || _currentUserId == null) return;

    try {
      await _firestore
          .collection('user_preferences')
          .doc(_currentUserId)
          .set(_userPreference!.toFirestore());
      print('💾 User preference saved to Firestore');
    } catch (e) {
      print('❌ Error saving user preference: $e');
      _handleServiceError('Save preference error');
    }
  }

  // Update display language with auto-retranslation
  Future<void> updateDisplayLanguage(String languageCode) async {
    if (_userPreference == null) return;

    final oldLanguage = _userPreference!.displayLanguage;

    _userPreference = _userPreference!.copyWith(
      displayLanguage: languageCode,
      updatedAt: DateTime.now(),
    );

    await _saveUserPreference();

    print('🔄 Display language updated: $oldLanguage → $languageCode');

    // Auto-retranslate existing transcriptions
    if (oldLanguage != languageCode) {
      await _retranslateForNewLanguage(languageCode);
    }

    notifyListeners();
  }

  // Update speaking language
  Future<void> updateSpeakingLanguage(String languageCode) async {
    if (_userPreference == null) return;

    _userPreference = _userPreference!.copyWith(
      speakingLanguage: languageCode,
      updatedAt: DateTime.now(),
    );

    await _saveUserPreference();
    notifyListeners();

    print('🗣️ Speaking language updated: $languageCode');
  }

  // Retranslate for new language
  Future<void> _retranslateForNewLanguage(String newDisplayLanguage) async {
    print('🔄 === RETRANSLATING FOR NEW LANGUAGE: $newDisplayLanguage ===');

    int queuedCount = 0;
    for (final transcription in _transcriptions) {
      if (_shouldTranslateTranscription(transcription, newDisplayLanguage)) {
        _queueTranslation(transcription, newDisplayLanguage, highPriority: true);
        queuedCount++;
      }
    }

    print('📋 Total queued for retranslation: $queuedCount');
  }

  // Retranslate for new participants
  Future<void> _retranslateForNewParticipants() async {
    print('🔄 === RETRANSLATING FOR NEW PARTICIPANTS ===');

    final allTargetLanguages = getAllTargetLanguages();
    int queuedCount = 0;

    for (final transcription in _transcriptions) {
      for (final targetLanguage in allTargetLanguages) {
        if (_shouldTranslateTranscription(transcription, targetLanguage)) {
          _queueTranslation(transcription, targetLanguage, highPriority: false);
          queuedCount++;
        }
      }
    }

    print('📋 Total queued for new participants: $queuedCount');
  }

  // Check if transcription should be translated
  bool _shouldTranslateTranscription(SpeechTranscription transcription, String targetLanguage) {
    // Don't translate if same language as original
    if (transcription.originalLanguage == targetLanguage) {
      return false;
    }

    // Don't translate if translation already exists
    if (transcription.hasTranslation(targetLanguage)) {
      return false;
    }

    // Only translate if there's a participant who needs this language
    final hasParticipantNeedingLanguage = _participantsLanguages.values
        .any((p) => p.isActive && p.targetLanguage == targetLanguage);

    if (!hasParticipantNeedingLanguage) {
      return false;
    }

    return true;
  }

  // Listen for transcriptions
  void _listenForTranscriptions() {
    if (_currentMeetingId == null) return;

    print('👂 === LISTENING FOR TRANSCRIPTIONS ===');
    print('   Meeting: $_currentMeetingId');

    final subscription = _firestore
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('transcriptions')
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {

      print('📡 === FIRESTORE SNAPSHOT RECEIVED ===');
      print('   Changes: ${snapshot.docChanges.length}');

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final transcription = SpeechTranscription.fromFirestore(change.doc);
          _transcriptions.add(transcription);

          print('📝 === NEW TRANSCRIPTION ===');
          print('   ID: ${transcription.id}');
          print('   Speaker: ${transcription.speakerName} (${transcription.speakerId})');
          print('   Language: ${transcription.originalLanguage}');
          print('   Text: "${transcription.originalText}"');
          print('   Is Final: ${transcription.isFinal}');
          print('   Existing Translations: ${transcription.translations.keys.toList()}');

          // Handle auto-translation for all participants
          _handleNewTranscription(transcription);
        }

        if (change.type == DocumentChangeType.modified) {
          final transcription = SpeechTranscription.fromFirestore(change.doc);
          final index = _transcriptions.indexWhere((t) => t.id == transcription.id);

          if (index != -1) {
            _transcriptions[index] = transcription;
            print('🔄 Transcription updated: ${transcription.id}');
            print('   New translations: ${transcription.translations.keys.toList()}');
          }
        }

        if (change.type == DocumentChangeType.removed) {
          _transcriptions.removeWhere((t) => t.id == change.doc.id);
          print('🗑️ Transcription removed: ${change.doc.id}');
        }
      }

      // Sort by timestamp
      _transcriptions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }, onError: (error) {
      print('❌ Firestore listening error: $error');
      _handleServiceError('Transcription listening error');
    });

    _subscriptions.add(subscription);
  }

  // Handle new transcription for ALL participants
  void _handleNewTranscription(SpeechTranscription transcription) {
    print('🎯 === HANDLING NEW TRANSCRIPTION FOR ALL PARTICIPANTS ===');

    if (!(_userPreference?.enableLiveTranslation ?? false)) {
      print('🚫 Live translation disabled');
      return;
    }

    if (!_isServiceHealthy) {
      print('🚫 Service unhealthy, skipping translation');
      return;
    }

    // Get all target languages from ALL participants
    final allTargetLanguages = getAllTargetLanguages();
    print('🌐 All target languages in meeting: $allTargetLanguages');

    int queuedCount = 0;
    for (final targetLanguage in allTargetLanguages) {
      if (_shouldTranslateTranscription(transcription, targetLanguage)) {
        print('📋 === QUEUING TRANSLATION ===');
        print('   From: ${transcription.originalLanguage} → To: $targetLanguage');
        print('   Text: "${transcription.originalText}"');
        print('   For participants needing: $targetLanguage');

        _queueTranslation(transcription, targetLanguage, highPriority: transcription.isFinal);
        queuedCount++;
      }
    }

    print('📊 Total translations queued for this transcription: $queuedCount');
  }

  // Queue translation
  void _queueTranslation(SpeechTranscription transcription, String targetLanguage, {bool highPriority = false}) {
    final task = _TranslationTask(
      transcriptionId: transcription.id,
      originalText: transcription.originalText,
      fromLanguage: transcription.originalLanguage,
      toLanguage: targetLanguage,
      isHighPriority: highPriority,
    );

    // Check for duplicates
    final exists = _pendingTranslations.any((t) =>
    t.transcriptionId == task.transcriptionId &&
        t.toLanguage == task.toLanguage);

    if (!exists) {
      if (highPriority) {
        _pendingTranslations.insert(0, task);
        print('🔥 High priority task added to front of queue');
      } else {
        _pendingTranslations.add(task);
        print('📋 Normal priority task added to queue');
      }

      print('📊 Queue size: ${_pendingTranslations.length}');
    } else {
      print('⚠️ Duplicate task ignored');
    }
  }

  // Start translation processor
  void _startTranslationProcessor() {
    _translationProcessor?.cancel();
    _translationProcessor = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _processTranslationQueue();
    });
    print('🔄 Translation processor started');
  }

  // Process translation queue
  Future<void> _processTranslationQueue() async {
    if (_pendingTranslations.isEmpty) return;

    if (_isTranslating) {
      return; // Already processing
    }

    if (!_isServiceHealthy) {
      print('🚫 Service unhealthy, pausing translation processing');
      return;
    }

    _isTranslating = true;
    notifyListeners();

    try {
      // Sort by priority (high priority first)
      _pendingTranslations.sort((a, b) {
        if (a.isHighPriority != b.isHighPriority) {
          return a.isHighPriority ? -1 : 1;
        }
        return 0;
      });

      final task = _pendingTranslations.removeAt(0);
      print('🌐 === PROCESSING TRANSLATION TASK ===');
      print('   ${task.toString()}');

      await _processTranslationTask(task);

      // Reset error count on successful translation
      if (_consecutiveErrors > 0) {
        _consecutiveErrors = 0;
        _isServiceHealthy = true;
        print('✅ Service recovered, error count reset');
      }

    } catch (e) {
      print('❌ Error processing translation: $e');
      _handleServiceError('Translation processing error');
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  // Handle service errors
  void _handleServiceError(String errorType) {
    _consecutiveErrors++;
    print('⚠️ Service error: $errorType (consecutive: $_consecutiveErrors/$_maxConsecutiveErrors)');

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _isServiceHealthy = false;
      print('🚨 Service marked as unhealthy due to consecutive errors');

      // Pause translation processing for 30 seconds
      Timer(const Duration(seconds: 30), () {
        _consecutiveErrors = 0;
        _isServiceHealthy = true;
        print('🔄 Service recovery attempted');
      });
    }
  }

  // Process individual translation task
  Future<void> _processTranslationTask(_TranslationTask task) async {
    try {
      print('🔤 Translating: "${task.originalText}"');
      print('   From: ${task.fromLanguage} → To: ${task.toLanguage}');

      // Skip if text is too short or just whitespace
      if (task.originalText.trim().length < 2) {
        print('⏭️ Skipping short text');
        return;
      }

      // Get translation with retry logic
      final translatedText = await _translateWithCacheAndRetry(
        task.originalText,
        task.fromLanguage,
        task.toLanguage,
      );

      print('✅ Translation result: "$translatedText"');

      // Find transcription in local list
      final transcriptionIndex = _transcriptions.indexWhere((t) => t.id == task.transcriptionId);
      if (transcriptionIndex == -1) {
        print('⚠️ Transcription not found in local list: ${task.transcriptionId}');
        return;
      }

      final transcription = _transcriptions[transcriptionIndex];
      final updatedTranslations = Map<String, String>.from(transcription.translations);
      updatedTranslations[task.toLanguage] = translatedText;

      print('💾 === SAVING TRANSLATION TO FIRESTORE ===');
      print('   Document: ${task.transcriptionId}');
      print('   Updated translations: $updatedTranslations');

      // Update Firestore
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId!)
          .collection('transcriptions')
          .doc(task.transcriptionId)
          .update({'translations': updatedTranslations});

      // Update local copy immediately
      _transcriptions[transcriptionIndex] = transcription.copyWith(
        translations: updatedTranslations,
      );

      print('✅ Translation saved and local copy updated');
      notifyListeners();

    } catch (e) {
      print('❌ Error processing translation task: $e');
      print('   Task: ${task.toString()}');
      rethrow;
    }
  }

  // Translate with cache and retry logic
  Future<String> _translateWithCacheAndRetry(String text, String fromLang, String toLang, {int maxRetries = 2}) async {
    if (text.trim().isEmpty || fromLang == toLang) {
      return text;
    }

    final cacheKey = '$fromLang:$toLang:${text.hashCode}';

    // Check cache first
    if (_translationCache.containsKey(cacheKey)) {
      print('💾 Cache hit for: $fromLang → $toLang');
      return _translationCache[cacheKey]!;
    }

    int attempts = 0;
    while (attempts <= maxRetries) {
      try {
        print('🌐 Google Translate API call (attempt ${attempts + 1}): $fromLang → $toLang');
        print('   Text: "$text"');

        final translation = await _translator.translate(
          text,
          from: fromLang,
          to: toLang,
        );

        final translatedText = translation.text;

        // Cache the result
        _translationCache[cacheKey] = translatedText;

        print('✅ Translation API success: "$translatedText"');
        return translatedText;

      } catch (e) {
        attempts++;
        print('❌ Translation API error (attempt $attempts): $e');

        if (attempts <= maxRetries) {
          // Wait before retry
          await Future.delayed(Duration(seconds: attempts * 2));
          print('🔄 Retrying translation...');
        } else {
          print('❌ Max retries exceeded, falling back to original text');
          return text; // Fallback to original
        }
      }
    }

    return text;
  }

  // Save speech transcription
  Future<String> saveSpeechTranscription({
    required String speakerId,
    required String speakerName,
    required String originalText,
    required String originalLanguage,
    required bool isFinal,
    double confidence = 1.0,
  }) async {
    if (_currentMeetingId == null) {
      throw Exception('No active meeting');
    }

    try {
      final transcriptionId = '${DateTime.now().millisecondsSinceEpoch}_$speakerId';

      final transcription = SpeechTranscription(
        id: transcriptionId,
        meetingId: _currentMeetingId!,
        speakerId: speakerId,
        speakerName: speakerName,
        originalText: originalText,
        originalLanguage: originalLanguage,
        timestamp: DateTime.now(),
        isFinal: isFinal,
        confidence: confidence,
        translations: {}, // Start with empty translations
        isActive: true,
      );

      print('💾 === SAVING TRANSCRIPTION TO FIRESTORE ===');
      print('   ID: $transcriptionId');
      print('   Speaker: $speakerName ($speakerId)');
      print('   Language: $originalLanguage');
      print('   Text: "$originalText"');
      print('   Final: $isFinal');
      print('   Meeting: $_currentMeetingId');

      // Save to Firestore
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId!)
          .collection('transcriptions')
          .doc(transcriptionId)
          .set(transcription.toFirestore());

      print('✅ Transcription saved to Firestore successfully');
      return transcriptionId;

    } catch (e) {
      print('❌ Error saving transcription: $e');
      throw Exception('Failed to save transcription: $e');
    }
  }

  // Get transcriptions for user
  List<SpeechTranscription> getTranscriptionsForUser() {
    return _transcriptions.where((t) => t.isActive).toList();
  }

  // Get text for user (with translation logic)
  String getTextForUser(SpeechTranscription transcription) {
    if (_userPreference == null) {
      return transcription.originalText;
    }

    // Rule 1: Always show original text for own speech
    if (transcription.speakerId == _currentUserId) {
      return transcription.originalText;
    }

    // Rule 2: Show translation for others' speech
    final displayLanguage = _userPreference!.displayLanguage;

    // If original language matches display language, show original
    if (transcription.originalLanguage == displayLanguage) {
      return transcription.originalText;
    }

    // Try to get translation
    final translatedText = transcription.getTranslation(displayLanguage);

    if (translatedText != transcription.originalText) {
      print('📖 Using translation: "${transcription.originalText}" → "$translatedText"');
    }

    return translatedText;
  }

  // Debug current state
  void debugCurrentState() {
    print('🔍 === CURRENT TRANSLATION SERVICE STATE ===');
    print('   Meeting ID: $_currentMeetingId');
    print('   User ID: $_currentUserId');
    print('   Service Healthy: $_isServiceHealthy');
    print('   Consecutive Errors: $_consecutiveErrors');
    print('   User Preference: ${_userPreference != null ? "SET" : "NULL"}');

    if (_userPreference != null) {
      print('     Display Language: ${_userPreference!.displayLanguage}');
      print('     Speaking Language: ${_userPreference!.speakingLanguage}');
      print('     Live Translation: ${_userPreference!.enableLiveTranslation}');
    }

    print('   Total Participants: ${_participantsLanguages.length}');
    print('   Participants Languages:');
    _participantsLanguages.forEach((id, info) {
      print('     $id: ${info.displayName} (${info.speakingLanguage} → ${info.targetLanguage})');
    });

    print('   All Target Languages: ${getAllTargetLanguages()}');
    print('   Total Transcriptions: ${_transcriptions.length}');
    print('   Pending Translations: ${_pendingTranslations.length}');
    print('   Is Translating: $_isTranslating');
    print('   Cache Size: ${_translationCache.length}');

    // List recent transcriptions
    final recentTranscriptions = _transcriptions.length > 5
        ? _transcriptions.sublist(_transcriptions.length - 5)
        : _transcriptions;

    for (int i = 0; i < recentTranscriptions.length; i++) {
      final t = recentTranscriptions[i];
      print('   [$i] ${t.speakerName}: "${t.originalText}" (${t.originalLanguage})');
      print('       Translations: ${t.translations.keys.toList()}');
      print('       Is Own: ${t.speakerId == _currentUserId}');
    }

    // List pending tasks
    for (int i = 0; i < _pendingTranslations.length && i < 5; i++) {
      final task = _pendingTranslations[i];
      print('   Task[$i]: ${task.toString()}');
    }
  }

  // Force retranslate all (for testing)
  Future<void> forceRetranslateAll() async {
    print('🔄 === FORCE RETRANSLATE ALL TRANSCRIPTIONS ===');

    final allTargetLanguages = getAllTargetLanguages();
    print('   Target languages: $allTargetLanguages');

    int queuedCount = 0;
    for (final transcription in _transcriptions) {
      for (final targetLanguage in allTargetLanguages) {
        if (_shouldTranslateTranscription(transcription, targetLanguage)) {
          _queueTranslation(transcription, targetLanguage, highPriority: true);
          queuedCount++;
        }
      }
    }

    print('📋 Total queued for force retranslation: $queuedCount');
  }

  // Test translation
  Future<void> testTranslation(String text, String fromLang, String toLang) async {
    print('🧪 === TEST TRANSLATION ===');
    print('   Text: "$text"');
    print('   From: $fromLang → To: $toLang');

    try {
      final result = await _translateWithCacheAndRetry(text, fromLang, toLang);
      print('   ✅ Result: "$result"');
    } catch (e) {
      print('   ❌ Error: $e');
    }
  }

  // Clear transcriptions
  Future<void> clearTranscriptions() async {
    if (_currentMeetingId == null) return;

    try {
      final batch = _firestore.batch();
      for (var transcription in _transcriptions) {
        final docRef = _firestore
            .collection('meetings')
            .doc(_currentMeetingId!)
            .collection('transcriptions')
            .doc(transcription.id);
        batch.update(docRef, {'isActive': false});
      }

      await batch.commit();
      _transcriptions.clear();
      _pendingTranslations.clear();
      notifyListeners();

      print('🗑️ Transcriptions cleared');
    } catch (e) {
      print('❌ Error clearing transcriptions: $e');
    }
  }

  // Get translation statistics
  Map<String, dynamic> getTranslationStats() {
    final totalTranscriptions = _transcriptions.length;
    final ownTranscriptions = _transcriptions.where((t) => t.speakerId == _currentUserId).length;
    final otherTranscriptions = totalTranscriptions - ownTranscriptions;

    final translatedCount = _transcriptions.where((t) =>
    t.speakerId != _currentUserId &&
        t.hasTranslation(_userPreference?.displayLanguage ?? 'en')).length;

    return {
      'totalTranscriptions': totalTranscriptions,
      'ownTranscriptions': ownTranscriptions,
      'otherTranscriptions': otherTranscriptions,
      'translatedTranscriptions': translatedCount,
      'pendingTranslations': _pendingTranslations.length,
      'isTranslating': _isTranslating,
      'participantsCount': _participantsLanguages.length,
      'allTargetLanguages': getAllTargetLanguages(),
      'serviceHealthy': _isServiceHealthy,
      'consecutiveErrors': _consecutiveErrors,
    };
  }

  @override
  void dispose() {
    print('🧹 Disposing Translation Service...');
    _translationProcessor?.cancel();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _transcriptions.clear();
    _pendingTranslations.clear();
    _translationCache.clear();
    _participantsLanguages.clear();
    super.dispose();
  }
}

// Translation task class
class _TranslationTask {
  final String transcriptionId;
  final String originalText;
  final String fromLanguage;
  final String toLanguage;
  final bool isHighPriority;

  _TranslationTask({
    required this.transcriptionId,
    required this.originalText,
    required this.fromLanguage,
    required this.toLanguage,
    this.isHighPriority = false,
  });

  @override
  String toString() => 'TranslationTask($transcriptionId: $fromLanguage → $toLanguage, priority: ${isHighPriority ? "HIGH" : "normal"}, text: "$originalText")';
}

// Participant Language Info class
class ParticipantLanguageInfo {
  final String userId;
  final String displayName;
  final String targetLanguage;
  final String speakingLanguage;
  final bool isActive;

  ParticipantLanguageInfo({
    required this.userId,
    required this.displayName,
    required this.targetLanguage,
    required this.speakingLanguage,
    required this.isActive,
  });

  @override
  String toString() => 'Participant($displayName: $speakingLanguage → $targetLanguage, active: $isActive)';
}