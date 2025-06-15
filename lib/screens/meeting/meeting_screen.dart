// lib/screens/meeting/meeting_screen.dart - Enhanced với Whisper test
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/audio_capture_service.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/screens/meeting/controller.dart';
import 'package:globecast_ui/screens/meeting/widgets/chat_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/participants_panel.dart';
import 'package:globecast_ui/screens/meeting/widgets/language_selection_panel.dart';
import 'package:globecast_ui/widgets/subtitle_widget.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import '../../router/app_router.dart';
import '../../services/webrtc_media_helper.dart';

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
  late EnhancedAudioCaptureService _audioCaptureService;

  bool _isTranscriptVisible = false;
  int _transcriptCount = 0;

  // Meeting state
  bool _isJoining = true;
  String? _errorMessage;
  bool _isInitializingAI = false;

  // AI Features state
  bool _subtitlesVisible = true;
  bool _whisperConnected = false;
  bool _audioCapturing = false;
  String _currentDisplayLanguage = 'en';
  String _currentNativeLanguage = 'auto';

  // TEST: Latest transcription for debugging
  String _latestTranscription = '';
  int _transcriptionCount = 0;

  // Subtitle configuration
  SubtitleConfig _subtitleConfig = const SubtitleConfig(
    showSpeakerName: true,
    showOriginalText: false,
    enableAnimations: true,
    maxLines: 3,
    displayDuration: Duration(seconds: 10),
  );

  // Connection statistics
  final Map<String, dynamic> _connectionStats = {
    'webrtc': {'status': 'disconnected', 'participants': 0},
    'whisper': {'status': 'disconnected', 'transcriptions': 0},
    'audio': {'status': 'stopped', 'streams': 0},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize services
    _webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
    _whisperService = Provider.of<WhisperService>(context, listen: false);
    _audioCaptureService = Provider.of<EnhancedAudioCaptureService>(context, listen: false);

    _setupServiceCallbacks();
    _joinMeeting();
    _initializeWhisperService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeWhisperService() async {
    _whisperService = WhisperService();

    // Listen to transcription count
    _whisperService.transcriptionStream.listen((result) {
      setState(() {
        _transcriptCount++;
      });
    });

    // Connect to Whisper server
    await _whisperService.connect(
      userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'User ${DateTime.now().millisecondsSinceEpoch % 1000}',
      nativeLanguage: 'auto',
      displayLanguage: 'en',
    );

    print('🌍 Whisper service initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.resumed:
        _checkAndReconnectServices();
        break;
      case AppLifecycleState.detached:
        _cleanupServices();
        break;
      default:
        break;
    }
  }

  /// Setup service callbacks
  void _setupServiceCallbacks() {
    // Whisper service callbacks
    _whisperService.onTranscriptionReceived = (result) {
      if (mounted) {
        setState(() {
          _latestTranscription = '${result.speakerName}: "${result.translatedText}"';
          _transcriptionCount++;
        });

        print('📝 [TEST] Transcription #$_transcriptionCount: ${result.speakerName}: "${result.translatedText}"');
        print('📝 [TEST] Original: "${result.originalText}" (${result.originalLanguage})');
        print('📝 [TEST] Confidence: ${result.transcriptionConfidence.toStringAsFixed(2)}');

        _updateConnectionStats();

        // Show snackbar for testing
        _showSnackBar('🎤 ${result.speakerName}: ${result.translatedText}');
      }
    };

    _whisperService.onError = (error) {
      if (mounted) {
        print('❌ [TEST] Whisper error: $error');
        _showSnackBar('Whisper error: $error', isError: true);
      }
    };

    _whisperService.onConnectionChanged = (state) {
      if (mounted) {
        setState(() {
          _whisperConnected = state == WhisperConnectionState.connected;
        });

        print('🔄 [TEST] Whisper connection state: $state');

        switch (state) {
          case WhisperConnectionState.connected:
            _showSnackBar('🤖 Whisper AI connected - Ready for speech!');
            break;
          case WhisperConnectionState.disconnected:
            _showSnackBar('Whisper disconnected', isError: true);
            break;
          case WhisperConnectionState.reconnecting:
            _showSnackBar('Reconnecting to Whisper...');
            break;
          case WhisperConnectionState.error:
            _showSnackBar('Whisper connection error', isError: true);
            break;
          default:
            break;
        }
        _updateConnectionStats();
      }
    };

    // Audio capture service callbacks
    _audioCaptureService.onAudioCaptured = (audioData, speakerId, speakerName) {
      print('🎤 [TEST] Audio captured from $speakerName: ${audioData.length} bytes');

      // Forward audio to Whisper service
      if (_whisperService.isConnected) {
        _whisperService.sendAudioData(audioData, speakerId, speakerName);
        print('📤 [TEST] Audio forwarded to Whisper service');
      } else {
        print('⚠️ [TEST] Whisper not connected, audio not sent');
      }
    };

    _audioCaptureService.onError = (error) {
      if (mounted) {
        print('❌ [TEST] Audio capture error: $error');
        _showSnackBar('Audio capture error: $error', isError: true);
      }
    };

    _audioCaptureService.onSpeakerActivityChanged = (speakerId, speakerName, isActive) {
      print('🎤 [TEST] $speakerName is ${isActive ? "speaking" : "silent"}');
      if (mounted) {
        _updateConnectionStats();
      }
    };
  }

  /// Join meeting with AI features
  Future<void> _joinMeeting() async {
    try {
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      // Step 1: Join WebRTC meeting
      print('🔗 [TEST] Joining WebRTC meeting...');
      await _joinWebRTCMeeting();

      // Step 2: Initialize AI features
      print('🤖 [TEST] Initializing AI features...');
      await _initializeAIFeatures();

      setState(() {
        _isJoining = false;
      });

      print('✅ [TEST] Meeting joined successfully with AI features');
      _showSnackBar('🎉 Meeting joined! Try speaking to test STT...');

    } catch (e) {
      setState(() {
        _isJoining = false;
        _errorMessage = e.toString();
      });
      print('❌ [TEST] Failed to join meeting: $e');
    }
  }

  /// Join WebRTC meeting
  Future<void> _joinWebRTCMeeting() async {
    final displayName = 'User ${DateTime.now().millisecondsSinceEpoch % 1000}';
    _webrtcService.setUserDetails(
      displayName: displayName,
      userId: _webrtcService.userId,
    );

    await _webrtcService.joinMeeting(meetingId: widget.code);
    _updateConnectionStats();
  }

  /// Initialize AI features (Whisper + Audio Capture)
  Future<void> _initializeAIFeatures() async {
    setState(() {
      _isInitializingAI = true;
    });

    try {
      print('🤖 [TEST] Initializing AI features...');

      // Step 1: Initialize audio capture service
      print('🎙️ [TEST] Initializing audio capture...');
      final audioCaptureInitialized = await _audioCaptureService.initialize();
      if (!audioCaptureInitialized) {
        throw Exception('Audio capture initialization failed');
      }
      print('✅ [TEST] Audio capture initialized');

      // Step 2: Connect to Whisper service
      if (_subtitlesVisible) {
        print('🌍 [TEST] Connecting to Whisper service...');
        await _connectWhisperService();
      }

      // Step 3: Start audio capture from WebRTC streams
      print('🎵 [TEST] Starting audio capture...');
      await _startAudioCapture();

      print('✅ [TEST] AI features initialized successfully');

    } catch (e) {
      print('⚠️ [TEST] AI features initialization failed: $e');
      setState(() {
        _subtitlesVisible = false;
      });
      _showSnackBar('AI features unavailable: $e', isError: true);
    } finally {
      setState(() {
        _isInitializingAI = false;
      });
    }
  }

  /// Connect to Whisper service
  Future<void> _connectWhisperService() async {
    try {
      print('🌍 [TEST] Connecting to Whisper service...');
      print('🌍 [TEST] User: ${_getDisplayName()}, ID: ${_webrtcService.userId}');
      print('🌍 [TEST] Languages: $_currentNativeLanguage → $_currentDisplayLanguage');

      final connected = await _whisperService.connect(
        userId: _webrtcService.userId ?? 'unknown',
        displayName: _getDisplayName(),
        nativeLanguage: _currentNativeLanguage,
        displayLanguage: _currentDisplayLanguage,
      );

      if (connected) {
        setState(() {
          _whisperConnected = true;
        });
        print('✅ [TEST] Whisper service connected successfully');
        _showSnackBar('🤖 Whisper connected! Start speaking to test...');
      } else {
        throw Exception('Failed to connect to Whisper service');
      }
    } catch (e) {
      print('❌ [TEST] Whisper connection failed: $e');
      setState(() {
        _whisperConnected = false;
        _subtitlesVisible = false;
      });
      _showSnackBar('AI Translation service unavailable', isError: true);
    }
  }

  /// Start audio capture from WebRTC streams
  Future<void> _startAudioCapture() async {
    try {
      // Start local audio capture
      if (_webrtcService.localRenderer?.srcObject != null) {
        await _audioCaptureService.startLocalCapture(
          _webrtcService.localRenderer!.srcObject!,
          _webrtcService.userId ?? 'unknown',
          _getDisplayName(),
        );

        setState(() {
          _audioCapturing = true;
        });

        print('🎙️ [TEST] Local audio capture started');
      } else {
        print('⚠️ [TEST] No local stream available for audio capture');
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
            print('🎙️ [TEST] Added remote stream for ${participant.name}');
          }
        }
      }

    } catch (e) {
      print('❌ [TEST] Audio capture start failed: $e');
      _showSnackBar('Audio capture failed: $e', isError: true);
    }
  }

  /// Get display name for current user
  String _getDisplayName() {
    final participants = _webrtcService.participants;
    final currentUser = participants.firstWhere(
          (p) => p.id == _webrtcService.userId,
      orElse: () => MeshParticipant(id: '', name: 'User'),
    );
    return currentUser.name;
  }

  /// Check and reconnect services
  Future<void> _checkAndReconnectServices() async {
    print('🔄 [TEST] Checking service connections...');

    if (_subtitlesVisible && !_whisperService.isConnected) {
      await _connectWhisperService();
    }
  }

  /// Cleanup services
  Future<void> _cleanupServices() async {
    print('🧹 [TEST] Cleaning up AI services...');

    await _audioCaptureService.stopCapture();
    await _whisperService.disconnect();
  }

  /// Navigate to home
  void _navigateToHome() {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.home,
            (route) => false,
      );
    }
  }

  /// Toggle subtitles on/off
  Future<void> _toggleSubtitles() async {
    setState(() {
      _subtitlesVisible = !_subtitlesVisible;
    });

    if (_subtitlesVisible) {
      await _connectWhisperService();
    } else {
      await _whisperService.disconnect();
      setState(() {
        _whisperConnected = false;
      });
    }

    HapticFeedback.lightImpact();
  }

  /// TEST: Manual test button for Whisper
  void _testWhisperConnection() async {
    _showSnackBar('🧪 Testing Whisper connection...');

    final health = _whisperService.getConnectionHealth();
    print('🧪 [TEST] Whisper health: $health');

    if (_whisperService.isConnected) {
      _showSnackBar('✅ Whisper is connected and ready!');
    } else {
      _showSnackBar('❌ Whisper not connected. Attempting reconnection...', isError: true);
      await _connectWhisperService();
    }
  }

  /// Update language preferences
  Future<void> _updateLanguages({
    String? nativeLanguage,
    String? displayLanguage,
  }) async {
    if (nativeLanguage != null) {
      _currentNativeLanguage = nativeLanguage;
    }
    if (displayLanguage != null) {
      _currentDisplayLanguage = displayLanguage;
    }

    // Update WebRTC service
    if (displayLanguage != null) {
      await _webrtcService.updateDisplayLanguage(displayLanguage);
    }

    // Update Whisper service
    if (_whisperService.isConnected) {
      await _whisperService.setUserLanguages(
        nativeLanguage: _currentNativeLanguage,
        displayLanguage: _currentDisplayLanguage,
      );
    }

    _showSnackBar('Languages updated: $_currentNativeLanguage → $_currentDisplayLanguage');
  }

  /// Update connection statistics
  void _updateConnectionStats() {
    setState(() {
      _connectionStats['webrtc'] = {
        'status': _webrtcService.isMeetingActive ? 'connected' : 'disconnected',
        'participants': _webrtcService.participants.length,
      };
      _connectionStats['whisper'] = {
        'status': _whisperConnected ? 'connected' : 'disconnected',
        'transcriptions': _transcriptionCount,
      };
      _connectionStats['audio'] = {
        'status': _audioCapturing ? 'capturing' : 'stopped',
        'streams': _audioCaptureService.activeStreamsCount,
      };
    });
  }

  /// Show snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 4 : 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.15,
            left: 16,
            right: 16,
          ),
        ),
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
      child: _MeetingContent(
        meetingCode: widget.code,
        subtitlesVisible: _subtitlesVisible,
        subtitleConfig: _subtitleConfig,
        whisperConnected: _whisperConnected,
        audioCapturing: _audioCapturing,
        currentLanguage: _currentDisplayLanguage,
        latestTranscription: _latestTranscription,
        transcriptionCount: _transcriptionCount,
        connectionStats: _connectionStats,
        onToggleSubtitles: _toggleSubtitles,
        onTestWhisper: _testWhisperConnection,
        onUpdateLanguages: _updateLanguages,
        onUpdateSubtitleConfig: (config) {
          setState(() {
            _subtitleConfig = config;
          });
        },
      ),
    );
  }

  /// Build loading screen
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: GcbAppTheme.primary),
            const SizedBox(height: 24),
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
              _isInitializingAI
                  ? 'Setting up AI translation...'
                  : 'Connecting to mesh network...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
            if (_isInitializingAI) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GcbAppTheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GcbAppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Connecting to Whisper AI...',
                      style: TextStyle(
                        color: GcbAppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build error screen
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
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Failed to Join Meeting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[300], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _joinMeeting();
                    },
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
}

