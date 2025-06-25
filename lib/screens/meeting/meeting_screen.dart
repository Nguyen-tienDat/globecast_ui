// lib/screens/meeting/meeting_screen.dart - COMPLETE PRODUCTION READY
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';

class MeetingScreen extends StatefulWidget {
  final String? code;
  final String? displayName;
  final String? targetLanguage;
  final String? meetingId;

  const MeetingScreen({
    super.key,
    this.code,
    this.displayName,
    this.targetLanguage,
    this.meetingId,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  // 🎯 STATE MANAGEMENT
  bool _isJoining = false;
  bool _isListening = false;
  bool _isSTTInitialized = false;

  // 🎯 REAL-TIME TRANSLATION STATE
  final List<SpeechResult> _speechResults = [];
  String? _currentSpeakerId;
  String _speechServiceStatus = 'Ready';
  String _lastTranslationTime = '';

  // 🎯 UI STATE
  bool _showTranslationOverlay = true;
  int _totalTranslations = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMeeting();
    });
  }

  // 🚀 COMPLETE MEETING INITIALIZATION
  Future<void> _initializeMeeting() async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
      _speechServiceStatus = 'Initializing services...';
    });

    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final speechService = context.read<MultilingualSpeechService>();

      if (kDebugMode) {
        print('🎯 Starting complete meeting initialization...');
      }

      // ✅ STEP 1: VERIFY GOOGLE CLOUD SERVICES
      setState(() {
        _speechServiceStatus = 'Checking Google Cloud services...';
      });

      if (!speechService.isAvailable) {
        setState(() {
          _speechServiceStatus = 'Initializing Google Cloud...';
        });
        await speechService.initialize();
      }

      if (!speechService.isAvailable) {
        throw Exception('Google Cloud services not available. Please check your internet connection and credentials.');
      }

      // ✅ STEP 2: INITIALIZE WEBRTC SERVICE
      setState(() {
        _speechServiceStatus = 'Setting up video calling...';
      });

      if (!webrtcService.isInitialized) {
        await webrtcService.initialize();
      }

      // ✅ STEP 3: SET USER CONTEXT
      if (widget.displayName != null && widget.displayName!.isNotEmpty) {
        webrtcService.setUserDetails(displayName: widget.displayName!);
      }

      // ✅ STEP 4: CONFIGURE SPEECH SERVICE
      setState(() {
        _speechServiceStatus = 'Configuring translation settings...';
      });

      speechService.setUserContext(
          webrtcService.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          widget.displayName ?? 'User'
      );

      final meetingCode = widget.code ?? widget.meetingId;
      if (meetingCode != null && meetingCode.isNotEmpty) {
        speechService.setTranslationContext(meetingCode);
      }

      speechService.setPreferredLanguage(widget.targetLanguage ?? 'en');
      speechService.setTargetLanguages([
        'en', 'vi', 'zh', 'ja', 'ko', 'es', 'fr', 'de', 'th', 'id', 'ms', 'ar', 'hi'
      ]);

      // ✅ STEP 5: JOIN MEETING
      setState(() {
        _speechServiceStatus = 'Joining meeting...';
      });

      if (meetingCode != null && meetingCode.isNotEmpty) {
        await webrtcService.joinMeeting(meetingId: meetingCode);
      } else {
        throw Exception('No meeting code provided');
      }

      // ✅ STEP 6: SETUP REAL-TIME LISTENERS
      setState(() {
        _speechServiceStatus = 'Setting up real-time translation...';
      });

      _setupSpeechListeners(speechService);
      _isSTTInitialized = true;

      // ✅ STEP 7: AUTO START SPEECH RECOGNITION
      setState(() {
        _speechServiceStatus = 'Starting speech recognition...';
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      await _startRealSpeechRecognition();

      setState(() {
        _speechServiceStatus = '✅ All systems ready';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('🎤 Real-time Google Cloud translation active!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (kDebugMode) {
        print('✅ Complete meeting initialization successful');
        print('   Meeting: $meetingCode');
        print('   User: ${widget.displayName} (${webrtcService.userId})');
        print('   Target Language: ${widget.targetLanguage}');
        print('   Google Cloud: ${speechService.isAvailable}');
        print('   Speech Recognition: $_isListening');
      }

    } catch (e) {
      setState(() {
        _speechServiceStatus = '❌ Initialization failed: $e';
      });

      if (kDebugMode) {
        print('❌ Error during meeting initialization: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Failed to join meeting', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(e.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeMeeting(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  // 🎧 SETUP COMPREHENSIVE SPEECH LISTENERS
  void _setupSpeechListeners(MultilingualSpeechService speechService) {
    // Listen to speech results
    speechService.speechResultStream.listen(
          (result) {
        if (mounted) {
          setState(() {
            // Add new result to the beginning of the list
            _speechResults.insert(0, result);

            // Keep only last 25 results for performance
            if (_speechResults.length > 25) {
              _speechResults.removeRange(25, _speechResults.length);
            }

            // Update current speaker and stats
            _currentSpeakerId = result.userId;
            _totalTranslations++;
            _lastTranslationTime = _formatTimestamp(result.timestamp);
          });

          if (kDebugMode) {
            print('📝 Real Google Cloud speech result:');
            print('   Speaker: ${result.userName} (${result.userId})');
            print('   Original (${result.detectedLanguage}): "${result.originalText}"');
            print('   Confidence: ${(result.confidence * 100).toInt()}%');
            print('   Translations: ${result.translations.keys.toList()}');
            print('   Target: ${result.translations[widget.targetLanguage ?? 'en']}');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Speech result stream error: $error');
        }
        if (mounted) {
          setState(() {
            _speechServiceStatus = 'Speech recognition error: $error';
          });
        }
      },
    );

    // Listen to status updates
    speechService.statusStream.listen(
          (status) {
        if (mounted) {
          setState(() {
            _speechServiceStatus = status;
          });
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Speech status stream error: $error');
        }
      },
    );

    if (kDebugMode) {
      print('🎧 Speech listeners setup complete');
    }
  }

  // 🎤 START REAL SPEECH RECOGNITION
  Future<void> _startRealSpeechRecognition() async {
    if (_isListening) {
      if (kDebugMode) {
        print('⚠️ Speech recognition already active');
      }
      return;
    }

    try {
      final speechService = context.read<MultilingualSpeechService>();

      setState(() {
        _isListening = true;
        _speechServiceStatus = 'Starting audio capture...';
      });

      await speechService.startListening(
        meetingId: widget.code ?? widget.meetingId,
        userId: _getCurrentUserId(),
        preferredLanguage: widget.targetLanguage ?? 'en',
      );

      setState(() {
        _speechServiceStatus = '🎤 Listening with Google Cloud...';
      });

      if (kDebugMode) {
        print('🎤 Real Google Cloud speech recognition started');
        print('   Meeting: ${widget.code ?? widget.meetingId}');
        print('   User: ${_getCurrentUserId()}');
        print('   Language: ${widget.targetLanguage ?? 'en'}');
      }

    } catch (e) {
      setState(() {
        _isListening = false;
        _speechServiceStatus = 'Failed to start: $e';
      });

      if (kDebugMode) {
        print('❌ Error starting speech recognition: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _startRealSpeechRecognition(),
            ),
          ),
        );
      }
    }
  }

  // 🛑 STOP SPEECH RECOGNITION
  Future<void> _stopSpeechRecognition() async {
    if (!_isListening) return;

    try {
      setState(() {
        _speechServiceStatus = 'Stopping speech recognition...';
      });

      final speechService = context.read<MultilingualSpeechService>();
      await speechService.stopListening();

      setState(() {
        _isListening = false;
        _currentSpeakerId = null;
        _speechServiceStatus = 'Speech recognition stopped';
      });

      if (kDebugMode) {
        print('🛑 Speech recognition stopped');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping speech recognition: $e');
      }

      setState(() {
        _speechServiceStatus = 'Error stopping: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: Consumer<WebRTCMeshMeetingService>(
        builder: (context, service, child) {
          // Show loading screen during initialization
          if (_isJoining || !service.isInitialized || !service.isMeetingActive) {
            return _buildLoadingScreen(service);
          }

          return Column(
            children: [
              // Enhanced top status bar
              _buildEnhancedTopStatusBar(service),

              // Main content area
              Expanded(
                child: Stack(
                  children: [
                    // Main video area
                    _buildMainVideoArea(service),

                    // Real-time translation overlay
                    if (_showTranslationOverlay)
                      Positioned(
                        bottom: 80,
                        left: 16,
                        right: 16,
                        child: _buildGoogleCloudTranslationOverlay(),
                      ),
                  ],
                ),
              ),

              // Enhanced bottom controls
              _buildEnhancedBottomControls(service),
            ],
          );
        },
      ),
    );
  }

  // 📊 ENHANCED LOADING SCREEN
  Widget _buildLoadingScreen(WebRTCMeshMeetingService service) {
    return Container(
      color: GcbAppTheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading indicator
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: GcbAppTheme.primary,
                    strokeWidth: 3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud,
                    color: GcbAppTheme.primary,
                    size: 32,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Status text
            Text(
              _isJoining ? 'Joining Meeting' : 'Setting up Services',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _speechServiceStatus,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),

            const SizedBox(height: 40),

            // Service status indicators
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Service Status',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildServiceIndicator(
                    'Google Cloud Speech',
                    context.read<MultilingualSpeechService>().isAvailable,
                    Icons.cloud,
                  ),
                  const SizedBox(height: 12),

                  _buildServiceIndicator(
                    'Google Cloud Translation',
                    context.read<MultilingualSpeechService>().isAvailable,
                    Icons.translate,
                  ),
                  const SizedBox(height: 12),

                  _buildServiceIndicator(
                    'WebRTC Connection',
                    service.isMeetingActive,
                    Icons.videocam,
                  ),
                  const SizedBox(height: 12),

                  _buildServiceIndicator(
                    'Audio Capture',
                    service.isInitialized,
                    Icons.mic,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Meeting info
            if (widget.code != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  'Meeting: ${widget.code}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceIndicator(String name, bool isReady, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: isReady ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isReady ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isReady ? 'Ready' : 'Connecting...',
            style: TextStyle(
              color: isReady ? Colors.green : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // 🎯 ENHANCED TOP STATUS BAR
  Widget _buildEnhancedTopStatusBar(WebRTCMeshMeetingService service) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.4),
          ],
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
                    const Icon(Icons.videocam, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.code ?? widget.meetingId ?? 'Unknown',
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
                  widget.displayName ?? 'User',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Service status indicators
          Row(
            children: [
              // Google Cloud status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.read<MultilingualSpeechService>().isAvailable
                      ? Colors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'Cloud',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Speech status
              if (_isListening)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(width: 8),

              // Participants
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${service.participants.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🎬 MAIN VIDEO AREA
  Widget _buildMainVideoArea(WebRTCMeshMeetingService service) {
    final participants = service.participants;

    if (participants.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, size: 80, color: Colors.grey[600]),
              const SizedBox(height: 24),
              Text(
                'Waiting for participants...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Google Cloud Translation: ${_isListening ? "🟢 Active" : "🔴 Inactive"}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (_totalTranslations > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Total translations: $_totalTranslations',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Main speaker view
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            child: _buildVideoTile(service, participants.first, isMainView: true),
          ),
        ),

        // Other participants grid
        if (participants.length > 1)
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length - 1,
              itemBuilder: (context, index) {
                return Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildVideoTile(
                    service,
                    participants[index + 1],
                    isMainView: false,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVideoTile(
      WebRTCMeshMeetingService service,
      MeshParticipant participant, {
        required bool isMainView,
      }) {
    final renderer = service.getRendererForParticipant(participant.id);
    final isCurrentSpeaker = _currentSpeakerId == participant.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentSpeaker
              ? Colors.red
              : (participant.isLocal
              ? GcbAppTheme.primary.withOpacity(0.6)
              : Colors.grey[700]!),
          width: isCurrentSpeaker ? 3 : 2,
        ),
        boxShadow: isCurrentSpeaker
            ? [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Video content
            if (renderer != null && participant.isVideoEnabled)
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
                  child: Container(
                    padding: EdgeInsets.all(isMainView ? 40 : 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: isMainView ? 48 : 24,
                    ),
                  ),
                ),
              ),

            // Participant name overlay
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  participant.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMainView ? 14 : 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Media status indicators
            Positioned(
              top: 12,
              left: 12,
              child: Row(
                children: [
                  if (!participant.isAudioEnabled)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_off, color: Colors.white, size: 12),
                    ),
                  if (!participant.isVideoEnabled)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_off, color: Colors.white, size: 12),
                    ),
                ],
              ),
            ),

            // Speaking indicator
            if (isCurrentSpeaker)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🎯 GOOGLE CLOUD TRANSLATION OVERLAY
  Widget _buildGoogleCloudTranslationOverlay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.grey[900]!.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with enhanced info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Cloud Translation',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Target: ${_getLanguageName(widget.targetLanguage ?? 'en')}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicators
              if (_isListening)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_totalTranslations',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isListening ? Icons.circle : Icons.circle_outlined,
                  color: _isListening ? Colors.green : Colors.grey,
                  size: 8,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _speechServiceStatus,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_lastTranslationTime.isNotEmpty)
                  Text(
                    _lastTranslationTime,
                    style: const TextStyle(color: Colors.grey, fontSize: 9),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Translation results
          if (_speechResults.isEmpty)
            _buildEmptyTranslationState()
          else
            _buildTranslationResults(),
        ],
      ),
    );
  }

  Widget _buildEmptyTranslationState() {
    return Center(
      child: Column(
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 12),
          Text(
            _isListening
                ? '🎤 Listening for speech...\nSpeak now to see real-time Google Cloud translations'
                : 'Speech recognition inactive\nTap "Start STT" to begin real-time translation',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (!_isListening) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSTTInitialized ? _startRealSpeechRecognition : null,
              icon: const Icon(Icons.cloud, size: 18),
              label: const Text('Start Google Cloud STT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GcbAppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranslationResults() {
    return Column(
      children: _speechResults.take(3).map((result) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: result.userId == _getCurrentUserId()
                ? Colors.blue.withOpacity(0.15)
                : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.green.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker info
              Row(
                children: [
                  Icon(
                    result.userId == _getCurrentUserId() ? Icons.account_circle : Icons.person,
                    color: result.userId == _getCurrentUserId() ? Colors.blue : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.userId == _getCurrentUserId() ? 'You' : result.userName,
                    style: TextStyle(
                      color: result.userId == _getCurrentUserId() ? Colors.blue : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.detectedLanguage.toUpperCase(),
                      style: const TextStyle(color: Colors.blue, fontSize: 9),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.cloud_done, color: Colors.green, size: 12),
                ],
              ),

              const SizedBox(height: 8),

              // Translation text
              Text(
                _getDisplayTextForUser(result),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 6),

              // Metadata
              Row(
                children: [
                  Text(
                    'Confidence: ${(result.confidence * 100).toInt()}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Google Cloud',
                    style: const TextStyle(color: Colors.green, fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimestamp(result.timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 🎯 ENHANCED BOTTOM CONTROLS
  Widget _buildEnhancedBottomControls(WebRTCMeshMeetingService service) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.4),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic control
          _buildEnhancedControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: service.isAudioEnabled,
            onPressed: () async => await service.toggleAudio(),
          ),

          // Camera control
          _buildEnhancedControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: service.isVideoEnabled,
            onPressed: () async => await service.toggleVideo(),
          ),

          // Speech recognition control
          _buildEnhancedControlButton(
            icon: _isListening ? Icons.pause : Icons.cloud,
            label: _isListening ? 'Stop STT' : 'Start STT',
            isActive: _isListening,
            onPressed: _isSTTInitialized
                ? () async {
              if (_isListening) {
                await _stopSpeechRecognition();
              } else {
                await _startRealSpeechRecognition();
              }
            }
                : null,
          ),

          // Translation history
          _buildEnhancedControlButton(
            icon: Icons.history,
            label: 'History',
            onPressed: () => _showTranslationHistory(),
            badge: _speechResults.isNotEmpty ? _speechResults.length.toString() : null,
          ),

          // Toggle overlay
          _buildEnhancedControlButton(
            icon: _showTranslationOverlay ? Icons.visibility : Icons.visibility_off,
            label: 'Overlay',
            isActive: _showTranslationOverlay,
            onPressed: () {
              setState(() {
                _showTranslationOverlay = !_showTranslationOverlay;
              });
            },
          ),

          // End call
          _buildEnhancedControlButton(
            icon: Icons.call_end,
            label: 'End Call',
            isDestructive: true,
            onPressed: () async => await _showEndCallDialog(service),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isDestructive = false,
    VoidCallback? onPressed,
    String? badge,
  }) {
    Color backgroundColor;
    Color iconColor;

    if (onPressed == null) {
      backgroundColor = Colors.grey[800]!;
      iconColor = Colors.grey[600]!;
    } else if (isDestructive) {
      backgroundColor = Colors.red;
      iconColor = Colors.white;
    } else if (isActive) {
      backgroundColor = GcbAppTheme.primary;
      iconColor = Colors.white;
    } else {
      backgroundColor = Colors.grey[800]!;
      iconColor = Colors.white;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: onPressed,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: onPressed != null
                      ? [
                    BoxShadow(
                      color: backgroundColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            // Badge
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
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
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white : Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 🎯 HELPER METHODS
  String _getDisplayTextForUser(SpeechResult result) {
    final myUserId = _getCurrentUserId();

    // If this is my own speech, show original text
    if (result.userId == myUserId) {
      return result.originalText;
    }

    // For others' speech, show translation in my target language
    final myTargetLanguage = widget.targetLanguage ?? 'en';

    // If speaker's language is same as my target language, show original
    if (result.detectedLanguage == myTargetLanguage) {
      return result.originalText;
    }

    // Otherwise, show translation to my target language
    return result.translations[myTargetLanguage] ?? result.originalText;
  }

  String _getCurrentUserId() {
    try {
      return context.read<WebRTCMeshMeetingService>().userId ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  String _getLanguageName(String languageCode) {
    const languageNames = {
      'en': 'English',
      'vi': 'Vietnamese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'th': 'Thai',
      'id': 'Indonesian',
      'ms': 'Malay',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'ar': 'Arabic',
      'hi': 'Hindi',
    };
    return languageNames[languageCode] ?? languageCode.toUpperCase();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  // 📊 TRANSLATION HISTORY MODAL
  void _showTranslationHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GcbAppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  const Icon(Icons.cloud, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Google Cloud Translation History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_speechResults.length} results',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Results list
              Expanded(
                child: _speechResults.isEmpty
                    ? const Center(
                  child: Text(
                    'No translation history yet\nStart speaking to see results',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _speechResults.length,
                  itemBuilder: (context, index) {
                    final result = _speechResults[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: result.userId == _getCurrentUserId()
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(
                                result.userId == _getCurrentUserId()
                                    ? Icons.account_circle
                                    : Icons.person,
                                color: result.userId == _getCurrentUserId()
                                    ? Colors.blue
                                    : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                result.userId == _getCurrentUserId()
                                    ? 'You'
                                    : result.userName,
                                style: TextStyle(
                                  color: result.userId == _getCurrentUserId()
                                      ? Colors.blue
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  result.detectedLanguage.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.blue, fontSize: 10),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(result.timestamp),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Original text
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Original:',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  result.originalText,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Translation
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Translation (${_getLanguageName(widget.targetLanguage ?? 'en')}):',
                                  style: const TextStyle(
                                      color: Colors.blue, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getDisplayTextForUser(result),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Metadata
                          Row(
                            children: [
                              const Icon(Icons.cloud_done,
                                  color: Colors.green, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Google Cloud',
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 10),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Confidence: ${(result.confidence * 100).toInt()}%',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔚 END CALL DIALOG
  Future<void> _showEndCallDialog(WebRTCMeshMeetingService service) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.call_end, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text('End Meeting', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to end this meeting?\n\nAll translation history will be saved.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Stop speech recognition
      if (_isListening) {
        await _stopSpeechRecognition();
      }

      // Leave meeting
      await service.leaveMeeting();

      // Navigate back
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  void dispose() {
    if (_isListening) {
      _stopSpeechRecognition();
    }
    super.dispose();
  }
}