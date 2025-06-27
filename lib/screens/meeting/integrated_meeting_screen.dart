// lib/screens/meeting/integrated_meeting_screen.dart - COMPLETE FIXED
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/translation_message.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../../services/meeting_coordinator_service.dart';
import '../../services/multilingual_speech_service.dart';
import '../../theme/app_theme.dart';

class IntegratedMeetingScreen extends StatefulWidget {
  final String code;
  final String? displayName;
  final String? targetLanguage;

  const IntegratedMeetingScreen({
    super.key,
    required this.code,
    this.displayName,
    this.targetLanguage,
  });

  @override
  State<IntegratedMeetingScreen> createState() => _IntegratedMeetingScreenState();
}

class _IntegratedMeetingScreenState extends State<IntegratedMeetingScreen> {
  bool _isJoining = true;
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isTranslationEnabled = true;
  String _translationStatus = 'Ready';
  List<TranslationMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _joinMeeting();
  }

  Future<void> _joinMeeting() async {
    try {
      final coordinator = context.read<MeetingCoordinatorService>();

      // ✅ ONLY translate to target language (not all languages)
      await coordinator.joinMeeting(
        meetingId: widget.code,
        displayName: widget.displayName ?? 'Guest',
        targetLanguage: widget.targetLanguage ?? 'en', // SINGLE TARGET
      );

      // Listen to coordinator changes
      coordinator.addListener(_onCoordinatorUpdate);

      setState(() {
        _isJoining = false;
      });

    } catch (e) {
      setState(() {
        _isJoining = false;
        _translationStatus = 'Error: $e';
      });

      print('❌ Error joining meeting: $e');
    }
  }

  void _onCoordinatorUpdate() {
    final coordinator = context.read<MeetingCoordinatorService>();

    setState(() {
      _messages = coordinator.getRecentTranslations();
      _translationStatus = coordinator.isTranslating ? 'Translating...' : 'Ready';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isJoining ? _buildJoiningScreen() : _buildMeetingScreen(),
      ),
    );
  }

  Widget _buildJoiningScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 20),
          Text(
            'Joining meeting ${widget.code}...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up translation: ${widget.targetLanguage ?? 'en'}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingScreen() {
    // ✅ RESPONSIVE LAYOUT for different screen sizes
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700; // Pixel 3 vs Pixel 4a

    return Column(
      children: [
        // Header
        _buildMeetingHeader(),

        // Video area (responsive)
        Expanded(
          flex: isSmallScreen ? 2 : 3,
          child: _buildVideoArea(),
        ),

        // Translation panel (responsive)
        Container(
          height: isSmallScreen ? 200 : 280, // Smaller on Pixel 3
          child: _buildTranslationPanel(),
        ),

        // Controls
        _buildMeetingControls(),
      ],
    );
  }

  Widget _buildMeetingHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          // Meeting info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting: ${widget.code}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Translation: Auto → ${widget.targetLanguage?.toUpperCase() ?? 'EN'}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Translation status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isTranslationEnabled ? Colors.green[900] : Colors.red[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isTranslationEnabled ? Icons.translate : Icons.translate_outlined,
                  color: _isTranslationEnabled ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _translationStatus,
                  style: TextStyle(
                    color: _isTranslationEnabled ? Colors.green : Colors.red,
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

  Widget _buildVideoArea() {
    return Container(
      color: Colors.grey[900],
      child: Stack(
        children: [
          // Main video placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  color: Colors.grey[600],
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.displayName ?? 'You',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Participants indicator
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('1', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              border: Border(bottom: BorderSide(color: Colors.blue[700]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Real-time Translation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _isTranslationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isTranslationEnabled = value;
                    });
                    _toggleTranslation(value);
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),

          // ✅ MESSAGES WITH TRANSLATIONS
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyTranslationState()
                : _buildTranslationMessages(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTranslationState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic,
            color: Colors.grey[600],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Start speaking to see translations',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Language: Auto → ${widget.targetLanguage?.toUpperCase() ?? 'EN'}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationMessages() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildTranslationMessageCard(message);
      },
    );
  }

  Widget _buildTranslationMessageCard(TranslationMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker info
          Row(
            children: [
              Icon(
                message.isCurrentUser ? Icons.person : Icons.person_outline,
                color: message.isCurrentUser ? Colors.blue : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                message.speakerName,
                style: TextStyle(
                  color: message.isCurrentUser ? Colors.blue : Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                message.timestamp,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Original text
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[750],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Original (${message.originalLanguage.toUpperCase()}):',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${message.confidence}%',
                      style: TextStyle(
                        color: message.confidence > 80 ? Colors.green : Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.originalText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // ✅ TRANSLATION (ONLY TARGET LANGUAGE)
          if (message.translation.isNotEmpty && message.translation != message.originalText) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[900]?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[700]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translation (${widget.targetLanguage?.toUpperCase() ?? 'EN'}):',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.translation,
                    style: TextStyle(
                      color: Colors.blue[100],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeetingControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone
          _buildControlButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            isActive: _isMicOn,
            activeColor: Colors.green,
            inactiveColor: Colors.red,
            onTap: () {
              setState(() {
                _isMicOn = !_isMicOn;
              });
              _toggleMicrophone(_isMicOn);
            },
          ),

          // Camera
          _buildControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            isActive: _isCameraOn,
            activeColor: Colors.blue,
            inactiveColor: Colors.red,
            onTap: () {
              setState(() {
                _isCameraOn = !_isCameraOn;
              });
              _toggleCamera(_isCameraOn);
            },
          ),

          // Translation toggle
          _buildControlButton(
            icon: Icons.translate,
            isActive: _isTranslationEnabled,
            activeColor: Colors.purple,
            inactiveColor: Colors.grey,
            onTap: () {
              setState(() {
                _isTranslationEnabled = !_isTranslationEnabled;
              });
              _toggleTranslation(_isTranslationEnabled);
            },
          ),

          // Leave meeting
          _buildControlButton(
            icon: Icons.call_end,
            isActive: false,
            activeColor: Colors.red,
            inactiveColor: Colors.red,
            onTap: _leaveMeeting,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _toggleMicrophone(bool enabled) {
    final coordinator = context.read<MeetingCoordinatorService>();
    coordinator.toggleMicrophone(enabled);
  }

  void _toggleCamera(bool enabled) {
    final coordinator = context.read<MeetingCoordinatorService>();
    coordinator.toggleCamera(enabled);
  }

  void _toggleTranslation(bool enabled) {
    final coordinator = context.read<MeetingCoordinatorService>();
    if (enabled) {
      coordinator.startTranslation(widget.targetLanguage ?? 'en');
    } else {
      coordinator.stopTranslation();
    }
  }

  void _leaveMeeting() {
    final coordinator = context.read<MeetingCoordinatorService>();
    coordinator.leaveMeeting();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  void dispose() {
    final coordinator = context.read<MeetingCoordinatorService>();
    coordinator.removeListener(_onCoordinatorUpdate);
    super.dispose();
  }
}