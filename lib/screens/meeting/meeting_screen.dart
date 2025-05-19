import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:globecast_ui/services/meeting_service.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/screens/meeting/controller.dart';
import 'package:globecast_ui/screens/meeting/widgets/chat_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/participants_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/language_selection_panel.dart';
import 'package:globecast_ui/theme/app_theme.dart';

@RoutePage()
class MeetingScreen extends StatelessWidget {
  final String code;

  const MeetingScreen({
    super.key,
    @PathParam('code') required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final meetingService = Provider.of<GcbMeetingService>(context, listen: false);

    // Join meeting when screen is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinMeeting(context, meetingService, code);
    });

    return ChangeNotifierProvider(
      create: (context) => MeetingController(meetingService),
      child: _MeetingContent(meetingCode: code),
    );
  }

  // Helper method to join meeting
  Future<void> _joinMeeting(BuildContext context, GcbMeetingService service, String code, [String? password]) async {
    try {
      // Set default user details if not already set
      service.setUserDetails(displayName: 'User');

      // Set default language preferences
      service.setLanguagePreferences(speaking: 'english', listening: 'english');

      // Join the meeting
      await service.joinMeeting(meetingId: code, password: password);
    } catch (e) {
      // Show error dialog and navigate back
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Error Joining Meeting'),
          content: Text('Failed to join meeting: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

class _MeetingContent extends StatelessWidget {
  final String meetingCode;

  const _MeetingContent({required this.meetingCode});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MeetingController>();

    // UI code for meeting screen
    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          _showLeaveMeetingDialog(context);
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
                    _buildSubtitleArea(context, controller),

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

  // Add missing method implementations
  Widget _buildInfoBar(BuildContext context, MeetingController controller, String meetingCode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          // Meeting duration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${controller.elapsedTime.inMinutes.toString().padLeft(2, '0')}:${(controller.elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

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
                  '${controller.participants.length}',
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
              Icons.play_circle_outline,
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
          final bool isHighlighted = participant.isSpeaking;
          final renderer = controller.getRendererForParticipant(participant.id);

          return Container(
            width: 120,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border.all(
                color: isHighlighted ? Colors.green : Colors.transparent,
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
                          participant.isMuted ? Icons.mic_off : Icons.mic,
                          color: participant.isMuted ? Colors.red : Colors.white,
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
  Widget _buildSubtitleArea(BuildContext context, MeetingController controller) {
    // Get first subtitle if available
    final subtitle = controller.subtitles.isNotEmpty
        ? controller.subtitles.first
        : null;

    if (subtitle == null) return const SizedBox.shrink();

    // Find speaking participant
    final speakingParticipant = controller.participants
        .firstWhere((p) => p.isSpeaking, orElse: () => controller.participants.first);

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
                speakingParticipant.name.isNotEmpty ? speakingParticipant.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speakingParticipant.name,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.text,
                    style: const TextStyle(
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
            icon: Icons.present_to_all,
            label: controller.isScreenSharing ? 'Stop Sharing' : 'Share Screen',
            isActive: true,
            isHighlighted: controller.isScreenSharing,
            onPressed: controller.toggleScreenSharing,
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
          _buildControlButton(
            icon: Icons.back_hand,
            label: 'Raise Hand',
            isActive: true,
            isHighlighted: controller.isHandRaised,
            onPressed: controller.toggleHandRaised,
          ),
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

  void _showLeaveMeetingDialog(BuildContext context) {
    final controller = Provider.of<MeetingController>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GcbAppTheme.surface,
          title: const Text(
            'Leave Meeting',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to leave this meeting?',
            style: TextStyle(color: Colors.white),
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
              onPressed: () {
                Navigator.of(context).pop();
                context.router.pop();
              },
              child: const Text(
                'Leave Meeting',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}