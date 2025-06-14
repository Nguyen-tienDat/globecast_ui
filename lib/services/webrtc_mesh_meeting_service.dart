// lib/services/webrtc_mesh_meeting_service.dart - FIXED MEDIA STREAM VERSION
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'whisper_service.dart';
import 'audio_capture_service.dart';

class WebRTCMeshMeetingService extends ChangeNotifier {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Services
  WhisperService? _whisperService;
  AudioCaptureService? _audioCaptureService;

  // WebRTC Mesh Network
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;

  // Meeting data
  String? _meetingId;
  String? _userId;
  String _displayName = 'User';
  bool _isHost = false;
  bool _isMeetingActive = false;
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;

  // Language preferences - NEW WORKFLOW
  String _userDisplayLanguage = 'en'; // Language user wants to see subtitles in
  bool _subtitlesEnabled = true;

  // Participants
  final List<MeshParticipant> _participants = [];

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Getters
  String? get meetingId => _meetingId;
  String? get userId => _userId;
  bool get isHost => _isHost;
  bool get isMeetingActive => _isMeetingActive;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get subtitlesEnabled => _subtitlesEnabled;
  String get userDisplayLanguage => _userDisplayLanguage;
  List<MeshParticipant> get participants => List.unmodifiable(_participants);
  RTCVideoRenderer? get localRenderer => _localRenderer;
  WhisperService? get whisperService => _whisperService;
  AudioCaptureService? get audioCaptureService => _audioCaptureService;

