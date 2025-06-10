// lib/screens/test/webrtc_group_test_screen.dart - FIXED VIDEO DISPLAY
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../services/meeting_service.dart';

import '../../theme/app_theme.dart';

class WebRTCGroupTestScreen extends StatefulWidget {
  const WebRTCGroupTestScreen({super.key});

  @override
  State<WebRTCGroupTestScreen> createState() => _WebRTCGroupTestScreenState();
}

class _WebRTCGroupTestScreenState extends State<WebRTCGroupTestScreen> {
  final _meetingIdController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _chatController = TextEditingController();

  bool _isCreating = false;
  bool _isJoining = false;
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = 'User ${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    _displayNameController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    if (_displayNameController.text.trim().isEmpty) {
      _showMessage('Please enter your name');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final service = Provider.of<GcbMeetingService>(context, listen: false);
      service.setUserDetails(displayName: _displayNameController.text.trim());

      final meetingId = await service.createMeeting(
        topic: 'Group Test Meeting',
        password: null,
      );

      _meetingIdController.text = meetingId;
      _showMessage('Meeting created! ID: $meetingId');

    } catch (e) {
      _showMessage('Failed to create: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _joinMeeting() async {
    if (_meetingIdController.text.trim().isEmpty) {
      _showMessage('Enter meeting ID');
      return;
    }

    if (_displayNameController.text.trim().isEmpty) {
      _showMessage('Enter your name');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final service = Provider.of<GcbMeetingService>(context, listen: false);
      service.setUserDetails(displayName: _displayNameController.text.trim());

      await service.joinMeeting(meetingId: _meetingIdController.text.trim());
      _showMessage('Joined successfully!');

    } catch (e) {
      _showMessage('Failed to join: $e');
    } finally {
      setState(() => _isJoining = false);
    }
  }

  Future<void> _leaveMeeting() async {
    try {
      final service = Provider.of<GcbMeetingService>(context, listen: false);

      if (service.isHost) {
        await service.endMeetingForAll();
      } else {
        await service.leaveMeetingAsParticipant();
      }

      setState(() => _showChat = false);
      _showMessage('Left meeting');

    } catch (e) {
      _showMessage('Error: $e');
    }
  }

  void _copyMeetingId() {
    if (_meetingIdController.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _meetingIdController.text));
      _showMessage('Meeting ID copied!');
    }
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;

    final service = Provider.of<GcbMeetingService>(context, listen: false);
    service.sendMessage(_chatController.text.trim());
    _chatController.clear();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'WebRTC Group Test',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          Consumer<GcbMeetingService>(
            builder: (context, service, child) {
              if (!service.isMeetingActive) return const SizedBox();

              return IconButton(
                icon: Icon(
                  _showChat ? Icons.videocam : Icons.chat,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _showChat = !_showChat),
              );
            },
          ),
        ],
      ),
      body: Consumer<GcbMeetingService>(
        builder: (context, service, child) {
          if (!service.isMeetingActive) {
            return _buildLobby(service);
          }

          return _showChat ? _buildChatView(service) : _buildMeetingView(service);
        },
      ),
    );
  }

  Widget _buildLobby(GcbMeetingService service) {
    return Container(
      color: GcbAppTheme.background,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.video_call, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'WebRTC Group Test',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          Card(
            color: GcbAppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _displayNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Your Name',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.person, color: Colors.grey),
                      filled: true,
                      fillColor: GcbAppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _meetingIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Meeting ID',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.meeting_room, color: Colors.grey),
                      suffixIcon: _meetingIdController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.copy, color: Colors.grey),
                        onPressed: _copyMeetingId,
                      )
                          : null,
                      filled: true,
                      fillColor: GcbAppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isCreating ? null : _createMeeting,
                          icon: _isCreating
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.add),
                          label: const Text('Create'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isJoining ? null : _joinMeeting,
                          icon: _isJoining
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.login),
                          label: const Text('Join'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          Card(
            color: GcbAppTheme.surfaceLight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Instructions:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Create meeting on Device 1\n'
                        '2. Copy meeting ID\n'
                        '3. Join from Device 2 with same ID\n'
                        '4. Both should see video feeds',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${service.isMeetingActive ? "In Meeting" : "Ready"}',
                    style: TextStyle(
                      color: service.isMeetingActive ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingView(GcbMeetingService service) {
    return Column(
      children: [
        // Meeting Info Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            children: [
              Icon(
                service.isHost ? Icons.star : Icons.person,
                color: service.isHost ? Colors.orange : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting: ${service.meetingId ?? "Unknown"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${service.isHost ? "Host" : "Participant"} • ${service.participants.length} participants • ${_formatDuration(service.elapsedTime)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.grey, size: 20),
                onPressed: _copyMeetingId,
              ),
            ],
          ),
        ),

        // Video Area - FIXED
        Expanded(
          child: Container(
            color: Colors.black,
            child: _buildVideoGrid(service),
          ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: _getLocalParticipant(service)?.isMuted == true ? Icons.mic_off : Icons.mic,
                label: 'Mic',
                isActive: _getLocalParticipant(service)?.isMuted != true,
                onPressed: service.toggleMicrophone,
              ),
              _buildControlButton(
                icon: Icons.videocam,
                label: 'Camera',
                isActive: true,
                onPressed: service.toggleCamera,
              ),
              _buildControlButton(
                icon: Icons.screen_share,
                label: 'Share',
                isActive: true,
                isHighlighted: _getLocalParticipant(service)?.isScreenSharing == true,
                onPressed: service.toggleScreenSharing,
              ),
              _buildControlButton(
                icon: Icons.back_hand,
                label: 'Hand',
                isActive: true,
                isHighlighted: _getLocalParticipant(service)?.isHandRaised == true,
                onPressed: service.toggleHandRaised,
              ),
              _buildControlButton(
                icon: Icons.call_end,
                label: 'Leave',
                isActive: true,
                color: Colors.red,
                onPressed: _leaveMeeting,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // FIXED: Video Grid Display
  Widget _buildVideoGrid(GcbMeetingService service) {
    final participants = service.participants;

    if (participants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No participants', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Single participant (self only)
    if (participants.length == 1) {
      return _buildSingleVideoView(service, participants[0]);
    }

    // Multiple participants - Grid layout
    return _buildMultiVideoGrid(service, participants);
  }

  Widget _buildSingleVideoView(GcbMeetingService service, ParticipantModel participant) {
    final renderer = service.getRendererForParticipant(participant.id);

    return Stack(
      children: [
        // Main video view
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: renderer != null
                ? RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: participant.id == service.userId, // Mirror local video
            )
                : _buildVideoPlaceholder(participant),
          ),
        ),

        // Participant info overlay
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  participant.isMuted ? Icons.mic_off : Icons.mic,
                  size: 16,
                  color: participant.isMuted ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  participant.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                if (participant.isHost) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 12, color: Colors.orange),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiVideoGrid(GcbMeetingService service, List<ParticipantModel> participants) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: participants.length > 4 ? 3 : 2,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final renderer = service.getRendererForParticipant(participant.id);

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: participant.isSpeaking ? Colors.green : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Video
                Positioned.fill(
                  child: renderer != null
                      ? RTCVideoView(
                    renderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: participant.id == service.userId,
                  )
                      : _buildVideoPlaceholder(participant),
                ),

                // Participant name and status
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          participant.isMuted ? Icons.mic_off : Icons.mic,
                          size: 12,
                          color: participant.isMuted ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            participant.name,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (participant.isHost)
                          const Icon(Icons.star, size: 10, color: Colors.orange),
                        if (participant.isHandRaised)
                          const Icon(Icons.back_hand, size: 10, color: Colors.orange),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoPlaceholder(ParticipantModel participant) {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue,
            child: Text(
              participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            participant.name,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Camera off',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(GcbMeetingService service) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            children: [
              const Icon(Icons.chat, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Meeting Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Text('${service.messages.length} messages', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.messages.length,
            itemBuilder: (context, index) {
              final message = service.messages[index];
              return _buildMessageTile(message);
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Colors.blue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isHighlighted = false,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.blue.withOpacity(0.3)
                : (color ?? (isActive ? Colors.transparent : Colors.red.withOpacity(0.3))),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: color ?? (isActive ? Colors.white : Colors.red),
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildMessageTile(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue,
            child: Text(
              message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(message.text, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ParticipantModel? _getLocalParticipant(GcbMeetingService service) {
    try {
      return service.participants.firstWhere((p) => p.id == service.userId);
    } catch (e) {
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}