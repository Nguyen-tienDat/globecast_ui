// lib/screens/meeting/controller.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import '../../models/meeting_models.dart';



class MeetingController extends ChangeNotifier {
  // Reference to SFU service
  final WebRTCMeshMeetingService _mediaService;

  // Local UI state
  bool _isChatVisible = false;
  bool _isParticipantsListVisible = false;
  bool _isLanguageMenuVisible = false;
  bool _areSubtitlesVisible = true;

  // Navigation callback
  VoidCallback? onMeetingEnded;

  // Constructor
  MeetingController(this._mediaService) {
    _mediaService.addListener(_syncStateFromService);
  }

  // === GETTERS ===
  String get meetingCode => _mediaService.currentMeetingId ?? 'Unknown';
  bool get isMicOn => _mediaService.isMicrophoneEnabled;
  bool get isCameraOn => _mediaService.isCameraEnabled;
  bool get isScreenSharing => _mediaService.isScreenSharing;
  bool get areSubtitlesVisible => _areSubtitlesVisible;
  bool get isChatVisible => _isChatVisible;
  bool get isParticipantsListVisible => _isParticipantsListVisible;
  bool get isLanguageMenuVisible => _isLanguageMenuVisible;
  bool get isHost => _mediaService.isHost;
  bool get isMeetingActive => _mediaService.isMeetingActive;
  bool get isConnectedToSFU => _mediaService.isConnectedToSFU;
  String? get userId => _mediaService.currentUserId;

  // Convert participants map to list of ParticipantModel
  List<ParticipantModel> get participants {
    return _mediaService.participants.entries.map((entry) {
      final data = entry.value;
      return ParticipantModel(
        id: entry.key,
        name: data['displayName'] ?? 'Unknown',
        isSpeaking: data['isSpeaking'] ?? false,
        isMuted: data['isMuted'] ?? false,
        isHost: data['role'] == 'host',
        isHandRaised: data['isHandRaised'] ?? false,
        isScreenSharing: data['isScreenSharing'] ?? false,
      );
    }).toList();
  }

  int get participantCount => participants.length;

  // Get local renderer
  dynamic get localRenderer => _mediaService.localRenderer;

  // Mock properties for compatibility
  Duration get elapsedTime => Duration.zero; // TODO: Implement timer
  bool get isListening => false; // TODO: Implement speech recognition
  List<SubtitleModel> get subtitles => []; // TODO: Implement subtitles
  List<ChatMessage> get messages => []; // TODO: Implement chat messages
  String get selectedLanguage => 'english'; // TODO: Implement language selection
  bool get isHandRaised => false; // TODO: Get from current user participant data

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

  // === CALLBACK MANAGEMENT ===

  /// Set navigation callback for when meeting ends
  void setOnMeetingEndedCallback(VoidCallback callback) {
    onMeetingEnded = callback;
  }

  /// Sync controller state from service changes
  void _syncStateFromService() {
    // Check if meeting has ended
    if (!_mediaService.isMeetingActive && _mediaService.currentMeetingId == null) {
      print('📱 Controller: Meeting has ended, triggering navigation callback');
      onMeetingEnded?.call();
      return;
    }

    notifyListeners();
  }

  // === MEDIA CONTROL METHODS ===

