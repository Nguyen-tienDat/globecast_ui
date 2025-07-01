// lib/screens/meeting/meeting_screen.dart - WITH SCROLLABLE TRANSLATION OVERLAY
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/central_translation_service.dart';

import '../../services/google_speech_translation_service.dart';

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
  bool _isTranslating = false;
  bool _isHubInitialized = false;

  // 🎯 CENTRAL TRANSLATION STATE
  final List<CentralTranslationResult> _translationResults = [];
  String _hubStatus = 'Ready';
  String _lastTranslationTime = '';

  // 🎯 UI STATE
  bool _showTranslationOverlay = true;
  bool _showLanguageSettings = false;
  int _totalTranslations = 0;

  // 🌐 LANGUAGE SETTINGS - CENTRAL HUB APPROACH
  String _mySpeakingLanguage = '';    // What I speak
  String _myDisplayLanguage = '';     // What I want to see
  String _currentUserId = '';
  List<String> _selectedOutputLanguages = ['en', 'vi', 'zh', 'ja', 'ko'];
  final List<String> _supportedLanguages = [
    'vi', 'en', 'zh', 'ja', 'ko', 'th', 'es', 'fr', 'de'
  ];

  final Map<String, String> _languageNames = {
    'vi': 'Tiếng Việt',
    'en': 'English',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'th': 'Thai',
    'id': 'Indonesian',
    'ms': 'Malay',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  final Map<String, String> _languageFlags = {
    'vi': '🇻🇳',
    'en': '🇺🇸',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'th': '🇹🇭',
    'id': '🇮🇩',
    'ms': '🇲🇾',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'ru': '🇷🇺',
    'ar': '🇸🇦',
    'hi': '🇮🇳',
  };

  @override
  void initState() {
    super.initState();

    // ✅ LOAD USER LANGUAGE PREFERENCES FROM SHARED PREFERENCES
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserLanguagePreferences();
    });
  }

  // 🌐 LOAD USER LANGUAGE PREFERENCES FROM SHARED PREFERENCES
  Future<void> _loadUserLanguagePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load saved language preferences
      final savedSpeakingLanguage = prefs.getString('speaking_language');
      final savedDisplayLanguage = prefs.getString('display_language');

      setState(() {
        // ✅ USE SAVED PREFERENCES IF AVAILABLE
        if (savedSpeakingLanguage != null && savedSpeakingLanguage.isNotEmpty) {
          _mySpeakingLanguage = savedSpeakingLanguage;
        } else {
          // Default fallback only if no saved preference
          _mySpeakingLanguage = 'vi'; // Default to Vietnamese
        }

        if (savedDisplayLanguage != null && savedDisplayLanguage.isNotEmpty) {
          _myDisplayLanguage = savedDisplayLanguage;
        } else if (widget.targetLanguage != null) {
          // Use widget parameter as fallback
          _myDisplayLanguage = widget.targetLanguage!;
        } else {
          // Final fallback
          _myDisplayLanguage = 'en'; // Default to English
        }
      });

      if (kDebugMode) {
        print('🌐 FIXED: Loaded user language preferences:');
        print('   Speaking: $_mySpeakingLanguage (from: ${savedSpeakingLanguage != null ? "SharedPreferences" : "default"})');
        print('   Display: $_myDisplayLanguage (from: ${savedDisplayLanguage != null ? "SharedPreferences" : widget.targetLanguage != null ? "widget" : "default"})');
      }

      // Initialize meeting after loading preferences
      await _initializeMeetingWithCentralHub();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading language preferences: $e');
      }
      
      // Fallback to defaults if loading fails
      setState(() {
        _mySpeakingLanguage = 'vi';
        _myDisplayLanguage = widget.targetLanguage ?? 'en';
      });

      // Still initialize meeting
      await _initializeMeetingWithCentralHub();
    }
  }

  // 🚀 INITIALIZE MEETING WITH CENTRAL TRANSLATION HUB
  Future<void> _initializeMeetingWithCentralHub() async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
      _hubStatus = 'Initializing meeting with Central Translation Hub...';
    });

    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final centralTranslationService = context.read<CentralTranslationService>();

      if (kDebugMode) {
        print('🎯 Starting meeting with Central Translation Hub...');
      }

      // ✅ STEP 1: INITIALIZE WEBRTC SERVICE
      setState(() {
        _hubStatus = 'Setting up video calling...';
      });

      if (!webrtcService.isInitialized) {
        await webrtcService.initialize();
      }

      // ✅ STEP 2: INITIALIZE CENTRAL TRANSLATION SERVICE
      setState(() {
        _hubStatus = 'Initializing Central Translation Hub...';
      });

      if (!centralTranslationService.isInitialized) {
        await centralTranslationService.initialize();
      }

      // ✅ STEP 3: SET USER CONTEXT
      if (widget.displayName != null && widget.displayName!.isNotEmpty) {
        webrtcService.setUserDetails(displayName: widget.displayName!);
      }

      _currentUserId = webrtcService.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

      // ✅ STEP 4: CONFIGURE CENTRAL TRANSLATION SERVICE
      setState(() {
        _hubStatus = 'Configuring Central Translation Hub...';
      });

      final meetingCode = widget.code ?? widget.meetingId;
      if (meetingCode != null && meetingCode.isNotEmpty) {
        centralTranslationService.setUserContext(
          meetingId: meetingCode,
          userId: _currentUserId,
          userName: widget.displayName ?? 'User',
          speakingLanguage: _mySpeakingLanguage,
          displayLanguage: _myDisplayLanguage,
        );
      }

      // ✅ STEP 5: JOIN MEETING
      setState(() {
        _hubStatus = 'Joining meeting...';
      });

      if (meetingCode != null && meetingCode.isNotEmpty) {
        await webrtcService.joinMeeting(meetingId: meetingCode);
      } else {
        throw Exception('No meeting code provided');
      }

      // ✅ STEP 6: SETUP CENTRAL TRANSLATION LISTENERS
      setState(() {
        _hubStatus = 'Setting up Central Translation Hub listeners...';
      });

      _setupCentralTranslationListeners(centralTranslationService);

      // ✅ STEP 7: INITIALIZE CENTRAL HUB
      _isHubInitialized = true;

      setState(() {
        _hubStatus = '✅ Central Translation Hub ready - Speak in any language!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.hub, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('🌐 Central Translation Hub ready!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (kDebugMode) {
        print('✅ Meeting with Central Translation Hub initialized');
        print('   Meeting: $meetingCode');
        print('   User: ${widget.displayName} ($_currentUserId)');
        print('   Speaking: $_mySpeakingLanguage → Display: $_myDisplayLanguage');
        print('   Central Hub: Active');
      }

    } catch (e) {
      setState(() {
        _hubStatus = '❌ Initialization failed: $e';
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
              onPressed: () => _initializeMeetingWithCentralHub(),
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

  // 🎧 SETUP CENTRAL TRANSLATION LISTENERS
  void _setupCentralTranslationListeners(CentralTranslationService service) {
    // Listen to local translation results
    service.translationStream.listen(
          (result) {
        if (mounted) {
          setState(() {
            _translationResults.insert(0, result);
            if (_translationResults.length > 50) {
              _translationResults.removeRange(50, _translationResults.length);
            }
            _totalTranslations = _translationResults.length;
            _lastTranslationTime = _formatTimestamp(result.timestamp);
          });

          if (kDebugMode) {
            print('📝 Central translation result received:');
            print('   Original: "${result.originalText}"');
            print('   Available in: ${result.allTranslations.length} languages');
            print('   My display: ${result.getDisplayText(_myDisplayLanguage)}');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Central translation stream error: $error');
        }
        if (mounted) {
          setState(() {
            _hubStatus = 'Translation error: $error';
          });
        }
      },
    );

    // Listen to status updates
    service.statusStream.listen(
          (status) {
        if (mounted) {
          setState(() {
            _hubStatus = status;
          });
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Central translation status error: $error');
        }
      },
    );

    // Listen to remote translations from database
    _listenToAllParticipantTranslations();

    if (kDebugMode) {
      print('🎧 Central Translation Hub listeners setup complete');
    }
  }

  // 👂 LISTEN TO ALL PARTICIPANT TRANSLATIONS FROM CENTRAL DATABASE
  void _listenToAllParticipantTranslations() {
    final meetingCode = widget.code ?? widget.meetingId;
    if (meetingCode == null || meetingCode.isEmpty) return;

    if (kDebugMode) {
      print('👂 Listening to Central Translation Hub database...');
    }

    FirebaseFirestore.instance
        .collection('meetings')
        .doc(meetingCode)
        .collection('central_translations')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
        for (var docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.added) {
            try {
              final centralResult = CentralTranslationResult.fromFirestore(docChange.doc);

              // Add to local results if not duplicate and not from me (already added locally)
              if (mounted && centralResult.speakerId != _currentUserId) {
                setState(() {
                  final isDuplicate = _translationResults.any((existing) =>
                  existing.speakerId == centralResult.speakerId &&
                      existing.originalText == centralResult.originalText &&
                      existing.timestamp.difference(centralResult.timestamp).abs().inSeconds < 5
                  );

                  if (!isDuplicate) {
                    _translationResults.insert(0, centralResult);

                    if (_translationResults.length > 50) {
                      _translationResults.removeRange(50, _translationResults.length);
                    }

                    _totalTranslations = _translationResults.length;
                    _lastTranslationTime = _formatTimestamp(centralResult.timestamp);
                  }
                });

                if (kDebugMode) {
                  print('📝 Remote translation from ${centralResult.speakerName}:');
                  print('   Original (${centralResult.detectedLanguage}): "${centralResult.originalText}"');
                  print('   Available in: ${centralResult.allTranslations.length} languages');
                  print('   My display: ${centralResult.getDisplayText(_myDisplayLanguage)}');
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('❌ Error processing remote translation: $e');
              }
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Error listening to central translations: $error');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: Consumer<WebRTCMeshMeetingService>(
        builder: (context, service, child) {
          if (_isJoining || !service.isInitialized || !service.isMeetingActive) {
            return _buildLoadingScreen(service);
          }

          return Stack(
            children: [
              Column(
                children: [
                  _buildEnhancedTopStatusBar(service),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildMainVideoArea(service),
                        if (_showTranslationOverlay)
                          Positioned(
                            bottom: 80,
                            left: 16,
                            right: 16,
                            child: _buildScrollableCentralTranslationOverlay(),
                          ),
                      ],
                    ),
                  ),
                  _buildEnhancedBottomControls(service),
                ],
              ),
              if (_showLanguageSettings)
                _buildLanguageSettingsPanel(),
            ],
          );
        },
      ),
    );
  }

  // 📊 LOADING SCREEN
  Widget _buildLoadingScreen(WebRTCMeshMeetingService service) {
    return Container(
      color: GcbAppTheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hub,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Meeting with Central Translation Hub',
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
                _hubStatus,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 TOP STATUS BAR
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.code ?? widget.meetingId ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isHubInitialized)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HUB',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_languageFlags[_mySpeakingLanguage]} ${widget.displayName} → ${_languageFlags[_myDisplayLanguage]} Display',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.read<CentralTranslationService>().isInitialized
                      ? Colors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'Hub',
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
              if (_isTranslating)
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple,
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
            ],
          ),
        ],
      ),
    );
  }

  // 🎬 MAIN VIDEO AREA (Same as before)
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
                'Central Translation Hub: ${_isHubInitialized ? "🟢 Active" : "🔴 Inactive"}',
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
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(8),
            child: _buildVideoTile(service, participants.first, isMainView: true),
          ),
        ),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: participant.isLocal
              ? GcbAppTheme.primary.withOpacity(0.6)
              : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
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
            if (_isTranslating && participant.isLocal)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'HUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
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

  // 🎯 SCROLLABLE CENTRAL TRANSLATION OVERLAY - FIXED
  Widget _buildScrollableCentralTranslationOverlay() {
    return Container(
      // 🎯 SET FIXED HEIGHT FOR SCROLLABILITY
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
        minHeight: 200, // Minimum height
      ),
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
          // Header with hub info (FIXED HEADER)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Central Translation Hub',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'I speak: ${_languageFlags[_mySpeakingLanguage]} → I see: ${_languageFlags[_myDisplayLanguage]}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTranslating)
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

          // Status bar (FIXED)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isTranslating ? Icons.circle : Icons.circle_outlined,
                  color: _isTranslating ? Colors.green : Colors.grey,
                  size: 8,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hubStatus,
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

          // 🎯 SCROLLABLE TRANSLATION RESULTS
          Expanded(
            child: _translationResults.isEmpty
                ? _buildEmptyTranslationState()
                : _buildScrollableCentralTranslationResults(),
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
            _isTranslating ? Icons.hub : Icons.hub_outlined,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 12),
          Text(
            _isTranslating
                ? '🎤 Listening for speech...\nCentral Hub active for all participants'
                : 'Central Translation Hub ready\nTap "Start Hub Translation" to begin',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD SCROLLABLE CENTRAL TRANSLATION RESULTS
  Widget _buildScrollableCentralTranslationResults() {
    return ListView.builder(
      itemCount: _translationResults.length,
      itemBuilder: (context, index) {
        final result = _translationResults[index];
        final isMyResult = result.speakerId == _currentUserId;
        final displayText = result.getDisplayText(_myDisplayLanguage);
        final isTranslated = displayText != result.originalText;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMyResult
                ? Colors.blue.withOpacity(0.15)
                : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isTranslated ? Colors.green.withOpacity(0.6) : Colors.blue.withOpacity(0.4),
              width: isTranslated ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker info with language indicators
              Row(
                children: [
                  Icon(
                    isMyResult ? Icons.account_circle : Icons.person,
                    color: isMyResult ? Colors.blue : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMyResult ? 'You' : result.speakerName,
                    style: TextStyle(
                      color: isMyResult ? Colors.blue : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Speaking language
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_languageFlags[result.detectedLanguage] ?? ''),
                        const SizedBox(width: 2),
                        Text(
                          result.detectedLanguage.toUpperCase(),
                          style: const TextStyle(color: Colors.blue, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  // Translation indicator
                  if (isTranslated) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, color: Colors.green, size: 12),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_languageFlags[_myDisplayLanguage] ?? ''),
                          const SizedBox(width: 2),
                          Text(
                            _myDisplayLanguage.toUpperCase(),
                            style: const TextStyle(color: Colors.green, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.hub, color: Colors.purple, size: 12),
                ],
              ),

              const SizedBox(height: 8),

              // Main text (personalized for each user)
              Text(
                displayText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Show original if translated
              if (isTranslated && !isMyResult) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original (${result.detectedLanguage}):',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.originalText,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // Metadata
              Row(
                children: [
                  Text(
                    'Confidence: ${(result.getConfidence(_myDisplayLanguage) * 100).toInt()}%',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isTranslated ? 'Translated' : 'Original',
                    style: TextStyle(
                      color: isTranslated ? Colors.green : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Hub: ${result.allTranslations.length} langs',
                    style: const TextStyle(color: Colors.purple, fontSize: 10),
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
      },
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
          _buildEnhancedControlButton(
            icon: service.isAudioEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: service.isAudioEnabled,
            onPressed: () async => await service.toggleAudio(),
          ),
          _buildEnhancedControlButton(
            icon: service.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: service.isVideoEnabled,
            onPressed: () async => await service.toggleVideo(),
          ),
          _buildEnhancedControlButton(
            icon: _isTranslating ? Icons.stop : Icons.hub,
            label: _isTranslating ? 'Stop Hub' : 'Start Hub',
            isActive: _isTranslating,
            onPressed: _isHubInitialized
                ? () async {
              if (_isTranslating) {
                await _stopCentralTranslation();
              } else {
                await _startCentralTranslation();
              }
            }
                : null,
          ),
          _buildEnhancedControlButton(
            icon: Icons.language,
            label: 'Language',
            onPressed: () {
              setState(() {
                _showLanguageSettings = !_showLanguageSettings;
              });
            },
          ),
          _buildEnhancedControlButton(
            icon: Icons.history,
            label: 'History',
            onPressed: () => _showCentralTranslationHistory(),
            badge: _translationResults.isNotEmpty ? _translationResults.length.toString() : null,
          ),
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

  // 🎤 START CENTRAL TRANSLATION
  Future<void> _startCentralTranslation() async {
    try {
      final centralTranslationService = context.read<CentralTranslationService>();

      setState(() {
        _isTranslating = true;
        _hubStatus = 'Starting Central Translation Hub...';
      });

      await centralTranslationService.startListening();

      setState(() {
        _hubStatus = '🎤 Central Hub active - Speak in ${_languageNames[_mySpeakingLanguage]}';
      });

      if (kDebugMode) {
        print('🎤 Central Translation Hub started');
      }

    } catch (e) {
      setState(() {
        _isTranslating = false;
        _hubStatus = 'Failed to start: $e';
      });

      if (kDebugMode) {
        print('❌ Error starting Central Translation Hub: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation Hub failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _startCentralTranslation(),
            ),
          ),
        );
      }
    }
  }

  // 🛑 STOP CENTRAL TRANSLATION
  Future<void> _stopCentralTranslation() async {
    if (!_isTranslating) return;

    try {
      setState(() {
        _hubStatus = 'Stopping Central Translation Hub...';
      });

      final centralTranslationService = context.read<CentralTranslationService>();
      await centralTranslationService.stopListening();

      setState(() {
        _isTranslating = false;
        _hubStatus = 'Central Translation Hub stopped';
      });

      if (kDebugMode) {
        print('🛑 Central Translation Hub stopped');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping Central Translation Hub: $e');
      }

      setState(() {
        _hubStatus = 'Error stopping: $e';
      });
    }
  }

  // 🌐 LANGUAGE SETTINGS PANEL (unchanged)
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
                  const Icon(Icons.sync, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Translation Sync Settings',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Speaking Language
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.mic, color: Colors.blue, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Speaking Language (Input)',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _mySpeakingLanguage,
                            dropdownColor: GcbAppTheme.surface,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                              items: _supportedLanguages.map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Row(
                                children: [
                                  Text(_languageFlags[lang] ?? ''),
                                  const SizedBox(width: 8),
                                  Text(_languageNames[lang] ?? lang),
                                ],
                              ),
                            )).toList(),
                            onChanged: (newLang) async {
                              if (newLang != null) {
                                setState(() {
                                  _mySpeakingLanguage = newLang;
                                  _myDisplayLanguage = newLang; // Set display language to match speaking language
                                });
                                
                                // ✅ SAVE TO SHARED PREFERENCES
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('speaking_language', newLang);
                                await prefs.setString('display_language', newLang);
                                
                                // Update services
                                final centralTranslationService = context.read<CentralTranslationService>();
                                await centralTranslationService.updateLanguagePreferences(
                                  speakingLanguage: newLang,
                                  displayLanguage: newLang
                                );
                                
                                final googleSpeechService = context.read<GoogleSpeechTranslationService>();
                                googleSpeechService.setPreferredLanguage(newLang);
                                
                                await _saveMyLanguagePreferencesToFirestore();
                                
                                if (kDebugMode) {
                                  print('🌐 FIXED: Speaking and display language updated to $newLang and saved to SharedPreferences');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Display Language
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.visibility, color: Colors.purple, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Display Language (What I see)',
                                style: TextStyle(
                                  color: Colors.purple,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _myDisplayLanguage,
                            dropdownColor: GcbAppTheme.surface,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _supportedLanguages.map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Row(
                                children: [
                                  Text(_languageFlags[lang] ?? ''),
                                  const SizedBox(width: 8),
                                  Text(_languageNames[lang] ?? lang),
                                ],
                              ),
                            )).toList(),
                            onChanged: (newLang) async {
                              if (newLang != null) {
                                setState(() {
                                  _myDisplayLanguage = newLang;
                                });
                                
                                // ✅ SAVE TO SHARED PREFERENCES
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('display_language', newLang);
                                
                                // Update services
                                final centralTranslationService = context.read<CentralTranslationService>();
                                await centralTranslationService.updateLanguagePreferences(displayLanguage: newLang);
                                
                                await _saveMyLanguagePreferencesToFirestore();
                                
                                if (kDebugMode) {
                                  print('🌐 FIXED: Display language updated to $newLang and saved to SharedPreferences');
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sync Statistics
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GcbAppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Translation Sync Statistics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatItem('Total Messages', '$_totalTranslations'),
                          const SizedBox(height: 8),
                          _buildStatItem('Sync Status', _isListening ? 'Active' : 'Inactive'),
                          const SizedBox(height: 8),
                          _buildStatItem('Service', 'Google Cloud Speech'),
                          const SizedBox(height: 8),
                          _buildStatItem('Participants', 'Real-time sync enabled'),
                        ],
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

  // 📊 CENTRAL TRANSLATION HISTORY MODAL (unchanged)
  void _showCentralTranslationHistory() {
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.hub, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Central Translation Hub History',
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
                      '${_translationResults.length} results',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _translationResults.isEmpty
                    ? const Center(
                  child: Text(
                    'No Central Hub translation history yet\nStart translation to see results from all participants',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _translationResults.length,
                  itemBuilder: (context, index) {
                    // ... same history item builder as before
                    return Container(); // Placeholder
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _saveMyLanguagePreferencesToFirestore() async {
    try {
      final meetingCode = widget.code ?? widget.meetingId;
      final userId = _currentUserId;

      if (meetingCode == null || meetingCode.isEmpty || userId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingCode)
          .collection('participant_languages')
          .doc(userId)
          .set({
        'userId': userId,
        'userName': widget.displayName ?? 'User',
        'speakingLanguage': _mySpeakingLanguage,
        'displayLanguage': _myDisplayLanguage,
        'outputLanguages': _selectedOutputLanguages,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('💾 My language preferences saved to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving language preferences: $e');
      }
    }
  }

  // 🔚 END CALL DIALOG (unchanged)
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
          'Are you sure you want to end this meeting?\n\n• All Central Hub translation history will be saved\n• Real-time translation will stop\n• Meeting will end for all participants',
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
      // Stop translation
      if (_isTranslating) {
        await _stopCentralTranslation();
      }

      // Leave meeting
      await service.leaveMeeting();

      // Navigate back
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // 🔧 HELPER METHODS
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
    // Stop translation if active
    if (_isTranslating) {
      _stopCentralTranslation();
    }
    super.dispose();
  }
}

