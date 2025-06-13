// lib/screens/meeting/controller.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/whisper_service.dart';

class MeetingController extends ChangeNotifier {
  // Reference to WebRTC mesh service
  final WebRTCMeshMeetingService _webrtcService;

  // Local state for UI elements
  bool _isChatVisible = false;
  bool _isParticipantsListVisible = false;
  bool _isLanguageMenuVisible = false;
  bool _areSubtitlesVisible = true;

  // Navigation callback
  VoidCallback? onMeetingEnded;

  // Constructor
  MeetingController(this._webrtcService) {
    // Listen for service changes
    _webrtcService.addListener(_syncStateFromService);

    // Initialize subtitle visibility based on service state
    _areSubtitlesVisible = _webrtcService.areSubtitlesEnabled;
  }

  // Getters
  String get meetingCode => _webrtcService.meetingId ?? 'Unknown';
  bool get isMicOn => _webrtcService.isAudioEnabled;
  bool get isCameraOn => _webrtcService.isVideoEnabled;
  bool get areSubtitlesVisible => _areSubtitlesVisible;
  bool get isChatVisible => _isChatVisible;
  bool get isParticipantsListVisible => _isParticipantsListVisible;
  bool get isLanguageMenuVisible => _isLanguageMenuVisible;
  bool get isHost => _webrtcService.isHost;
  bool get isMeetingActive => _webrtcService.isMeetingActive;
  int get participantCount => _webrtcService.participants.length;
  List<MeshParticipant> get participants => _webrtcService.participants;

  // Get Whisper service for subtitle functionality
  WhisperService? get whisperService => _webrtcService.whisperService;

  // Get current language settings
  String get userNativeLanguage => _webrtcService.userNativeLanguage;
  String get userDisplayLanguage => _webrtcService.userDisplayLanguage;

  // Get subtitle service connection status
  bool get isSubtitleServiceConnected => whisperService?.isConnected ?? false;
  bool get isSubtitleProcessing => whisperService?.isProcessing ?? false;

  // Set navigation callback
  void setOnMeetingEndedCallback(VoidCallback callback) {
    onMeetingEnded = callback;
  }

  // Sync state from service changes
  void _syncStateFromService() {
    // Check if meeting has ended
    if (!_webrtcService.isMeetingActive && _webrtcService.meetingId == null) {
      print('Meeting has ended, triggering navigation callback');
      onMeetingEnded?.call();
    }

    // Sync subtitle visibility with service state
    if (_areSubtitlesVisible != _webrtcService.areSubtitlesEnabled) {
      _areSubtitlesVisible = _webrtcService.areSubtitlesEnabled;
    }

    notifyListeners();
  }

  // End call method (for host)
  Future<void> endCall() async {
    try {
      print('Ending call...');
      await _webrtcService.leaveMeeting();
      onMeetingEnded?.call();
    } catch (e) {
      print('Error ending call: $e');
      onMeetingEnded?.call();
    }
  }

  // Leave call method (for participants)
  Future<void> leaveCall() async {
    try {
      print('Leaving call...');
      await _webrtcService.leaveMeeting();
      onMeetingEnded?.call();
    } catch (e) {
      print('Error leaving call: $e');
      onMeetingEnded?.call();
    }
  }

  // Combined end/leave call method
  Future<void> endOrLeaveCall() async {
    if (isHost) {
      await endCall();
    } else {
      await leaveCall();
    }
  }

  // Toggle controls
  void toggleMicrophone() async {
    await _webrtcService.toggleAudio();
    notifyListeners();
  }

  void toggleCamera() async {
    await _webrtcService.toggleVideo();
    notifyListeners();
  }

  void toggleSubtitlesVisibility() async {
    _areSubtitlesVisible = !_areSubtitlesVisible;

    // Also toggle subtitles in the WebRTC service
    await _webrtcService.toggleSubtitles();

    notifyListeners();
  }

  void toggleChat() {
    _isChatVisible = !_isChatVisible;
    if (_isChatVisible) {
      _isParticipantsListVisible = false;
      _isLanguageMenuVisible = false;
    }
    notifyListeners();
  }

  void toggleParticipantsList() {
    _isParticipantsListVisible = !_isParticipantsListVisible;
    if (_isParticipantsListVisible) {
      _isChatVisible = false;
      _isLanguageMenuVisible = false;
    }
    notifyListeners();
  }

