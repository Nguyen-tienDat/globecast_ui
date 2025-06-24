// lib/screens/meeting/meeting_screen.dart - SIMPLIFIED FOR GOOGLE CLOUD TESTING
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
  bool _isJoining = false;
  bool _isSTTInitialized = false;
  bool _isInitializingSTT = false;

  // Track speech results for display
  final List<SpeechResult> _speechResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMeeting();
    });
  }

  Future<void> _initializeMeeting() async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final speechService = context.read<MultilingualSpeechService>();

      if (kDebugMode) {
        print('🎯 Initializing meeting with Google Cloud STT...');
      }

      // Set user details
      if (widget.displayName != null) {
        webrtcService.setUserDetails(displayName: widget.displayName!);
      }

      // Join meeting first
      final meetingCode = widget.code ?? widget.meetingId;
      if (meetingCode != null) {
        await webrtcService.joinMeeting(meetingId: meetingCode);

        // Set speech service context
        speechService.setUserContext(
            webrtcService.userId ?? 'unknown',
            widget.displayName ?? 'User'
        );
        speechService.setTranslationContext(meetingCode);

        // Connect services
        webrtcService.setSpeechService(speechService);

        // Initialize STT after WebRTC connection
        await _initializeSTTService(speechService);

        // Listen for speech results
        _listenForSpeechResults(speechService);

        if (kDebugMode) {
          print('✅ Meeting initialized with Google Cloud STT');
        }
      } else {
        throw Exception('No meeting code provided');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error joining meeting: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _initializeSTTService(MultilingualSpeechService speechService) async {
    if (_isSTTInitialized || _isInitializingSTT) return;

    setState(() {
      _isInitializingSTT = true;
    });

    try {
      if (kDebugMode) {
        print('🎤 Initializing Google Cloud STT service...');
      }

      await speechService.initialize();

      if (speechService.isAvailable) {
        _isSTTInitialized = true;
        if (kDebugMode) {
          print('✅ Google Cloud STT service ready');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Google Cloud Speech & Translation ready'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (kDebugMode) {
          print('❌ Google Cloud STT service not available');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Google Cloud services not available'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Google Cloud STT: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Google Cloud setup failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeSTTService(speechService),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isInitializingSTT = false;
      });
    }
  }

  void _listenForSpeechResults(MultilingualSpeechService speechService) {
    speechService.speechResultStream.listen((result) {
      setState(() {
        _speechResults.add(result);
        // Keep only last 10 results for display
        if (_speechResults.length > 10) {
          _speechResults.removeAt(0);
        }
      });

      if (kDebugMode) {
        print('📝 Speech result received:');
        print('   Original: ${result.originalText}');
        print('   Language: ${result.detectedLanguage}');
        print('   Vietnamese: ${result.translations['vi']}');
        print('   Chinese: ${result.translations['zh']}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: Consumer<WebRTCMeshMeetingService>(
        builder: (context, service, child) {
          if (_isJoining || !service.isMeetingActive) {
            return _buildLoadingScreen();
          }

          return Column(
            children: [
              _buildTopBar(service),
              Expanded(
                child: Row(
                  children: [
                    // Video grid
                    Expanded(
                      flex: 2,
                      child: _buildVideoGrid(service),
                    ),
                    // Speech results panel
                    Container(
                      width: 400,
                      decoration: BoxDecoration(
                        color: GcbAppTheme.surface,
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey[700]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildSpeechResultsPanel(),
                    ),
                  ],
                ),
              ),
              _buildBottomControls(service),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: GcbAppTheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: GcbAppTheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _isJoining ? 'Joining meeting...' : 'Setting up services...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isInitializingSTT
                  ? 'Initializing Google Cloud services...'
                  : _isJoining
                  ? 'Connecting to real-time translation'
                  : 'Please wait',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(WebRTCMeshMeetingService service) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: GcbAppTheme.background.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Meeting info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Google Cloud Meeting',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Google Cloud status
          Consumer<MultilingualSpeechService>(
            builder: (context, speechService, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getCloudStatusColor(speechService).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getCloudStatusColor(speechService).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCloudStatusIcon(speechService),
                      color: _getCloudStatusColor(speechService),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getCloudStatusText(speechService),
                      style: TextStyle(
                        color: _getCloudStatusColor(speechService),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),

          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GcbAppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.translate,
                  color: GcbAppTheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_speechResults.length} results',
                  style: const TextStyle(
                    color: GcbAppTheme.primary,
                    fontSize: 14,
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

  Color _getCloudStatusColor(MultilingualSpeechService speechService) {
    if (speechService.isListening) return Colors.red;
    if (_isInitializingSTT) return Colors.orange;
    if (speechService.isAvailable && _isSTTInitialized) return Colors.green;
    if (speechService.speechStatus == 'error') return Colors.red;
    return Colors.grey;
  }

  IconData _getCloudStatusIcon(MultilingualSpeechService speechService) {
    if (speechService.isListening) return Icons.cloud_upload;
    if (_isInitializingSTT) return Icons.cloud_sync;
    if (speechService.isAvailable && _isSTTInitialized) return Icons.cloud_done;
    if (speechService.speechStatus == 'error') return Icons.cloud_off;
    return Icons.cloud_queue;
  }

  String _getCloudStatusText(MultilingualSpeechService speechService) {
    if (speechService.isListening) return 'Processing';
    if (_isInitializingSTT) return 'Connecting';
    if (speechService.isAvailable && _isSTTInitialized) return 'Cloud Ready';
    if (speechService.speechStatus == 'error') return 'Error';
    return 'Offline';
  }

  Widget _buildVideoGrid(WebRTCMeshMeetingService service) {
    final participants = service.participants;

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No participants yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          return _buildVideoTile(service, participants[index]);
        },
      ),
    );
  }

  Widget _buildVideoTile(WebRTCMeshMeetingService service, MeshParticipant participant) {
    final renderer = service.getRendererForParticipant(participant.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: participant.isLocal
              ? GcbAppTheme.primary.withOpacity(0.5)
              : Colors.grey[700]!,
          width: participant.isLocal ? 2 : 1,
        ),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: 40,
                    ),
                  ),
                ),
              ),

            // Participant info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechResultsPanel() {
    return Column(
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GcbAppTheme.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[700]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_queue,
                color: GcbAppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Google Cloud Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_speechResults.length}',
                  style: const TextStyle(
                    color: GcbAppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Speech results list
        Expanded(
          child: _speechResults.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No results yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start testing Google Cloud\nSpeech & Translation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _speechResults.length,
            itemBuilder: (context, index) {
              return _buildSpeechResultItem(_speechResults[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpeechResultItem(SpeechResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GcbAppTheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and confidence
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.detectedLanguage.toUpperCase(),
                  style: const TextStyle(
                    color: GcbAppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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
                  '${(result.confidence * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimestamp(result.timestamp),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Original text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.originalText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Translations
          ...result.translations.entries.where((entry) =>
          entry.key != result.detectedLanguage && entry.value.isNotEmpty
          ).map((entry) {
            final languageNames = {
              'en': 'English',
              'vi': 'Vietnamese',
              'zh': 'Chinese',
              'ja': 'Japanese',
              'ko': 'Korean',
              'th': 'Thai',
              'id': 'Indonesian',
              'ms': 'Malay',
            };

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GcbAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GcbAppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageNames[entry.key] ?? entry.key.toUpperCase(),
                    style: const TextStyle(
                      color: GcbAppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBottomControls(WebRTCMeshMeetingService service) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: GcbAppTheme.background.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone button
          _buildControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: service.isAudioEnabled,
            onPressed: () async {
              await service.toggleAudio();
            },
          ),

          // Camera button
          _buildControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: service.isVideoEnabled,
            onPressed: () async {
              await service.toggleVideo();
            },
          ),

          // Google Cloud Speech Test Button
          Consumer<MultilingualSpeechService>(
            builder: (context, speechService, child) {
              return _buildControlButton(
                icon: speechService.isListening ? Icons.cloud_upload : Icons.cloud_queue,
                label: speechService.isListening ? 'Testing...' : 'Test STT',
                isActive: speechService.isListening,
                onPressed: _isSTTInitialized ? () async {
                  await _handleGoogleCloudTest(speechService);
                } : () {
                  _showCloudNotReadyDialog();
                },
              );
            },
          ),

          // Translation Test Button
          Consumer<MultilingualSpeechService>(
            builder: (context, speechService, child) {
              return _buildControlButton(
                icon: Icons.translate,
                label: 'Test Translation',
                onPressed: _isSTTInitialized ? () async {
                  await _showTranslationTestDialog(speechService);
                } : () {
                  _showCloudNotReadyDialog();
                },
              );
            },
          ),

          // Clear Results Button
          _buildControlButton(
            icon: Icons.clear_all,
            label: 'Clear',
            onPressed: _speechResults.isNotEmpty ? () {
              setState(() {
                _speechResults.clear();
              });
            } : null,
          ),

          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End Call',
            isDestructive: true,
            onPressed: () async {
              await _showEndCallDialog(service);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isDestructive = false,
    VoidCallback? onPressed,
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
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: onPressed != null ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handleGoogleCloudTest(MultilingualSpeechService speechService) async {
    try {
      if (speechService.isListening) {
        await speechService.stopListening();
      } else {
        await speechService.startListening(
          meetingId: widget.code ?? widget.meetingId,
          userId: _currentUserId,
          preferredLanguage: widget.targetLanguage ?? 'en',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Cloud test error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showTranslationTestDialog(MultilingualSpeechService speechService) async {
    final textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Test Google Cloud Translation',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter text to translate...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'This will detect language and translate to all supported languages using Google Cloud.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                await speechService.testTranslation(textController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GcbAppTheme.primary,
            ),
            child: const Text('Test Translation'),
          ),
        ],
      ),
    );

    textController.dispose();
  }

  void _showCloudNotReadyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Google Cloud Not Ready',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please wait for Google Cloud services to initialize.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEndCallDialog(WebRTCMeshMeetingService service) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'End Meeting',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to end this meeting?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );

    if (result == true) {
      await service.leaveMeeting();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
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

  String get _currentUserId => context.read<WebRTCMeshMeetingService>().userId ?? 'unknown';
}