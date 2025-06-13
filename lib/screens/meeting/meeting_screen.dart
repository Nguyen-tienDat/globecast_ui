// lib/screens/meeting/meeting_screen.dart (UPDATED)
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/whisper_service.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/screens/meeting/controller.dart';
import 'package:globecast_ui/screens/meeting/widgets/chat_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/participants_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/language_selection_panel.dart';
import 'package:globecast_ui/widgets/subtitle_display_widget.dart';
import 'package:globecast_ui/screens/meeting/language_selection_screen.dart';
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

class _MeetingScreenState extends State<MeetingScreen> {
  late WebRTCMeshMeetingService _webrtcService;
  WhisperService? _whisperService;
  bool _isJoining = true;
  String? _errorMessage;
  bool _hasSetupLanguages = false;

  @override
  void initState() {
    super.initState();
    _webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
    _joinMeeting();
  }

  Future<void> _joinMeeting() async {
    try {
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      // Set default user details if not already set
      _webrtcService.setUserDetails(
        displayName: 'User ${DateTime.now().millisecondsSinceEpoch % 1000}',
        nativeLanguage: 'en',
        displayLanguage: 'en',
      );

      // Join the meeting
      await _webrtcService.joinMeeting(meetingId: widget.code);

      // Get Whisper service reference
      _whisperService = _webrtcService.whisperService;

      setState(() {
        _isJoining = false;
      });

      // Show language selection if user hasn't set languages yet
      if (!_hasSetupLanguages) {
        _showLanguageSetup();
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showLanguageSetup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              LanguageSelectionScreen(
                meetingId: widget.code,
                onLanguagesSelected: () {
                  setState(() {
                    _hasSetupLanguages = true;
                  });
                },
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );
    });
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
    if (_isJoining) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Joining Meeting...',
                style: TextStyle(color: Colors.grey[300], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Setting up real-time translation',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to Join Meeting',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.grey[300]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _navigateToHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Only provide MeetingController, WhisperService is accessed through WebRTC service
    return ChangeNotifierProvider(
      create: (context) {
        final controller = MeetingController(_webrtcService);
        controller.setOnMeetingEndedCallback(_navigateToHome);
        return controller;
      },
      child: _MeetingContent(meetingCode: widget.code),
    );
  }
}

class _MeetingContent extends StatelessWidget {
  final String meetingCode;

  const _MeetingContent({required this.meetingCode});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MeetingController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          _showEndCallDialog(context, controller);
          return false;
        },
        child: SafeArea(
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

                  // Subtitle area
                  if (controller.areSubtitlesVisible)
                    _buildSubtitleArea(context),

                  // Control panel
                  _buildControlBar(context, controller),
                ],
              ),

              // Side panels
              if (controller.isChatVisible)
                Positioned(
                  top: 56,
                  right: 0,
                  bottom: 80,
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: const ChatPanel(),
                ),

              if (controller.isParticipantsListVisible)
                Positioned(
                  top: 56,
                  right: 0,
                  bottom: 80,
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: const ParticipantsPanel(),
                ),

              if (controller.isLanguageMenuVisible)
                Positioned(
                  top: 56,
                  right: 0,
                  bottom: 80,
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: LanguageSelectionPanel(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBar(BuildContext context, MeetingController controller, String meetingCode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          // Meeting ID
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.meeting_room, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  meetingCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Translation status
          Consumer<WhisperService>(
            builder: (context, whisperService, child) {
              if (whisperService.isConnected) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate,
                        color: Colors.green,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Live Translation',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Connecting...',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),

          const SizedBox(width: 8),

          // Participants count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${controller.participantCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
    return Stack(
      children: [
        // Centered video area or placeholder when no video
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.videocam,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),

        // Thumbnails row at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildParticipantThumbnails(context, controller),
        ),
      ],
    );
  }

  Widget _buildParticipantThumbnails(BuildContext context, MeetingController controller) {
    return Container(
      height: 80,
      color: Colors.black.withOpacity(0.5),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.participants.length,
        itemBuilder: (context, index) {
          final participant = controller.participants[index];
          final renderer = controller.getRendererForParticipant(participant.id);

          return Container(
            width: 120,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border.all(
                color: participant.isAudioEnabled ? Colors.green : Colors.red,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Video preview
                Positioned.fill(
                  child: renderer != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: RTCVideoView(renderer),
                  )
                      : Center(
                    child: Icon(
                      Icons.person,
                      color: Colors.white.withOpacity(0.5),
                      size: 32,
                    ),
                  ),
                ),

                // Language indicator
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      participant.nativeLanguage.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Name at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.black.withOpacity(0.7),
                    child: Row(
                      children: [
                        // Mic icon
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
                            ),
                            overflow: TextOverflow.ellipsis,
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

  Widget _buildSubtitleArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SubtitleDisplayWidget(
        isVisible: true,
        maxHeight: 120,
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, MeetingController controller) {
    return Container(
      color: GcbAppTheme.background,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: controller.isMicOn ? Icons.mic : Icons.mic_off,
            label: controller.isMicOn ? 'Mute' : 'Unmute',
            isActive: controller.isMicOn,
            onPressed: controller.toggleMicrophone,
          ),
          _buildControlButton(
            icon: controller.isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: controller.isCameraOn ? 'Camera On' : 'Camera Off',
            isActive: controller.isCameraOn,
            onPressed: controller.toggleCamera,
          ),
          _buildControlButton(
            icon: Icons.closed_caption,
            label: controller.areSubtitlesVisible ? 'Hide Subtitles' : 'Show Subtitles',
            isActive: true,
            isHighlighted: controller.areSubtitlesVisible,
            onPressed: controller.toggleSubtitlesVisibility,
          ),
          _buildControlButton(
            icon: Icons.translate,
            label: 'Language',
            isActive: true,
            isHighlighted: controller.isLanguageMenuVisible,
            onPressed: () => _showLanguageDialog(context),
          ),
          _buildControlButton(
            icon: Icons.chat,
            label: 'Chat',
            isActive: true,
            isHighlighted: controller.isChatVisible,
            onPressed: controller.toggleChat,
          ),
          _buildControlButton(
            icon: Icons.people,
            label: 'Participants',
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
          decoration: BoxDecoration(
            color: isHighlighted
                ? GcbAppTheme.primary.withOpacity(0.2)
                : isActive
                ? Colors.transparent
                : Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isHighlighted
                  ? GcbAppTheme.primary
                  : isActive
                  ? Colors.white
                  : Colors.red,
              size: 20,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
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
        const SizedBox(height: 4),
        const Text(
          'End Call',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        currentNativeLanguage: webrtcService.userNativeLanguage,
        currentDisplayLanguage: webrtcService.userDisplayLanguage,
        onLanguagesChanged: (nativeLanguage, displayLanguage) async {
          await webrtcService.updateLanguageSettings(
            nativeLanguage: nativeLanguage,
            displayLanguage: displayLanguage,
          );

          // Show confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Languages updated! Speaking: $nativeLanguage, Viewing: $displayLanguage',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
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
          title: Text(
            isHost ? 'End Meeting' : 'Leave Meeting',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            isHost
                ? 'Are you sure you want to end this meeting for everyone?'
                : 'Are you sure you want to leave this meeting?',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.endOrLeaveCall();
              },
              child: Text(
                isHost ? 'End Meeting' : 'Leave Meeting',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}