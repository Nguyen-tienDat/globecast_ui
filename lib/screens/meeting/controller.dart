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

  // Constructor
  MeetingController(this._meetingService) {
    // Listen for meeting service changes
    _meetingService.addListener(_syncStateFromService);
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
    notifyListeners();
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

  void setSelectedLanguage(String language) {
    _meetingService.setLanguagePreferences(
        speaking: _meetingService.speakingLanguage,
        listening: language
    );
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  void leaveMeeting(BuildContext context) async {
    await _meetingService.leaveMeeting();
    Navigator.of(context).pop();
  }

  // Speech recognition
  void toggleSpeechRecognition() async {
    await _meetingService.toggleSpeechRecognition();
  }

  // Send message
  void sendMessage(String message) async {
    await _meetingService.sendMessage(message);
  }

  // Get renderer for a participant
  dynamic getRendererForParticipant(String participantId) {
    return _meetingService.getRendererForParticipant(participantId);
  }

  @override
  void dispose() {
    _meetingService.removeListener(_syncStateFromService);
    super.dispose();
  }
}