  void toggleLanguageMenu() {
    _isLanguageMenuVisible = !_isLanguageMenuVisible;
    if (_isLanguageMenuVisible) {
      _isChatVisible = false;
      _isParticipantsListVisible = false;
    }
    notifyListeners();
  }

  void closePanels() {
    _isChatVisible = false;
    _isParticipantsListVisible = false;
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  // Update language settings
  Future<void> updateLanguageSettings({
    required String nativeLanguage,
    required String displayLanguage,
  }) async {
    try {
      await _webrtcService.updateLanguageSettings(
        nativeLanguage: nativeLanguage,
        displayLanguage: displayLanguage,
      );

      print('Language settings updated: $nativeLanguage → $displayLanguage');
      notifyListeners();
    } catch (e) {
      print('Error updating language settings: $e');
      rethrow;
    }
  }

  // Get renderer for a participant
  dynamic getRendererForParticipant(String participantId) {
    return _webrtcService.getRendererForParticipant(participantId);
  }

  // Subtitle management methods
  void clearSubtitles() {
    whisperService?.clearSubtitles();
  }

  // Get subtitle for specific speaker
  dynamic getSubtitleForSpeaker(String speakerId) {
    return whisperService?.getSubtitleForSpeaker(speakerId);
  }

  // Test subtitle functionality
  Future<void> testSubtitleConnection() async {
    try {
      print('Testing subtitle connection...');

      if (whisperService == null) {
        print('Whisper service not available');
        return;
      }

      final connected = await whisperService!.connect();
      if (connected) {
        print('✅ Subtitle service connected successfully');
      } else {
        print('❌ Failed to connect to subtitle service');
      }
    } catch (e) {
      print('Error testing subtitle connection: $e');
    }
  }

  // Send test audio for subtitle testing
  Future<void> sendTestAudio() async {
    try {
      if (whisperService == null) return;

      // This would send actual audio data in a real implementation
      // For now, we'll trigger the test through the service
      print('Sending test audio for transcription...');

      // In a real implementation, you would capture audio and send it
      // await whisperService!.sendAudioData(audioData, userId, displayName);

    } catch (e) {
      print('Error sending test audio: $e');
    }
  }

  // Get meeting status summary
  Map<String, dynamic> getMeetingStatus() {
    return {
      'meetingId': meetingCode,
      'participantCount': participantCount,
      'isHost': isHost,
      'isMeetingActive': isMeetingActive,
      'audioEnabled': isMicOn,
      'videoEnabled': isCameraOn,
      'subtitlesEnabled': areSubtitlesVisible,
      'subtitleServiceConnected': isSubtitleServiceConnected,
      'userNativeLanguage': userNativeLanguage,
      'userDisplayLanguage': userDisplayLanguage,
    };
  }

  // Handle subtitle errors
  void handleSubtitleError(String error) {
    print('Subtitle error: $error');
    // You could show a snackbar or handle the error in the UI
    notifyListeners();
  }

  // Reconnect subtitle service
  Future<void> reconnectSubtitleService() async {
    try {
      print('Reconnecting subtitle service...');

      if (whisperService == null) return;

      await whisperService!.disconnect();
      await Future.delayed(const Duration(seconds: 2));

      final connected = await whisperService!.connect();
      if (connected) {
        print('✅ Subtitle service reconnected');
      } else {
        print('❌ Failed to reconnect subtitle service');
      }

      notifyListeners();
    } catch (e) {
      print('Error reconnecting subtitle service: $e');
    }
  }

  // Check if translation is needed for current user
  bool needsTranslationForUser() {
    return userNativeLanguage != userDisplayLanguage;
  }

  // Get participant by ID
  MeshParticipant? getParticipantById(String participantId) {
    try {
      return participants.firstWhere((p) => p.id == participantId);
    } catch (e) {
      return null;
    }
  }

  // Check if participant speaks different language than user's display language
  bool participantNeedsTranslation(String participantId) {
    final participant = getParticipantById(participantId);
    if (participant == null) return false;

    return participant.nativeLanguage != userDisplayLanguage;
  }

  // Get language info for display
  String getLanguageDisplayName(String languageCode) {
    final languages = WhisperService.supportedLanguages;
    return languages[languageCode]?.name ?? languageCode.toUpperCase();
  }

  String getLanguageFlag(String languageCode) {
    final languages = WhisperService.supportedLanguages;
    return languages[languageCode]?.flag ?? '🌐';
  }

  @override
  void dispose() {
    print('Disposing MeetingController...');
    _webrtcService.removeListener(_syncStateFromService);
    super.dispose();
  }
}