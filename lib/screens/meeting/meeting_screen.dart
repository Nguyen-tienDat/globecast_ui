// lib/screens/meeting/meeting_screen.dart - Updated with User-Specific Workflow
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../../services/whisper_service.dart';
import '../../services/user_specific_transcript_service.dart';
import '../../services/audio_capture_service.dart';
import '../../widgets/enahanced_subtitle_widget.dart';
import '../../theme/app_theme.dart';
import '../../router/app_router.dart';
import 'controller.dart';
import 'language_selection_screen.dart';
import 'widgets/chat_panel.dart';
import 'widgets/participants_panel.dart';

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

  // Services
  late WebRTCMeshMeetingService _webrtcService;
  late WhisperService _whisperService;
  late UserSpecificTranscriptService _transcriptService;
  late EnhancedAudioCaptureService _audioCaptureService;

  // Meeting state
  bool _isJoining = true;
  String? _errorMessage;
  String _userDisplayLanguage = 'en';
  String _userName = 'User';

  // UI state
  bool _isChatVisible = false;
  bool _isParticipantsVisible = false;
  bool _areSubtitlesVisible = true;
  bool _showLanguageSelection = false;

  // Initialization flags
  bool _servicesInitialized = false;
  bool _meetingJoined = false;
  bool _transcriptServiceReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _extractArgumentsAndInitialize();
  }

  void _extractArgumentsAndInitialize() {
    // Extract arguments from route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _userDisplayLanguage = args['displayLanguage'] ?? 'en';
        _userName = args['userName'] ?? 'User';
      }

      print('🎯 Meeting Screen initialized');
      print('   Meeting Code: ${widget.code}');
      print('   User: $_userName');
      print('   Display Language: $_userDisplayLanguage');

      _initializeServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseServices();
        break;
      case AppLifecycleState.resumed:
        _resumeServices();
        break;
      case AppLifecycleState.detached:
        _cleanupServices();
        break;
      default:
        break;
    }
  }

  /// Initialize all services in proper order
  Future<void> _initializeServices() async {
    try {
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      // Get service instances
      _webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
      _whisperService = Provider.of<WhisperService>(context, listen: false);
      _transcriptService = Provider.of<UserSpecificTranscriptService>(context, listen: false);
      _audioCaptureService = Provider.of<EnhancedAudioCaptureService>(context, listen: false);

      print('🔄 Step 1: Initializing core services...');

      // Step 1: Initialize audio capture service
      final audioCaptureInitialized = await _audioCaptureService.initialize();
      if (!audioCaptureInitialized) {
        throw Exception('Audio capture initialization failed');
      }

      // Step 2: Join WebRTC meeting
      print('🔄 Step 2: Joining WebRTC meeting...');
      await _joinWebRTCMeeting();

      // Step 3: Initialize transcript service for this user
      print('🔄 Step 3: Setting up user-specific transcript service...');
      final transcriptInitialized = await _transcriptService.initializeForUser(
        userId: _webrtcService.userId ?? 'unknown',
        meetingId: widget.code,
        displayLanguage: _userDisplayLanguage,
      );

      if (!transcriptInitialized) {
        print('⚠️ Transcript service initialization failed, continuing without AI features');
      }

      // Step 4: Connect to Whisper service
      print('🔄 Step 4: Connecting to Whisper AI...');
      await _connectWhisperService();

      // Step 5: Start audio capture
      print('🔄 Step 5: Starting audio capture...');
      await _startAudioCapture();

      setState(() {
        _isJoining = false;
        _servicesInitialized = true;
        _meetingJoined = true;
        _transcriptServiceReady = transcriptInitialized;
      });

      print('✅ Meeting joined successfully with AI translation!');
      _showSuccessMessage();

    } catch (e) {
      print('❌ Meeting initialization failed: $e');
      setState(() {
        _isJoining = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Join WebRTC meeting
  Future<void> _joinWebRTCMeeting() async {
    _webrtcService.setUserDetails(
      displayName: _userName,
      userId: _webrtcService.userId,
    );

    await _webrtcService.joinMeeting(meetingId: widget.code);
    print('✅ WebRTC meeting joined successfully');
  }

  /// Connect to Whisper service
  Future<void> _connectWhisperService() async {
    final connected = await _whisperService.connect(
      userId: _webrtcService.userId ?? 'unknown',
      displayName: _userName,
      nativeLanguage: 'auto', // Auto-detect speech language
      displayLanguage: _userDisplayLanguage,
    );

    if (!connected) {
      throw Exception('Failed to connect to Whisper AI service');
    }

    print('✅ Whisper AI connected successfully');
  }

  /// Start audio capture from WebRTC streams
  Future<void> _startAudioCapture() async {
    // Start local audio capture
    if (_webrtcService.localRenderer?.srcObject != null) {
      await _audioCaptureService.startLocalCapture(
        _webrtcService.localRenderer!.srcObject!,
        _webrtcService.userId ?? 'unknown',
        _userName,
      );
      print('🎙️ Local audio capture started');
    }

    // Add existing remote streams
    for (final participant in _webrtcService.participants) {
      if (!participant.isLocal) {
        final renderer = _webrtcService.getRendererForParticipant(participant.id);
        if (renderer?.srcObject != null) {
          await _audioCaptureService.addRemoteStream(
            participant.id,
            participant.name,
            renderer!.srcObject!,
          );
          print('🎙️ Added remote stream for ${participant.name}');
        }
      }
    }

    print('✅ Audio capture fully operational');
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Meeting Joined Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'AI translation to ${_getLanguageName(_userDisplayLanguage)} is active',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _pauseServices() {
    print('⏸️ Pausing services due to app state change');
    // Implement pause logic if needed
  }

  void _resumeServices() {
    print('▶️ Resuming services due to app state change');
    // Implement resume logic if needed
  }

  Future<void> _cleanupServices() async {
    print('🧹 Cleaning up all services...');

    try {
      await _audioCaptureService.stopCapture();
      await _whisperService.disconnect();
      await _webrtcService.leaveMeeting();
      await _transcriptService.dispose();
    } catch (e) {
      print('⚠️ Error during cleanup: $e');
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
    if (_isJoining) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return ChangeNotifierProvider(
      create: (context) {
        final controller = MeetingController(_webrtcService);
        controller.setOnMeetingEndedCallback(_navigateToHome);
        return controller;
      },
      child: _buildMeetingContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading indicator
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: GcbAppTheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const CircularProgressIndicator(
                color: GcbAppTheme.primary,
                strokeWidth: 3,
              ),
            ),

            const SizedBox(height: 32),

            // Main status
            Text(
              'Joining Meeting...',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            // Language info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: GcbAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GcbAppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getLanguageFlag(_userDisplayLanguage),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Subtitles: ${_getLanguageName(_userDisplayLanguage)}',
                    style: const TextStyle(
                      color: GcbAppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Steps
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildLoadingStep('Connecting to meeting...', true),
                  _buildLoadingStep('Setting up real-time translation...', _meetingJoined),
                  _buildLoadingStep('Initializing AI transcription...', _transcriptServiceReady),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStep(String text, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.grey[700],
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isCompleted ? Colors.white : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
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
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Failed to Join Meeting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initializeServices,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GcbAppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _navigateToHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.home, color: Colors.white),
                    label: const Text(
                      'Back to Home',
                      style: TextStyle(color: Colors.white),
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

  Widget _buildMeetingContent() {
    return Consumer<MeetingController>(
      builder: (context, controller, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: WillPopScope(
            onWillPop: () async {
              _showEndCallDialog(controller);
              return false;
            },
            child: SafeArea(
              child: Stack(
                children: [
                  // Main meeting layout
                  Column(
                    children: [
                      // Meeting header
                      _buildMeetingHeader(controller),

                      // Video area
                      Expanded(
                        child: _buildVideoArea(controller),
                      ),

                      // Enhanced subtitle widget
                      if (_areSubtitlesVisible && _transcriptServiceReady)
                        EnhancedSubtitleWidget(
                          isVisible: _areSubtitlesVisible,
                          userDisplayLanguage: _userDisplayLanguage,
                          onToggleVisibility: () {
                            setState(() {
                              _areSubtitlesVisible = !_areSubtitlesVisible;
                            });
                          },
                          onLanguagePressed: () {
                            setState(() {
                              _showLanguageSelection = true;
                            });
                          },
                          showControls: true,
                          isCompactMode: false,
                        ),

                      // Control bar
                      _buildControlBar(controller),
                    ],
                  ),

                  // Side panels
                  if (_isChatVisible)
                    Positioned(
                      top: 60,
                      right: 0,
                      bottom: _areSubtitlesVisible ? 280 : 100,
                      width: MediaQuery.of(context).size.width * 0.35,
                      child: const ChatPanel(),
                    ),

                  if (_isParticipantsVisible)
                    Positioned(
                      top: 60,
                      right: 0,
                      bottom: _areSubtitlesVisible ? 280 : 100,
                      width: MediaQuery.of(context).size.width * 0.35,
                      child: const ParticipantsPanel(),
                    ),

                  // Floating language indicator
                  if (!_areSubtitlesVisible)
                    FloatingLanguageIndicator(
                      currentLanguage: _userDisplayLanguage,
                      onTap: () {
                        setState(() {
                          _showLanguageSelection = true;
                        });
                      },
                      isActive: _transcriptServiceReady,
                    ),

                  // Language selection overlay
                  if (_showLanguageSelection)
                    _buildLanguageSelectionOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeetingHeader(MeetingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Meeting info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.meeting_room,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getLanguageColor(_userDisplayLanguage).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getLanguageName(_userDisplayLanguage),
                        style: TextStyle(
                          color: _getLanguageColor(_userDisplayLanguage),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.participantCount} participants • AI Translation Active',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Connection status
          Row(
            children: [
              _buildStatusIndicator(
                'AI',
                _transcriptServiceReady,
                _transcriptServiceReady ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildStatusIndicator(
                'AUDIO',
                controller.isMicOn,
                controller.isMicOn ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildVideoArea(MeetingController controller) {
    final participants = controller.participants;
    final remoteParticipants = participants.where((p) => !p.isLocal).toList();
    final localRenderer = _webrtcService.localRenderer;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main video content
          if (remoteParticipants.isNotEmpty)
            _buildMainVideoView(controller, remoteParticipants.first)
          else
            _buildWaitingView(),

          // Local video PiP
          if (localRenderer != null)
            Positioned(
              top: 16,
              right: 16,
              child: _buildLocalVideoPip(localRenderer),
            ),

          // Participant thumbnails
          if (remoteParticipants.length > 1)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildParticipantThumbnails(controller, remoteParticipants),
            ),
        ],
      ),
    );
  }

  Widget _buildMainVideoView(MeetingController controller, MeshParticipant participant) {
    final renderer = controller.getRendererForParticipant(participant.id);

    return Stack(
      children: [
        if (renderer != null)
          Positioned.fill(
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: false,
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _getLanguageColor(_userDisplayLanguage),
                    child: Text(
                      participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    participant.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

        // Speaker name overlay
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                  color: participant.isAudioEnabled ? Colors.white : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  participant.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _getLanguageColor(_userDisplayLanguage).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: _getLanguageColor(_userDisplayLanguage),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: _getLanguageColor(_userDisplayLanguage),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Waiting for participants...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'AI translation to ${_getLanguageName(_userDisplayLanguage)} is ready',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalVideoPip(RTCVideoRenderer renderer) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getLanguageColor(_userDisplayLanguage), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            if (_webrtcService.isVideoEnabled)
              Positioned.fill(
                child: RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
              )
            else
              Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(Icons.videocam_off, color: Colors.white, size: 32),
                ),
              ),

            // User label
            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _webrtcService.isAudioEnabled ? Icons.mic : Icons.mic_off,
                      color: _webrtcService.isAudioEnabled ? Colors.white : Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'You',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantThumbnails(MeetingController controller, List<MeshParticipant> participants) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          final renderer = controller.getRendererForParticipant(participant.id);

          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: participant.isAudioEnabled ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: renderer != null
                  ? RTCVideoView(renderer)
                  : Container(
                color: Colors.grey[800],
                child: Center(
                  child: Text(
                    participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlBar(MeetingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
            icon: _areSubtitlesVisible ? Icons.subtitles : Icons.subtitles_off,
            label: 'Subtitles',
            isActive: _areSubtitlesVisible,
            isHighlighted: _areSubtitlesVisible && _transcriptServiceReady,
            onPressed: () {
              setState(() {
                _areSubtitlesVisible = !_areSubtitlesVisible;
              });
            },
          ),

          _buildControlButton(
            icon: Icons.chat,
            label: 'Chat',
            isActive: true,
            isHighlighted: _isChatVisible,
            onPressed: () {
              setState(() {
                _isChatVisible = !_isChatVisible;
                if (_isChatVisible) _isParticipantsVisible = false;
              });
            },
          ),

          _buildControlButton(
            icon: Icons.people,
            label: 'People',
            isActive: true,
            isHighlighted: _isParticipantsVisible,
            onPressed: () {
              setState(() {
                _isParticipantsVisible = !_isParticipantsVisible;
                if (_isParticipantsVisible) _isChatVisible = false;
              });
            },
          ),

          _buildEndCallButton(controller),
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
                ? _getLanguageColor(_userDisplayLanguage).withOpacity(0.2)
                : isActive
                ? Colors.transparent
                : Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isHighlighted
                  ? _getLanguageColor(_userDisplayLanguage)
                  : isActive
                  ? Colors.white
                  : Colors.red,
              size: 22,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? _getLanguageColor(_userDisplayLanguage) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEndCallButton(MeetingController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.call_end, color: Colors.white, size: 24),
            onPressed: () => _showEndCallDialog(controller),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'End Call',
          style: TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLanguageSelectionOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: LanguageSelectionWidget(
              showBeforeMeeting: false,
              onLanguageSelected: () {
                setState(() {
                  _showLanguageSelection = false;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showEndCallDialog(MeetingController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GcbAppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            controller.isHost ? 'End Meeting' : 'Leave Meeting',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            controller.isHost
                ? 'Are you sure you want to end this meeting for everyone?'
                : 'Are you sure you want to leave this meeting?',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: GcbAppTheme.primary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.endOrLeaveCall();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                controller.isHost ? 'End Meeting' : 'Leave Meeting',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageName(String languageCode) {
    const names = {
      'en': 'English',
      'vi': 'Tiếng Việt',
      'fr': 'Français',
      'es': 'Español',
      'de': 'Deutsch',
      'zh': '中文',
      'ja': '日本語',
      'ko': '한국어',
    };
    return names[languageCode] ?? languageCode.toUpperCase();
  }

  String _getLanguageFlag(String languageCode) {
    const flags = {
      'en': '🇺🇸',
      'vi': '🇻🇳',
      'fr': '🇫🇷',
      'es': '🇪🇸',
      'de': '🇩🇪',
      'zh': '🇨🇳',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
    };
    return flags[languageCode] ?? '🌍';
  }

  Color _getLanguageColor(String languageCode) {
    const colors = {
      'en': Color(0xFF1E88E5),
      'vi': Color(0xFFD32F2F),
      'fr': Color(0xFF1976D2),
      'es': Color(0xFFFF8F00),
      'de': Color(0xFF424242),
      'zh': Color(0xFFD32F2F),
      'ja': Color(0xFFE53935),
      'ko': Color(0xFF1565C0),
    };
    return colors[languageCode] ?? const Color(0xFF64B5F6);
  }
}