// lib/screens/meeting/controller.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/services/meeting_service.dart';

class MeetingController extends ChangeNotifier {
  // Reference to meeting service
  final GcbMeetingService _meetingService;

  // Local state for UI elements
  bool _isChatVisible = false;
  bool _isParticipantsListVisible = false;
  bool _isLanguageMenuVisible = false;
  bool _areSubtitlesVisible = true;

  // END CALL - Navigation callback
  VoidCallback? onMeetingEnded;

  // Getters
  String get meetingCode => _meetingService.meetingId ?? 'Unknown';
  Duration get elapsedTime => _meetingService.elapsedTime;
  bool get isMicOn => !_getLocalParticipant().isMuted;
  bool get isCameraOn => true; // Get from localStream's video track
  bool get isScreenSharing => _getLocalParticipant().isScreenSharing;
  bool get isHandRaised => _getLocalParticipant().isHandRaised;
  bool get areSubtitlesVisible => _areSubtitlesVisible;
  bool get isChatVisible => _isChatVisible;
  bool get isParticipantsListVisible => _isParticipantsListVisible;
  bool get isLanguageMenuVisible => _isLanguageMenuVisible;
  String get selectedLanguage => _meetingService.listeningLanguage;
  List<ParticipantModel> get participants => _meetingService.participants;
  List<SubtitleModel> get subtitles => _meetingService.subtitles;

  // END CALL - Additional getters
  bool get isHost => _meetingService.isHost;
  bool get isMeetingActive => _meetingService.isMeetingActive;
  bool get isListening => _meetingService.isListening;
  int get participantCount => _meetingService.participants.length;

  // Format elapsed time for display
  String get formattedElapsedTime {
    final hours = elapsedTime.inHours;
    final minutes = elapsedTime.inMinutes % 60;
    final seconds = elapsedTime.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Constructor
  MeetingController(this._meetingService) {
    // Listen for meeting service changes
    _meetingService.addListener(_syncStateFromService);
  }

  // END CALL - Set navigation callback
  void setOnMeetingEndedCallback(VoidCallback callback) {
    onMeetingEnded = callback;
  }

  // Get local participant
  ParticipantModel _getLocalParticipant() {
    if (_meetingService.participants.isEmpty) {
      return ParticipantModel(
        id: _meetingService.userId ?? 'unknown',
        name: 'You',
        isMuted: true,
        isHost: _meetingService.isHost,
      );
    }

    return _meetingService.participants.firstWhere(
          (p) => p.id == _meetingService.userId,
      orElse: () => ParticipantModel(
        id: _meetingService.userId ?? 'unknown',
        name: 'You',
        isMuted: true,
        isHost: _meetingService.isHost,
      ),
    );
  }

  // Sync controller from service changes
  void _syncStateFromService() {
    // END CALL - Check if meeting has ended
    if (!_meetingService.isMeetingActive && _meetingService.meetingId == null) {
      print('Meeting has ended, triggering navigation callback');
      // Meeting has ended, trigger navigation callback
      onMeetingEnded?.call();
    }
    notifyListeners();
  }

  // END CALL METHODS

  // End call method (for host - ends meeting for everyone)
  Future<void> endCall() async {
    try {
      print('Ending call as host...');
      await _meetingService.endMeetingForAll();

      // Trigger navigation callback
      onMeetingEnded?.call();
    } catch (e) {
      print('Error ending call: $e');
      // Still trigger navigation even if there's an error
      onMeetingEnded?.call();
    }
  }

  // Leave call method (for participants)
  Future<void> leaveCall() async {
    try {
      print('Leaving call as participant...');
      await _meetingService.leaveMeetingAsParticipant();

      // Trigger navigation callback
      onMeetingEnded?.call();
    } catch (e) {
      print('Error leaving call: $e');
      // Still trigger navigation even if there's an error
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

  // Legacy method - updated to use new logic
  void leaveMeeting(BuildContext context) async {
    try {
      await endOrLeaveCall();
      // Navigation will be handled by callback
    } catch (e) {
      print('Error in leaveMeeting: $e');
      // Fallback navigation
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // Methods to toggle controls
  void toggleMicrophone() async {
    await _meetingService.toggleMicrophone();
    notifyListeners();
  }

  void toggleCamera() async {
    await _meetingService.toggleCamera();
    notifyListeners();
  }

  void toggleScreenSharing() async {
    await _meetingService.toggleScreenSharing();
    notifyListeners();
  }

  void toggleHandRaised() async {
    await _meetingService.toggleHandRaised();
    notifyListeners();
  }

  void toggleSubtitlesVisibility() {
    _areSubtitlesVisible = !_areSubtitlesVisible;
    notifyListeners();
  }

  void toggleChat() {
    _isChatVisible = !_isChatVisible;

    // Close other panels
    if (_isChatVisible) {
      _isParticipantsListVisible = false;
      _isLanguageMenuVisible = false;
    }

    notifyListeners();
  }

  void toggleParticipantsList() {
    _isParticipantsListVisible = !_isParticipantsListVisible;

    // Close other panels
    if (_isParticipantsListVisible) {
      _isChatVisible = false;
      _isLanguageMenuVisible = false;
    }

    notifyListeners();
  }

  void toggleLanguageMenu() {
    _isLanguageMenuVisible = !_isLanguageMenuVisible;

    // Close other panels
    if (_isLanguageMenuVisible) {
      _isChatVisible = false;
      _isParticipantsListVisible = false;
    }

    notifyListeners();
  }

  // END CALL - Close all panels
  void closePanels() {
    _isChatVisible = false;
    _isParticipantsListVisible = false;
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  void setSelectedLanguage(String language) {
    _meetingService.setLanguagePreferences(
        speaking: _meetingService.speakingLanguage,
        listening: language
    );
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  // Speech recognition
  void toggleSpeechRecognition() async {
    await _meetingService.toggleSpeechRecognition();
  }

  // START/STOP speech recognition separately
  Future<void> startSpeechRecognition() async {
    try {
      await _meetingService.startSpeechRecognition();
    } catch (e) {
      print('Error starting speech recognition: $e');
    }
  }

  Future<void> stopSpeechRecognition() async {
    try {
      await _meetingService.stopSpeechRecognition();
    } catch (e) {
      print('Error stopping speech recognition: $e');
    }
  }

  // Send message
  void sendMessage(String message) async {
    await _meetingService.sendMessage(message);
  }

  // Get renderer for a participant
  dynamic getRendererForParticipant(String participantId) {
    return _meetingService.getRendererForParticipant(participantId);
  }

  // END CALL - Utility methods

  // Get current speaking participant
  ParticipantModel? getCurrentSpeakingParticipant() {
    try {
      return participants.firstWhere((p) => p.isSpeaking);
    } catch (e) {
      return null;
    }
  }

  // Get local participant (public method)
  ParticipantModel? getLocalParticipant() {
    try {
      return participants.firstWhere((p) => p.id == _meetingService.userId);
    } catch (e) {
      return null;
    }
  }

  // Check if user is the only participant
  bool get isOnlyParticipant => participants.length <= 1;

  // Better camera state detection
  bool get isCameraOnDetailed {
    if (_meetingService.localRenderer?.srcObject == null) return false;

    // You can implement more detailed camera detection here
    // For now, return true if we have local renderer
    return _meetingService.localRenderer?.srcObject != null;
  }

  @override
  void dispose() {
    print('Disposing MeetingController...');
    _meetingService.removeListener(_syncStateFromService);
    super.dispose();
  }
}