/// Meeting content with enhanced Whisper testing
class _MeetingContent extends StatelessWidget {
  final String meetingCode;
  final bool subtitlesVisible;
  final SubtitleConfig subtitleConfig;
  final bool whisperConnected;
  final bool audioCapturing;
  final String currentLanguage;
  final String latestTranscription;
  final int transcriptionCount;
  final Map<String, dynamic> connectionStats;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onTestWhisper;
  final Function({String? nativeLanguage, String? displayLanguage}) onUpdateLanguages;
  final Function(SubtitleConfig) onUpdateSubtitleConfig;

  const _MeetingContent({
    required this.meetingCode,
    required this.subtitlesVisible,
    required this.subtitleConfig,
    required this.whisperConnected,
    required this.audioCapturing,
    required this.currentLanguage,
    required this.latestTranscription,
    required this.transcriptionCount,
    required this.connectionStats,
    required this.onToggleSubtitles,
    required this.onTestWhisper,
    required this.onUpdateLanguages,
    required this.onUpdateSubtitleConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, webrtcService, child) {
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
                      // Enhanced info bar with AI status
                      _buildEnhancedInfoBar(context, controller),

                      // Video area
                      Expanded(
                        child: _buildVideoAreaWithTranscription(context, controller, webrtcService),
                      ),

                      // Enhanced control panel
                      _buildEnhancedControlBar(context, controller),
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
      },
    );
  }

  /// Build enhanced info bar with Whisper testing info
  Widget _buildEnhancedInfoBar(BuildContext context, MeetingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
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
                      connectionStats['webrtc']['status'] == 'connected'
                          ? Icons.meeting_room
                          : Icons.meeting_room_outlined,
                      color: connectionStats['webrtc']['status'] == 'connected'
                          ? Colors.green
                          : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      meetingCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${connectionStats['webrtc']['participants']} participants • ${connectionStats['whisper']['transcriptions']} transcriptions',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // AI Features status with test button
          Row(
            children: [
              // Audio capture status
              _buildStatusIndicator(
                icon: audioCapturing ? Icons.graphic_eq : Icons.mic_off,
                label: 'AUDIO',
                isActive: audioCapturing,
                color: audioCapturing ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),

              // AI status with test button
              GestureDetector(
                onTap: onTestWhisper,
                child: _buildStatusIndicator(
                  icon: whisperConnected ? Icons.psychology : Icons.psychology_outlined,
                  label: 'AI',
                  isActive: whisperConnected,
                  color: whisperConnected ? GcbAppTheme.primary : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),

              // Language indicator
              if (whisperConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GcbAppTheme.primary, width: 1),
                  ),
                  child: Text(
                    currentLanguage.toUpperCase(),
                    style: const TextStyle(
                      color: GcbAppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status indicator
  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build video area with transcription display
  Widget _buildVideoAreaWithTranscription(BuildContext context, MeetingController controller, WebRTCMeshMeetingService webrtcService) {
    return Stack(
      children: [
        // Main video area (same as before)
        _buildMainVideoView(context, controller, webrtcService),

        // Whisper test panel overlay (top-left)
        if (whisperConnected || transcriptionCount > 0)
          Positioned(
            top: 16,
            left: 16,
            child: _buildWhisperTestPanel(),
          ),

        // Latest transcription overlay (bottom)
        if (latestTranscription.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildTranscriptionDisplay(),
          ),

        // Participant thumbnails
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: _buildParticipantThumbnails(context, controller),
        ),
      ],
    );
  }

  /// Build main video view (simplified version)
  Widget _buildMainVideoView(BuildContext context, MeetingController controller, WebRTCMeshMeetingService webrtcService) {
    final participants = controller.participants;
    final remoteParticipants = participants.where((p) => !p.isLocal).toList();
    final localRenderer = webrtcService.localRenderer;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Main content area
          if (remoteParticipants.isNotEmpty)
            _buildRemoteVideoView(controller, remoteParticipants.first)
          else
            _buildWaitingView(),

          // Local video pip (top-right)
          if (localRenderer != null)
            Positioned(
              top: 16,
              right: 16,
              child: _buildLocalVideoPip(localRenderer, webrtcService),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideoView(MeetingController controller, MeshParticipant participant) {
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
                    radius: 32,
                    backgroundColor: GcbAppTheme.primary,
                    child: Text(
                      participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    participant.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        // Name overlay
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                  color: participant.isAudioEnabled ? Colors.white : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
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
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Waiting for participants...',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Try speaking to test Whisper STT',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalVideoPip(RTCVideoRenderer renderer, WebRTCMeshMeetingService webrtcService) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: webrtcService.isVideoEnabled ? GcbAppTheme.primary : Colors.grey,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            if (webrtcService.isVideoEnabled)
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
            // "You" label
            Positioned(
              bottom: 4,
              left: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      webrtcService.isAudioEnabled ? Icons.mic : Icons.mic_off,
                      color: webrtcService.isAudioEnabled ? Colors.white : Colors.red,
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

  /// Build Whisper test panel
  Widget _buildWhisperTestPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: whisperConnected ? GcbAppTheme.primary : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                whisperConnected ? Icons.psychology : Icons.psychology_outlined,
                color: whisperConnected ? GcbAppTheme.primary : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Whisper AI',
                style: TextStyle(
                  color: whisperConnected ? GcbAppTheme.primary : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            whisperConnected ? 'Connected & Listening' : 'Disconnected',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
            ),
          ),
          if (transcriptionCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Transcriptions: $transcriptionCount',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Tap AI status to test connection',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Build transcription display
  Widget _buildTranscriptionDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GcbAppTheme.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.transcribe,
                color: GcbAppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Latest Transcription (#$transcriptionCount)',
                style: TextStyle(
                  color: GcbAppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            latestTranscription,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build participant thumbnails
  Widget _buildParticipantThumbnails(BuildContext context, MeetingController controller) {
    final participants = controller.participants;
    final remoteParticipants = participants.where((p) => !p.isLocal).toList();

    if (remoteParticipants.length <= 1) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: remoteParticipants.length,
        itemBuilder: (context, index) {
          final participant = remoteParticipants[index];
          final renderer = controller.getRendererForParticipant(participant.id);

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border.all(
                color: participant.isAudioEnabled ? Colors.green : Colors.red,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  if (renderer != null)
                    Positioned.fill(
                      child: RTCVideoView(
                        renderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: GcbAppTheme.primary,
                          child: Text(
                            participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  // Name overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
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
                              style: const TextStyle(color: Colors.white, fontSize: 10),
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
        },
      ),
    );
  }

  /// Build enhanced control bar with Whisper test features
  Widget _buildEnhancedControlBar(BuildContext context, MeetingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.background,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone
          _buildControlButton(
            icon: controller.isMicOn ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: controller.isMicOn,
            onPressed: controller.toggleMicrophone,
          ),

          // Camera
          _buildControlButton(
            icon: controller.isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: controller.isCameraOn,
            onPressed: controller.toggleCamera,
          ),

          // AI Subtitles with enhanced visual feedback
          _buildControlButton(
            icon: subtitlesVisible ? Icons.subtitles : Icons.subtitles_off,
            label: 'AI STT',
            isActive: subtitlesVisible,
            isHighlighted: subtitlesVisible && whisperConnected,
            badge: transcriptionCount > 0 ? transcriptionCount.toString() : null,
            onPressed: onToggleSubtitles,
          ),

          // Chat
          _buildControlButton(
            icon: Icons.chat,
            label: 'Chat',
            isActive: true,
            isHighlighted: controller.isChatVisible,
            onPressed: controller.toggleChat,
          ),

          // Participants
          _buildControlButton(
            icon: Icons.people,
            label: 'People',
            isActive: true,
            isHighlighted: controller.isParticipantsListVisible,
            onPressed: controller.toggleParticipantsList,
          ),

          // End call
          _buildEndCallButton(context, controller),
        ],
      ),
    );
  }

  /// Build control button with optional badge
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isHighlighted = false,
    String? badge,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
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
                  size: 22,
                ),
                onPressed: onPressed,
              ),
            ),
            if (badge != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isHighlighted ? GcbAppTheme.primary : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build end call button
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
            icon: const Icon(Icons.call_end, color: Colors.white, size: 24),
            onPressed: () => _showEndCallDialog(context, controller),
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

  /// Show end call dialog
  void _showEndCallDialog(BuildContext context, MeetingController controller) {
    // Implementation same as before...
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
}