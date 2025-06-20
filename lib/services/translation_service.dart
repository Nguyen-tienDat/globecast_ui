// lib/services/translation_service.dart - FIXED VERSION
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import '../models/translation_models.dart';

class TranslationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleTranslator _translator = GoogleTranslator();

  // Cache for translations to avoid repeated API calls
  final Map<String, Map<String, String>> _translationCache = {};

  // Active transcriptions for current meeting
  final List<SpeechTranscription> _transcriptions = [];

  // Current user language preference
  UserLanguagePreference? _userPreference;

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Current meeting context
  String? _currentMeetingId;
  String? _currentUserId;

  // Translation state
  bool _isTranslating = false;

  // Getters
  List<SpeechTranscription> get transcriptions => List.unmodifiable(_transcriptions);
  UserLanguagePreference? get userPreference => _userPreference;
  String? get currentMeetingId => _currentMeetingId;
  String? get currentUserId => _currentUserId;
  bool get isTranslating => _isTranslating;

  // Initialize service for a meeting
  Future<void> initializeForMeeting(String meetingId, String userId) async {
    try {
      _currentMeetingId = meetingId;
      _currentUserId = userId;

      print('🌐 Initializing Translation Service for meeting: $meetingId, user: $userId');

      // Load user language preference
      await _loadUserPreference(userId);

      // Start listening for transcriptions
      _listenForTranscriptions();

      print('✅ Translation Service initialized');
    } catch (e) {
      print('❌ Error initializing Translation Service: $e');
      throw Exception('Failed to initialize translation service: $e');
    }
  }

  // Load user language preference
  Future<void> _loadUserPreference(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_preferences')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _userPreference = UserLanguagePreference(
          userId: data['userId'] ?? userId,
          displayLanguage: data['displayLanguage'] ?? 'en',
          speakingLanguage: data['speakingLanguage'] ?? 'en',
          autoDetectSpeaking: data['autoDetectSpeaking'] ?? false,
          enableLiveTranslation: data['enableLiveTranslation'] ?? true,
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      } else {
        // Create default preference
        _userPreference = UserLanguagePreference(
          userId: userId,
          displayLanguage: 'en', // Default to English
          speakingLanguage: 'en',
          autoDetectSpeaking: false,
          enableLiveTranslation: true,
          updatedAt: DateTime.now(),
        );
        await _saveUserPreference();
      }

      print('👤 User preference loaded: Display=${_userPreference!.displayLanguage}, Speaking=${_userPreference!.speakingLanguage}');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading user preference: $e');
      // Fallback to default
      _userPreference = UserLanguagePreference(
        userId: userId,
        displayLanguage: 'en',
        speakingLanguage: 'en',
        autoDetectSpeaking: false,
        enableLiveTranslation: true,
        updatedAt: DateTime.now(),
      );
    }
  }

  // Save user language preference
  Future<void> _saveUserPreference() async {
    if (_userPreference == null || _currentUserId == null) return;

    try {
      await _firestore
          .collection('user_preferences')
          .doc(_currentUserId)
          .set({
        'userId': _userPreference!.userId,
        'displayLanguage': _userPreference!.displayLanguage,
        'speakingLanguage': _userPreference!.speakingLanguage,
        'autoDetectSpeaking': _userPreference!.autoDetectSpeaking,
        'enableLiveTranslation': _userPreference!.enableLiveTranslation,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('💾 User preference saved');
    } catch (e) {
      print('❌ Error saving user preference: $e');
    }
  }

  // Update user display language
  Future<void> updateDisplayLanguage(String languageCode) async {
    if (_userPreference == null) return;

    _userPreference = UserLanguagePreference(
      userId: _userPreference!.userId,
      displayLanguage: languageCode,
      speakingLanguage: _userPreference!.speakingLanguage,
      autoDetectSpeaking: _userPreference!.autoDetectSpeaking,
      enableLiveTranslation: _userPreference!.enableLiveTranslation,
      updatedAt: DateTime.now(),
    );

    await _saveUserPreference();
    notifyListeners();

    print('🔄 Display language updated to: ${SupportedLanguages.getLanguageName(languageCode)}');
  }

  // Update user speaking language
  Future<void> updateSpeakingLanguage(String languageCode) async {
    if (_userPreference == null) return;

    _userPreference = UserLanguagePreference(
      userId: _userPreference!.userId,
      displayLanguage: _userPreference!.displayLanguage,
      speakingLanguage: languageCode,
      autoDetectSpeaking: _userPreference!.autoDetectSpeaking,
      enableLiveTranslation: _userPreference!.enableLiveTranslation,
      updatedAt: DateTime.now(),
    );

    await _saveUserPreference();
    notifyListeners();

    print('🗣️ Speaking language updated to: ${SupportedLanguages.getLanguageName(languageCode)}');
  }

  // Listen for transcriptions in current meeting
  void _listenForTranscriptions() {
    if (_currentMeetingId == null) return;

    print('👂 Listening for transcriptions in meeting: $_currentMeetingId');

    final subscription = _firestore
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('transcriptions')
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          final transcription = SpeechTranscription(
            id: data['id'] ?? change.doc.id,
            meetingId: data['meetingId'] ?? _currentMeetingId!,
            speakerId: data['speakerId'] ?? '',
            speakerName: data['speakerName'] ?? 'Unknown',
            originalText: data['originalText'] ?? '',
            originalLanguage: data['originalLanguage'] ?? 'en',
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isFinal: data['isFinal'] ?? true,
            confidence: (data['confidence'] ?? 1.0).toDouble(),
            translations: Map<String, String>.from(data['translations'] ?? {}),
            isActive: data['isActive'] ?? true,
          );

          // Add to local list
          _transcriptions.add(transcription);

          // Auto-translate if needed
          if (_userPreference != null &&
              _userPreference!.enableLiveTranslation &&
              !transcription.hasTranslation(_userPreference!.displayLanguage)) {
            await _ensureTranslation(transcription, _userPreference!.displayLanguage);
          }

          print('📝 New transcription added: ${transcription.speakerName} (${transcription.originalLanguage})');
        }

        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data()!;
          final transcription = SpeechTranscription(
            id: data['id'] ?? change.doc.id,
            meetingId: data['meetingId'] ?? _currentMeetingId!,
            speakerId: data['speakerId'] ?? '',
            speakerName: data['speakerName'] ?? 'Unknown',
            originalText: data['originalText'] ?? '',
            originalLanguage: data['originalLanguage'] ?? 'en',
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isFinal: data['isFinal'] ?? true,
            confidence: (data['confidence'] ?? 1.0).toDouble(),
            translations: Map<String, String>.from(data['translations'] ?? {}),
            isActive: data['isActive'] ?? true,
          );
          final index = _transcriptions.indexWhere((t) => t.id == transcription.id);

          if (index != -1) {
            _transcriptions[index] = transcription;
            print('📝 Transcription updated: ${transcription.id}');
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
      print('❌ Error listening for transcriptions: $error');
    });

    _subscriptions.add(subscription);
  }

  // Save speech transcription to database
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
        translations: {},
        isActive: true,
      );

      // Save to Firestore
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('transcriptions')
          .doc(transcriptionId)
          .set({
        'id': transcription.id,
        'meetingId': transcription.meetingId,
        'speakerId': transcription.speakerId,
        'speakerName': transcription.speakerName,
        'originalText': transcription.originalText,
        'originalLanguage': transcription.originalLanguage,
        'timestamp': FieldValue.serverTimestamp(),
        'isFinal': transcription.isFinal,
        'confidence': transcription.confidence,
        'translations': transcription.translations,
        'isActive': transcription.isActive,
      });

      print('💾 Transcription saved: $transcriptionId');

      // Auto-translate for all participants
      _autoTranslateForAllParticipants(transcription);

      return transcriptionId;
    } catch (e) {
      print('❌ Error saving transcription: $e');
      throw Exception('Failed to save transcription: $e');
    }
  }

  // Auto-translate for all meeting participants
  Future<void> _autoTranslateForAllParticipants(SpeechTranscription transcription) async {
    if (_currentMeetingId == null) return;

    try {
      // Get all participants' language preferences
      final participantsSnapshot = await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('participants')
          .where('isActive', isEqualTo: true)
          .get();

      final Set<String> targetLanguages = {};

      for (var doc in participantsSnapshot.docs) {
        final participantId = doc.id;

        // Get participant's language preference
        try {
          final prefDoc = await _firestore
              .collection('user_preferences')
              .doc(participantId)
              .get();

          if (prefDoc.exists) {
            final data = prefDoc.data()!;
            final enableLiveTranslation = data['enableLiveTranslation'] ?? true;
            if (enableLiveTranslation) {
              targetLanguages.add(data['displayLanguage'] ?? 'en');
            }
          } else {
            targetLanguages.add('en'); // Default to English
          }
        } catch (e) {
          print('⚠️ Error getting preference for $participantId: $e');
          targetLanguages.add('en');
        }
      }

      // Remove original language from targets
      targetLanguages.remove(transcription.originalLanguage);

      // Translate to all target languages
      final translations = <String, String>{};

      for (String targetLang in targetLanguages) {
        try {
          final translatedText = await _translateText(
            transcription.originalText,
            transcription.originalLanguage,
            targetLang,
          );
          translations[targetLang] = translatedText;
        } catch (e) {
          print('❌ Translation failed for $targetLang: $e');
          translations[targetLang] = transcription.originalText; // Fallback
        }
      }

      // Update transcription with translations
      if (translations.isNotEmpty) {
        await _firestore
            .collection('meetings')
            .doc(_currentMeetingId)
            .collection('transcriptions')
            .doc(transcription.id)
            .update({'translations': translations});

        print('🌐 Auto-translated to ${translations.length} languages');
      }
    } catch (e) {
      print('❌ Error in auto-translation: $e');
    }
  }

  // Ensure translation exists for specific language
  Future<void> _ensureTranslation(SpeechTranscription transcription, String targetLanguage) async {
    if (transcription.hasTranslation(targetLanguage)) return;

    try {
      final translatedText = await _translateText(
        transcription.originalText,
        transcription.originalLanguage,
        targetLanguage,
      );

      // Update transcription in database
      final updatedTranslations = Map<String, String>.from(transcription.translations);
      updatedTranslations[targetLanguage] = translatedText;

      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('transcriptions')
          .doc(transcription.id)
          .update({'translations': updatedTranslations});

      print('🌐 Translation added: ${transcription.originalLanguage} → $targetLanguage');
    } catch (e) {
      print('❌ Error ensuring translation: $e');
    }
  }

  // Translate text with caching using Google Translator
  Future<String> _translateText(String text, String fromLang, String toLang) async {
    if (text.trim().isEmpty || fromLang == toLang) {
      return text;
    }

    // Check cache first
    final cacheKey = '$fromLang:$toLang:${text.hashCode}';
    if (_translationCache.containsKey(fromLang) &&
        _translationCache[fromLang]!.containsKey(cacheKey)) {
      return _translationCache[fromLang]![cacheKey]!;
    }

    try {
      _isTranslating = true;
      notifyListeners();

      print('🌐 Google Translator: "$text" ($fromLang → $toLang)');

      final translation = await _translator.translate(
        text,
        from: fromLang,
        to: toLang,
      );

      final translatedText = translation.text;

      // Cache the result
      _translationCache.putIfAbsent(fromLang, () => {});
      _translationCache[fromLang]![cacheKey] = translatedText;

      print('✅ Translation result: "$translatedText"');
      return translatedText;
    } catch (e) {
      print('❌ Translation error ($fromLang → $toLang): $e');
      return text; // Return original text as fallback
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  // Get transcriptions for user's display language
  List<SpeechTranscription> getTranscriptionsForUser() {
    if (_userPreference == null) return _transcriptions;

    return _transcriptions.map((transcription) {
      // For current user's own speech, show original
      if (transcription.speakerId == _currentUserId) {
        return transcription;
      }

      // For others, show translation if available
      final displayLanguage = _userPreference!.displayLanguage;
      if (transcription.hasTranslation(displayLanguage)) {
        return transcription;
      }

      return transcription;
    }).toList();
  }

  // Get text for user's display language
  String getTextForUser(SpeechTranscription transcription) {
    if (_userPreference == null) return transcription.originalText;

    // For current user's own speech, show original
    if (transcription.speakerId == _currentUserId) {
      return transcription.originalText;
    }

    // For others, show translation
    return transcription.getTranslation(_userPreference!.displayLanguage);
  }

  // Clear transcriptions (for testing)
  Future<void> clearTranscriptions() async {
    if (_currentMeetingId == null) return;

    try {
      final batch = _firestore.batch();

      for (var transcription in _transcriptions) {
        final docRef = _firestore
            .collection('meetings')
            .doc(_currentMeetingId)
            .collection('transcriptions')
            .doc(transcription.id);
        batch.update(docRef, {'isActive': false});
      }

      await batch.commit();
      _transcriptions.clear();
      notifyListeners();

      print('🗑️ Transcriptions cleared');
    } catch (e) {
      print('❌ Error clearing transcriptions: $e');
    }
  }

  // Get live subtitle for specific user
  LiveSubtitle? getCurrentLiveSubtitle() {
    if (_transcriptions.isEmpty || _userPreference == null) return null;

    // Get the latest non-final transcription
    final latestTranscription = _transcriptions
        .where((t) => !t.isFinal)
        .lastOrNull;

    if (latestTranscription == null) return null;

    return LiveSubtitle(
      id: latestTranscription.id,
      speakerId: latestTranscription.speakerId,
      speakerName: latestTranscription.speakerName,
      text: getTextForUser(latestTranscription),
      language: _userPreference!.displayLanguage,
      timestamp: latestTranscription.timestamp,
      isCurrentUser: latestTranscription.speakerId == _currentUserId,
      isFinal: latestTranscription.isFinal,
    );
  }

  // Get translation statistics
  Map<String, dynamic> getTranslationStats() {
    final totalTranscriptions = _transcriptions.length;
    final ownTranscriptions = _transcriptions.where((t) => t.speakerId == _currentUserId).length;
    final translatedTranscriptions = _transcriptions.where((t) =>
    t.speakerId != _currentUserId &&
        t.hasTranslation(_userPreference?.displayLanguage ?? 'en')).length;

    final languageDistribution = <String, int>{};
    for (final transcription in _transcriptions) {
      final lang = transcription.originalLanguage;
      languageDistribution[lang] = (languageDistribution[lang] ?? 0) + 1;
    }

    return {
      'totalTranscriptions': totalTranscriptions,
      'ownTranscriptions': ownTranscriptions,
      'translatedTranscriptions': translatedTranscriptions,
      'totalTranslations': translatedTranscriptions,
      'languageDistribution': languageDistribution,
    };
  }

  // Cleanup resources
  @override
  void dispose() {
    print('🧹 Disposing Translation Service...');

    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _transcriptions.clear();
    _translationCache.clear();
    _currentMeetingId = null;
    _currentUserId = null;
    _userPreference = null;

    super.dispose();
  }
}