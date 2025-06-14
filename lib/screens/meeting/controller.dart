// lib/screens/meeting/controller.dart - FIXED VERSION
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

  // Loading states
  bool _isToggling = false;

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
  bool get isToggling => _isToggling;
  int get participantCount => _webrtcService.participants.length;
  List<MeshParticipant> get participants => _webrtcService.participants;

  // Service status getters
  bool get hasWhisperService => _webrtcService.whisperService != null;
  bool get isWhisperConnected => _webrtcService.whisperService?.isConnected ?? false;
  String get userNativeLanguage => _webrtcService.userNativeLanguage;
  String get userDisplayLanguage => _webrtcService.userDisplayLanguage;

  // Set navigation callback
  void setOnMeetingEndedCallback(VoidCallback callback) {
    onMeetingEnded = callback;
  }

  // Sync state from service changes
  void _syncStateFromService() {
    // Check if meeting has ended
    if (!_webrtcService.isMeetingActive && _webrtcService.meetingId == null) {
      print('🏁 Meeting has ended, triggering navigation callback');
      onMeetingEnded?.call();
    }
    notifyListeners();
  }

  // End call method (for host)
  Future<void> endCall() async {
    if (_isToggling) return;

    try {
      _isToggling = true;
      notifyListeners();

      print('🛑 Host ending call...');
      await _webrtcService.leaveMeeting();
      onMeetingEnded?.call();
    } catch (e) {
      print('❌ Error ending call: $e');
      onMeetingEnded?.call();
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  // Leave call method (for participants)
  Future<void> leaveCall() async {
    if (_isToggling) return;

    try {
      _isToggling = true;
      notifyListeners();

      print('🚪 Participant leaving call...');
      await _webrtcService.leaveMeeting();
      onMeetingEnded?.call();
    } catch (e) {
      print('❌ Error leaving call: $e');
      onMeetingEnded?.call();
    } finally {
      _isToggling = false;
      notifyListeners();
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

  // Toggle controls with error handling
  Future<void> toggleMicrophone() async {
    if (_isToggling) return;

    try {
      _isToggling = true;
      notifyListeners();

      print('🎙️ Toggling microphone: ${!isMicOn}');
      await _webrtcService.toggleAudio();
    } catch (e) {
      print('❌ Error toggling microphone: $e');
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  Future<void> toggleCamera() async {
    if (_isToggling) return;

    try {
      _isToggling = true;
      notifyListeners();

      print('📹 Toggling camera: ${!isCameraOn}');
      await _webrtcService.toggleVideo();
    } catch (e) {
      print('❌ Error toggling camera: $e');
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  void toggleSubtitlesVisibility() {
    print('📝 Toggling subtitles visibility: ${!_areSubtitlesVisible}');
    _areSubtitlesVisible = !_areSubtitlesVisible;

    // If we have subtitle service, toggle it
    if (hasWhisperService) {
      _webrtcService.toggleSubtitles().catchError((error) {
        print('❌ Error toggling subtitles service: $error');
      });
    }

    notifyListeners();
  }

  void toggleChat() {
    print('💬 Toggling chat: ${!_isChatVisible}');
    _isChatVisible = !_isChatVisible;
    if (_isChatVisible) {
      _isParticipantsListVisible = false;
      _isLanguageMenuVisible = false;
    }
    notifyListeners();
  }

  void toggleParticipantsList() {
    print('👥 Toggling participants list: ${!_isParticipantsListVisible}');
    _isParticipantsListVisible = !_isParticipantsListVisible;
    if (_isParticipantsListVisible) {
      _isChatVisible = false;
      _isLanguageMenuVisible = false;
    }
    notifyListeners();
  }

  void toggleLanguageMenu() {
    print('🌍 Toggling language menu: ${!_isLanguageMenuVisible}');
    _isLanguageMenuVisible = !_isLanguageMenuVisible;
    if (_isLanguageMenuVisible) {
      _isChatVisible = false;
      _isParticipantsListVisible = false;
    }
    notifyListeners();
  }

  void closePanels() {
    print('❌ Closing all panels');
    _isChatVisible = false;
    _isParticipantsListVisible = false;
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  // Get renderer for a participant
  dynamic getRendererForParticipant(String participantId) {
    try {
      return _webrtcService.getRendererForParticipant(participantId);
    } catch (e) {
      print('❌ Error getting renderer for $participantId: $e');
      return null;
    }
  }

  // Language settings
  Future<void> updateLanguageSettings({
    required String nativeLanguage,
    required String displayLanguage,
  }) async {
    try {
      print('🌍 Updating language settings: $nativeLanguage -> $displayLanguage');
      await _webrtcService.updateLanguageSettings(
        nativeLanguage: nativeLanguage,
        displayLanguage: displayLanguage,
      );
    } catch (e) {
      print('❌ Error updating language settings: $e');
    }
  }

  // Meeting info methods
  String get meetingInfo {
    return '''
Meeting ID: $meetingCode
Participants: $participantCount
Status: ${isMeetingActive ? 'Active' : 'Inactive'}
Audio: ${isMicOn ? 'On' : 'Off'}
Video: ${isCameraOn ? 'On' : 'Off'}
Subtitles: ${areSubtitlesVisible ? 'On' : 'Off'}
Role: ${isHost ? 'Host' : 'Participant'}
''';
  }

  // Get participant by ID
  MeshParticipant? getParticipant(String participantId) {
    try {
      return participants.firstWhere((p) => p.id == participantId);
    } catch (e) {
      return null;
    }
  }

  // Get local participant
  MeshParticipant? get localParticipant {
    try {
      return participants.firstWhere((p) => p.isLocal);
    } catch (e) {
      return null;
    }
  }

  // Get remote participants
  List<MeshParticipant> get remoteParticipants {
    return participants.where((p) => !p.isLocal).toList();
  }

  // Check if any remote participant is speaking
  bool get hasActiveSpeaker {
    // This would integrate with audio level detection
    // For now, return false as we don't have real audio analysis
    return false;
  }

  // Get current speaker (if any)
  MeshParticipant? get currentSpeaker {
    // This would integrate with audio level detection
    // For now, return null as we don't have real audio analysis
    return null;
  }

  // Connection quality methods
  String get connectionQuality {
    if (!isMeetingActive) return 'Disconnected';

    // This would be based on actual WebRTC stats
    // For now, return a simple status
    return participantCount > 1 ? 'Good' : 'Excellent';
  }

  // Debug info
  Map<String, dynamic> get debugInfo {
    return {
      'meetingId': meetingCode,
      'userId': _webrtcService.userId,
      'isHost': isHost,
      'isMeetingActive': isMeetingActive,
      'participantCount': participantCount,
      'isAudioEnabled': isMicOn,
      'isVideoEnabled': isCameraOn,
      'areSubtitlesVisible': areSubtitlesVisible,
      'hasWhisperService': hasWhisperService,
      'isWhisperConnected': isWhisperConnected,
      'panelStates': {
        'chat': _isChatVisible,
        'participants': _isParticipantsListVisible,
        'language': _isLanguageMenuVisible,
      },
      'isToggling': _isToggling,
    };
  }

  // Refresh meeting state
  Future<void> refreshMeetingState() async {
    try {
      print('🔄 Refreshing meeting state...');
      // Force a state update
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing meeting state: $e');
    }
  }

  // Handle network changes
  void onNetworkChanged(bool isConnected) {
    print('🌐 Network changed: ${isConnected ? 'Connected' : 'Disconnected'}');
    if (isConnected && isMeetingActive) {
      // Try to reconnect or refresh state
      refreshMeetingState();
    }
  }

  // Emergency leave (force leave without cleanup)
  void emergencyLeave() {
    print('🚨 Emergency leave initiated');
    onMeetingEnded?.call();
  }

  @override
  void dispose() {
    print('🧹 Disposing MeetingController...');
    _webrtcService.removeListener(_syncStateFromService);
    super.dispose();
  }
}