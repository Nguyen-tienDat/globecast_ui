// lib/screens/meeting/meeting_screen.dart - COMPLETE WITH REAL-TIME TRANSLATION SYNC
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/google_speech_translation_service.dart';

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
  bool _isRealtimeInitialized = false;

  // 🎯 REAL-TIME TRANSLATION STATE
  final List<SpeechTranslationResult> _speechResults = [];
  String? _currentSpeakerId;
  String _speechServiceStatus = 'Ready';
  String _lastTranslationTime = '';

  // 🎯 UI STATE
  bool _showTranslationOverlay = true;
  bool _showLanguageSettings = false;
  int _totalTranslations = 0;

  // 🌐 LANGUAGE SETTINGS
  String _mySpeakingLanguage = 'vi';
  String _myDisplayLanguage = 'en';
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
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
  };

  final Map<String, String> _languageFlags = {
    'vi': '🇻🇳',
    'en': '🇺🇸',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'th': '🇹🇭',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
  };

  @override
  void initState() {
    super.initState();
    if (widget.targetLanguage != null) {
      _mySpeakingLanguage = widget.targetLanguage!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMeeting();
    });
  }

  // 🚀 INITIALIZE MEETING WITH REAL-TIME TRANSLATION SYNC
  Future<void> _initializeMeeting() async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
      _speechServiceStatus = 'Initializing meeting with real-time translation...';
    });

    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final googleSpeechService = context.read<GoogleSpeechTranslationService>();

      if (kDebugMode) {
        print('🎯 Starting meeting initialization with real-time translation sync...');
      }

      // ✅ STEP 1: INITIALIZE WEBRTC SERVICE
      setState(() {
        _speechServiceStatus = 'Setting up video calling...';
      });

      if (!webrtcService.isInitialized) {
        await webrtcService.initialize();
      }

      // ✅ STEP 2: INITIALIZE GOOGLE SPEECH SERVICE
      setState(() {
        _speechServiceStatus = 'Initializing Google Cloud Speech & Translation...';
      });

      if (!googleSpeechService.isInitialized) {
        await googleSpeechService.initialize();
      }

      // ✅ STEP 3: SET USER CONTEXT
      if (widget.displayName != null && widget.displayName!.isNotEmpty) {
        webrtcService.setUserDetails(displayName: widget.displayName!);
      }

      // ✅ STEP 4: CONFIGURE TRANSLATION SERVICE
      setState(() {
        _speechServiceStatus = 'Configuring real-time translation...';
      });

      googleSpeechService.setUserContext(
          webrtcService.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          widget.displayName ?? 'User'
      );

      final meetingCode = widget.code ?? widget.meetingId;
      if (meetingCode != null && meetingCode.isNotEmpty) {
        googleSpeechService.setTranslationContext(meetingCode);
      }

      googleSpeechService.setPreferredLanguage(_mySpeakingLanguage);
      googleSpeechService.setTargetLanguages(_selectedOutputLanguages);

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
        _speechServiceStatus = 'Setting up real-time translation listeners...';
      });

      _setupRealtimeSpeechListeners(googleSpeechService);

      // ✅ STEP 7: INITIALIZE TRANSLATION SYNC FOR ALL PARTICIPANTS
      setState(() {
        _speechServiceStatus = 'Setting up real-time translation sync...';
      });

      await _initializeTranslationSync();
      _isRealtimeInitialized = true;

      setState(() {
        _speechServiceStatus = '✅ Meeting with real-time translation sync ready';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.sync, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('🎤 Meeting with real-time translation sync ready!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (kDebugMode) {
        print('✅ Meeting with real-time translation sync initialized successfully');
        print('   Meeting: $meetingCode');
        print('   User: ${widget.displayName} (${webrtcService.userId})');
        print('   Speaking Language: $_mySpeakingLanguage');
        print('   Display Language: $_myDisplayLanguage');
        print('   Translation sync: Active');
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

  // 🔧 INITIALIZE TRANSLATION SYNC FOR ALL PARTICIPANTS
  Future<void> _initializeTranslationSync() async {
    final meetingCode = widget.code ?? widget.meetingId;
    if (meetingCode == null || meetingCode.isEmpty) return;

    try {
      // ✅ START LISTENING TO ALL PARTICIPANT TRANSLATIONS
      _listenToAllParticipantTranslations();

      // ✅ SAVE MY LANGUAGE PREFERENCES TO FIRESTORE
      await _saveMyLanguagePreferencesToFirestore();

      if (kDebugMode) {
        print('🔄 Translation sync initialized for meeting: $meetingCode');
        print('   Listening to real-time translations from all participants');
        print('   My preferences saved to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing translation sync: $e');
      }
    }
  }

  // 🔧 LISTEN TO TRANSLATIONS FROM ALL PARTICIPANTS
  void _listenToAllParticipantTranslations() {
    final meetingCode = widget.code ?? widget.meetingId;
    if (meetingCode == null || meetingCode.isEmpty) return;

    if (kDebugMode) {
      print('👂 Listening to real-time translations from all participants...');
    }

    FirebaseFirestore.instance
        .collection('meetings')
        .doc(meetingCode)
        .collection('real_time_translations')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
        for (var docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.added) {
            final data = docChange.doc.data() as Map<String, dynamic>;

            // ✅ CREATE SPEECH RESULT FROM FIRESTORE DATA
            final speechResult = SpeechTranslationResult(
              userId: data['userId'] ?? '',
              userName: data['userName'] ?? '',
              originalText: data['originalText'] ?? '',
              detectedLanguage: data['detectedLanguage'] ?? 'unknown',
              translations: Map<String, String>.from(data['translations'] ?? {}),
              confidence: (data['confidence'] ?? 0.0).toDouble(),
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isFinal: data['isFinal'] ?? false,
              isFromGoogleSpeech: data['isFromGoogleSpeech'] ?? true,
            );

            // ✅ ADD TO LOCAL RESULTS (for UI display)
            if (mounted) {
              setState(() {
                // Check if not duplicate
                final isDuplicate = _speechResults.any((existing) =>
                existing.userId == speechResult.userId &&
                    existing.originalText == speechResult.originalText &&
                    existing.timestamp.difference(speechResult.timestamp).abs().inSeconds < 5
                );

                if (!isDuplicate) {
                  _speechResults.insert(0, speechResult);

                  if (_speechResults.length > 50) {
                    _speechResults.removeRange(50, _speechResults.length);
                  }

                  _totalTranslations = _speechResults.length;
                  _currentSpeakerId = speechResult.userId;
                  _lastTranslationTime = _formatTimestamp(speechResult.timestamp);
                }
              });

              if (kDebugMode) {
                print('📝 Received translation from ${speechResult.userName}:');
                print('   Original (${speechResult.detectedLanguage}): "${speechResult.originalText}"');
                print('   Available in: ${speechResult.translations.keys.join(", ")}');
                print('   My display: ${_getPersonalDisplayText(speechResult)}');
              }
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Error listening to translations: $error');
        }
      },
    );
  }

  // 🔧 SAVE MY LANGUAGE PREFERENCES TO FIRESTORE
  Future<void> _saveMyLanguagePreferencesToFirestore() async {
    try {
      final meetingCode = widget.code ?? widget.meetingId;
      final userId = _getCurrentUserId();

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

  // 🔧 SAVE TRANSLATION TO FIRESTORE (for all participants)
  Future<void> _saveTranslationToFirestore(SpeechTranslationResult result) async {
    try {
      final meetingCode = widget.code ?? widget.meetingId;
      if (meetingCode == null || meetingCode.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingCode)
          .collection('real_time_translations')
          .add({
        'userId': result.userId,
        'userName': result.userName,
        'originalText': result.originalText,
        'detectedLanguage': result.detectedLanguage,
        'translations': result.translations,
        'confidence': result.confidence,
        'timestamp': FieldValue.serverTimestamp(),
        'isFinal': result.isFinal,
        'isFromGoogleSpeech': result.isFromGoogleSpeech,
        'meetingId': meetingCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('💾 Translation saved to Firestore for all participants');
        print('   Available languages: ${result.translations.keys.join(", ")}');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving translation to Firestore: $e');
      }
    }
  }

  // 🔧 PERSONAL DISPLAY LOGIC - Each user sees in their preferred language
  String _getPersonalDisplayText(SpeechTranslationResult result) {
    // If this is my own speech, show original
    if (result.userId == _getCurrentUserId()) {
      return result.originalText;
    }

    // If speaker's language matches my display preference, show original
    if (result.detectedLanguage == _myDisplayLanguage) {
      return result.originalText;
    }

    // If translation available in my display language, show translation
    if (result.translations.containsKey(_myDisplayLanguage)) {
      return result.translations[_myDisplayLanguage]!;
    }

    // Fallback: try English
    if (result.translations.containsKey('en')) {
      return result.translations['en']!;
    }

    // Last resort: show original
    return result.originalText;
  }

  // 🎧 SETUP REAL-TIME SPEECH LISTENERS WITH FIRESTORE SYNC
  void _setupRealtimeSpeechListeners(GoogleSpeechTranslationService googleSpeechService) {
    // Listen to speech results from my own speech
    googleSpeechService.resultStream.listen(
          (result) async {
        if (mounted) {
          // ✅ SAVE TO FIRESTORE FOR ALL PARTICIPANTS
          await _saveTranslationToFirestore(result);

          // ✅ ADD TO LOCAL RESULTS (immediate UI update)
          setState(() {
            _speechResults.insert(0, result);
            if (_speechResults.length > 50) {
              _speechResults.removeRange(50, _speechResults.length);
            }
            _currentSpeakerId = result.userId;
            _totalTranslations = _speechResults.length;
            _lastTranslationTime = _formatTimestamp(result.timestamp);
          });

          if (kDebugMode) {
            print('📝 My speech result processed and shared:');
            print('   Original: "${result.originalText}"');
            print('   Available languages: ${result.translations.keys.join(", ")}');
            print('   Saved to Firestore for all participants');
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
    googleSpeechService.statusStream.listen(
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
      print('🎧 Real-time speech listeners with Firestore sync setup complete');
    }
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
                            child: _buildGoogleCloudTranslationOverlay(),
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
                    Icons.sync,
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Meeting with Real-time Translation Sync',
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
                _speechServiceStatus,
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
                    const Icon(Icons.sync, color: Colors.blue, size: 16),
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
                    if (_isRealtimeInitialized)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SYNC',
                          style: TextStyle(
                            color: Colors.green,
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
                  color: context.read<GoogleSpeechTranslationService>().isInitialized
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
                'Translation Sync: ${_isRealtimeInitialized ? "🟢 Active" : "🔴 Inactive"}',
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
            if (_isListening && participant.isLocal)
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
                      Icon(Icons.sync, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'SYNC',
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

  // 🎯 GOOGLE CLOUD TRANSLATION OVERLAY WITH SYNC
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
          // Header with sync info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sync, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Real-time Translation Sync',
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
            _buildTranslationResultsWithSync(),
        ],
      ),
    );
  }

  Widget _buildEmptyTranslationState() {
    return Center(
      child: Column(
        children: [
          Icon(
            _isListening ? Icons.sync : Icons.sync_disabled,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 12),
          Text(
            _isListening
                ? '🎤 Listening for speech...\nReal-time sync active for all participants'
                : 'Real-time translation sync ready\nTap "Start Translation" to begin',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD TRANSLATION RESULTS WITH SYNC - Shows translations from all participants
  Widget _buildTranslationResultsWithSync() {
    return Column(
      children: _speechResults.take(3).map((result) {
        final isMyResult = result.userId == _getCurrentUserId();
        final displayText = _getPersonalDisplayText(result);
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
                    isMyResult ? 'You' : result.userName,
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
                  const Icon(Icons.sync, color: Colors.green, size: 12),
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
                    'Confidence: ${(result.confidence * 100).toInt()}%',
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
            icon: _isListening ? Icons.stop : Icons.sync,
            label: _isListening ? 'Stop Sync' : 'Start Sync',
            isActive: _isListening,
            onPressed: _isRealtimeInitialized
                ? () async {
              if (_isListening) {
                await _stopRealTimeTranslation();
              } else {
                await _startRealTimeTranslation();
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
            onPressed: () => _showTranslationHistory(),
            badge: _speechResults.isNotEmpty ? _speechResults.length.toString() : null,
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

  // 🎤 START REAL-TIME TRANSLATION
  Future<void> _startRealTimeTranslation() async {
    try {
      final googleSpeechService = context.read<GoogleSpeechTranslationService>();

      setState(() {
        _isListening = true;
        _speechServiceStatus = 'Starting real-time translation sync...';
      });

      await googleSpeechService.startListening(
        meetingId: widget.code ?? widget.meetingId,
        userId: _getCurrentUserId(),
        preferredLanguage: _mySpeakingLanguage,
      );

      setState(() {
        _speechServiceStatus = '🎤 Translation sync active for all participants...';
      });

      if (kDebugMode) {
        print('🎤 Real-time translation sync started');
      }

    } catch (e) {
      setState(() {
        _isListening = false;
        _speechServiceStatus = 'Failed to start: $e';
      });

      if (kDebugMode) {
        print('❌ Error starting real-time translation: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation sync failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _startRealTimeTranslation(),
            ),
          ),
        );
      }
    }
  }

  // 🛑 STOP REAL-TIME TRANSLATION
  Future<void> _stopRealTimeTranslation() async {
    if (!_isListening) return;

    try {
      setState(() {
        _speechServiceStatus = 'Stopping real-time translation sync...';
      });

      final googleSpeechService = context.read<GoogleSpeechTranslationService>();
      await googleSpeechService.stopListening();

      setState(() {
        _isListening = false;
        _currentSpeakerId = null;
        _speechServiceStatus = 'Translation sync stopped';
      });

      if (kDebugMode) {
        print('🛑 Real-time translation sync stopped');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping real-time translation: $e');
      }

      setState(() {
        _speechServiceStatus = 'Error stopping: $e';
      });
    }
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
                                });
                                final googleSpeechService = context.read<GoogleSpeechTranslationService>();
                                googleSpeechService.setPreferredLanguage(newLang);
                                await _saveMyLanguagePreferencesToFirestore();
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
                                await _saveMyLanguagePreferencesToFirestore();
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
                  const Icon(Icons.sync, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Translation Sync History',
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
              Expanded(
                child: _speechResults.isEmpty
                    ? const Center(
                  child: Text(
                    'No translation sync history yet\nStart translation to see results from all participants',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _speechResults.length,
                  itemBuilder: (context, index) {
                    final result = _speechResults[index];
                    final isMyResult = result.userId == _getCurrentUserId();
                    final displayText = _getPersonalDisplayText(result);
                    final isTranslated = displayText != result.originalText;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isMyResult
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTranslated ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with sync indicator
                          Row(
                            children: [
                              Icon(
                                isMyResult ? Icons.account_circle : Icons.person,
                                color: isMyResult ? Colors.blue : Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMyResult ? 'You' : result.userName,
                                style: TextStyle(
                                  color: isMyResult ? Colors.blue : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_languageFlags[result.detectedLanguage] ?? ''),
                                    const SizedBox(width: 4),
                                    Text(
                                      result.detectedLanguage.toUpperCase(),
                                      style: const TextStyle(color: Colors.blue, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              if (isTranslated) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward, color: Colors.green, size: 12),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_languageFlags[_myDisplayLanguage] ?? ''),
                                      const SizedBox(width: 4),
                                      Text(
                                        _myDisplayLanguage.toUpperCase(),
                                        style: const TextStyle(color: Colors.green, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              const Icon(Icons.sync, color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(result.timestamp),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Display text
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isTranslated ? Colors.green.withOpacity(0.1) : Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTranslated ? 'Translated:' : 'Original:',
                                  style: TextStyle(
                                    color: isTranslated ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayText,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          if (isTranslated && !isMyResult) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Original (${result.detectedLanguage}):',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    result.originalText,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // All translations
                          if (result.translations.isNotEmpty && result.translations.length > 1)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available in ${result.translations.length} languages:',
                                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  ...result.translations.entries.map((entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_languageFlags[entry.key] ?? ''),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            entry.key.toUpperCase(),
                                            style: const TextStyle(color: Colors.blue, fontSize: 9),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Metadata
                          Row(
                            children: [
                              const Icon(Icons.sync, color: Colors.green, size: 12),
                              const SizedBox(width: 4),
                              const Text(
                                'Real-time Sync',
                                style: TextStyle(color: Colors.green, fontSize: 10),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Confidence: ${(result.confidence * 100).toInt()}%',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
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
          'Are you sure you want to end this meeting?\n\n• All translation sync history will be saved\n• Real-time translation will stop\n• Meeting will end for all participants',
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
      if (_isListening) {
        await _stopRealTimeTranslation();
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
  String _getCurrentUserId() {
    try {
      return context.read<WebRTCMeshMeetingService>().userId ?? 'unknown';
    } catch (e) {
      return 'unknown';
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

  @override
  void dispose() {
    // Stop translation if active
    if (_isListening) {
      _stopRealTimeTranslation();
    }
    super.dispose();
  }
}