  /// Toggle microphone
  Future<void> toggleMicrophone() async {
    try {
      await _mediaService.toggleMicrophone();
      notifyListeners();
    } catch (e) {
      print('❌ Controller: Error toggling microphone: $e');
    }
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    try {
      print('📹 Controller: Toggle camera called, current state: $isCameraOn');
      await _mediaService.toggleCamera();

      // Check if renderer is healthy after toggle
      await Future.delayed(Duration(milliseconds: 500));

      if (!isRendererHealthy() && _mediaService.isCameraEnabled) {
        print('🔧 Controller: Renderer unhealthy after camera toggle, attempting recovery...');
        await recoverRenderer();
      }

      notifyListeners();
    } catch (e) {
      print('❌ Controller: Error in toggleCamera: $e');
      await recoverRenderer();
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    try {
      await _mediaService.switchCamera();
      await Future.delayed(Duration(milliseconds: 300));
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error switching camera: $e');
    }
  }

  /// Toggle screen sharing
  Future<void> toggleScreenSharing() async {
    try {
      await _mediaService.toggleScreenSharing();
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error toggling screen sharing: $e');
    }
  }

  /// Toggle hand raised
  Future<void> toggleHandRaised() async {
    try {
      await _mediaService.toggleHandRaised();
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error toggling hand raised: $e');
    }
  }

  // === UI PANEL CONTROL METHODS ===

  /// Toggle subtitles visibility
  void toggleSubtitlesVisibility() {
    _areSubtitlesVisible = !_areSubtitlesVisible;
    notifyListeners();
  }

  /// Toggle chat panel
  void toggleChat() {
    _isChatVisible = !_isChatVisible;

    // Close other panels when opening chat
    if (_isChatVisible) {
      _isParticipantsListVisible = false;
      _isLanguageMenuVisible = false;
    }

    notifyListeners();
  }

  /// Toggle participants list panel
  void toggleParticipantsList() {
    _isParticipantsListVisible = !_isParticipantsListVisible;

    // Close other panels when opening participants list
    if (_isParticipantsListVisible) {
      _isChatVisible = false;
      _isLanguageMenuVisible = false;
    }

    notifyListeners();
  }

  /// Toggle language selection menu
  void toggleLanguageMenu() {
    _isLanguageMenuVisible = !_isLanguageMenuVisible;

    // Close other panels when opening language menu
    if (_isLanguageMenuVisible) {
      _isChatVisible = false;
      _isParticipantsListVisible = false;
    }

    notifyListeners();
  }

  /// Close all panels
  void closePanels() {
    _isChatVisible = false;
    _isParticipantsListVisible = false;
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  /// Set selected language preference
  void setSelectedLanguage(String language) {
    // TODO: Implement language selection in service
    _isLanguageMenuVisible = false;
    notifyListeners();
  }

  // === SPEECH RECOGNITION METHODS (Placeholder) ===

  /// Toggle speech recognition
  Future<void> toggleSpeechRecognition() async {
    try {
      // TODO: Implement in service
      print('🎤 Enhanced Controller: Speech recognition toggle requested');
    } catch (e) {
      print('❌ Enhanced Controller: Error toggling speech recognition: $e');
    }
  }

  /// Start speech recognition
  Future<void> startSpeechRecognition() async {
    try {
      // TODO: Implement in service
      print('🎤 Enhanced Controller: Speech recognition start requested');
    } catch (e) {
      print('❌ Enhanced Controller: Error starting speech recognition: $e');
    }
  }

  /// Stop speech recognition
  Future<void> stopSpeechRecognition() async {
    try {
      // TODO: Implement in service
      print('🎤 Enhanced Controller: Speech recognition stop requested');
    } catch (e) {
      print('❌ Enhanced Controller: Error stopping speech recognition: $e');
    }
  }

  // === COMMUNICATION METHODS ===

  /// Send a chat message
  void sendMessage(String message) async {
    if (message.trim().isNotEmpty) {
      try {
        await _mediaService.sendMessage(message.trim());
      } catch (e) {
        print('❌ Enhanced Controller: Error sending message: $e');
      }
    }
  }

  // === VIDEO RENDERER METHODS ===

  /// Get video renderer for a specific participant
  dynamic getRendererForParticipant(String participantId) {
    try {
      return _mediaService.getRendererForParticipant(participantId);
    } catch (e) {
      print('❌ Enhanced Controller: Error getting renderer for participant $participantId: $e');
      return null;
    }
  }

  /// Check if participant has video
  bool participantHasVideo(String participantId) {
    try {
      return _mediaService.participantHasVideo(participantId);
    } catch (e) {
      print('❌ Enhanced Controller: Error checking video for participant $participantId: $e');
      return false;
    }
  }

  /// Check if renderer is healthy
  bool isRendererHealthy() {
    try {
      return _mediaService.isRendererHealthy();
    } catch (e) {
      print('❌ Enhanced Controller: Error checking renderer health: $e');
      return false;
    }
  }

  /// Recover renderer from errors
  Future<void> recoverRenderer() async {
    try {
      await _mediaService.recoverFromRendererError();
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error recovering renderer: $e');
    }
  }

  /// Refresh all participant video streams
  Future<void> refreshParticipantStreams() async {
    try {
      print('🔄 Enhanced Controller: Refreshing participant streams...');
      await _mediaService.refreshAllParticipantStreams();

      // Wait a bit for streams to be established
      await Future.delayed(Duration(milliseconds: 1000));
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error refreshing participant streams: $e');
    }
  }

  /// Force refresh of a specific participant's video
  Future<void> refreshParticipantVideo(String participantId) async {
    try {
      print('🔄 Enhanced Controller: Refreshing video for participant $participantId');
      await _mediaService.requestParticipantStream(participantId);

      await Future.delayed(Duration(milliseconds: 500));
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error refreshing video for participant $participantId: $e');
    }
  }

  // === MEETING CONTROL METHODS ===

  /// End call method (for host - ends meeting for everyone)
  Future<void> endCall() async {
    try {
      print('📱 Enhanced Controller: Ending call as host...');
      await _mediaService.endMeetingForAll();
      onMeetingEnded?.call();
    } catch (e) {
      print('❌ Enhanced Controller: Error ending call: $e');
      onMeetingEnded?.call();
    }
  }

  /// Leave call method (for participants)
  Future<void> leaveCall() async {
    try {
      print('📱 Enhanced Controller: Leaving call as participant...');
      await _mediaService.leaveMeetingAsParticipant();
      onMeetingEnded?.call();
    } catch (e) {
      print('❌ Enhanced Controller: Error leaving call: $e');
      onMeetingEnded?.call();
    }
  }

  /// Combined end/leave call method
  Future<void> endOrLeaveCall() async {
    if (isHost) {
      await endCall();
    } else {
      await leaveCall();
    }
  }

  /// Legacy method - updated to use new logic
  void leaveMeeting(BuildContext context) async {
    try {
      await endOrLeaveCall();
    } catch (e) {
      print('❌ Enhanced Controller: Error in leaveMeeting: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // === PARTICIPANT MANAGEMENT ===

  /// Get participant by ID
  ParticipantModel? getParticipantById(String participantId) {
    try {
      return participants.firstWhere((p) => p.id == participantId);
    } catch (e) {
      return null;
    }
  }

  /// Get current speaking participant
  ParticipantModel? getCurrentSpeakingParticipant() {
    try {
      return participants.firstWhere((p) => p.isSpeaking);
    } catch (e) {
      return null;
    }
  }

  /// Get local participant
  ParticipantModel? getLocalParticipant() {
    try {
      return participants.firstWhere((p) => p.id == _mediaService.currentUserId);
    } catch (e) {
      return null;
    }
  }

  /// Get main display participant (speaker or self)
  ParticipantModel getMainDisplayParticipant() {
    // Priority: Current speaker > Local user > Host > First participant
    final speaker = getCurrentSpeakingParticipant();
    if (speaker != null) return speaker;

    final localUser = participants.firstWhere(
          (p) => p.id == userId,
      orElse: () => participants.isNotEmpty ? participants.first :
      ParticipantModel(id: 'unknown', name: 'Unknown'),
    );

    return localUser;
  }

  /// Check if user is the only participant
  bool get isOnlyParticipant => participants.length <= 1;

  /// Check if participant is speaking
  bool isParticipantSpeaking(String participantId) {
    final participant = getParticipantById(participantId);
    return participant?.isSpeaking ?? false;
  }

  // === UTILITY METHODS ===

  /// Get meeting status with video info
  Map<String, dynamic> getMeetingStatus() {
    return {
      'meetingId': meetingCode,
      'isHost': isHost,
      'participantCount': participantCount,
      'isActive': isMeetingActive,
      'isConnectedToSFU': isConnectedToSFU,
      'elapsedTime': formattedElapsedTime,
      'micEnabled': isMicOn,
      'cameraEnabled': isCameraOn,
      'isListening': isListening,
      'videoStats': getParticipantVideoStats(),
      'rendererHealth': getAllRendererHealth(),
      'mainSpeaker': getCurrentSpeakingParticipant()?.name ?? 'None',
    };
  }

  /// Get participant video statistics
  Map<String, bool> getParticipantVideoStats() {
    final stats = <String, bool>{};
    for (var participant in participants) {
      stats[participant.id] = participantHasVideo(participant.id);
    }
    return stats;
  }

  /// Get renderer health status for all participants
  Map<String, bool> getAllRendererHealth() {
    final health = <String, bool>{};

    // Check local renderer
    health['local'] = isRendererHealthy();

    // Check participant renderers
    for (var participant in participants) {
      if (participant.id != userId) {
        health[participant.id] = participantHasVideo(participant.id);
      }
    }

    return health;
  }

  /// Get recent subtitles (last 3)
  List<SubtitleModel> get recentSubtitles {
    return subtitles.take(3).toList();
  }

  /// Get unread message count (placeholder)
  int get unreadMessageCount {
    // TODO: Implement unread message tracking
    return 0;
  }

  /// Get count of participants with video
  int get participantsWithVideoCount {
    return participants.where((p) => participantHasVideo(p.id)).length;
  }

  /// Get count of participants with audio
  int get participantsWithAudioCount {
    return participants.where((p) => !p.isMuted).length;
  }

  // === DEBUG METHODS ===

  /// Debug method to check all renderer states
  Future<void> debugAllRenderers() async {
    try {
      await _mediaService.debugAllParticipants();

      print('=== 📱 ENHANCED CONTROLLER DEBUG ===');
      for (var participant in participants) {
        final hasRenderer = getRendererForParticipant(participant.id) != null;
        final hasVideo = participantHasVideo(participant.id);
        print('📱 ${participant.name}: renderer=$hasRenderer, video=$hasVideo');
      }
      print('===============================');
    } catch (e) {
      print('❌ Enhanced Controller: Error in debug: $e');
    }
  }

  /// Test all video connections
  Future<void> testAllVideoConnections() async {
    try {
      print('🧪 Enhanced Controller: Testing all video connections...');

      // Test local video
      final localHealthy = isRendererHealthy();
      print('📹 Local video: ${localHealthy ? "OK" : "FAILED"}');

      // Test remote videos
      for (var participant in participants) {
        if (participant.id != userId) {
          final hasVideo = participantHasVideo(participant.id);
          print('📹 ${participant.name} video: ${hasVideo ? "OK" : "FAILED"}');

          if (!hasVideo) {
            // Try to refresh this participant's stream
            await refreshParticipantVideo(participant.id);
          }
        }
      }

      print('✅ Enhanced Controller: Video connection test completed');
    } catch (e) {
      print('❌ Enhanced Controller: Error testing video connections: $e');
    }
  }

  /// Emergency video recovery for all participants
  Future<void> emergencyVideoRecovery() async {
    try {
      print('🚨 Enhanced Controller: Starting emergency video recovery...');

      // Recover local video first
      await recoverRenderer();

      // Wait a bit
      await Future.delayed(Duration(milliseconds: 1000));

      // Refresh all participant streams
      await refreshParticipantStreams();

      // Wait for recovery
      await Future.delayed(Duration(milliseconds: 2000));

      print('✅ Enhanced Controller: Emergency video recovery completed');
      notifyListeners();
    } catch (e) {
      print('❌ Enhanced Controller: Error in emergency video recovery: $e');
    }
  }

  /// Test SFU connection
  Future<void> testSFUConnection() async {
    try {
      final isConnected = await _mediaService.testSFUConnection();
      print('🌐 Enhanced Controller: SFU connection test result: $isConnected');
    } catch (e) {
      print('❌ Enhanced Controller: Error testing SFU connection: $e');
    }
  }

  // === CLEANUP ===

  @override
  void dispose() {
    print('♻️ Controller: Disposing MeetingController...');
    _mediaService.removeListener(_syncStateFromService);
    super.dispose();
  }
}