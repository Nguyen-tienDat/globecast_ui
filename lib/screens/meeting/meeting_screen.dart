// lib/screens/meeting/meeting_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:provider/provider.dart';
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
  bool _isJoining = true;
  String? _errorMessage;

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
      _webrtcService.setUserDetails(displayName: 'User ${DateTime.now().millisecondsSinceEpoch % 1000}');

      // Join the meeting
      await _webrtcService.joinMeeting(meetingId: widget.code);

      setState(() {
        _isJoining = false;
      });
    } catch (e) {
      setState(() {
        _isJoining = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _leaveMeeting() async {
    try {
      await _webrtcService.leaveMeeting();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.home,
              (route) => false,
        );
      }
    } catch (e) {
      // Force navigation even if there's an error
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.home,
              (route) => false,
        );
      }
    }
  }

  void _showLeaveDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GcbAppTheme.surface,
          title: Text(
            _webrtcService.isHost ? 'End Meeting' : 'Leave Meeting',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            _webrtcService.isHost
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
                await _leaveMeeting();
              },
              child: Text(
                _webrtcService.isHost ? 'End Meeting' : 'Leave Meeting',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
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
                'Joining WebRTC Meeting...',
                style: TextStyle(color: Colors.grey[300], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting to mesh network',
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
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      Routes.home,
                          (route) => false,
                    );
                  },
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

    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, service, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: WillPopScope(
            onWillPop: () async {
              _showLeaveDialog();
              return false;
            },
            child: SafeArea(
              child: Column(
                children: [
                  // Top info bar
                  _buildInfoBar(service),

                  // Video area
                  Expanded(
                    child: _buildVideoArea(service),
                  ),

                  // Control panel
                  _buildControlBar(service),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBar(WebRTCMeshMeetingService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withOpacity(0.8),
      child: Row(
        children: [
          // Meeting ID
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.meeting_room, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Meeting: ${widget.code}',
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
                  '${service.participants.length}/6',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Mesh indicator
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.hub, color: Colors.green, size: 12),
                SizedBox(width: 4),
                Text(
                  'MESH',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(WebRTCMeshMeetingService service) {
    return Stack(
      children: [
        // Main video view (local user)
        Center(
          child: service.localRenderer != null
              ? Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RTCVideoView(service.localRenderer!),
            ),
          )
              : Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        ),

        // Participant thumbnails
        if (service.participants.length > 1)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildParticipantThumbnails(service),
          ),
      ],
    );
  }

  Widget _buildParticipantThumbnails(WebRTCMeshMeetingService service) {
    // Filter out local participant
    final remoteParticipants = service.participants
        .where((p) => p.id != service.userId)
        .toList();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: remoteParticipants.length,
        itemBuilder: (context, index) {
          final participant = remoteParticipants[index];
          final renderer = service.getRendererForParticipant(participant.id);

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: participant.isAudioEnabled ? Colors.green : Colors.red,
                width: 2,
              ),
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
                      : const Center(
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                // Name and status
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                          color: participant.isAudioEnabled ? Colors.white : Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
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
                        if (participant.isHost)
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 12,
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

  Widget _buildControlBar(WebRTCMeshMeetingService service) {
    return Container(
      color: GcbAppTheme.background,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: service.isAudioEnabled ? 'Mute' : 'Unmute',
            isActive: service.isAudioEnabled,
            onPressed: service.toggleAudio,
          ),
          _buildControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: service.isVideoEnabled ? 'Camera On' : 'Camera Off',
            isActive: service.isVideoEnabled,
            onPressed: service.toggleVideo,
          ),
          _buildEndCallButton(),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.transparent : Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? Colors.white : Colors.red,
              size: 24,
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

  Widget _buildEndCallButton() {
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
            onPressed: _showLeaveDialog,
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
}