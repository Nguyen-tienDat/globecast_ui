// lib/services/webrtc_mesh_meeting_service.dart - FIXED INITIALIZATION
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'multilingual_speech_service.dart';

class WebRTCMeshMeetingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🎯 SPEECH SERVICE INTEGRATION
  MultilingualSpeechService? _speechService;

  // WebRTC components
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;

  // 🚀 INITIALIZATION STATE
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Meeting data
  String? _meetingId;
  String? _userId;
  String _displayName = 'User';
  bool _isHost = false;
  bool _isMeetingActive = false;
  bool _isAudioEnabled = true; // ✅ DEFAULT TO TRUE
  bool _isVideoEnabled = true; // ✅ DEFAULT TO TRUE

  // Participants
  final List<MeshParticipant> _participants = [];

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Track negotiation states
  final Map<String, bool> _negotiationStates = {};

  // Connection retry mechanism
  final Map<String, int> _connectionRetryCount = {};
  final int _maxRetryAttempts = 3;

  // 🎯 FIXED ICE SERVERS - LATEST CREDENTIALS
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': "stun:stun.relay.metered.ca:80",
      },
      {
        'urls': "turn:global.relay.metered.ca:80",
        'username': "78ab09d5fdbe13575ac81025",
        'credential': "CvgUNnNpQhpd3XvC",
      },
      {
        'urls': "turn:global.relay.metered.ca:80?transport=tcp",
        'username': "78ab09d5fdbe13575ac81025",
        'credential': "CvgUNnNpQhpd3XvC",
      },
      {
        'urls': "turn:global.relay.metered.ca:443",
        'username': "78ab09d5fdbe13575ac81025",
        'credential': "CvgUNnNpQhpd3XvC",
      },
      {
        'urls': "turns:global.relay.metered.ca:443?transport=tcp",
        'username': "78ab09d5fdbe13575ac81025",
        'credential': "CvgUNnNpQhpd3XvC",
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  // Getters
  String? get meetingId => _meetingId;
  String? get userId => _userId;
  bool get isHost => _isHost;
  bool get isMeetingActive => _isMeetingActive;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isInitialized => _isInitialized;
  List<MeshParticipant> get participants => List.unmodifiable(_participants);
  RTCVideoRenderer? get localRenderer => _localRenderer;

  // 🚀 PROPER INITIALIZATION - MUST BE CALLED FIRST
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      if (kDebugMode) {
        print('⚠️ WebRTC service already initialized or initializing');
      }
      return;
    }

    _isInitializing = true;

    try {
      if (kDebugMode) {
        print('🔧 Initializing WebRTC Mesh Service...');
      }

      // Generate unique user ID
      _userId ??= 'USR${const Uuid().v4().replaceAll('-', '').substring(0, 8)}';

      // ✅ IMMEDIATELY SETUP MEDIA STREAM ON INITIALIZATION
      await _initializeMediaStream();

      _isInitialized = true;
      _isInitializing = false;

      if (kDebugMode) {
        print('✅ WebRTC Service initialized successfully');
        print('   User ID: $_userId');
        print('   Audio enabled: $_isAudioEnabled');
        print('   Video enabled: $_isVideoEnabled');
      }

      notifyListeners();
    } catch (e) {
      _isInitializing = false;
      if (kDebugMode) {
        print('❌ Error initializing WebRTC service: $e');
      }
      throw Exception('Failed to initialize WebRTC service: $e');
    }
  }

  // 🎬 INITIALIZE MEDIA STREAM IMMEDIATELY
  Future<void> _initializeMediaStream() async {
    try {
      if (kDebugMode) {
        print('🎬 Initializing media stream with audio+video enabled...');
      }

      // Initialize local renderer first
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
        if (kDebugMode) {
          print('✅ Local renderer initialized');
        }
      }

      // Get media stream with BOTH audio and video enabled by default
      final mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'googEchoCancellation': true,
          'googAutoGainControl': true,
          'googNoiseSuppression': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 1280, 'min': 320},
          'height': {'ideal': 480, 'max': 720, 'min': 240},
          'frameRate': {'ideal': 30, 'max': 30, 'min': 15},
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // ✅ FORCE ENABLE BOTH AUDIO AND VIDEO
      final audioTracks = _localStream!.getAudioTracks();
      final videoTracks = _localStream!.getVideoTracks();

      for (var track in audioTracks) {
        track.enabled = true; // ✅ FORCE ENABLE
      }

      for (var track in videoTracks) {
        track.enabled = true; // ✅ FORCE ENABLE
      }

      _isAudioEnabled = audioTracks.isNotEmpty;
      _isVideoEnabled = videoTracks.isNotEmpty;

      // Connect to renderer
      await Future.delayed(const Duration(milliseconds: 100));
      _localRenderer!.srcObject = _localStream;

      // Connect to speech service if available
      if (_speechService != null) {
        _speechService!.setWebRTCStream(_localStream);
        if (kDebugMode) {
          print('🔗 Media stream connected to Speech service');
        }
      }

      if (kDebugMode) {
        print('📊 Media stream initialized:');
        print('   📹 Video tracks: ${videoTracks.length} (enabled: $_isVideoEnabled)');
        print('   🎤 Audio tracks: ${audioTracks.length} (enabled: $_isAudioEnabled)');
        print('   🎯 Both audio and video ENABLED by default');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing media stream: $e');
      }
      throw Exception('Could not initialize media stream: $e');
    }
  }

  // 🎯 SET SPEECH SERVICE
  void setSpeechService(MultilingualSpeechService speechService) {
    _speechService = speechService;

    // Connect current stream if available
    if (_localStream != null) {
      _speechService!.setWebRTCStream(_localStream);
    }

    if (kDebugMode) {
      print('🔗 Speech service connected to WebRTC service');
    }
  }

  // 👤 SET USER DETAILS
  void setUserDetails({required String displayName, String? userId}) {
    _displayName = displayName;
    if (userId != null) _userId = userId;

    if (kDebugMode) {
      print('👤 User details set: $_displayName (ID: $_userId)');
    }
    notifyListeners();
  }

  // 🏗️ CREATE MEETING
  Future<String> createMeeting({required String topic}) async {
    try {
      // ✅ ENSURE INITIALIZATION FIRST
      if (!_isInitialized) {
        await initialize();
      }

      if (topic.trim().isEmpty) {
        throw Exception('Meeting topic cannot be empty');
      }

      final String meetingId = 'GCM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _meetingId = meetingId;
      _isHost = true;

      if (kDebugMode) {
        print('🏗️ Creating meeting: $meetingId');
      }

      // Create meeting document
      await _firestore.collection('meetings').doc(meetingId).set({
        'meetingId': meetingId,
        'topic': topic,
        'hostId': _userId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'participantCount': 0,
        'topology': 'mesh',
        'maxParticipants': 6,
        'translationLanguages': {
          'primary': 'vi',
          'supported': ['en', 'vi', 'zh', 'ja', 'ko'],
        },
      });

      // Join mesh network (stream already ready)
      await _joinMeshNetwork(meetingId);

      if (kDebugMode) {
        print('✅ Meeting created successfully: $meetingId');
      }

      return meetingId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating meeting: $e');
      }
      throw Exception('Failed to create meeting: $e');
    }
  }

  // 🚪 JOIN MEETING
  Future<void> joinMeeting({required String meetingId}) async {
    try {
      // ✅ ENSURE INITIALIZATION FIRST
      if (!_isInitialized) {
        await initialize();
      }

      final cleanMeetingId = meetingId.trim().toUpperCase();
      if (cleanMeetingId.isEmpty) {
        throw Exception('Meeting ID cannot be empty');
      }

      if (kDebugMode) {
        print('🚪 Joining meeting: $cleanMeetingId');
      }

      // Check if meeting exists
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
        throw Exception('Meeting is full (max 6 participants)');
      }

      _meetingId = cleanMeetingId;
      _isHost = meetingData['hostId'] == _userId;

      // Join mesh network (stream already ready)
      await _joinMeshNetwork(cleanMeetingId);

      if (kDebugMode) {
        print('✅ Joined meeting successfully: $cleanMeetingId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error joining meeting: $e');
      }
      throw Exception('Failed to join meeting: $e');
    }
  }

  // 🕸️ JOIN MESH NETWORK
  Future<void> _joinMeshNetwork(String meetingId) async {
    try {
      if (kDebugMode) {
        print('🕸️ Joining mesh network for meeting: $meetingId');
      }

      _isMeetingActive = true;

      // Add self as participant
      await _addSelfAsParticipant();

      // Start listeners
      _listenForMeshParticipants();
      _listenForSignalingMessages();

      if (kDebugMode) {
        print('✅ Successfully joined mesh network');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error joining mesh network: $e');
      }
      _isMeetingActive = false;
      notifyListeners();
      throw Exception('Failed to join mesh network: $e');
    }
  }

  // 👥 ADD SELF AS PARTICIPANT
  Future<void> _addSelfAsParticipant() async {
    if (_meetingId == null || _userId == null) {
      throw Exception('Meeting ID or User ID is null');
    }

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
        'isAudioEnabled': _isAudioEnabled, // ✅ TRUE BY DEFAULT
        'isVideoEnabled': _isVideoEnabled, // ✅ TRUE BY DEFAULT
        'connectionType': 'mesh',
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Update participant count
      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      if (kDebugMode) {
        print('✅ Added self as participant: $_displayName (Audio: $_isAudioEnabled, Video: $_isVideoEnabled)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding self as participant: $e');
      }
      throw Exception('Failed to add participant: $e');
    }
  }

  // 👂 LISTEN FOR PARTICIPANTS
  void _listenForMeshParticipants() {
    if (_meetingId == null) return;

    if (kDebugMode) {
      print('👂 Listening for mesh participants...');
    }

    final subscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) async {
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

        if (kDebugMode) {
          print('👥 Updated participants: ${_participants.length}');
        }

        notifyListeners();
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Error listening for participants: $error');
        }
      },
    );

    _subscriptions.add(subscription);
  }

  // 🤝 COORDINATED CONNECTION CREATION
  Future<void> _coordinatedCreateConnection(String peerId) async {
    if (_negotiationStates.containsKey(peerId) && _negotiationStates[peerId] == true) {
      if (kDebugMode) {
        print('⚠️ Already creating connection with $peerId');
      }
      return;
    }

    final shouldInitiate = (_userId?.compareTo(peerId) ?? 0) > 0;

    if (kDebugMode) {
      print('🤝 Coordinated connection with $peerId - shouldInitiate: $shouldInitiate');
    }

    _negotiationStates[peerId] = true;

    try {
      await _createMeshConnection(peerId, isInitiator: shouldInitiate);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in coordinated connection creation: $e');
      }
      _negotiationStates[peerId] = false;
    }
  }

  // 🌐 CREATE MESH CONNECTION
  Future<void> _createMeshConnection(String peerId, {required bool isInitiator}) async {
    try {
      if (kDebugMode) {
        print('🌐 Creating mesh connection with $peerId (initiator: $isInitiator)');
      }

      if (_peerConnections.containsKey(peerId)) {
        if (kDebugMode) {
          print('⚠️ Connection with $peerId already exists');
        }
        return;
      }

      // Create peer connection
      final pc = await createPeerConnection({
        ..._iceServers,
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });

      _peerConnections[peerId] = pc;

      // Initialize remote renderer
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[peerId] = renderer;

      // Add local stream tracks (already available)
      if (_localStream != null) {
        if (kDebugMode) {
          print('➕ Adding local stream tracks to peer connection...');
        }

        for (var track in _localStream!.getTracks()) {
          try {
            await pc.addTrack(track, _localStream!);
            if (kDebugMode) {
              print('✅ Added ${track.kind} track to $peerId');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error adding track to $peerId: $e');
            }
          }
        }
      }

      // Setup event handlers
      _setupPeerConnectionEventHandlers(pc, peerId);

      // Create offer if initiator
      if (isInitiator) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _createAndSendOffer(pc, peerId);
      } else {
        if (kDebugMode) {
          print('📱 Waiting for offer from $peerId...');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating mesh connection with $peerId: $e');
      }
      await _removeMeshConnection(peerId);
      _negotiationStates[peerId] = false;
    }
  }

  // 🔧 SETUP PEER CONNECTION EVENT HANDLERS
  void _setupPeerConnectionEventHandlers(RTCPeerConnection pc, String peerId) {
    pc.onIceConnectionState = (state) {
      if (kDebugMode) {
        print('🧊 ICE connection state with $peerId: $state');
      }

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          if (kDebugMode) {
            print('💥 Connection with $peerId failed or disconnected');
          }
          _handleConnectionFailure(peerId);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          if (kDebugMode) {
            print('✅ Successfully connected to $peerId');
          }
          _connectionRetryCount[peerId] = 0;
          break;
        default:
          break;
      }
    };

    pc.onIceCandidate = (candidate) async {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        await _sendIceCandidate(peerId, candidate);
        if (kDebugMode) {
          print('🧊 ICE candidate sent to $peerId');
        }
      }
    };

    pc.onTrack = (event) {
      if (kDebugMode) {
        print('📺 onTrack event received from $peerId');
        print('   Streams: ${event.streams.length}');
        print('   Track: ${event.track.kind} - ${event.track.id}');
      }

      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[peerId] = stream;

        final renderer = _remoteRenderers[peerId];
        if (renderer != null) {
          Future.delayed(const Duration(milliseconds: 100), () {
            renderer.srcObject = stream;
            if (kDebugMode) {
              print('📺 Remote stream connected to renderer for $peerId');
            }
            notifyListeners();
          });
        }
      }
    };

    pc.onConnectionState = (state) {
      if (kDebugMode) {
        print('🔗 Connection state with $peerId: $state');
      }
    };
  }

  // 📤 CREATE AND SEND OFFER
  Future<void> _createAndSendOffer(RTCPeerConnection pc, String peerId) async {
    try {
      if (_negotiationStates[peerId] != true) {
        if (kDebugMode) {
          print('⚠️ Not in negotiation state with $peerId, skipping offer');
        }
        return;
      }

      if (kDebugMode) {
        print('📤 Creating offer for $peerId...');
      }

      final offer = await pc.createOffer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
        'iceRestart': false,
      });

      await pc.setLocalDescription(offer);

      await _sendSignalingMessage(peerId, {
        'type': 'offer',
        'sdp': offer.sdp,
        'from': _userId,
        'to': peerId,
      });

      if (kDebugMode) {
        print('📤 Offer sent to $peerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating/sending offer to $peerId: $e');
      }
      _negotiationStates[peerId] = false;
    }
  }

  // 👂 LISTEN FOR SIGNALING MESSAGES
  void _listenForSignalingMessages() {
    if (_meetingId == null || _userId == null) return;

    if (kDebugMode) {
      print('👂 Listening for signaling messages...');
    }

    final subscription = _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('signaling')
        .where('to', isEqualTo: _userId)
        .snapshots()
        .listen(
          (snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              await _handleSignalingMessage(data);
              try {
                await change.doc.reference.delete();
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ Could not delete signaling message: $e');
                }
              }
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Error listening for signaling messages: $error');
        }
      },
    );

    _subscriptions.add(subscription);
  }

  // 📨 HANDLE SIGNALING MESSAGE
  Future<void> _handleSignalingMessage(Map<String, dynamic> message) async {
    final String type = message['type'];
    final String fromId = message['from'];

    if (kDebugMode) {
      print('📨 Received signaling message: $type from $fromId');
    }

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
      if (kDebugMode) {
        print('❌ Error handling signaling message: $e');
      }
    }
  }

  // 📨 HANDLE OFFER
  Future<void> _handleOffer(String fromId, Map<String, dynamic> message) async {
    try {
      if (kDebugMode) {
        print('📨 Handling offer from $fromId');
      }

      if (!_peerConnections.containsKey(fromId)) {
        await _createMeshConnection(fromId, isInitiator: false);
      }

      final pc = _peerConnections[fromId];
      if (pc == null) {
        if (kDebugMode) {
          print('❌ No peer connection found for $fromId');
        }
        return;
      }

      final offer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(offer);

      final answer = await pc.createAnswer({
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
      });

      await pc.setLocalDescription(answer);

      await _sendSignalingMessage(fromId, {
        'type': 'answer',
        'sdp': answer.sdp,
        'from': _userId,
        'to': fromId,
      });

      if (kDebugMode) {
        print('📤 Answer sent to $fromId');
      }
      _negotiationStates[fromId] = false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling offer from $fromId: $e');
      }
      _negotiationStates[fromId] = false;
    }
  }

  // 📨 HANDLE ANSWER
  Future<void> _handleAnswer(String fromId, Map<String, dynamic> message) async {
    try {
      if (kDebugMode) {
        print('📨 Handling answer from $fromId');
      }

      final pc = _peerConnections[fromId];
      if (pc == null) {
        if (kDebugMode) {
          print('❌ No peer connection found for $fromId');
        }
        return;
      }

      if (pc.signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        if (kDebugMode) {
          print('⚠️ Cannot handle answer from $fromId, wrong signaling state: ${pc.signalingState}');
        }
        return;
      }

      final answer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(answer);

      if (kDebugMode) {
        print('✅ Answer processed from $fromId');
      }
      _negotiationStates[fromId] = false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling answer from $fromId: $e');
      }
      _negotiationStates[fromId] = false;
    }
  }

  // 🧊 HANDLE ICE CANDIDATE
  Future<void> _handleIceCandidate(String fromId, Map<String, dynamic> message) async {
    try {
      final pc = _peerConnections[fromId];
      if (pc == null) {
        if (kDebugMode) {
          print('⚠️ No peer connection found for ICE candidate from $fromId');
        }
        return;
      }

      final signalingState = pc.signalingState;
      if (signalingState == RTCSignalingState.RTCSignalingStateClosed) {
        if (kDebugMode) {
          print('⚠️ Connection closed, cannot add ICE candidate from $fromId');
        }
        return;
      }

      final candidate = RTCIceCandidate(
        message['candidate'],
        message['sdpMid'],
        message['sdpMLineIndex'],
      );

      await pc.addCandidate(candidate);
      if (kDebugMode) {
        print('🧊 ICE candidate added from $fromId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling ICE candidate from $fromId: $e');
      }
    }
  }

  // 📡 SEND SIGNALING MESSAGE
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

      if (kDebugMode) {
        print('📡 Signaling message sent to $toId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending signaling message: $e');
      }
    }
  }

  // 🧊 SEND ICE CANDIDATE
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

  // 🚨 HANDLE CONNECTION FAILURE
  void _handleConnectionFailure(String peerId) {
    if (kDebugMode) {
      print('🚨 Handling connection failure with $peerId');
    }

    _negotiationStates[peerId] = false;

    final retryCount = _connectionRetryCount[peerId] ?? 0;
    if (retryCount < _maxRetryAttempts) {
      _connectionRetryCount[peerId] = retryCount + 1;
      if (kDebugMode) {
        print('🔄 Retrying connection with $peerId (attempt ${retryCount + 1}/$_maxRetryAttempts)');
      }

      Future.delayed(Duration(seconds: 2 * (retryCount + 1)), () async {
        await _removeMeshConnection(peerId);
        await _coordinatedCreateConnection(peerId);
      });
    } else {
      if (kDebugMode) {
        print('❌ Max retry attempts reached for $peerId');
      }
      _connectionRetryCount.remove(peerId);
    }
  }

  // 🗑️ REMOVE MESH CONNECTION
  Future<void> _removeMeshConnection(String peerId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Removing mesh connection with $peerId');
      }

      _negotiationStates.remove(peerId);
      _connectionRetryCount.remove(peerId);

      final pc = _peerConnections[peerId];
      if (pc != null) {
        try {
          await pc.close();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error closing peer connection: $e');
          }
        }
        _peerConnections.remove(peerId);
      }

      final stream = _remoteStreams[peerId];
      if (stream != null) {
        try {
          for (var track in stream.getTracks()) {
            await track.stop();
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error stopping remote stream tracks: $e');
          }
        }
        _remoteStreams.remove(peerId);
      }

      final renderer = _remoteRenderers[peerId];
      if (renderer != null) {
        try {
          await renderer.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error disposing renderer: $e');
          }
        }
        _remoteRenderers.remove(peerId);
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing mesh connection: $e');
      }
    }
  }

  // 🎤 TOGGLE AUDIO
  Future<void> toggleAudio() async {
    if (_localStream == null) {
      if (kDebugMode) {
        print('❌ Cannot toggle audio: local stream is null');
      }
      return;
    }

    try {
      final audioTracks = _localStream!.getAudioTracks();
      if (kDebugMode) {
        print('🎤 Toggling audio. Current tracks: ${audioTracks.length}');
      }

      if (audioTracks.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No audio tracks available');
        }
        _isAudioEnabled = false;
      } else {
        // Check if speech service is using audio
        bool speechIsManaging = false;
        if (_speechService != null && _speechService!.isListening) {
          speechIsManaging = true;
          if (kDebugMode) {
            print('⚠️ Speech service is currently using audio');
          }
        }

        for (var track in audioTracks) {
          track.enabled = !track.enabled;
          if (kDebugMode) {
            print('🎵 Audio track ${track.id} enabled: ${track.enabled}');
          }
        }
        _isAudioEnabled = audioTracks.first.enabled;

        // Update speech service if not currently managing
        if (_speechService != null && !speechIsManaging) {
          _speechService!.setWebRTCStream(_localStream);
          if (kDebugMode) {
            print('🔗 Updated speech service with new audio state');
          }
        }
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
          if (kDebugMode) {
            print('📡 Updated audio status in Firestore: $_isAudioEnabled');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error updating audio status: $e');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling audio: $e');
      }
    }
  }

  // 🎥 TOGGLE VIDEO
  Future<void> toggleVideo() async {
    if (_localStream == null) {
      if (kDebugMode) {
        print('❌ Cannot toggle video: local stream is null');
      }
      return;
    }

    try {
      final videoTracks = _localStream!.getVideoTracks();
      if (kDebugMode) {
        print('🎥 Toggling video. Current tracks: ${videoTracks.length}');
      }

      if (videoTracks.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No video tracks available');
        }
        _isVideoEnabled = false;
      } else {
        for (var track in videoTracks) {
          track.enabled = !track.enabled;
          if (kDebugMode) {
            print('📹 Video track ${track.id} enabled: ${track.enabled}');
          }
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
          if (kDebugMode) {
            print('📡 Updated video status in Firestore: $_isVideoEnabled');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error updating video status: $e');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling video: $e');
      }
    }
  }

  // 🎬 GET RENDERER FOR PARTICIPANT
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }
    return _remoteRenderers[participantId];
  }

  // 🚪 LEAVE MEETING
  Future<void> leaveMeeting() async {
    if (_meetingId == null || _userId == null) return;

    try {
      if (kDebugMode) {
        print('🚪 Leaving meeting...');
      }

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

      // If host is leaving, end meeting
      if (_isHost) {
        await _firestore.collection('meetings').doc(_meetingId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      }

      await _cleanup();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error leaving meeting: $e');
      }
      await _cleanup();
    }
  }

  // 🧹 CLEANUP
  Future<void> _cleanup() async {
    try {
      if (kDebugMode) {
        print('🧹 Cleaning up resources...');
      }

      // Disconnect speech service first
      if (_speechService != null) {
        if (_speechService!.isListening) {
          await _speechService!.stopListening();
        }
        _speechService!.setWebRTCStream(null);
        if (kDebugMode) {
          print('🔗 Speech service disconnected');
        }
      }

      // Cancel subscriptions
      for (var subscription in _subscriptions) {
        try {
          await subscription.cancel();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error canceling subscription: $e');
          }
        }
      }
      _subscriptions.clear();

      // Close peer connections
      for (var pc in _peerConnections.values) {
        try {
          await pc.close();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error closing peer connection: $e');
          }
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
          if (kDebugMode) {
            print('⚠️ Error stopping remote stream: $e');
          }
        }
      }
      _remoteStreams.clear();

      // Dispose renderers
      for (var renderer in _remoteRenderers.values) {
        try {
          await renderer.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error disposing remote renderer: $e');
          }
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
          if (kDebugMode) {
            print('⚠️ Error stopping local stream: $e');
          }
        }
        _localStream = null;
      }

      // Dispose local renderer
      if (_localRenderer != null) {
        try {
          await _localRenderer!.dispose();
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error disposing local renderer: $e');
          }
        }
        _localRenderer = null;
      }

      // Reset state
      _meetingId = null;
      _isHost = false;
      _isMeetingActive = false;
      _isInitialized = false;
      _participants.clear();

      if (kDebugMode) {
        print('✅ Resources cleaned up');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during cleanup: $e');
      }
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing WebRTC Mesh Service...');
    }
    _cleanup();
    super.dispose();
  }
}

// 👥 MESH PARTICIPANT MODEL
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