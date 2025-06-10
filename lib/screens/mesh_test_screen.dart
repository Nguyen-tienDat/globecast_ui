// lib/screens/mesh_test_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_mesh_meeting_service.dart';

class MeshTestScreen extends StatefulWidget {
  const MeshTestScreen({Key? key}) : super(key: key);

  @override
  State<MeshTestScreen> createState() => _MeshTestScreenState();
}

class _MeshTestScreenState extends State<MeshTestScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _meetingIdController = TextEditingController();

  late WebRTCMeshMeetingService _meshService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _meshService =
        Provider.of<WebRTCMeshMeetingService>(context, listen: false);
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _meshService.initialize();
      print('Mesh service initialized');
    } catch (e) {
      print('Error initializing mesh service: $e');
      _showErrorDialog('Failed to initialize service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Mesh Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<WebRTCMeshMeetingService>(
        builder: (context, service, child) {
          if (!service.isMeetingActive) {
            return _buildJoinCreateInterface();
          } else {
            return _buildMeetingInterface(service);
          }
        },
      ),
    );
  }

  Widget _buildJoinCreateInterface() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'WebRTC Mesh Topology Test',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Display Name Input
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),

          // Create Meeting Section
          const Divider(),
          const Text(
            'Create New Meeting',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Meeting Topic',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.topic),
            ),
          ),
          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _isLoading ? null : _createMeeting,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Create Meeting'),
          ),

          // Join Meeting Section
          const SizedBox(height: 20),
          const Divider(),
          const Text(
            'Join Existing Meeting',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _meetingIdController,
            decoration: const InputDecoration(
              labelText: 'Meeting ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.meeting_room),
            ),
          ),
          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _isLoading ? null : _joinMeeting,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Join Meeting'),
          ),

          const SizedBox(height: 30),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('1. Enter your name'),
                const Text('2. Create a new meeting or join existing one'),
                const Text('3. Share Meeting ID with others to join'),
                const Text('4. Maximum 6 participants (Mesh topology limit)'),
                const SizedBox(height: 8),
                Text(
                  'Note: Each participant connects directly to all others',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingInterface(WebRTCMeshMeetingService service) {
    return Column(
      children: [
        // Meeting Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting ID: ${service.meetingId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Participants: ${service.participants.length}/6',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _copyMeetingId,
                icon: const Icon(Icons.copy, color: Colors.white),
                tooltip: 'Copy Meeting ID',
              ),
            ],
          ),
        ),

        // Video Grid
        Expanded(
          child: _buildVideoGrid(service),
        ),

        // Control Bar
        _buildControlBar(service),
      ],
    );
  }

  Widget _buildVideoGrid(WebRTCMeshMeetingService service) {
    final participants = service.participants;

    if (participants.isEmpty) {
      return const Center(
        child: Text('No participants yet...'),
      );
    }

    // Calculate grid layout
    int crossAxisCount = _calculateGridColumns(participants.length);

    return Container(
      color: Colors.black,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return _buildParticipantVideo(participant, service);
        },
      ),
    );
  }

  Widget _buildParticipantVideo(MeshParticipant participant,
      WebRTCMeshMeetingService service) {
    final renderer = service.getRendererForParticipant(participant.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: participant.isLocal ? Colors.blue : Colors.grey,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // Video Stream
            if (renderer != null && participant.isVideoEnabled)
              RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Container(
                color: Colors.grey[800],
                child: Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: Text(
                      participant.name.isNotEmpty ? participant.name[0]
                          .toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Participant Info Overlay
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audio Status
                    Icon(
                      participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                      color: participant.isAudioEnabled ? Colors.white : Colors
                          .red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),

                    // Participant Name
                    Expanded(
                      child: Text(
                        participant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Host Badge
                    if (participant.isHost)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(2),
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

            // Video Off Indicator
            if (!participant.isVideoEnabled)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.videocam_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(WebRTCMeshMeetingService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Toggle Audio
          _buildControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Audio',
            isActive: service.isAudioEnabled,
            onPressed: service.toggleAudio,
            activeColor: Colors.green,
            inactiveColor: Colors.red,
          ),

          // Toggle Video
          _buildControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Video',
            isActive: service.isVideoEnabled,
            onPressed: service.toggleVideo,
            activeColor: Colors.green,
            inactiveColor: Colors.red,
          ),

          // Leave Meeting
          _buildControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: false,
            onPressed: _leaveMeeting,
            activeColor: Colors.red,
            inactiveColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final color = isActive ? activeColor : inactiveColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _calculateGridColumns(int participantCount) {
    if (participantCount <= 1) return 1;
    if (participantCount <= 4) return 2;
    return 3; // For 5-6 participants
  }

  Future<void> _createMeeting() async {
    if (_nameController.text
        .trim()
        .isEmpty) {
      _showErrorDialog('Please enter your name');
      return;
    }

    if (_topicController.text
        .trim()
        .isEmpty) {
      _showErrorDialog('Please enter meeting topic');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _meshService.setUserDetails(displayName: _nameController.text.trim());

      final meetingId = await _meshService.createMeeting(
        topic: _topicController.text.trim(),
      );

      _showSuccessDialog(
          'Meeting created successfully!\nMeeting ID: $meetingId');
    } catch (e) {
      _showErrorDialog('Failed to create meeting: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinMeeting() async {
    if (_nameController.text
        .trim()
        .isEmpty) {
      _showErrorDialog('Please enter your name');
      return;
    }

    if (_meetingIdController.text
        .trim()
        .isEmpty) {
      _showErrorDialog('Please enter meeting ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _meshService.setUserDetails(displayName: _nameController.text.trim());

      await _meshService.joinMeeting(
        meetingId: _meetingIdController.text.trim(),
      );

      _showSuccessDialog('Joined meeting successfully!');
    } catch (e) {
      _showErrorDialog('Failed to join meeting: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveMeeting() async {
    final confirmed = await _showConfirmDialog(
      'Leave Meeting',
      'Are you sure you want to leave the meeting?',
    );

    if (confirmed) {
      try {
        await _meshService.leaveMeeting();
        _showSuccessDialog('Left meeting successfully');
      } catch (e) {
        _showErrorDialog('Error leaving meeting: $e');
      }
    }
  }

  void _copyMeetingId() {
    if (_meshService.meetingId != null) {
      // Copy to clipboard (you'll need to add clipboard package)
      // Clipboard.setData(ClipboardData(text: _meshService.meetingId!));
      _showSuccessDialog('Meeting ID copied to clipboard');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Success'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _meetingIdController.dispose();
    super.dispose();
  }
}