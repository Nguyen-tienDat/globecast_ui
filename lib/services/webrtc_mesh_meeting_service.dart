// lib/services/webrtc_mesh_meeting_service.dart
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

  // FIXED: Track pending connections to prevent duplicates
  final Set<String> _pendingConnections = {};

  // Getters
  String? get meetingId => _meetingId;
  String? get userId => _userId;
  bool get isHost => _isHost;
  bool get isMeetingActive => _isMeetingActive;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  List<MeshParticipant> get participants => List.unmodifiable(_participants);
  RTCVideoRenderer? get localRenderer => _localRenderer;

  // ICE Servers configuration - KEEP ORIGINAL
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
      print('WebRTC Mesh Service initialized with userId: $_userId');
      notifyListeners();
    } catch (e) {
      print('Error initializing service: $e');
      throw Exception('Failed to initialize service: $e');
    }
  }

  // Set user details
  void setUserDetails({required String displayName, String? userId}) {
    _displayName = displayName;
    if (userId != null) _userId = userId;
    notifyListeners();
  }

  // Create a new meeting using existing database structure
  Future<String> createMeeting({required String topic}) async {
    try {
      // Generate meeting ID compatible with existing format (GCM-XXXXXXXX)
      final String meetingId = 'GCM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _meetingId = meetingId;
      _isHost = true;

      print('Creating mesh meeting: $meetingId');

      // Validate topic input
      if (topic.trim().isEmpty) {
        throw Exception('Meeting topic cannot be empty');
      }

      // Create meeting document using existing database structure
      await _firestore.collection('meetings').doc(meetingId).set({
        'meetingId': meetingId,
        'topic': topic,
        'hostId': _userId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'participantCount': 0,
        'password': '123', // Default password for compatibility
        'translationLanguages': {
          '0': 'english',
          '1': 'vietnamese',
        },
        // WebRTC Mesh specific fields
        'topology': 'mesh',
        'maxParticipants': 6, // Mesh topology limit
      });

      await _setupLocalStream();
      await _joinMeshNetwork(meetingId);

      return meetingId;
    } catch (e) {
      print('Error creating mesh meeting: $e');
      throw Exception('Failed to create meeting: $e');
    }
  }

  // Join an existing meeting using existing database structure
  Future<void> joinMeeting({required String meetingId}) async {
    try {
      print('Joining mesh meeting: $meetingId');

      // Clean meetingId input
      final cleanMeetingId = meetingId.trim().toUpperCase();
      if (cleanMeetingId.isEmpty) {
        throw Exception('Meeting ID cannot be empty');
      }

      // Check existing database structure first
      final meetingDoc = await _firestore.collection('meetings').doc(cleanMeetingId).get();
      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;
      if (meetingData['status'] != 'active') {
        throw Exception('Meeting has ended');
      }

      // Check participant limit for mesh topology
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

  // FIXED: Enhanced local media stream setup
  Future<void> _setupLocalStream() async {
    try {
      print('Setting up local stream...');

      // Initialize local renderer
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
      }

      // FIXED: Get user media with better constraints
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30},
        },
      });

      // FIXED: Verify stream has tracks
      final audioTracks = _localStream!.getAudioTracks();
      final videoTracks = _localStream!.getVideoTracks();

      print('Local stream setup - Audio tracks: ${audioTracks.length}, Video tracks: ${videoTracks.length}');

      // Set track states
      for (var track in audioTracks) {
        track.enabled = _isAudioEnabled;
      }
      for (var track in videoTracks) {
        track.enabled = _isVideoEnabled;
      }

      _localRenderer!.srcObject = _localStream;
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

      // Add self as participant using existing structure
      await _addSelfAsParticipant();

      // Listen for other participants
      _listenForMeshParticipants();

      // Listen for signaling messages
      _listenForSignalingMessages();

      notifyListeners();
    } catch (e) {
      print('Error joining mesh network: $e');
      _isMeetingActive = false;
      notifyListeners();
      throw Exception('Failed to setup meeting: $e');
    }
  }

  // Add self as participant using existing database structure
  Future<void> _addSelfAsParticipant() async {
    if (_meetingId == null || _userId == null) return;

    try {
      // Add to participants subcollection (existing structure)
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
        // WebRTC Mesh specific fields
        'connectionType': 'mesh',
        'peerConnections': [], // Will track connected peers
      });

      // Update participant count in main meeting document
      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      print('Added self as participant');
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

        // Create participant model
        final participant = MeshParticipant(
          id: participantId,
          name: participantId == _userId ? '${data['displayName']} (You)' : data['displayName'],
          isHost: data['isHost'] ?? false,
          isAudioEnabled: data['isAudioEnabled'] ?? true,
          isVideoEnabled: data['isVideoEnabled'] ?? true,
          isLocal: participantId == _userId,
        );

        newParticipants.add(participant);

        // FIXED: Create peer connection for remote participants with duplicate check
        if (participantId != _userId &&
            !_peerConnections.containsKey(participantId) &&
            !_pendingConnections.contains(participantId)) {
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

  // FIXED: Create mesh connection with better logic
  Future<void> _createMeshConnection(String peerId) async {
    if (_pendingConnections.contains(peerId)) {
      print('Connection to $peerId already pending, skipping');
      return;
    }

    _pendingConnections.add(peerId);

    try {
      print("Creating mesh connection with peer: $peerId");

      // Create peer connection
      final pc = await createPeerConnection(_iceServers);
      _peerConnections[peerId] = pc;

      // Create renderer for remote stream
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[peerId] = renderer;

      // FIXED: Add local stream tracks properly
      if (_localStream != null) {
        // Add each track individually
        final tracks = _localStream!.getTracks();
        for (var track in tracks) {
          await pc.addTrack(track, _localStream!);
          print('Added ${track.kind} track to peer connection with $peerId');
        }
      }

      // Setup event handlers
      _setupPeerConnectionEventHandlers(pc, peerId);

      // FIXED: Only create offer if we have lower ID (deterministic initiator)
      if (_userId!.compareTo(peerId) < 0) {
        await _createAndSendOffer(pc, peerId);
      }

    } catch (e) {
      print('Error creating mesh connection with $peerId: $e');
    } finally {
      _pendingConnections.remove(peerId);
    }
  }

  // FIXED: Setup peer connection event handlers
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
      if (candidate.candidate != null) {
        await _sendIceCandidate(peerId, candidate);
      }
    };

    // FIXED: Enhanced onTrack handler
    pc.onTrack = (event) {
      print('Received ${event.track.kind} track from $peerId');

      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[peerId] = stream;

        // Set the stream to renderer
        final renderer = _remoteRenderers[peerId];
        if (renderer != null) {
          renderer.srcObject = stream;
          print('Remote stream assigned to renderer for $peerId');
          notifyListeners();
        }
      }
    };

    pc.onConnectionState = (state) {
      print('Connection state with $peerId: $state');
    };
  }

  // Create and send offer
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

  // Listen for signaling messages using existing structure
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
            // Delete processed message
            await change.doc.reference.delete();
          }
        }
      }
    }, onError: (error) {
      print('Error listening for signaling messages: $error');
    });

    _subscriptions.add(subscription);
  }

  // Handle signaling message
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

  // FIXED: Handle offer properly
  Future<void> _handleOffer(String fromId, Map<String, dynamic> message) async {
    try {
      // Create peer connection if doesn't exist
      if (!_peerConnections.containsKey(fromId)) {
        await _createMeshConnection(fromId);
      }

      final pc = _peerConnections[fromId];
      if (pc == null) return;

      // Set remote description
      final offer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(offer);

      // Create and send answer
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

  // Handle answer
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

  // Handle ICE candidate
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

  // Send signaling message using existing database
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
      print('Message details: $message');
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

  // Handle connection failure
  void _handleConnectionFailure(String peerId) {
    print('Handling connection failure with $peerId');
    // Could implement reconnection logic here
  }

  // Remove mesh connection
  Future<void> _removeMeshConnection(String peerId) async {
    try {
      print('Removing mesh connection with $peerId');

      // Remove from pending
      _pendingConnections.remove(peerId);

      // Close peer connection
      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.close();
        _peerConnections.remove(peerId);
      }

      // Stop remote stream
      final stream = _remoteStreams[peerId];
      if (stream != null) {
        stream.getTracks().forEach((track) => track.stop());
        _remoteStreams.remove(peerId);
      }

      // Dispose renderer
      final renderer = _remoteRenderers[peerId];
      if (renderer != null) {
        await renderer.dispose();
        _remoteRenderers.remove(peerId);
      }

      notifyListeners();
    } catch (e) {
      print('Error removing mesh connection: $e');
    }
  }

  // Toggle audio
  Future<void> toggleAudio() async {
    if (_localStream == null) return;

    try {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }

      _isAudioEnabled = audioTracks.first.enabled;

      // Update in Firestore using existing structure
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

  // Toggle video
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    try {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }

      _isVideoEnabled = videoTracks.first.enabled;

      // Update in Firestore using existing structure
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

  // Get renderer for participant
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }
    return _remoteRenderers[participantId];
  }

  /// Update display language preference
  Future<void> updateDisplayLanguage(String languageCode) async {
    try {
      if (_meetingId != null && _userId != null) {
        await _firestore
            .collection('meetings')
            .doc(_meetingId)
            .collection('participants')
            .doc(_userId)
            .update({'displayLanguage': languageCode});

        print('Display language updated to: $languageCode');
      }
    } catch (e) {
      print('Error updating display language: $e');
    }
  }

  // Leave meeting using existing structure
  Future<void> leaveMeeting() async {
    if (_meetingId == null || _userId == null) return;

    try {
      print('Leaving mesh meeting...');

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
      print('Error leaving meeting: $e');
      await _cleanup();
    }
  }

  // Cleanup resources
  Future<void> _cleanup() async {
    try {
      print('Cleaning up mesh resources...');

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

      // Clear pending connections
      _pendingConnections.clear();

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

  @override
  void dispose() {
    print('Disposing WebRTC Mesh Service...');
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