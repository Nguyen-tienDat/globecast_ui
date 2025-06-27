// lib/services/meeting_coordinator_service.dart - COMPLETE FIXED VERSION
import 'package:flutter/foundation.dart';
import '../models/translation_message.dart';
import 'webrtc_mesh_meeting_service.dart';
import 'multilingual_speech_service.dart';

class MeetingCoordinatorService extends ChangeNotifier {
  final WebRTCMeshMeetingService _webrtcService;
  final MultilingualSpeechService _speechService;

  String? _currentMeetingId;
  String? _currentTargetLanguage; // ✅ SINGLE TARGET LANGUAGE
  String? _currentUserName;
  bool _isTranslating = false;
  final List<TranslationMessage> _messages = [];

  MeetingCoordinatorService({
    required WebRTCMeshMeetingService webrtcService,
    required MultilingualSpeechService speechService,
  }) : _webrtcService = webrtcService,
        _speechService = speechService {
    _setupListeners();
  }

  // Getters
  bool get isTranslating => _isTranslating;
  String? get currentMeetingId => _currentMeetingId;
  String? get currentTargetLanguage => _currentTargetLanguage;
  List<TranslationMessage> get recentMessages => List.from(_messages);

  void _setupListeners() {
    // Listen to speech results stream
    _speechService.speechResultStream.listen(_onSpeechResult);

    // Listen to status updates
    _speechService.statusStream.listen((status) {
      if (kDebugMode) {
        print('📱 Speech service status: $status');
      }
    });
  }

  // ✅ JOIN MEETING WITH SINGLE TARGET LANGUAGE
  Future<void> joinMeeting({
    required String meetingId,
    required String displayName,
    required String targetLanguage, // SINGLE TARGET
  }) async {
    try {
      print('🎯 Joining meeting: $meetingId');
      print('🌐 Target language: $targetLanguage'); // SINGLE TARGET
      print('👤 Display name: $displayName');

      _currentMeetingId = meetingId;
      _currentTargetLanguage = targetLanguage; // ✅ SET SINGLE TARGET
      _currentUserName = displayName;

      // Set user details in WebRTC service
      _webrtcService.setUserDetails(displayName: displayName);

      // Join WebRTC meeting - Fix method signature (only meetingId required)
      await _webrtcService.joinMeeting(meetingId: meetingId);

      // Start translation for SINGLE target language
      await startTranslation(targetLanguage);

      notifyListeners();
      print('✅ Meeting coordinator ready');

    } catch (e) {
      print('❌ Error joining meeting: $e');
      rethrow;
    }
  }

  // ✅ START TRANSLATION FOR SINGLE LANGUAGE
  Future<void> startTranslation(String targetLanguage, {String? speakingLanguage}) async {
    try {
      print('🎯 Starting translation: ${speakingLanguage ?? 'Auto'} -> $targetLanguage');

      _currentTargetLanguage = targetLanguage; // ✅ SINGLE TARGET
      _isTranslating = true;

      // Set user context for speech service
      _speechService.setUserContext(
          'user_${DateTime.now().millisecondsSinceEpoch}',
          _currentUserName ?? 'Guest'
      );

      // Set translation context (meeting ID)
      _speechService.setTranslationContext(_currentMeetingId ?? '');

      // Save personal preferences with user's choice
      await _speechService.savePersonalPreferences(
          speakingLanguage ?? 'auto', // User can choose speaking language
          targetLanguage
      );

      // Start listening
      await _speechService.startListening(
        meetingId: _currentMeetingId,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        preferredLanguage: speakingLanguage ?? 'auto', // User's speaking language
      );

      notifyListeners();
      print('✅ Translation started for: $targetLanguage');

    } catch (e) {
      print('❌ Error starting translation: $e');
      _isTranslating = false;
      notifyListeners();
    }
  }

  Future<void> stopTranslation() async {
    try {
      _isTranslating = false;
      await _speechService.stopListening();
      notifyListeners();
      print('⏹️ Translation stopped');
    } catch (e) {
      print('❌ Error stopping translation: $e');
    }
  }

  // ✅ HANDLE SPEECH RESULTS WITH SINGLE TRANSLATION
  void _onSpeechResult(SpeechResult result) {
    if (result.originalText.isNotEmpty && _currentTargetLanguage != null) {
      print('📝 Processing speech: "${result.originalText}"');
      print('🎯 Target language: $_currentTargetLanguage');

      // ✅ GET ONLY TARGET TRANSLATION (not all languages)
      final translation = _getTargetTranslation(result, _currentTargetLanguage!);

      final message = TranslationMessage(
        speakerName: result.userName.isNotEmpty ? result.userName : 'Speaker',
        originalText: result.originalText,
        originalLanguage: result.detectedLanguage,
        translation: translation, // ✅ SINGLE TRANSLATION
        targetLanguage: _currentTargetLanguage!,
        confidence: (result.confidence * 100).round(),
        timestamp: _formatTimestamp(result.timestamp),
        isCurrentUser: true, // Assume current user for now
      );

      _messages.add(message);

      // Keep only last 50 messages
      if (_messages.length > 50) {
        _messages.removeAt(0);
      }

      print('✅ Message added: ${message.originalText} -> ${message.translation}');
      notifyListeners();
    }
  }

  // ✅ GET ONLY TARGET TRANSLATION (not all languages)
  String _getTargetTranslation(SpeechResult speechResult, String targetLanguage) {
    try {
      // Check translations map first
      if (speechResult.translations.containsKey(targetLanguage)) {
        final translation = speechResult.translations[targetLanguage];
        if (translation != null && translation.isNotEmpty) {
          return translation;
        }
      }

      // If original language is same as target, no translation needed
      if (speechResult.detectedLanguage == targetLanguage) {
        return speechResult.originalText;
      }

      // Try to find any available translation
      if (speechResult.translations.isNotEmpty) {
        return speechResult.translations.values.first;
      }

      return 'Translation not available';

    } catch (e) {
      print('❌ Error getting translation: $e');
      return 'Translation error';
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes == 0) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // WebRTC controls - Fix method signatures to match actual service
  Future<void> toggleMicrophone(bool enabled) async {
    try {
      // WebRTC service has toggleAudio() method (no parameters)
      await _webrtcService.toggleAudio();
      print('🎤 Microphone toggled');
    } catch (e) {
      print('❌ Error toggling microphone: $e');
    }
  }

  Future<void> toggleCamera(bool enabled) async {
    try {
      // WebRTC service has toggleVideo() method (no parameters)
      await _webrtcService.toggleVideo();
      print('📹 Camera toggled');
    } catch (e) {
      print('❌ Error toggling camera: $e');
    }
  }

  Future<void> leaveMeeting() async {
    try {
      await stopTranslation();
      await _webrtcService.leaveMeeting();

      _currentMeetingId = null;
      _currentTargetLanguage = null;
      _currentUserName = null;
      _messages.clear();

      notifyListeners();
      print('👋 Left meeting');
    } catch (e) {
      print('❌ Error leaving meeting: $e');
    }
  }

  List<TranslationMessage> getRecentTranslations() {
    return List.from(_messages.reversed.take(20));
  }

  @override
  void dispose() {
    // Speech service stream is already being listened to, no need to remove specific listener
    super.dispose();
  }
}