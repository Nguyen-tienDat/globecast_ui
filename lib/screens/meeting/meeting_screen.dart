// lib/screens/meeting/meeting_screen.dart - CLEAN PRODUCTION VERSION
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/models/translation_models.dart';
import 'widgets/live_subtitle_overlay.dart';
import 'widgets/translation_history_panel.dart';
import 'widgets/language_settings_panel.dart';

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
  // UI state
  bool _showTranslationHistory = false;
  bool _showLanguageSettings = false;
  bool _isJoining = false;

  // Services
  TranslationService? _translationService;

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

      print('🎯 Initializing meeting with real-time translation...');

      // Set user details
      if (widget.displayName != null) {
        webrtcService.setUserDetails(displayName: widget.displayName!);
      }

      // Join meeting
      final meetingCode = widget.code ?? widget.meetingId;
      if (meetingCode != null) {
        await webrtcService.joinMeeting(meetingId: meetingCode);

        // Initialize translation service
        _translationService = TranslationService();
        await _translationService!.initializeForMeeting(
            meetingCode,
            webrtcService.userId ?? 'unknown'
        );

        // Set user's language preferences
        if (widget.targetLanguage != null) {
          await _translationService!.updateDisplayLanguage(widget.targetLanguage!);
          await _translationService!.updateSpeakingLanguage(widget.targetLanguage!);
        }

        // Connect services
        speechService.setTranslationService(_translationService!);
        speechService.setUserContext(
            webrtcService.userId ?? 'unknown',
            widget.displayName ?? 'User'
        );
        webrtcService.setSpeechService(speechService);

        print('✅ Meeting initialized with multilingual support');
      } else {
        throw Exception('No meeting code provided');
      }

    } catch (e) {
      print('❌ Error joining meeting: $e');
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

  @override
  void dispose() {
    _translationService?.dispose();
    super.dispose();
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

          return Stack(
            children: [
              // Main meeting content
              Column(
                children: [
                  _buildTopBar(service),
                  Expanded(
                    child: _buildVideoGrid(service),
                  ),
                  _buildBottomControls(service),
                ],
              ),

              // Live subtitle overlay
              if (_translationService != null)
                ChangeNotifierProvider.value(
                  value: _translationService!,
                  child: const LiveSubtitleOverlay(),
                ),

              // Translation history panel
              if (_showTranslationHistory && _translationService != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: ChangeNotifierProvider.value(
                    value: _translationService!,
                    child: TranslationHistoryPanel(
                      onClose: () {
                        setState(() {
                          _showTranslationHistory = false;
                        });
                      },
                    ),
                  ),
                ),

              // Language settings panel
              if (_showLanguageSettings && _translationService != null)
                Positioned.fill(
                  child: ChangeNotifierProvider.value(
                    value: _translationService!,
                    child: LanguageSettingsPanel(
                      onClose: () {
                        setState(() {
                          _showLanguageSettings = false;
                        });
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: GcbAppTheme.background,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: GcbAppTheme.primary,
            ),
            SizedBox(height: 24),
            Text(
              'Joining meeting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Setting up real-time translation',
              style: TextStyle(
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
                  Icons.meeting_room,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                  child: Text(
                    service.meetingId ?? widget.code ?? 'Meeting',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Translation status
          if (_translationService != null)
            Flexible(
              child: ChangeNotifierProvider.value(
                value: _translationService!,
                child: Consumer<TranslationService>(
                  builder: (context, translationService, child) {
                    final userPref = translationService.userPreference;
                    if (userPref == null) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GcbAppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: GcbAppTheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Speech status indicator
                          Consumer<MultilingualSpeechService>(
                            builder: (context, speechService, child) {
                              return Icon(
                                speechService.isListening ? Icons.mic : Icons.translate,
                                color: speechService.isListening ? Colors.red : GcbAppTheme.primary,
                                size: 14,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            SupportedLanguages.getLanguageFlag(userPref.displayLanguage),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              SupportedLanguages.getLanguageName(userPref.displayLanguage),
                              style: const TextStyle(
                                color: GcbAppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          const Spacer(),

          // Connection status and participants
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Connection status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Participants count
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
                      Icons.people,
                      color: GcbAppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${service.participants.length}',
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
        ],
      ),
    );
  }

  Widget _buildVideoGrid(WebRTCMeshMeetingService service) {
    final participants = service.participants;

    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'No participants',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: _buildGridLayout(service, participants),
    );
  }

  Widget _buildGridLayout(WebRTCMeshMeetingService service, List<MeshParticipant> participants) {
    if (participants.length == 1) {
      return _buildVideoTile(service, participants[0]);
    } else if (participants.length == 2) {
      return Column(
        children: participants.map((p) =>
            Expanded(child: _buildVideoTile(service, p))
        ).toList(),
      );
    } else if (participants.length <= 4) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          return _buildVideoTile(service, participants[index]);
        },
      );
    } else {
      // Support 5+ participants (mesh topology can handle up to 6-8)
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          return _buildVideoTile(service, participants[index]);
        },
      );
    }
  }

  Widget _buildVideoTile(WebRTCMeshMeetingService service, MeshParticipant participant) {
    final renderer = service.getRendererForParticipant(participant.id);

    return Container(
      margin: const EdgeInsets.all(4),
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
            // Placeholder when video is disabled
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

            // Participant info overlay
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
                child: Row(
                  children: [
                    Icon(
                      participant.isAudioEnabled ? Icons.mic : Icons.mic_off,
                      color: participant.isAudioEnabled ? Colors.white : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
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
                    if (participant.isHost)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GcbAppTheme.primary,
                          borderRadius: BorderRadius.circular(10),
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

            // Video disabled indicator
            if (!participant.isVideoEnabled)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.videocam_off,
                    color: Colors.red,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
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

          // Speech recognition button
          Consumer<MultilingualSpeechService>(
            builder: (context, speechService, child) {
              return _buildControlButton(
                icon: speechService.isListening
                    ? Icons.mic_external_on
                    : speechService.getSpeechStatus() == 'ready'
                    ? Icons.mic_external_off
                    : Icons.mic_off,
                label: speechService.isListening
                    ? 'Speaking'
                    : speechService.getSpeechStatus() == 'ready'
                    ? 'Speech'
                    : 'STT Off',
                isActive: speechService.isListening,
                badgeText: speechService.getSpeechStatus() == 'error' ? '!' : null,
                onPressed: () async {
                  if (speechService.getSpeechStatus() == 'error') {
                    speechService.resetErrorState();
                  }
                  await speechService.toggleListening();
                },
              );
            },
          ),

          // Translation history button
          _buildControlButton(
            icon: Icons.history,
            label: 'History',
            isActive: _showTranslationHistory,
            badgeText: _translationService?.transcriptions.length.toString(),
            onPressed: () {
              setState(() {
                _showTranslationHistory = !_showTranslationHistory;
                if (_showTranslationHistory) {
                  _showLanguageSettings = false;
                }
              });
            },
          ),

          // Language settings button
          _buildControlButton(
            icon: Icons.language,
            label: 'Language',
            isActive: _showLanguageSettings,
            onPressed: () {
              setState(() {
                _showLanguageSettings = !_showLanguageSettings;
                if (_showLanguageSettings) {
                  _showTranslationHistory = false;
                }
              });
            },
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
    String? badgeText,
    required VoidCallback onPressed,
  }) {
    Color backgroundColor;
    Color iconColor;

    if (isDestructive) {
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
            ),

            // Status badge
            if (badgeText != null && badgeText.isNotEmpty && badgeText != '0')
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeText == '!' ? Colors.red : GcbAppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        content: Text(
          service.isHost
              ? 'Are you sure you want to end this meeting for everyone?'
              : 'Are you sure you want to leave this meeting?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(service.isHost ? 'End Meeting' : 'Leave'),
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
}