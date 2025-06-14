// lib/screens/meeting/meeting_screen.dart - PROVIDER FIX
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/screens/meeting/controller.dart';
import 'package:globecast_ui/screens/meeting/widgets/chat_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/participants_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/language_selection_panel.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import '../../router/app_router.dart';

class MeetingScreen extends StatefulWidget {
  final String code;

  const MeetingScreen({
    super.key,
    required this.code,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> with WidgetsBindingObserver {
  bool _isJoining = true;
  String? _errorMessage;
  bool _isSubtitlesMinimized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Join meeting after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinMeeting();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        print('📱 Meeting paused - maintaining connections');
        break;
      case AppLifecycleState.resumed:
        print('📱 Meeting resumed - checking connections');
        _checkConnectionStatus();
        break;
      case AppLifecycleState.detached:
        print('📱 Meeting detached - cleaning up');
        _leaveMeetingQuietly();
        break;
      default:
        break;
    }
  }

  void _checkConnectionStatus() {
    try {
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
      if (webrtcService.isMeetingActive) {
        print('🔄 Meeting still active after resume');
      }
    } catch (e) {
      print('⚠️ Error checking connection status: $e');
    }
  }

  Future<void> _joinMeeting() async {
    try {
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      // Get WebRTC service from context
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);

      print('📱 Got WebRTC service, checking initialization...');

      // Ensure service is initialized
      if (webrtcService.userId == null || webrtcService.userId!.isEmpty) {
        print('🔧 Setting user details...');
        webrtcService.setUserDetails(
          displayName: 'User ${DateTime.now().millisecondsSinceEpoch % 1000}',
        );
      }

      print('🚪 Joining meeting with ID: ${widget.code}');

      // Join the meeting
      await webrtcService.joinMeeting(meetingId: widget.code);

      if (mounted) {
        setState(() {
          _isJoining = false;
        });
        print('✅ Successfully joined meeting');
      }
    } catch (e) {
      print('❌ Error joining meeting: $e');
      if (mounted) {
        setState(() {
          _isJoining = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _leaveMeetingQuietly() async {
    try {
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
      await webrtcService.leaveMeeting();
    } catch (e) {
      print('⚠️ Error leaving meeting quietly: $e');
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.home,
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isJoining) {
      return _buildLoadingScreen();
    }

    // Error state
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    // Main meeting screen - NO NEW PROVIDER HERE!
    // Just consume the existing one and create controller
    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, webrtcService, child) {
        return ChangeNotifierProvider<MeetingController>(
          create: (_) {
            print('🎮 Creating MeetingController...');
            final controller = MeetingController(webrtcService);
            controller.setOnMeetingEndedCallback(_navigateToHome);
            return controller;
          },
          child: _MeetingContent(
            meetingCode: widget.code,
            onToggleSubtitleMinimize: () {
              setState(() {
                _isSubtitlesMinimized = !_isSubtitlesMinimized;
              });
            },
            isSubtitlesMinimized: _isSubtitlesMinimized,
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loading spinner
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: GcbAppTheme.primary,
                  strokeWidth: 4,
                ),
              ),

              const SizedBox(height: 24),

              // Loading text
              Text(
                'Joining Meeting...',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Connecting to mesh network',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Meeting ID: ${widget.code}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 40,
                ),
              ),

              const SizedBox(height: 24),

              // Error title
              const Text(
                'Failed to Join Meeting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Error message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Column(
                children: [
                  // Retry button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _joinMeeting();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GcbAppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'Try Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Back to home button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _navigateToHome,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[600]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(Icons.home, color: Colors.grey[400]),
                      label: Text(
                        'Back to Home',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingContent extends StatelessWidget {
  final String meetingCode;
  final VoidCallback onToggleSubtitleMinimize;
  final bool isSubtitlesMinimized;

  const _MeetingContent({
    required this.meetingCode,
    required this.onToggleSubtitleMinimize,
    required this.isSubtitlesMinimized,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingController>(
      builder: (context, controller, child) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) {
              _showEndCallDialog(context, controller);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  // Main content
                  Column(
                    children: [
                      // Top info bar
                      _buildInfoBar(context, controller, meetingCode),

                      // Video area
                      Expanded(
                        child: _buildVideoArea(context, controller),
                      ),

                      // Subtitle area - Simple placeholder for now
                      if (controller.areSubtitlesVisible)
                        _buildSubtitleArea(context, controller),

                      // Control panel
                      _buildControlBar(context, controller),
                    ],
                  ),

                  // Side panels
                  _buildSidePanels(context, controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBar(BuildContext context, MeetingController controller, String meetingCode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Meeting ID
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: GcbAppTheme.primary.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room, color: GcbAppTheme.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        meetingCode,
                        style: const TextStyle(
                          color: GcbAppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: controller.isMeetingActive
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.isMeetingActive ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  controller.isMeetingActive ? 'Connected' : 'Connecting',
                  style: TextStyle(
                    color: controller.isMeetingActive ? Colors.green : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Participants count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${controller.participantCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(BuildContext context, MeetingController controller) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main video area (placeholder for now)
          Center(
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[700]!,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_outlined,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video Preview',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Participants thumbnails at bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildParticipantThumbnails(context, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantThumbnails(BuildContext context, MeetingController controller) {
    if (controller.participants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: controller.participants.length,
        itemBuilder: (context, index) {
          final participant = controller.participants[index];

          return Container(
            width: 120,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border.all(
                color: participant.isAudioEnabled
                    ? Colors.green.withOpacity(0.8)
                    : Colors.red.withOpacity(0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Video preview placeholder
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: GcbAppTheme.primary,
                        child: Text(
                          participant.name.isNotEmpty
                              ? participant.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Name and status at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Audio status icon
                        Icon(
                          participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                          color: participant.isAudioEnabled ? Colors.white : Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        // Name
                        Expanded(
                          child: Text(
                            participant.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Host indicator
                        if (participant.isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: GcbAppTheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HOST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubtitleArea(BuildContext context, MeetingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.black,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          border: Border.all(color: Colors.green, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Text(
                controller.participants.isNotEmpty ? controller.participants.first.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Speaking...',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Real-time transcription will appear here',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, MeetingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.background,
        border: Border(
          top: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: controller.isMicOn ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: controller.isMicOn,
            onPressed: controller.toggleMicrophone,
          ),
          _buildControlButton(
            icon: controller.isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: controller.isCameraOn,
            onPressed: controller.toggleCamera,
          ),
          _buildControlButton(
            icon: Icons.closed_caption,
            label: 'Subtitles',
            isActive: controller.areSubtitlesVisible,
            onPressed: controller.toggleSubtitlesVisibility,
          ),
          _buildControlButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            isActive: true,
            isHighlighted: controller.isChatVisible,
            onPressed: controller.toggleChat,
          ),
          _buildControlButton(
            icon: Icons.people_outline,
            label: 'People',
            isActive: true,
            isHighlighted: controller.isParticipantsListVisible,
            onPressed: controller.toggleParticipantsList,
          ),
          _buildEndCallButton(context, controller),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isHighlighted = false,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isHighlighted
                ? GcbAppTheme.primary.withOpacity(0.3)
                : isActive
                ? Colors.grey[800]
                : Colors.red.withOpacity(0.3),
            shape: BoxShape.circle,
            border: isHighlighted
                ? Border.all(color: GcbAppTheme.primary, width: 2)
                : null,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isHighlighted
                  ? GcbAppTheme.primary
                  : isActive
                  ? Colors.white
                  : Colors.red,
              size: 24,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? GcbAppTheme.primary : Colors.white,
            fontSize: 11,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildEndCallButton(BuildContext context, MeetingController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () => _showEndCallDialog(context, controller),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'End',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSidePanels(BuildContext context, MeetingController controller) {
    return Stack(
      children: [
        // Chat panel
        if (controller.isChatVisible)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: const ChatPanel(),
            ),
          ),

        // Participants panel
        if (controller.isParticipantsListVisible)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: const ParticipantsPanel(),
            ),
          ),

        // Language panel
        if (controller.isLanguageMenuVisible)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.35,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: LanguageSelectionPanel(),
            ),
          ),
      ],
    );
  }

  void _showEndCallDialog(BuildContext context, MeetingController controller) {
    final isHost = controller.isHost;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GcbAppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isHost ? Icons.meeting_room_outlined : Icons.exit_to_app,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isHost ? 'End Meeting' : 'Leave Meeting',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            isHost
                ? 'Are you sure you want to end this meeting for everyone?'
                : 'Are you sure you want to leave this meeting?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.endOrLeaveCall();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isHost ? 'End Meeting' : 'Leave Meeting',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}