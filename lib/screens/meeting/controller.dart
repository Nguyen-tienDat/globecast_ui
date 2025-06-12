// lib/screens/meeting/controller.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';

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

  void toggleSubtitlesVisibility() {
    _areSubtitlesVisible = !_areSubtitlesVisible;
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

  // Get renderer for a participant
  dynamic getRendererForParticipant(String participantId) {
    return _webrtcService.getRendererForParticipant(participantId);
  }

  @override
  void dispose() {
    print('Disposing MeetingController...');
    _webrtcService.removeListener(_syncStateFromService);
    super.dispose();
  }
}