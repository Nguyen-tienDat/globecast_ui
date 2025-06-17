// lib/services/webrtc_mesh_meeting_service.dart - FIXED VERSION
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

class WebRTCMeshMeetingService extends ChangeNotifier {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // WebRTC Mesh Network - Each peer connects to all other peers
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

  // Participants
  final List<MeshParticipant> _participants = [];

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Track negotiation states to prevent race conditions
  final Map<String, bool> _negotiationStates = {};

  // Connection retry mechanism
  final Map<String, int> _connectionRetryCount = {};
  final int _maxRetryAttempts = 3;

  // Getters
  String? get meetingId => _meetingId;
  String? get userId => _userId;
  bool get isHost => _isHost;
  bool get isMeetingActive => _isMeetingActive;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  List<MeshParticipant> get participants => List.unmodifiable(_participants);
  RTCVideoRenderer? get localRenderer => _localRenderer;

  // FIXED: Enhanced ICE Servers configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': "stun:stun.relay.metered.ca:80",
      },
      {
        'urls': "turn:global.relay.metered.ca:80",
        'username': "011cf7f1d7b04d87a51a1826",
        'credential': "WYpn3MCOSKNDBfFw",
      },
      {
        'urls': "turn:global.relay.metered.ca:80?transport=tcp",
        'username': "011cf7f1d7b04d87a51a1826",
        'credential': "WYpn3MCOSKNDBfFw",
      },
      {
        'urls': "turn:global.relay.metered.ca:443",
        'username': "011cf7f1d7b04d87a51a1826",
        'credential': "WYpn3MCOSKNDBfFw",
      },
      {
        'urls': "turns:global.relay.metered.ca:443?transport=tcp",
        'username': "011cf7f1d7b04d87a51a1826",
        'credential': "WYpn3MCOSKNDBfFw",
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  // Initialize service
  Future<void> initialize() async {
    try {
      _userId ??= 'USR${const Uuid().v4().replaceAll('-', '').substring(0, 8)}';
      print('🔧 WebRTC Mesh Service initialized with userId: $_userId');
      notifyListeners();
    } catch (e) {
      print('❌ Error initializing service: $e');
      throw Exception('Failed to initialize service: $e');
    }
  }

  // Debug media stream method
  Future<void> debugMediaStream() async {
    print('=== 🔍 MEDIA STREAM DEBUG ===');

    // Check local stream
    if (_localStream != null) {
      print('✅ Local stream exists');
      print('📹 Video tracks: ${_localStream!.getVideoTracks().length}');
      print('🎤 Audio tracks: ${_localStream!.getAudioTracks().length}');

      for (var track in _localStream!.getVideoTracks()) {
        print('📹 Video track: ${track.id}, enabled: ${track.enabled}');
      }

      for (var track in _localStream!.getAudioTracks()) {
        print('🎤 Audio track: ${track.id}, enabled: ${track.enabled}');
      }
    } else {
      print('❌ Local stream is null');
    }

    // Check local renderer
    if (_localRenderer != null) {
      print('✅ Local renderer exists');
      print('🔗 Renderer srcObject: ${_localRenderer!.srcObject != null ? "Connected" : "Not connected"}');
    } else {
      print('❌ Local renderer is null');
    }

    // Check remote streams
    print('🌐 Remote streams count: ${_remoteStreams.length}');
    _remoteStreams.forEach((peerId, stream) {
      print('🔗 Remote stream $peerId: Video=${stream.getVideoTracks().length}, Audio=${stream.getAudioTracks().length}');
    });

    // Check peer connections
    print('🤝 Peer connections count: ${_peerConnections.length}');
    _peerConnections.forEach((peerId, pc) {
      print('🤝 Peer $peerId connection state: ${pc.connectionState}');
      print('🧊 Peer $peerId ICE state: ${pc.iceConnectionState}');
      print('🔄 Peer $peerId signaling state: ${pc.signalingState}');
    });

    print('=== 🔍 DEBUG END ===');
  }

  // Set user details
  void setUserDetails({required String displayName, String? userId}) {
    _displayName = displayName;
    if (userId != null) _userId = userId;
    print('👤 User details set: $_displayName (ID: $_userId)');
    notifyListeners();
  }

  // Create a new meeting
  Future<String> createMeeting({required String topic}) async {
    try {
      final String meetingId = 'GCM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _meetingId = meetingId;
      _isHost = true;

      print('🏗️ Creating mesh meeting: $meetingId');

      if (topic.trim().isEmpty) {
        throw Exception('Meeting topic cannot be empty');
      }

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
      });

      await _setupLocalStream();
      await _joinMeshNetwork(meetingId);

      return meetingId;
    } catch (e) {
      print('❌ Error creating mesh meeting: $e');
      throw Exception('Failed to create meeting: $e');
    }
  }

  // Join an existing meeting
  Future<void> joinMeeting({required String meetingId}) async {
    try {
      print('🚪 Joining mesh meeting: $meetingId');

      final cleanMeetingId = meetingId.trim().toUpperCase();
      if (cleanMeetingId.isEmpty) {
        throw Exception('Meeting ID cannot be empty');
      }

      final meetingDoc = await _firestore.collection('meetings').doc(cleanMeetingId).get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      if (meetingData['status'] != 'active') {
        throw Exception('Meeting has ended');
      }

      final participantCount = meetingData['participantCount'] ?? 0;
      if (participantCount >= 6) {
        throw Exception('Meeting is full (max 6 participants for mesh topology)');
      }

      _meetingId = cleanMeetingId;
      _isHost = meetingData['hostId'] == _userId;

      await _setupLocalStream();
      await _joinMeshNetwork(cleanMeetingId);
    } catch (e) {
      print('❌ Error joining mesh meeting: $e');
      throw Exception('Failed to join meeting: $e');
    }
  }

  // FIXED: Enhanced local stream setup
  Future<void> _setupLocalStream() async {
    try {
      print('🎬 Setting up local stream...');

      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
        print('✅ Local renderer initialized');
      }

      MediaStream? stream;

      // Try to get user media with multiple fallback strategies
      try {
        final mediaConstraints = {
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
            'googEchoCancellation': true,
            'googAutoGainControl': true,
            'googNoiseSuppression': true,
            'googHighpassFilter': true,
            'googTypingNoiseDetection': true,
          },
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 640, 'max': 1280, 'min': 320},
            'height': {'ideal': 480, 'max': 720, 'min': 240},
            'frameRate': {'ideal': 30, 'max': 30, 'min': 15},
          },
        };

        stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        print('✅ Full media stream obtained');
      } catch (e) {
        print('⚠️ Full media failed: $e');

        // Fallback: Audio only
        try {
          stream = await navigator.mediaDevices.getUserMedia({
            'audio': {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            },
            'video': false,
          });
          print('✅ Audio-only stream obtained');
          _isVideoEnabled = false;
        } catch (e2) {
          print('⚠️ Audio-only failed: $e2');

          // Fallback: Video only
          try {
            stream = await navigator.mediaDevices.getUserMedia({
              'audio': false,
              'video': {
                'facingMode': 'user',
                'width': {'ideal': 320},
                'height': {'ideal': 240},
              },
            });
            print('✅ Video-only stream obtained');
            _isAudioEnabled = false;
          } catch (e3) {
            print('❌ All media access failed: $e3');
            throw Exception('Could not access any media devices. Please check permissions.');
          }
        }
      }

      if (stream != null) {
        _localStream = stream;

        // FIXED: Ensure renderer is properly connected
        await Future.delayed(const Duration(milliseconds: 100));
        _localRenderer!.srcObject = stream;

        _isAudioEnabled = stream.getAudioTracks().isNotEmpty &&
            stream.getAudioTracks().first.enabled;
        _isVideoEnabled = stream.getVideoTracks().isNotEmpty &&
            stream.getVideoTracks().first.enabled;

        print('📊 Stream setup complete:');
        print('   📹 Video tracks: ${stream.getVideoTracks().length} (enabled: $_isVideoEnabled)');
        print('   🎤 Audio tracks: ${stream.getAudioTracks().length} (enabled: $_isAudioEnabled)');

        notifyListeners();
      } else {
        throw Exception('Failed to obtain media stream');
      }

    } catch (e) {
      print('💥 Fatal error in _setupLocalStream: $e');
      throw Exception('Could not setup media stream: $e');
    }
  }

  // Join the mesh network
  Future<void> _joinMeshNetwork(String meetingId) async {
    try {
      print('🕸️ Joining mesh network for meeting: $meetingId');

      _isMeetingActive = true;
      await _addSelfAsParticipant();
      _listenForMeshParticipants();
      _listenForSignalingMessages();

      notifyListeners();
    } catch (e) {
      print('❌ Error joining mesh network: $e');
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
      });

      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      print('✅ Added self as participant');
    } catch (e) {
      print('❌ Error adding self as participant: $e');
      rethrow;
    }
  }

  // FIXED: Listen for participants with better error handling
  void _listenForMeshParticipants() {
    if (_meetingId == null) return;

    print('👂 Listening for mesh participants...');

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
        );

        newParticipants.add(participant);

        // Create peer connection for remote participants
        if (participantId != _userId && !_peerConnections.containsKey(participantId)) {
          await _coordinatedCreateConnection(participantId);
        }
      }

      // Remove disconnected participants
      final disconnectedIds = _peerConnections.keys.toSet().difference(currentParticipantIds);
      for (var id in disconnectedIds) {
        await _removeMeshConnection(id);
      }

      _participants.clear();
      _participants.addAll(newParticipants);

      print('👥 Updated participants: ${_participants.length}');
      notifyListeners();
    }, onError: (error) {
      print('❌ Error listening for mesh participants: $error');
    });

    _subscriptions.add(subscription);
  }

  // FIXED: Better coordination for connection creation
  Future<void> _coordinatedCreateConnection(String peerId) async {
    // Prevent multiple attempts
    if (_negotiationStates.containsKey(peerId) && _negotiationStates[peerId] == true) {
      print('⚠️ Already creating connection with $peerId');
      return;
    }

    final shouldInitiate = (_userId?.compareTo(peerId) ?? 0) > 0;
    print('🤝 Coordinated connection with $peerId - shouldInitiate: $shouldInitiate');

    _negotiationStates[peerId] = true;

    try {
      await _createMeshConnection(peerId, isInitiator: shouldInitiate);
    } catch (e) {
      print('❌ Error in coordinated connection creation: $e');
      _negotiationStates[peerId] = false;
    }
  }

  // FIXED: Enhanced mesh connection creation
  Future<void> _createMeshConnection(String peerId, {required bool isInitiator}) async {
    try {
      print("🤝 Creating mesh connection with peer: $peerId (initiator: $isInitiator)");

      if (_peerConnections.containsKey(peerId)) {
        print('⚠️ Connection with $peerId already exists');
        return;
      }

      // Create peer connection with enhanced configuration
      final pc = await createPeerConnection({
        ..._iceServers,
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });

      _peerConnections[peerId] = pc;

      // Create renderer for remote stream
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[peerId] = renderer;

      // FIXED: Add tracks BEFORE setting up event handlers
      if (_localStream != null) {
        print('➕ Adding local stream tracks to peer connection...');

        // Add each track individually
        for (var track in _localStream!.getTracks()) {
          try {
            await pc.addTrack(track, _localStream!);
            print('✅ Added ${track.kind} track ${track.id} to peer connection with $peerId');
          } catch (e) {
            print('⚠️ Error adding track ${track.id}: $e');
          }
        }
      }

      // Setup event handlers AFTER adding tracks
      _setupPeerConnectionEventHandlers(pc, peerId);

      // FIXED: Better timing for offer creation
      if (isInitiator) {
        // Wait a bit longer to ensure everything is properly set up
        await Future.delayed(const Duration(milliseconds: 300));
        await _createAndSendOffer(pc, peerId);
      } else {
        print('📱 Waiting for offer from $peerId...');
      }

    } catch (e) {
      print('❌ Error creating mesh connection with $peerId: $e');
      await _removeMeshConnection(peerId);
      _negotiationStates[peerId] = false;
    }
  }

  // FIXED: Enhanced event handlers
  void _setupPeerConnectionEventHandlers(RTCPeerConnection pc, String peerId) {
    pc.onIceConnectionState = (state) {
      print('🧊 ICE connection state with $peerId: $state');

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          print('💥 Connection with $peerId failed or disconnected');
          _handleConnectionFailure(peerId);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          print('✅ Successfully connected to $peerId');
          _connectionRetryCount[peerId] = 0; // Reset retry count
          break;
        default:
          print('🔄 ICE state: $state');
      }
    };

    pc.onIceCandidate = (candidate) async {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        await _sendIceCandidate(peerId, candidate);
        print('🧊 ICE candidate sent to $peerId: ${candidate.candidate!.substring(0, 50)}...');
      }
    };

    // FIXED: Enhanced onTrack handler
    pc.onTrack = (event) {
      print('📺 onTrack event received from $peerId');
      print('   Streams count: ${event.streams.length}');
      print('   Track kind: ${event.track.kind}');
      print('   Track id: ${event.track.id}');

      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[peerId] = stream;

        final renderer = _remoteRenderers[peerId];
        if (renderer != null) {
          // FIXED: Ensure renderer connection happens properly
          Future.delayed(const Duration(milliseconds: 100), () {
            renderer.srcObject = stream;
            print('📺 Remote stream connected to renderer for $peerId');
            notifyListeners();
          });
        }

        print('📺 Remote stream received from $peerId');
        print('   📹 Remote video tracks: ${stream.getVideoTracks().length}');
        print('   🎤 Remote audio tracks: ${stream.getAudioTracks().length}');

        // Log track details
        for (var track in stream.getTracks()) {
          print('   Track: ${track.kind} - ${track.id} - enabled: ${track.enabled}');
        }

        notifyListeners();
      }
    };

    pc.onConnectionState = (state) {
      print('🔗 Connection state with $peerId: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ WebRTC connection established with $peerId');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        print('❌ WebRTC connection failed with $peerId');
        _handleConnectionFailure(peerId);
      }
    };

    // FIXED: Add signaling state handler
    pc.onSignalingState = (state) {
      print('📡 Signaling state with $peerId: $state');
    };

    pc.onDataChannel = (channel) {
      print('📡 Data channel received from $peerId: ${channel.label}');
    };
  }

  // FIXED: Enhanced offer creation
  Future<void> _createAndSendOffer(RTCPeerConnection pc, String peerId) async {
    try {
      if (_negotiationStates[peerId] != true) {
        print('⚠️ Not in negotiation state with $peerId, skipping offer');
        return;
      }

      print('📤 Creating offer for $peerId...');

      // Create offer with specific options
      final offer = await pc.createOffer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
        'iceRestart': false,
      });

      await pc.setLocalDescription(offer);
      print('✅ Local description set for $peerId');

      await _sendSignalingMessage(peerId, {
        'type': 'offer',
        'sdp': offer.sdp,
        'from': _userId,
        'to': peerId,
      });

      print('📤 Offer sent to $peerId');
    } catch (e) {
      print('❌ Error creating/sending offer to $peerId: $e');
      _negotiationStates[peerId] = false;
    }
  }

  // Listen for signaling messages
  void _listenForSignalingMessages() {
    if (_meetingId == null || _userId == null) return;

    print('👂 Listening for signaling messages...');

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
            try {
              await change.doc.reference.delete();
            } catch (e) {
              print('⚠️ Could not delete signaling message: $e');
            }
          }
        }
      }
    }, onError: (error) {
      print('❌ Error listening for signaling messages: $error');
    });

    _subscriptions.add(subscription);
  }

  // Handle signaling message
  Future<void> _handleSignalingMessage(Map<String, dynamic> message) async {
    final String type = message['type'];
    final String fromId = message['from'];

    print('📨 Received signaling message: $type from $fromId');

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
      print('❌ Error handling signaling message: $e');
    }
  }

  // FIXED: Enhanced offer handling
  Future<void> _handleOffer(String fromId, Map<String, dynamic> message) async {
    try {
      print('📨 Handling offer from $fromId');

      // Create peer connection if doesn't exist
      if (!_peerConnections.containsKey(fromId)) {
        await _createMeshConnection(fromId, isInitiator: false);
      }

      final pc = _peerConnections[fromId];
      if (pc == null) {
        print('❌ No peer connection found for $fromId');
        return;
      }

      // Check signaling state
      print('📡 Current signaling state with $fromId: ${pc.signalingState}');

      // Set remote description
      final offer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(offer);
      print('✅ Remote description set for offer from $fromId');

      // Create and send answer
      final answer = await pc.createAnswer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
      });

      await pc.setLocalDescription(answer);
      print('✅ Local description set for answer to $fromId');

      await _sendSignalingMessage(fromId, {
        'type': 'answer',
        'sdp': answer.sdp,
        'from': _userId,
        'to': fromId,
      });

      print('📤 Answer sent to $fromId');
      _negotiationStates[fromId] = false;
    } catch (e) {
      print('❌ Error handling offer from $fromId: $e');
      _negotiationStates[fromId] = false;
    }
  }

  // FIXED: Enhanced answer handling
  Future<void> _handleAnswer(String fromId, Map<String, dynamic> message) async {
    try {
      print('📨 Handling answer from $fromId');

      final pc = _peerConnections[fromId];
      if (pc == null) {
        print('❌ No peer connection found for $fromId');
        return;
      }

      print('📡 Current signaling state with $fromId: ${pc.signalingState}');

      if (pc.signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print('⚠️ Cannot handle answer from $fromId, wrong signaling state: ${pc.signalingState}');
        return;
      }

      final answer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(answer);

      print('✅ Answer processed from $fromId');
      _negotiationStates[fromId] = false;
    } catch (e) {
      print('❌ Error handling answer from $fromId: $e');
      _negotiationStates[fromId] = false;
    }
  }

  // FIXED: Enhanced ICE candidate handling
  Future<void> _handleIceCandidate(String fromId, Map<String, dynamic> message) async {
    try {
      final pc = _peerConnections[fromId];
      if (pc == null) {
        print('⚠️ No peer connection found for ICE candidate from $fromId');
        return;
      }

      // Check if we can add the candidate
      final signalingState = pc.signalingState;
      if (signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        print('⚠️ Connection closed, cannot add ICE candidate from $fromId');
        return;
      }

      // Check if we're in a proper state to add candidates
      if (signalingState == RTCSignalingState.RTCSignalingStateStable ||
          signalingState == RTCSignalingState.RTCSignalingStateHaveRemoteOffer ||
          signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {

        final candidate = RTCIceCandidate(
          message['candidate'],
          message['sdpMid'],
          message['sdpMLineIndex'],
        );

        await pc.addCandidate(candidate);
        print('🧊 ICE candidate added from $fromId');
      } else {
        print('⚠️ Cannot add ICE candidate, signaling state: $signalingState');
      }
    } catch (e) {
      print('❌ Error handling ICE candidate from $fromId: $e');
    }
  }

  // Send signaling message
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

      print('📡 Signaling message sent successfully to $toId');
    } catch (e) {
      print('❌ Error sending signaling message: $e');
    }
  }

  // Send ICE candidate
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

  // FIXED: Enhanced connection failure handling with retry
  void _handleConnectionFailure(String peerId) {
    print('🚨 Handling connection failure with $peerId');

    _negotiationStates[peerId] = false;

    // Implement retry logic
    final retryCount = _connectionRetryCount[peerId] ?? 0;
    if (retryCount < _maxRetryAttempts) {
      _connectionRetryCount[peerId] = retryCount + 1;
      print('🔄 Retrying connection with $peerId (attempt ${retryCount + 1}/$_maxRetryAttempts)');

      // Retry after delay
      Future.delayed(Duration(seconds: 2 * (retryCount + 1)), () async {
        await _removeMeshConnection(peerId);
        await _coordinatedCreateConnection(peerId);
      });
    } else {
      print('❌ Max retry attempts reached for $peerId');
      _connectionRetryCount.remove(peerId);
    }
  }

  // FIXED: Enhanced connection removal
  Future<void> _removeMeshConnection(String peerId) async {
    try {
      print('🗑️ Removing mesh connection with $peerId');

      _negotiationStates.remove(peerId);
      _connectionRetryCount.remove(peerId);

      // Close peer connection
      final pc = _peerConnections[peerId];
      if (pc != null) {
        try {
          await pc.close();
        } catch (e) {
          print('⚠️ Error closing peer connection: $e');
        }
        _peerConnections.remove(peerId);
      }

      // Stop remote stream
      final stream = _remoteStreams[peerId];
      if (stream != null) {
        try {
          for (var track in stream.getTracks()) {
            await track.stop();
          }
        } catch (e) {
          print('⚠️ Error stopping remote stream tracks: $e');
        }
        _remoteStreams.remove(peerId);
      }

      // Dispose renderer
      final renderer = _remoteRenderers[peerId];
      if (renderer != null) {
        try {
          await renderer.dispose();
        } catch (e) {
          print('⚠️ Error disposing renderer: $e');
        }
        _remoteRenderers.remove(peerId);
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error removing mesh connection: $e');
    }
  }

  // FIXED: Enhanced audio toggle
  Future<void> toggleAudio() async {
    if (_localStream == null) {
      print('❌ Cannot toggle audio: local stream is null');
      return;
    }

    try {
      final audioTracks = _localStream!.getAudioTracks();
      print('🎤 Toggling audio. Current tracks: ${audioTracks.length}');

      if (audioTracks.isEmpty) {
        print('⚠️ No audio tracks available');
        _isAudioEnabled = false;
      } else {
        for (var track in audioTracks) {
          track.enabled = !track.enabled;
          print('🎵 Audio track ${track.id} enabled: ${track.enabled}');
        }
        _isAudioEnabled = audioTracks.first.enabled;
      }

      // Update in Firestore
      if (_meetingId != null && _userId != null) {
        try {
          await _firestore
              .collection('meetings')
              .doc(_meetingId)
              .collection('participants')
              .doc(_userId)
              .update({'isAudioEnabled': _isAudioEnabled});
          print('📡 Updated audio status in Firestore: $_isAudioEnabled');
        } catch (e) {
          print('⚠️ Error updating audio status in Firestore: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error toggling audio: $e');
    }
  }

  // FIXED: Enhanced video toggle
  Future<void> toggleVideo() async {
    if (_localStream == null) {
      print('❌ Cannot toggle video: local stream is null');
      return;
    }

    try {
      final videoTracks = _localStream!.getVideoTracks();
      print('🎥 Toggling video. Current tracks: ${videoTracks.length}');

      if (videoTracks.isEmpty) {
        print('⚠️ No video tracks available');
        _isVideoEnabled = false;
      } else {
        for (var track in videoTracks) {
          track.enabled = !track.enabled;
          print('📹 Video track ${track.id} enabled: ${track.enabled}');
        }
        _isVideoEnabled = videoTracks.first.enabled;
      }

      // Update in Firestore
      if (_meetingId != null && _userId != null) {
        try {
          await _firestore
              .collection('meetings')
              .doc(_meetingId)
              .collection('participants')
              .doc(_userId)
              .update({'isVideoEnabled': _isVideoEnabled});
          print('📡 Updated video status in Firestore: $_isVideoEnabled');
        } catch (e) {
          print('⚠️ Error updating video status in Firestore: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error toggling video: $e');
    }
  }

  // Get renderer for participant
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }
    return _remoteRenderers[participantId];
  }

  // FIXED: Enhanced meeting leave
  Future<void> leaveMeeting() async {
    if (_meetingId == null || _userId == null) return;

    try {
      print('🚪 Leaving mesh meeting...');

      // Update participant status
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isActive': false,
        'leftAt': FieldValue.serverTimestamp(),
      });

      // Update participant count
      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(-1),
      });

      // If host is leaving, end meeting for all
      if (_isHost) {
        await _firestore.collection('meetings').doc(_meetingId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }

      await _cleanup();
    } catch (e) {
      print('❌ Error leaving meeting: $e');
      await _cleanup();
    }
  }

  // FIXED: Enhanced cleanup with better error handling
  Future<void> _cleanup() async {
    try {
      print('🧹 Cleaning up mesh resources...');

      // Cancel subscriptions
      for (var subscription in _subscriptions) {
        try {
          await subscription.cancel();
        } catch (e) {
          print('⚠️ Error canceling subscription: $e');
        }
      }
      _subscriptions.clear();

      // Close peer connections
      for (var pc in _peerConnections.values) {
        try {
          await pc.close();
        } catch (e) {
          print('⚠️ Error closing peer connection: $e');
        }
      }
      _peerConnections.clear();

      // Clear states
      _negotiationStates.clear();
      _connectionRetryCount.clear();

      // Stop remote streams
      for (var stream in _remoteStreams.values) {
        try {
          for (var track in stream.getTracks()) {
            await track.stop();
          }
        } catch (e) {
          print('⚠️ Error stopping remote stream: $e');
        }
      }
      _remoteStreams.clear();

      // Dispose renderers
      for (var renderer in _remoteRenderers.values) {
        try {
          await renderer.dispose();
        } catch (e) {
          print('⚠️ Error disposing remote renderer: $e');
        }
      }
      _remoteRenderers.clear();

      // Stop local stream
      if (_localStream != null) {
        try {
          for (var track in _localStream!.getTracks()) {
            await track.stop();
          }
        } catch (e) {
          print('⚠️ Error stopping local stream: $e');
        }
        _localStream = null;
      }

      // Dispose local renderer
      if (_localRenderer != null) {
        try {
          await _localRenderer!.dispose();
        } catch (e) {
          print('⚠️ Error disposing local renderer: $e');
        }
        _localRenderer = null;
      }

      // Reset state
      _meetingId = null;
      _isHost = false;
      _isMeetingActive = false;
      _participants.clear();

      notifyListeners();
      print('✅ Mesh resources cleaned up');
    } catch (e) {
      print('❌ Error cleaning up: $e');
    }
  }

  @override
  void dispose() {
    print('🗑️ Disposing WebRTC Mesh Service...');
    _cleanup();
    super.dispose();
  }
}

// Mesh Participant Model
class MeshParticipant {
  final String id;
  final String name;
  final bool isHost;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isLocal;

  MeshParticipant({
    required this.id,
    required this.name,
    this.isHost = false,
    this.isAudioEnabled = true,
    this.isVideoEnabled = true,
    this.isLocal = false,
  });

  MeshParticipant copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isAudioEnabled,
    bool? isVideoEnabled,
    bool? isLocal,
  }) {
    return MeshParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}