// lib/services/webrtc_mesh_meeting_service.dart (UPDATED)
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

  // Whisper and Audio services
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

  // Subtitle settings
  bool _areSubtitlesEnabled = true;
  String _userNativeLanguage = 'en';
  String _userDisplayLanguage = 'en';

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
  bool get areSubtitlesEnabled => _areSubtitlesEnabled;
  String get userNativeLanguage => _userNativeLanguage;
  String get userDisplayLanguage => _userDisplayLanguage;
  List<MeshParticipant> get participants => List.unmodifiable(_participants);
  RTCVideoRenderer? get localRenderer => _localRenderer;
  WhisperService? get whisperService => _whisperService;
  AudioCaptureService? get audioCaptureService => _audioCaptureService;

  // ICE Servers configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': 'stun:stun.relay.metered.ca:80',
      },
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

      // Initialize Whisper service
      _whisperService = WhisperService();

      // Initialize Audio capture service
      _audioCaptureService = AudioCaptureService();

      // Setup audio capture callbacks
      _audioCaptureService!.onAudioCaptured = (audioData, speakerId, speakerName) {
        _whisperService?.sendAudioData(audioData, speakerId, speakerName);
      };

      _audioCaptureService!.onError = (error) {
        print('Audio capture error: $error');
      };

      // Setup Whisper service callbacks
      _whisperService!.onError = (error) {
        print('Whisper service error: $error');
      };

      _whisperService!.onConnectionChanged = (isConnected) {
        print('Whisper connection changed: $isConnected');
        notifyListeners();
      };

      print('WebRTC Mesh Service with Whisper initialized: $_userId');
      notifyListeners();
    } catch (e) {
      print('Error initializing service: $e');
      throw Exception('Failed to initialize service: $e');
    }
  }

  // Set user details and language preferences
  void setUserDetails({
    required String displayName,
    String? userId,
    String? nativeLanguage,
    String? displayLanguage,
  }) {
    _displayName = displayName;
    if (userId != null) _userId = userId;
    if (nativeLanguage != null) _userNativeLanguage = nativeLanguage;
    if (displayLanguage != null) _userDisplayLanguage = displayLanguage;

    // Update Whisper service with language settings
    _whisperService?.setUserLanguages(
      nativeLanguage: _userNativeLanguage,
      displayLanguage: _userDisplayLanguage,
    );

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

      // Create meeting document
      await _firestore.collection('meetings').doc(meetingId).set({
        'meetingId': meetingId,
        'topic': topic,
        'hostId': _userId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'participantCount': 0,
        'password': '123',
        'translationLanguages': {
          '0': 'english',
          '1': 'vietnamese',
        },
        'topology': 'mesh',
        'maxParticipants': 6,
        // Subtitle settings
        'subtitlesEnabled': _areSubtitlesEnabled,
        'primaryLanguage': _userNativeLanguage,
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

  // Setup local media stream
  Future<void> _setupLocalStream() async {
    try {
      print('Setting up local stream...');

      // Initialize local renderer
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
      }

      // Get user media
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': _isAudioEnabled,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });

      _localRenderer!.srcObject = _localStream;

      // Start audio capture for subtitles if enabled
      if (_areSubtitlesEnabled && _localStream != null && _userId != null) {
        await _audioCaptureService?.startLocalCapture(
          _localStream!,
          _userId!,
          _displayName,
        );
      }

      print('Local stream setup complete');
      notifyListeners();
    } catch (e) {
      print('Error setting up local stream: $e');
      throw Exception('Could not access camera or microphone: $e');
    }
  }

  // Join the mesh network
  Future<void> _joinMeshNetwork(String meetingId) async {
    try {
      print('Joining mesh network for meeting: $meetingId');

      _isMeetingActive = true;

      // Connect to Whisper service if subtitles enabled
      if (_areSubtitlesEnabled) {
        final whisperConnected = await _whisperService?.connect() ?? false;
        if (whisperConnected) {
          print('✅ Connected to Whisper service for real-time subtitles');
        } else {
          print('⚠️ Failed to connect to Whisper service - subtitles disabled');
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

  // Add self as participant
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
        // Language preferences
        'nativeLanguage': _userNativeLanguage,
        'displayLanguage': _userDisplayLanguage,
        'subtitlesEnabled': _areSubtitlesEnabled,
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
          nativeLanguage: data['nativeLanguage'] ?? 'en',
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

  // Create mesh connection with a peer (existing method - unchanged)
  Future<void> _createMeshConnection(String peerId) async {
    try {
      print("Creating mesh connection with peer: $peerId");

      final pc = await createPeerConnection(_iceServers);
      _peerConnections[peerId] = pc;

      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[peerId] = renderer;

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
      }

      _setupPeerConnectionEventHandlers(pc, peerId);
      await _createAndSendOffer(pc, peerId);
    } catch (e) {
      print('Error creating mesh connection with $peerId: $e');
    }
  }

  // Setup peer connection event handlers (updated to handle remote audio capture)
  void _setupPeerConnectionEventHandlers(RTCPeerConnection pc, String peerId) {
    pc.onIceConnectionState = (state) {
      print('ICE connection state with $peerId: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        print('Connection with $peerId failed or disconnected');
        _handleConnectionFailure(peerId);
      }
    };

    pc.onIceCandidate = (candidate) async {
      await _sendIceCandidate(peerId, candidate);
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[peerId] = stream;
        _remoteRenderers[peerId]?.srcObject = stream;

        // Add remote stream for audio capture if subtitles enabled
        if (_areSubtitlesEnabled) {
          final participant = _participants.firstWhere(
                (p) => p.id == peerId,
            orElse: () => MeshParticipant(id: peerId, name: 'Unknown'),
          );
          _audioCaptureService?.addRemoteStream(peerId, participant.name, stream);
        }

        print('Remote stream received from $peerId');
        notifyListeners();
      }
    };

    pc.onConnectionState = (state) {
      print('Connection state with $peerId: $state');
    };
  }

  // Toggle subtitle functionality
  Future<void> toggleSubtitles() async {
    _areSubtitlesEnabled = !_areSubtitlesEnabled;

    if (_areSubtitlesEnabled) {
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

    notifyListeners();
  }

  // Update language settings
  Future<void> updateLanguageSettings({
    required String nativeLanguage,
    required String displayLanguage,
  }) async {
    _userNativeLanguage = nativeLanguage;
    _userDisplayLanguage = displayLanguage;

    // Update Whisper service
    _whisperService?.setUserLanguages(
      nativeLanguage: nativeLanguage,
      displayLanguage: displayLanguage,
    );

    // Update in Firestore
    if (_meetingId != null && _userId != null) {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'nativeLanguage': nativeLanguage,
        'displayLanguage': displayLanguage,
      });
    }

    notifyListeners();
  }

  // Toggle audio (updated to handle audio capture)
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    try {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }

      _isAudioEnabled = audioTracks.first.enabled;

      // Update audio capture based on audio state
      if (_areSubtitlesEnabled) {
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

      notifyListeners();
    } catch (e) {
      print('Error toggling audio: $e');
    }
  }

  // Toggle video (existing method - unchanged)
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    try {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }

      _isVideoEnabled = videoTracks.first.enabled;

      if (_meetingId != null && _userId != null) {
        await _firestore
            .collection('meetings')
            .doc(_meetingId)
            .collection('participants')
            .doc(_userId)
            .update({'isVideoEnabled': _isVideoEnabled});
      }

      notifyListeners();
    } catch (e) {
      print('Error toggling video: $e');
    }
  }

  // Get renderer for participant (existing method - unchanged)
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }
    return _remoteRenderers[participantId];
  }

  // Leave meeting (updated with cleanup)
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

  // Cleanup resources (updated with audio and whisper cleanup)
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
        await pc.close();
      }
      _peerConnections.clear();

      // Stop remote streams
      for (var stream in _remoteStreams.values) {
        stream.getTracks().forEach((track) => track.stop());
      }
      _remoteStreams.clear();

      // Dispose renderers
      for (var renderer in _remoteRenderers.values) {
        await renderer.dispose();
      }
      _remoteRenderers.clear();

      // Stop local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        _localStream = null;
      }

      // Dispose local renderer
      if (_localRenderer != null) {
        await _localRenderer!.dispose();
        _localRenderer = null;
      }

      // Reset state
      _meetingId = null;
      _isHost = false;
      _isMeetingActive = false;
      _participants.clear();

      notifyListeners();
      print('Mesh resources cleaned up');
    } catch (e) {
      print('Error cleaning up: $e');
    }
  }

  // Existing signaling methods (unchanged)
  void _listenForSignalingMessages() { /* ... existing implementation ... */ }
  Future<void> _handleSignalingMessage(Map<String, dynamic> message) async { /* ... existing implementation ... */ }
  Future<void> _handleOffer(String fromId, Map<String, dynamic> message) async { /* ... existing implementation ... */ }
  Future<void> _handleAnswer(String fromId, Map<String, dynamic> message) async { /* ... existing implementation ... */ }
  Future<void> _handleIceCandidate(String fromId, Map<String, dynamic> message) async { /* ... existing implementation ... */ }
  Future<void> _sendSignalingMessage(String toId, Map<String, dynamic> message) async { /* ... existing implementation ... */ }
  Future<void> _sendIceCandidate(String toId, RTCIceCandidate candidate) async { /* ... existing implementation ... */ }
  Future<void> _createAndSendOffer(RTCPeerConnection pc, String peerId) async { /* ... existing implementation ... */ }
  void _handleConnectionFailure(String peerId) { /* ... existing implementation ... */ }
  Future<void> _removeMeshConnection(String peerId) async { /* ... existing implementation ... */ }

  @override
  void dispose() {
    print('Disposing WebRTC Mesh Service...');
    _cleanup();
    super.dispose();
  }
}

// Updated Mesh Participant Model
class MeshParticipant {
  final String id;
  final String name;
  final bool isHost;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isLocal;
  final String nativeLanguage;
  final String displayLanguage;

  MeshParticipant({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isLocal = false,
    this.nativeLanguage = 'en',
    this.displayLanguage = 'en',
  });

  MeshParticipant copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isAudioEnabled,
    bool? isVideoEnabled,
    bool? isLocal,
    String? nativeLanguage,
    String? displayLanguage,
  }) {
    return MeshParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isLocal: isLocal ?? this.isLocal,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      displayLanguage: displayLanguage ?? this.displayLanguage,
    );
  }
}