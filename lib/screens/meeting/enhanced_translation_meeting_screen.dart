// lib/screens/meeting/enhanced_translation_meeting_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_meeting_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/models/translation_models.dart';

import '../../services/multilingual_speech_service.dart';

class EnhancedTranslationMeetingScreen extends StatefulWidget {
  final String meetingId;
  final String userName;
  final String speakingLanguage;
  final String displayLanguage;

  const EnhancedTranslationMeetingScreen({
    super.key,
    required this.meetingId,
    required this.userName,
    required this.speakingLanguage,
    required this.displayLanguage,
  });

  @override
  State<EnhancedTranslationMeetingScreen> createState() => _EnhancedTranslationMeetingScreenState();
}

class _EnhancedTranslationMeetingScreenState extends State<EnhancedTranslationMeetingScreen> {
  // 🎯 STATE MANAGEMENT
  TranslationMeetingService? _translationService;
  bool _isInitializing = true;
  bool _showTranslationOverlay = true;
  bool _showLanguageSettings = false;
  String _initializationStatus = 'Connecting...';

  // 🎯 REAL-TIME TRANSLATION STATE
  final List<TranslationMessage> _displayMessages = [];
  String? _currentSpeakerId;
  int _totalTranslations = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTranslationMeeting();
    });
  }

  // 🚀 INITIALIZE COMPLETE TRANSLATION MEETING
  Future<void> _initializeTranslationMeeting() async {
    try {
      setState(() {
        _initializationStatus = 'Setting up translation services...';
      });

      // Get integrated services
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final speechService = context.read<MultilingualSpeechService>();

      // Create integrated translation service
      _translationService = TranslationMeetingService(
        webrtcService: webrtcService,
        speechService: speechService,
      );

      setState(() {
        _initializationStatus = 'Initializing meeting with real-time translation...';
      });

      // Initialize complete translation meeting
      await _translationService!.initializeTranslationMeeting(
        meetingId: widget.meetingId,
        userId: 'USER_${DateTime.now().millisecondsSinceEpoch}',
        userName: widget.userName,
        speakingLanguage: widget.speakingLanguage,
        displayLanguage: widget.displayLanguage,
      );

      // Setup real-time listeners
      _setupTranslationListeners();

      setState(() {
        _initializationStatus = 'Starting speech recognition...';
      });

      // Auto-start speech translation
      await Future.delayed(const Duration(milliseconds: 1500));
      await _translationService!.startSpeechTranslation();

      setState(() {
        _isInitializing = false;
        _initializationStatus = 'Connected! Real-time translation active.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('🌐 Real-time translation active!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (kDebugMode) {
        print('✅ Enhanced translation meeting initialized');
        print('   Meeting: ${widget.meetingId}');
        print('   User: ${widget.userName}');
        print('   Speaking: ${widget.speakingLanguage}');
        print('   Display: ${widget.displayLanguage}');
      }

    } catch (e) {
      setState(() {
        _initializationStatus = 'Failed to initialize: $e';
      });

      if (kDebugMode) {
        print('❌ Error initializing translation meeting: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Failed to start translation meeting',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(e.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeTranslationMeeting(),
            ),
          ),
        );
      }
    }
  }

  // 🎧 SETUP TRANSLATION LISTENERS
  void _setupTranslationListeners() {
    if (_translationService == null) return;

    // Listen to new translation messages
    _translationService!.newMessageStream.listen((message) {
      if (mounted) {
        setState(() {
          // Add message to display (only show what current user should see)
          final userMessages = _translationService!.getCurrentUserMessages();
          _displayMessages.clear();
          _displayMessages.addAll(userMessages.take(10).toList()); // Show last 10
          _totalTranslations++;
        });
      }
    });

    // Listen to speaker changes
    _translationService!.speakerChangeStream.listen((speakerId) {
      if (mounted) {
        setState(() {
          _currentSpeakerId = speakerId;
        });
      }
    });

    // Listen to language preferences changes
    _translationService!.preferencesStream.listen((preferences) {
      if (mounted) {
        setState(() {
          // Update display when language preferences change
          final userMessages = _translationService!.getCurrentUserMessages();
          _displayMessages.clear();
          _displayMessages.addAll(userMessages.take(10).toList());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildInitializationScreen();
    }

    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, webrtcService, child) {
        return Scaffold(
          backgroundColor: GcbAppTheme.background,
          body: Stack(
            children: [
              // Main meeting content
              Column(
                children: [
                  // Enhanced top status bar
                  _buildEnhancedTopStatusBar(webrtcService),

                  // Main video area
                  Expanded(
                    child: Stack(
                      children: [
                        _buildMainVideoArea(webrtcService),

                        // Real-time translation overlay
                        if (_showTranslationOverlay)
                          _buildTranslationOverlay(),
                      ],
                    ),
                  ),

                  // Enhanced bottom controls
                  _buildEnhancedBottomControls(webrtcService),
                ],
              ),

              // Language settings panel
              if (_showLanguageSettings)
                _buildLanguageSettingsPanel(),
            ],
          ),
        );
      },
    );
  }

  // 📊 INITIALIZATION SCREEN
  Widget _buildInitializationScreen() {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with translation icon
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    color: GcbAppTheme.primary,
                    strokeWidth: 3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.translate,
                    color: GcbAppTheme.primary,
                    size: 40,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            const Text(
              'Enhanced Translation Meeting',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _initializationStatus,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 40),

            // Meeting details
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
                  _buildDetailRow('Meeting', widget.meetingId),
                  const SizedBox(height: 12),
                  _buildDetailRow('Your Name', widget.userName),
                  const SizedBox(height: 12),
                  _buildDetailRow('Speaking', _getLanguageName(widget.speakingLanguage)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Display', _getLanguageName(widget.displayLanguage)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feature highlights
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Google Cloud Speech + Real-time Translation',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
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
                    const Icon(Icons.translate, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.meetingId,
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
                  '${_getLanguageFlag(widget.speakingLanguage)} → ${_getLanguageFlag(widget.displayLanguage)} ${widget.userName}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Status indicators
          Row(
            children: [
              // Translation status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _translationService?.isTranslationActive == true
                      ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.translate, color: Colors.white, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      _translationService?.isTranslationActive == true ? 'LIVE' : 'OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Translation count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalTranslations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Participants
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple,
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
                'Real-time Translation: ${_translationService?.isTranslationActive == true ? "🟢 Active" : "🔴 Inactive"}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
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

  // 🌐 TRANSLATION OVERLAY
  Widget _buildTranslationOverlay() {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.translate, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Real-time Translation',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Display: ${_getLanguageName(widget.displayLanguage)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _translationService?.isTranslationActive == true
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _translationService?.isTranslationActive == true ? 'LIVE' : 'OFF',
                    style: TextStyle(
                      color: _translationService?.isTranslationActive == true
                          ? Colors.green
                          : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Translation messages
            if (_displayMessages.isEmpty)
              _buildEmptyTranslationState()
            else
              _buildTranslationMessages(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTranslationState() {
    return Center(
      child: Column(
        children: [
          Icon(
            _translationService?.isTranslationActive == true ? Icons.mic : Icons.mic_off,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 12),
          Text(
            _translationService?.isTranslationActive == true
                ? '🎤 Listening for speech...\nSpeak now to see real-time translations'
                : 'Translation inactive\nTap "Start Translation" to begin',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationMessages() {
    return Column(
      children: _displayMessages.take(3).map((message) {
        final isMyMessage = message.speakerId == _translationService?.currentUserId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMyMessage
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
                    isMyMessage ? Icons.account_circle : Icons.person,
                    color: isMyMessage ? Colors.blue : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMyMessage ? 'You' : message.speakerName,
                    style: TextStyle(
                      color: isMyMessage ? Colors.blue : Colors.white,
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
                      message.detectedLanguage.toUpperCase(),
                      style: const TextStyle(color: Colors.blue, fontSize: 9),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.cloud_done, color: Colors.green, size: 12),
                ],
              ),

              const SizedBox(height: 8),

              // Message text
              Text(
                message.originalText,
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
                    'Confidence: ${(message.confidence * 100).toInt()}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Real-time',
                    style: TextStyle(color: Colors.green, fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimestamp(message.timestamp),
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
          _buildControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: service.isAudioEnabled,
            onPressed: () async => await service.toggleAudio(),
          ),

          // Camera control
          _buildControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: service.isVideoEnabled,
            onPressed: () async => await service.toggleVideo(),
          ),

          // Translation control
          _buildControlButton(
            icon: _translationService?.isTranslationActive == true ? Icons.pause : Icons.translate,
            label: _translationService?.isTranslationActive == true ? 'Stop STT' : 'Start STT',
            isActive: _translationService?.isTranslationActive == true,
            onPressed: () async {
              if (_translationService?.isTranslationActive == true) {
                await _translationService?.stopSpeechTranslation();
              } else {
                await _translationService?.startSpeechTranslation();
              }
            },
          ),

          // Language settings
          _buildControlButton(
            icon: Icons.language,
            label: 'Language',
            onPressed: () {
              setState(() {
                _showLanguageSettings = !_showLanguageSettings;
              });
            },
          ),

          // Translation overlay toggle
          _buildControlButton(
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
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End',
            isDestructive: true,
            onPressed: () => _showEndMeetingDialog(),
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

  // 🌐 LANGUAGE SETTINGS PANEL
  Widget _buildLanguageSettingsPanel() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        color: GcbAppTheme.surface,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: GcbAppTheme.surfaceLight,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Language Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showLanguageSettings = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLanguageSettingItem(
                      'Speaking Language',
                      '${_getLanguageFlag(widget.speakingLanguage)} ${_getLanguageName(widget.speakingLanguage)}',
                      'Language you speak in the meeting',
                    ),

                    const SizedBox(height: 16),

                    _buildLanguageSettingItem(
                      'Display Language',
                      '${_getLanguageFlag(widget.displayLanguage)} ${_getLanguageName(widget.displayLanguage)}',
                      'Language you see all translations in',
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Translation Statistics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_translationService != null)
                      ..._buildTranslationStats(),

                    const SizedBox(height: 24),

                    const Text(
                      'Participants',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_translationService != null)
                      ..._buildParticipantsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSettingItem(String title, String value, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: GcbAppTheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTranslationStats() {
    final stats = _translationService!.getTranslationStats();
    return [
      _buildStatItem('Total Messages', '${stats['totalMessages']}'),
      const SizedBox(height: 8),
      _buildStatItem('Participants', '${stats['participantCount']}'),
      const SizedBox(height: 8),
      _buildStatItem('Translation Status', stats['activeTranslation'] ? 'Active' : 'Inactive'),
    ];
  }

  List<Widget> _buildParticipantsList() {
    final participants = _translationService!.getAllParticipants();
    return participants.map((participant) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GcbAppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: participant.userId == _translationService?.currentUserId
                  ? GcbAppTheme.primary
                  : Colors.grey[600],
              child: Text(
                participant.userName.isNotEmpty
                    ? participant.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_getLanguageFlag(participant.speakingLanguage)} → ${_getLanguageFlag(participant.displayLanguage)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 🔚 END MEETING DIALOG
  Future<void> _showEndMeetingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.call_end, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text('End Translation Meeting', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to end this meeting?\n\nAll translation data will be saved.',
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
      await _translationService?.leaveTranslationMeeting();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // 🔧 UTILITY METHODS
  String _getLanguageName(String code) {
    const names = {
      'en': 'English',
      'vi': 'Vietnamese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'th': 'Thai',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'ar': 'Arabic',
      'hi': 'Hindi',
    };
    return names[code] ?? code.toUpperCase();
  }

  String _getLanguageFlag(String code) {
    const flags = {
      'en': '🇺🇸',
      'vi': '🇻🇳',
      'zh': '🇨🇳',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
      'th': '🇹🇭',
      'es': '🇪🇸',
      'fr': '🇫🇷',
      'de': '🇩🇪',
      'ar': '🇸🇦',
      'hi': '🇮🇳',
    };
    return flags[code] ?? '🌐';
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

  @override
  void dispose() {
    _translationService?.leaveTranslationMeeting();
    super.dispose();
  }
}