  // Enhanced ICE Servers configuration with fallbacks
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      // Google STUN servers (free and reliable)
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},

      // Metered TURN servers (your existing config)
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': 'daf1014df8d621757bb0b93b',
        'credential': '1Qumr8pcp8fzj0Fo',
      },
      {
        'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
        'username': 'daf1014df8d621757bb0b93b',
        'credential': '1Qumr8pcp8fzj0Fo',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': 'daf1014df8d621757bb0b93b',
        'credential': '1Qumr8pcp8fzj0Fo',
      },
      {
        'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
        'username': 'daf1014df8d621757bb0b93b',
        'credential': '1Qumr8pcp8fzj0Fo',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  // Initialize service
  Future<void> initialize() async {
    try {
      // Generate clean user ID compatible with existing database
      _userId ??= 'USR${const Uuid().v4().replaceAll('-', '').substring(0, 8)}';

      // Initialize Whisper service for translation
      _whisperService = WhisperService();

      // Initialize Audio capture service
      _audioCaptureService = AudioCaptureService();

      // Setup audio capture callbacks
      _audioCaptureService!.onAudioCaptured = (audioData, speakerId, speakerName) {
        if (_subtitlesEnabled && _whisperService != null) {
          _whisperService!.sendAudioData(audioData, speakerId, speakerName);
        }
      };

      _audioCaptureService!.onError = (error) {
        print('Audio capture error: $error');
      };

      // Setup Whisper service callbacks with new workflow
      _whisperService!.onError = (error) {
        print('Whisper service error: $error');
      };

      _whisperService!.onConnectionChanged = (isConnected) {
        print('Whisper connection changed: $isConnected');
        notifyListeners();
      };

      print('WebRTC Mesh Service initialized: $_userId');
      notifyListeners();
    } catch (e) {
      print('Error initializing service: $e');
      throw Exception('Failed to initialize service: $e');
    }
  }

  // NEW: Set user display language preference (like YouTube subtitles)
  void setUserDisplayLanguage(String languageCode) {
    _userDisplayLanguage = languageCode;

    // Update Whisper service to translate everything to this language
    _whisperService?.setUserLanguages(
      nativeLanguage: 'auto', // Auto-detect what each person speaks
      displayLanguage: languageCode, // Always translate to user's preferred language
    );

    print('🌍 User display language set to: $languageCode');
    notifyListeners();
  }

  // Set user details
  void setUserDetails({
    required String displayName,
    String? userId,
    String? displayLanguage,
  }) {
    _displayName = displayName;
    if (userId != null) _userId = userId;
    if (displayLanguage != null) setUserDisplayLanguage(displayLanguage);
    notifyListeners();
  }

  // Create a new meeting
  Future<String> createMeeting({required String topic}) async {
    try {
      final String meetingId = 'GCM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _meetingId = meetingId;
      _isHost = true;

      print('Creating mesh meeting: $meetingId');

      if (topic.trim().isEmpty) {
        throw Exception('Meeting topic cannot be empty');
      }

      // Create meeting document with language support
      await _firestore.collection('meetings').doc(meetingId).set({
        'meetingId': meetingId,
        'topic': topic,
        'hostId': _userId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'participantCount': 0,
        'password': '123',
        'topology': 'mesh',
        'maxParticipants': 6,
        // New language settings
        'subtitlesEnabled': _subtitlesEnabled,
        'supportedLanguages': ['en', 'vi', 'zh', 'ja', 'ko', 'fr', 'de', 'es'], // Add more as needed
      });

      await _setupLocalStream();
      await _joinMeshNetwork(meetingId);

      return meetingId;
    } catch (e) {
      print('Error creating mesh meeting: $e');
      throw Exception('Failed to create meeting: $e');
    }
  }

  // Join an existing meeting
  Future<void> joinMeeting({required String meetingId}) async {
    try {
      print('Joining mesh meeting: $meetingId');

      final cleanMeetingId = meetingId.trim().toUpperCase();
      if (cleanMeetingId.isEmpty) {
        throw Exception('Meeting ID cannot be empty');
      }

      // Check meeting exists
      final meetingDoc = await _firestore.collection('meetings').doc(cleanMeetingId).get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      if (meetingData['status'] != 'active') {
        throw Exception('Meeting has ended');
      }

      // Check participant limit
      final participantCount = meetingData['participantCount'] ?? 0;
      if (participantCount >= 6) {
        throw Exception('Meeting is full (max 6 participants for mesh topology)');
      }

      _meetingId = cleanMeetingId;
      _isHost = meetingData['hostId'] == _userId;

      await _setupLocalStream();
      await _joinMeshNetwork(cleanMeetingId);
    } catch (e) {
      print('Error joining mesh meeting: $e');
      throw Exception('Failed to join meeting: $e');
    }
  }

  // FIXED: Setup local media stream with better error handling
  Future<void> _setupLocalStream() async {
    try {
      print('Setting up local stream...');

      // Initialize local renderer first
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
        print('✅ Local renderer initialized');
      }

      // Check if we already have a stream
      if (_localStream != null) {
        print('🔄 Disposing existing local stream...');
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        _localStream = null;
      }

      // Get user media with progressive fallback
      _localStream = await _getUserMediaWithFallback();

      if (_localStream != null) {
        _localRenderer!.srcObject = _localStream;

        // Start audio capture for subtitles if enabled
        if (_subtitlesEnabled && _userId != null) {
          await _audioCaptureService?.startLocalCapture(
            _localStream!,
            _userId!,
            _displayName,
          );
        }

        print('✅ Local stream setup complete');
        notifyListeners();
      } else {
        throw Exception('Failed to get media stream');
      }
    } catch (e) {
      print('❌ Error setting up local stream: $e');
      throw Exception('Could not access camera or microphone: $e');
    }
  }

  // FIXED: Progressive fallback for getUserMedia
  Future<MediaStream?> _getUserMediaWithFallback() async {
    // List of constraints to try, from most preferred to fallback
    final List<Map<String, dynamic>> constraintsList = [
      // High quality
      {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 48000,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280, 'max': 1920},
          'height': {'ideal': 720, 'max': 1080},
          'frameRate': {'ideal': 30, 'max': 60},
        },
      },
      // Medium quality
      {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 1280},
          'height': {'ideal': 480, 'max': 720},
          'frameRate': {'ideal': 30},
        },
      },
      // Basic quality
      {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
        },
        'video': {
          'width': {'ideal': 320, 'max': 640},
          'height': {'ideal': 240, 'max': 480},
          'frameRate': {'ideal': 15, 'max': 30},
        },
      },
      // Audio only fallback
      {
        'audio': {
          'echoCancellation': true,
        },
        'video': false,
      },
      // Minimal constraints
      {
        'audio': true,
        'video': true,
      },
      // Audio only minimal
      {
        'audio': true,
        'video': false,
      },
    ];

    for (int i = 0; i < constraintsList.length; i++) {
      try {
        final constraints = constraintsList[i];
        print('🔄 Trying media constraints ${i + 1}/${constraintsList.length}: ${constraints['video'] != false ? 'Video+Audio' : 'Audio only'}');

        final stream = await navigator.mediaDevices.getUserMedia(constraints);

        if (stream.getTracks().isNotEmpty) {
          final audioTracks = stream.getAudioTracks();
          final videoTracks = stream.getVideoTracks();

          print('✅ Media stream obtained:');
          print('   Audio tracks: ${audioTracks.length}');
          print('   Video tracks: ${videoTracks.length}');

          // Update internal state based on what we actually got
          _isAudioEnabled = audioTracks.isNotEmpty;
          _isVideoEnabled = videoTracks.isNotEmpty;

          return stream;
        }
      } catch (e) {
        print('❌ Constraints ${i + 1} failed: ${e.toString()}');

        // Log specific error types for debugging
        if (e.toString().contains('NotFoundError') || e.toString().contains('DevicesNotFoundError')) {
          print('   📍 Device not found - trying next constraint');
        } else if (e.toString().contains('NotAllowedError') || e.toString().contains('PermissionDeniedError')) {
          print('   🚫 Permission denied');
          if (i < constraintsList.length - 1) {
            print('   🔄 Trying with reduced permissions...');
          } else {
            throw Exception('Permission denied to access camera/microphone');
          }
        } else if (e.toString().contains('NotReadableError') || e.toString().contains('TrackStartError')) {
          print('   🔒 Device already in use');
        } else if (e.toString().contains('OverconstrainedError') || e.toString().contains('ConstraintNotSatisfiedError')) {
          print('   ⚠️ Constraints not satisfied - trying simpler constraints');
        }

        // If this is the last attempt, throw the error
        if (i == constraintsList.length - 1) {
          throw e;
        }
      }
    }

    throw Exception('Failed to obtain media stream with any constraints');
  }

  // Join the mesh network
  Future<void> _joinMeshNetwork(String meetingId) async {
    try {
      print('Joining mesh network for meeting: $meetingId');

      _isMeetingActive = true;

      // Connect to Whisper service if subtitles enabled
      if (_subtitlesEnabled) {
        try {
          final whisperConnected = await _whisperService?.connect() ?? false;
          if (whisperConnected) {
            print('✅ Connected to Whisper service for real-time subtitles');
          } else {
            print('⚠️ Failed to connect to Whisper service - subtitles disabled');
            _subtitlesEnabled = false;
          }
        } catch (e) {
          print('⚠️ Whisper connection error: $e - continuing without subtitles');
          _subtitlesEnabled = false;
        }
      }

      await _addSelfAsParticipant();
      _listenForMeshParticipants();
      _listenForSignalingMessages();

      notifyListeners();
    } catch (e) {
      print('Error joining mesh network: $e');
      _isMeetingActive = false;
      notifyListeners();
      throw Exception('Failed to setup meeting: $e');
    }
  }

  // Add self as participant with language preferences
  Future<void> _addSelfAsParticipant() async {
    if (_meetingId == null || _userId == null) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .set({
        'userId': _userId,
        'displayName': _displayName,
        'isHost': _isHost,
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isAudioEnabled': _isAudioEnabled,
        'isVideoEnabled': _isVideoEnabled,
        'connectionType': 'mesh',
        'peerConnections': [],
        // NEW: Language preferences for this participant
        'displayLanguage': _userDisplayLanguage, // What this user wants to see
        'subtitlesEnabled': _subtitlesEnabled,
      });

      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      print('Added self as participant with language settings');
    } catch (e) {
      print('Error adding self as participant: $e');
      rethrow;
    }
  }

  // Listen for participants in mesh network
  void _listenForMeshParticipants() {
    if (_meetingId == null) return;

    print('Listening for mesh participants...');

    final subscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      final List<MeshParticipant> newParticipants = [];
      final Set<String> currentParticipantIds = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participantId = doc.id;
        currentParticipantIds.add(participantId);

        final participant = MeshParticipant(
          id: participantId,
          name: participantId == _userId ? '${data['displayName']} (You)' : data['displayName'],
          isHost: data['isHost'] ?? false,
          isAudioEnabled: data['isAudioEnabled'] ?? true,
          isVideoEnabled: data['isVideoEnabled'] ?? true,
          isLocal: participantId == _userId,
          displayLanguage: data['displayLanguage'] ?? 'en',
        );

        newParticipants.add(participant);

        if (participantId != _userId && !_peerConnections.containsKey(participantId)) {
          await _createMeshConnection(participantId);
        }
      }

      // Remove disconnected participants
      final disconnectedIds = _peerConnections.keys.toSet().difference(currentParticipantIds);
      for (var id in disconnectedIds) {
        await _removeMeshConnection(id);
      }

      _participants.clear();
      _participants.addAll(newParticipants);

      print('Updated participants: ${_participants.length}');
      notifyListeners();
    }, onError: (error) {
      print('Error listening for mesh participants: $error');
    });

    _subscriptions.add(subscription);
  }

  // Create mesh connection with a peer - FIXED
  Future<void> _createMeshConnection(String peerId) async {
    try {
      print("Creating mesh connection with peer: $peerId");

      // Check if we have local stream
      if (_localStream == null) {
        print('⚠️ No local stream available for peer connection');
        return;
      }

      final pc = await createPeerConnection(_iceServers);
      _peerConnections[peerId] = pc;

      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[peerId] = renderer;

      // Add local stream tracks to peer connection
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
        print('📡 Added ${track.kind} track to peer connection with $peerId');
      }

      _setupPeerConnectionEventHandlers(pc, peerId);
      await _createAndSendOffer(pc, peerId);
    } catch (e) {
      print('Error creating mesh connection with $peerId: $e');
    }
  }

  // Setup peer connection event handlers with better logging
  void _setupPeerConnectionEventHandlers(RTCPeerConnection pc, String peerId) {
    pc.onIceConnectionState = (state) {
      print('🧊 ICE connection state with $peerId: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        print('💔 Connection with $peerId failed or disconnected');
        _handleConnectionFailure(peerId);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        print('✅ ICE connection established with $peerId');
      }
    };

    pc.onIceCandidate = (candidate) async {
      if (candidate.candidate != null) {
        await _sendIceCandidate(peerId, candidate);
      }
    };

    pc.onTrack = (event) {
      print('📺 Received track from $peerId: ${event.track?.kind}');
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[peerId] = stream;
        _remoteRenderers[peerId]?.srcObject = stream;

        // Add remote stream for audio capture if subtitles enabled
        if (_subtitlesEnabled) {
          final participant = _participants.firstWhere(
                (p) => p.id == peerId,
            orElse: () => MeshParticipant(id: peerId, name: 'Unknown'),
          );
          _audioCaptureService?.addRemoteStream(peerId, participant.name, stream);
        }

        print('✅ Remote stream from $peerId added to renderer');
        notifyListeners();
      }
    };

    pc.onConnectionState = (state) {
      print('🔗 Peer connection state with $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ Peer connection established with $peerId');
      }
    };

    pc.onSignalingState = (state) {
      print('📡 Signaling state with $peerId: $state');
    };
  }

  // Toggle subtitle functionality
  Future<void> toggleSubtitles() async {
    _subtitlesEnabled = !_subtitlesEnabled;

    if (_subtitlesEnabled) {
      // Connect to Whisper service and start audio capture
      final connected = await _whisperService?.connect() ?? false;
      if (connected && _localStream != null && _userId != null) {
        await _audioCaptureService?.startLocalCapture(
          _localStream!,
          _userId!,
          _displayName,
        );
      }
    } else {
      // Disconnect from Whisper service and stop audio capture
      await _audioCaptureService?.stopCapture();
      await _whisperService?.disconnect();
    }

    // Update in Firestore
    if (_meetingId != null && _userId != null) {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({'subtitlesEnabled': _subtitlesEnabled});
    }

    notifyListeners();
  }

  // Update language settings - NEW WORKFLOW
  Future<void> updateDisplayLanguage(String displayLanguage) async {
    _userDisplayLanguage = displayLanguage;

    // Update Whisper service to translate everything to this language
    _whisperService?.setUserLanguages(
      nativeLanguage: 'auto', // Auto-detect what each person speaks
      displayLanguage: displayLanguage, // Always translate to user's preferred language
    );

    // Update in Firestore
    if (_meetingId != null && _userId != null) {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'displayLanguage': displayLanguage,
      });
    }

    print('🌍 Display language updated to: $displayLanguage');
    notifyListeners();
  }

  // FIXED: Toggle audio with better error handling
  Future<void> toggleAudio() async {
    if (_localStream == null) {
      print('⚠️ No local stream available for audio toggle');
      return;
    }

    try {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isEmpty) {
        print('⚠️ No audio tracks available');
        return;
      }

      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }

      _isAudioEnabled = audioTracks.first.enabled;

      // Update audio capture based on audio state
      if (_subtitlesEnabled) {
        if (_isAudioEnabled) {
          await _audioCaptureService?.startLocalCapture(
            _localStream!,
            _userId!,
            _displayName,
          );
        } else {
          await _audioCaptureService?.stopCapture();
        }
      }

      // Update in Firestore
      if (_meetingId != null && _userId != null) {
        await _firestore
            .collection('meetings')
            .doc(_meetingId)
            .collection('participants')
            .doc(_userId)
            .update({'isAudioEnabled': _isAudioEnabled});
      }

      print('🎙️ Audio ${_isAudioEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      print('Error toggling audio: $e');
    }
  }

  // FIXED: Toggle video with better error handling
  Future<void> toggleVideo() async {
    if (_localStream == null) {
      print('⚠️ No local stream available for video toggle');
      return;
    }

    try {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isEmpty) {
        print('⚠️ No video tracks available');
        return;
      }

      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }

      _isVideoEnabled = videoTracks.first.enabled;

      // Update in Firestore
      if (_meetingId != null && _userId != null) {
        await _firestore
            .collection('meetings')
            .doc(_meetingId)
            .collection('participants')
            .doc(_userId)
            .update({'isVideoEnabled': _isVideoEnabled});
      }

      print('📹 Video ${_isVideoEnabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    } catch (e) {
      print('Error toggling video: $e');
    }
  }

  // Get renderer for participant
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }
    return _remoteRenderers[participantId];
  }

  // [Remaining methods continue with the same signaling logic...]
  // Leave meeting with enhanced cleanup
  Future<void> leaveMeeting() async {
    if (_meetingId == null || _userId == null) return;

    try {
      print('Leaving mesh meeting...');

      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isActive': false,
        'leftAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(-1),
      });

      if (_isHost) {
        await _firestore.collection('meetings').doc(_meetingId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }

      await _cleanup();
    } catch (e) {
      print('Error leaving meeting: $e');
      await _cleanup();
    }
  }

  // [Include all remaining signaling methods from the original file...]
  void _listenForSignalingMessages() {
    if (_meetingId == null || _userId == null) return;

    print('Listening for signaling messages...');

    final subscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('signaling')
        .where('to', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            await _handleSignalingMessage(data);
            await change.doc.reference.delete();
          }
        }
      }
    }, onError: (error) {
      print('Error listening for signaling messages: $error');
    });

    _subscriptions.add(subscription);
  }

  Future<void> _handleSignalingMessage(Map<String, dynamic> message) async {
    final String type = message['type'];
    final String fromId = message['from'];

    print('Received signaling message: $type from $fromId');

    try {
      switch (type) {
        case 'offer':
          await _handleOffer(fromId, message);
          break;
        case 'answer':
          await _handleAnswer(fromId, message);
          break;
        case 'ice-candidate':
          await _handleIceCandidate(fromId, message);
          break;
      }
    } catch (e) {
      print('Error handling signaling message: $e');
    }
  }

  Future<void> _handleOffer(String fromId, Map<String, dynamic> message) async {
    try {
      if (!_peerConnections.containsKey(fromId)) {
        await _createMeshConnection(fromId);
      }

      final pc = _peerConnections[fromId];
      if (pc == null) return;

      final offer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(offer);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      await _sendSignalingMessage(fromId, {
        'type': 'answer',
        'sdp': answer.sdp,
        'from': _userId,
        'to': fromId,
      });

      print('Answer sent to $fromId');
    } catch (e) {
      print('Error handling offer from $fromId: $e');
    }
  }

  Future<void> _handleAnswer(String fromId, Map<String, dynamic> message) async {
    try {
      final pc = _peerConnections[fromId];
      if (pc == null) return;

      final answer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(answer);

      print('Answer processed from $fromId');
    } catch (e) {
      print('Error handling answer from $fromId: $e');
    }
  }

  Future<void> _handleIceCandidate(String fromId, Map<String, dynamic> message) async {
    try {
      final pc = _peerConnections[fromId];
      if (pc == null) return;

      final candidate = RTCIceCandidate(
        message['candidate'],
        message['sdpMid'],
        message['sdpMLineIndex'],
      );

      await pc.addCandidate(candidate);
      print('ICE candidate added from $fromId');
    } catch (e) {
      print('Error handling ICE candidate from $fromId: $e');
    }
  }

  Future<void> _sendSignalingMessage(String toId, Map<String, dynamic> message) async {
    if (_meetingId == null) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('signaling')
          .add({
        ...message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Signaling message sent successfully to $toId');
    } catch (e) {
      print('Error sending signaling message: $e');
    }
  }

  Future<void> _createAndSendOffer(RTCPeerConnection pc, String peerId) async {
    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await _sendSignalingMessage(peerId, {
        'type': 'offer',
        'sdp': offer.sdp,
        'from': _userId,
        'to': peerId,
      });

      print('Offer sent to $peerId');
    } catch (e) {
      print('Error creating/sending offer to $peerId: $e');
    }
  }

  Future<void> _sendIceCandidate(String toId, RTCIceCandidate candidate) async {
    await _sendSignalingMessage(toId, {
      'type': 'ice-candidate',
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'from': _userId,
      'to': toId,
    });
  }

  void _handleConnectionFailure(String peerId) {
    print('Handling connection failure with $peerId');
    // Could implement reconnection logic here
  }

  Future<void> _removeMeshConnection(String peerId) async {
    try {
      print('Removing mesh connection with $peerId');

      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.close();
        _peerConnections.remove(peerId);
      }

      final stream = _remoteStreams[peerId];
      if (stream != null) {
        stream.getTracks().forEach((track) => track.stop());
        _remoteStreams.remove(peerId);
      }

      final renderer = _remoteRenderers[peerId];
      if (renderer != null) {
        await renderer.dispose();
        _remoteRenderers.remove(peerId);
      }

      // Remove from audio capture
      _audioCaptureService?.removeRemoteStream(peerId);

      notifyListeners();
    } catch (e) {
      print('Error removing mesh connection: $e');
    }
  }

  // Enhanced cleanup with better error handling
  Future<void> _cleanup() async {
    try {
      print('Cleaning up mesh resources...');

      // Stop audio capture and disconnect Whisper
      await _audioCaptureService?.clearAllStreams();
      await _whisperService?.disconnect();

      // Cancel subscriptions
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();

      // Close peer connections
      for (var pc in _peerConnections.values) {
        try {
          await pc.close();
        } catch (e) {
          print('Error closing peer connection: $e');
        }
      }
      _peerConnections.clear();

      // Stop remote streams
      for (var stream in _remoteStreams.values) {
        try {
          stream.getTracks().forEach((track) => track.stop());
        } catch (e) {
          print('Error stopping remote stream: $e');
        }
      }
      _remoteStreams.clear();

      // Dispose renderers
      for (var renderer in _remoteRenderers.values) {
        try {
          await renderer.dispose();
        } catch (e) {
          print('Error disposing renderer: $e');
        }
      }
      _remoteRenderers.clear();

      // Stop local stream
      if (_localStream != null) {
        try {
          _localStream!.getTracks().forEach((track) => track.stop());
        } catch (e) {
          print('Error stopping local stream: $e');
        }
        _localStream = null;
      }

      // Dispose local renderer
      if (_localRenderer != null) {
        try {
          await _localRenderer!.dispose();
        } catch (e) {
          print('Error disposing local renderer: $e');
        }
        _localRenderer = null;
      }

      // Reset state
      _meetingId = null;
      _isHost = false;
      _isMeetingActive = false;
      _participants.clear();

      notifyListeners();
      print('✅ Mesh resources cleaned up successfully');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    print('Disposing WebRTC Mesh Service...');
    _cleanup();
    super.dispose();
  }
}

// Updated Mesh Participant Model with language support
class MeshParticipant {
  final String id;
  final String name;
  final bool isHost;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isLocal;
  final String displayLanguage; // NEW: What language this user wants to see

  MeshParticipant({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isLocal = false,
    this.displayLanguage = 'en',
  });

  MeshParticipant copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isAudioEnabled,
    bool? isVideoEnabled,
    bool? isLocal,
    String? displayLanguage,
  }) {
    return MeshParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isLocal: isLocal ?? this.isLocal,
      displayLanguage: displayLanguage ?? this.displayLanguage,
    );
  }
}