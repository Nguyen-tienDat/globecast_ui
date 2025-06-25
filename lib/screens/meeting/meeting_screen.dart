// lib/screens/meeting/meeting_screen.dart - FIXED UI AND VIDEO CALL
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/models/translation_models.dart';

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
  bool _isListening = false;

  // 🎯 REAL-TIME TRANSLATION STATE
  final List<RealtimeTranscription> _liveTranscriptions = [];
  String? _currentSpeakerId;

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
        print('🎯 Initializing meeting with real-time translation...');
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
        speechService.setPreferredLanguage(widget.targetLanguage ?? 'en');

        // 🎯 ENSURE ALL COMMON LANGUAGES ARE IN TARGET LIST
        speechService.setTargetLanguages(['en', 'vi', 'zh', 'ja', 'ko', 'es', 'fr', 'de', 'th', 'id', 'ms', 'ar', 'hi']);

        // Connect services
        webrtcService.setSpeechService(speechService);

        // Initialize STT after WebRTC connection
        await _initializeSTTService(speechService);

        // 🎯 SETUP REAL-TIME TRANSLATION LISTENER
        _setupRealtimeTranslationListener(speechService);

        if (kDebugMode) {
          print('✅ Meeting initialized with real-time translation');
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

  // 🎯 SETUP REAL-TIME TRANSLATION LISTENER
  void _setupRealtimeTranslationListener(MultilingualSpeechService speechService) {
    speechService.speechResultStream.listen((result) {
      setState(() {
        final myUserId = context.read<WebRTCMeshMeetingService>().userId;

        // Create real-time transcription with corrected display logic
        final transcription = RealtimeTranscription(
          id: '${result.userId}_${result.timestamp.millisecondsSinceEpoch}',
          speakerId: result.userId,
          speakerName: result.userName,
          originalText: result.originalText,
          detectedLanguage: result.detectedLanguage,
          displayText: _getDisplayTextForUser(result, myUserId),
          timestamp: result.timestamp,
          confidence: result.confidence,
          isFinal: result.isFinal,
          isFromMe: result.userId == myUserId,
        );

        // Update live transcriptions
        _updateLiveTranscriptions(transcription);
      });

      if (kDebugMode) {
        final myUserId = context.read<WebRTCMeshMeetingService>().userId;
        final myTargetLang = widget.targetLanguage ?? 'en';

        print('📝 Real-time translation received:');
        print('   Speaker: ${result.userName} (ID: ${result.userId})');
        print('   My User ID: $myUserId');
        print('   Original (${result.detectedLanguage}): "${result.originalText}"');
        print('   My Target Language: $myTargetLang');
        print('   Translation for me: "${result.translations[myTargetLang] ?? 'No translation'}"');
        print('   Available translations: ${result.translations.keys.toList()}');

        if (result.userId == myUserId) {
          print('   ✅ This is MY speech - showing original');
        } else {
          print('   🌐 This is OTHER\'S speech - showing translation');
        }
      }
    });
  }

  // 🎯 GET DISPLAY TEXT FOR CURRENT USER - FIXED LOGIC
  String _getDisplayTextForUser(SpeechResult result, String? myUserId) {
    // If this is my own speech, show original text (no self-translation)
    if (result.userId == myUserId) {
      return result.originalText;
    }

    // For others' speech, show translation in MY target language
    final myTargetLanguage = widget.targetLanguage ?? 'en';

    // If speaker's language is same as my target language, show original
    if (result.detectedLanguage == myTargetLanguage) {
      return result.originalText;
    }

    // Otherwise, show translation to my target language
    return result.translations[myTargetLanguage] ?? result.originalText;
  }

  // 🎯 UPDATE LIVE TRANSCRIPTIONS
  void _updateLiveTranscriptions(RealtimeTranscription transcription) {
    // Find existing transcription from same speaker
    final existingIndex = _liveTranscriptions.indexWhere(
          (t) => t.speakerId == transcription.speakerId && !t.isFinal,
    );

    if (existingIndex != -1 && !transcription.isFinal) {
      // Update existing partial transcription
      _liveTranscriptions[existingIndex] = transcription;
    } else {
      // Add new transcription
      _liveTranscriptions.insert(0, transcription);

      // Keep only last 10 transcriptions for performance
      if (_liveTranscriptions.length > 10) {
        _liveTranscriptions.removeLast();
      }
    }

    // Update current speaker
    if (!transcription.isFinal && transcription.originalText.isNotEmpty) {
      _currentSpeakerId = transcription.speakerId;
    } else if (transcription.isFinal) {
      _currentSpeakerId = null;
    }
  }

  Future<void> _initializeSTTService(MultilingualSpeechService speechService) async {
    if (_isSTTInitialized || _isInitializingSTT) return;

    setState(() {
      _isInitializingSTT = true;
    });

    try {
      if (kDebugMode) {
        print('🎤 Initializing real-time speech service...');
      }

      await speechService.initialize();

      if (speechService.isAvailable) {
        _isSTTInitialized = true;
        if (kDebugMode) {
          print('✅ Real-time speech service ready');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Real-time translation ready!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (kDebugMode) {
          print('❌ Speech service not available');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing speech service: $e');
      }
    } finally {
      setState(() {
        _isInitializingSTT = false;
      });
    }
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
              // 🎯 TOP STATUS BAR
              _buildTopStatusBar(service),

              // 🎯 MAIN VIDEO AREA
              Expanded(
                child: Stack(
                  children: [
                    // Main video grid
                    _buildMainVideoArea(service),

                    // Translation overlay at bottom
                    Positioned(
                      bottom: 80,
                      left: 16,
                      right: 16,
                      child: _buildTranslationOverlay(),
                    ),
                  ],
                ),
              ),

              // 🎯 BOTTOM CONTROLS
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
            const CircularProgressIndicator(color: GcbAppTheme.primary),
            const SizedBox(height: 24),
            Text(
              _isJoining ? 'Joining meeting...' : 'Setting up services...',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _isInitializingSTT ? 'Initializing real-time translation...' : 'Please wait',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 TOP STATUS BAR LIKE IN IMAGE
  Widget _buildTopStatusBar(WebRTCMeshMeetingService service) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        children: [
          // Meeting ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.code ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 4),
                Text('Connected', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const Spacer(),

          // Participants count
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
                Text('${service.participants.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 MAIN VIDEO AREA LIKE IN IMAGE
  Widget _buildMainVideoArea(WebRTCMeshMeetingService service) {
    final participants = service.participants;

    if (participants.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text('Waiting for participants...', style: TextStyle(color: Colors.grey[400], fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Main speaker view (larger)
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            child: _buildVideoTile(service, participants.first, isMainView: true),
          ),
        ),

        // Other participants (smaller, horizontal)
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
                  child: _buildVideoTile(service, participants[index + 1], isMainView: false),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVideoTile(WebRTCMeshMeetingService service, MeshParticipant participant, {required bool isMainView}) {
    final renderer = service.getRendererForParticipant(participant.id);
    final isCurrentSpeaker = _currentSpeakerId == participant.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentSpeaker ? Colors.red : (participant.isLocal ? GcbAppTheme.primary.withOpacity(0.5) : Colors.grey[700]!),
          width: isCurrentSpeaker ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
                    padding: EdgeInsets.all(isMainView ? 30 : 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.grey[400],
                      size: isMainView ? 40 : 20,
                    ),
                  ),
                ),
              ),

            // Participant name overlay
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  participant.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMainView ? 14 : 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Speaking indicator
            if (isCurrentSpeaker)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🎯 TRANSLATION OVERLAY LIKE IN IMAGE
  Widget _buildTranslationOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.translate, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Live Translations',
                style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_liveTranscriptions.length}',
                  style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Everything translated to ${SupportedLanguages.getLanguageName(widget.targetLanguage ?? 'en')}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),

          const SizedBox(height: 12),

          // Recent translations
          if (_liveTranscriptions.isEmpty)
            const Center(
              child: Text(
                'No conversations yet\nStart speaking to see real-time translations',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else
            ...(_liveTranscriptions.take(2).map((transcription) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: transcription.isFromMe ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        transcription.isFromMe ? 'You' : transcription.speakerName,
                        style: TextStyle(
                          color: transcription.isFromMe ? Colors.blue : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (transcription.isFinal)
                        const Icon(Icons.check_circle, color: Colors.green, size: 10)
                      else
                        const Icon(Icons.radio_button_checked, color: Colors.orange, size: 10),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transcription.displayText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontStyle: transcription.isFinal ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ))),
        ],
      ),
    );
  }

  // 🎯 BOTTOM CONTROLS LIKE IN IMAGE
  Widget _buildBottomControls(WebRTCMeshMeetingService service) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20,
      ),
      color: Colors.black.withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic button
          _buildControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: service.isAudioEnabled,
            onPressed: () async => await service.toggleAudio(),
          ),

          // Camera button
          _buildControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: service.isVideoEnabled,
            onPressed: () async => await service.toggleVideo(),
          ),

          // STT button
          _buildControlButton(
            icon: _isListening ? Icons.pause : Icons.play_arrow,
            label: _isListening ? 'STT Off' : 'Start Listening',
            isActive: _isListening,
            onPressed: _isSTTInitialized ? () async {
              if (_isListening) {
                await _stopListening();
              } else {
                await _startListening();
              }
            } : null,
          ),

          // History button
          _buildControlButton(
            icon: Icons.history,
            label: 'History',
            onPressed: () => _showTranslationHistory(),
          ),

          // Translations button
          _buildControlButton(
            icon: Icons.translate,
            label: 'Translations',
            onPressed: () => _showTranslationHistory(),
          ),

          // Clear button
          _buildControlButton(
            icon: Icons.clear_all,
            label: 'Clear',
            onPressed: _liveTranscriptions.isNotEmpty ? () {
              setState(() => _liveTranscriptions.clear());
            } : null,
          ),

          // End call button
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End Call',
            isDestructive: true,
            onPressed: () async => await _showEndCallDialog(service),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: onPressed != null ? Colors.white : Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 🎯 START LISTENING
  Future<void> _startListening() async {
    try {
      final speechService = context.read<MultilingualSpeechService>();

      setState(() => _isListening = true);

      await speechService.startListening(
        meetingId: widget.code ?? widget.meetingId,
        userId: context.read<WebRTCMeshMeetingService>().userId,
        preferredLanguage: widget.targetLanguage ?? 'en',
      );

      if (kDebugMode) {
        print('🎤 Started listening - settings: userId=${context.read<WebRTCMeshMeetingService>().userId}, targetLang=${widget.targetLanguage}');
      }

    } catch (e) {
      setState(() => _isListening = false);
      if (kDebugMode) print('❌ Error starting listening: $e');
    }
  }

  // 🎯 STOP LISTENING
  Future<void> _stopListening() async {
    try {
      final speechService = context.read<MultilingualSpeechService>();
      await speechService.stopListening();
      setState(() {
        _isListening = false;
        _currentSpeakerId = null;
      });
    } catch (e) {
      if (kDebugMode) print('❌ Error stopping listening: $e');
    }
  }

  void _showTranslationHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GcbAppTheme.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Translation History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _liveTranscriptions.length,
                  itemBuilder: (context, index) {
                    final transcription = _liveTranscriptions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: transcription.isFromMe ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                transcription.isFromMe ? 'You' : transcription.speakerName,
                                style: TextStyle(color: transcription.isFromMe ? Colors.blue : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(_formatTimestamp(transcription.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(transcription.displayText, style: const TextStyle(color: Colors.white, fontSize: 14)),
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

  Future<void> _showEndCallDialog(WebRTCMeshMeetingService service) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text('End Meeting', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to end this meeting?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Meeting'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (_isListening) await _stopListening();
      await service.leaveMeeting();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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

// 🎯 REALTIME TRANSCRIPTION MODEL
class RealtimeTranscription {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String detectedLanguage;
  final String displayText; // Text shown to current user (original or translated)
  final DateTime timestamp;
  final double confidence;
  final bool isFinal;
  final bool isFromMe;

  RealtimeTranscription({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.detectedLanguage,
    required this.displayText,
    required this.timestamp,
    required this.confidence,
    required this.isFinal,
    required this.isFromMe,
  });
}