// lib/services/webrtc_mesh_meeting_service.dart - ENHANCED VERSION
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

  // Services for enhanced functionality
  WhisperService? _whisperService;
  AudioCaptureService? _audioCaptureService;

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

  // Enhanced language and subtitle features
  String _userDisplayLanguage = 'en';
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
      // Existing Metered TURN servers
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

  // Initialize service with enhanced features
  Future<void> initialize() async {
    try {
      print('🚀 Initializing Enhanced WebRTC Mesh Service...');

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
        print('❌ Audio capture error: $error');
      };

      // Setup Whisper service callbacks
      _whisperService!.onError = (error) {
        print('❌ Whisper service error: $error');
      };

      _whisperService!.onConnectionChanged = (isConnected) {
        print('🌍 Whisper connection changed: $isConnected');
        notifyListeners();
      };

      print('✅ Enhanced WebRTC Mesh Service initialized with userId: $_userId');
      notifyListeners();
    } catch (e) {
      print('❌ Error initializing service: $e');
      throw Exception('Failed to initialize service: $e');
    }
  }

  // Set user details with language preferences
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

  // Set user display language preference
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

  // Create a new meeting using existing database structure
  Future<String> createMeeting({required String topic}) async {
    try {
      // Generate meeting ID compatible with existing format (GCM-XXXXXXXX)
      final String meetingId = 'GCM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _meetingId = meetingId;
      _isHost = true;

      print('🏗️ Creating enhanced mesh meeting: $meetingId');

      // Validate topic input
      if (topic.trim().isEmpty) {
        throw Exception('Meeting topic cannot be empty');
      }

      // Create meeting document using existing database structure with enhancements
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
        // Enhanced features
        'subtitlesEnabled': _subtitlesEnabled,
        'supportedLanguages': ['en', 'vi', 'zh', 'ja', 'ko', 'fr', 'de', 'es'],
      });

      await _setupLocalStream();
      await _joinMeshNetwork(meetingId);

      return meetingId;
    } catch (e) {
      print('❌ Error creating mesh meeting: $e');
      throw Exception('Failed to create meeting: $e');
    }
  }

  // Join an existing meeting using existing database structure
  Future<void> joinMeeting({required String meetingId}) async {
    try {
      print('🚪 Joining enhanced mesh meeting: $meetingId');

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
      print('❌ Error joining mesh meeting: $e');
      throw Exception('Failed to join meeting: $e');
    }
  }

  // Enhanced setup local media stream with progressive fallback
  Future<void> _setupLocalStream() async {
    try {
      print('🎥 Setting up enhanced local stream...');

      // Initialize local renderer
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
        print('✅ Local renderer initialized');
      }

      // Clean up any existing stream
      if (_localStream != null) {
        print('🔄 Disposing existing local stream...');
        for (var track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      // Get user media with progressive fallback
      _localStream = await _getUserMediaWithProgressiveFallback();

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

        print('✅ Enhanced local stream setup complete');
        notifyListeners();
      } else {
        throw Exception('Failed to get media stream');
      }
    } catch (e) {
      print('❌ Error setting up local stream: $e');
      throw Exception('Could not access camera or microphone: $e');
    }
  }

  // Progressive fallback for getUserMedia with enhanced error handling
  Future<MediaStream?> _getUserMediaWithProgressiveFallback() async {
    // Progressive constraints from high quality to basic
    final List<Map<String, dynamic>> constraintsList = [
      // High quality - Desktop/good mobile
      {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 48000,
          'sampleSize': 16,
          'channelCount': 1,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 1280},
          'height': {'ideal': 480, 'max': 720},
          'frameRate': {'ideal': 30, 'max': 60},
        },
      },
      // Medium quality - Most mobile devices
      {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 480, 'max': 640},
          'height': {'ideal': 360, 'max': 480},
          'frameRate': {'ideal': 24, 'max': 30},
        },
      },
      // Basic quality - Older devices
      {
        'audio': {
          'echoCancellation': true,
        },
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 320, 'max': 480},
          'height': {'ideal': 240, 'max': 360},
          'frameRate': {'ideal': 15, 'max': 24},
        },
      },
      // Existing working constraints as fallback
      {
        'audio': _isAudioEnabled,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      },
      // Audio only fallback
      {
        'audio': true,
        'video': false,
      },
      // Minimal constraints
      {
        'audio': true,
        'video': true,
      },
    ];

    Exception? lastError;

    for (int i = 0; i < constraintsList.length; i++) {
      try {
        final constraints = constraintsList[i];
        final hasVideo = constraints['video'] != false;

        print('🔄 Trying media constraints ${i + 1}/${constraintsList.length}: ${hasVideo ? 'Video+Audio' : 'Audio only'}');

        final stream = await navigator.mediaDevices.getUserMedia(constraints);

        if (stream.getTracks().isNotEmpty) {
          final audioTracks = stream.getAudioTracks();
          final videoTracks = stream.getVideoTracks();

          print('✅ Media stream obtained:');
          print('   📱 Audio tracks: ${audioTracks.length}');
          print('   📹 Video tracks: ${videoTracks.length}');

          // Update internal state based on what we actually got
          _isAudioEnabled = audioTracks.isNotEmpty;
          _isVideoEnabled = videoTracks.isNotEmpty;

          return stream;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('❌ Constraints ${i + 1} failed: ${e.toString()}');

        // More specific error handling
        final errorStr = e.toString().toLowerCase();

        if (errorStr.contains('notfound') || errorStr.contains('devicenotfound')) {
          print('   📍 Device not found - trying next constraint');
        } else if (errorStr.contains('notallowed') || errorStr.contains('permission')) {
          print('   🚫 Permission denied');
          if (i == constraintsList.length - 1) {
            throw Exception('Permission denied to access camera/microphone. Please allow permissions in your browser/device settings.');
          }
        } else if (errorStr.contains('notreadable') || errorStr.contains('trackstart')) {
          print('   🔒 Device already in use or hardware error');
        } else if (errorStr.contains('overconstrained') || errorStr.contains('constraint')) {
          print('   ⚠️ Constraints not satisfied - trying simpler constraints');
        }

        // Wait a bit before trying next constraint
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // If all attempts failed, throw the last error with helpful message
    throw Exception('Failed to access camera/microphone: ${lastError?.toString() ?? "Unknown error"}. Please check your device permissions and try again.');
  }

  // Join the enhanced mesh network
  Future<void> _joinMeshNetwork(String meetingId) async {
    try {
      print('🌐 Joining enhanced mesh network for meeting: $meetingId');

      _isMeetingActive = true;

      // Connect to Whisper service if subtitles enabled
      if (_subtitlesEnabled) {
        try {
          print('🔌 Attempting to connect to Whisper service...');
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

      // Add self as participant using existing structure
      await _addSelfAsParticipant();

      // Listen for other participants
      _listenForMeshParticipants();

      // Listen for signaling messages
      _listenForSignalingMessages();

      notifyListeners();
    } catch (e) {
      print('❌ Error joining mesh network: $e');
      _isMeetingActive = false;
      notifyListeners();
      throw Exception('Failed to setup meeting: $e');
    }
  }

  // Add self as participant using existing database structure with enhancements
  Future<void> _addSelfAsParticipant() async {
    if (_meetingId == null || _userId == null) return;

    try {
      // Add to participants subcollection (existing structure) with enhancements
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
        // Enhanced features
        'displayLanguage': _userDisplayLanguage,
        'subtitlesEnabled': _subtitlesEnabled,
      });

      // Update participant count in main meeting document
      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      print('✅ Added self as participant with enhanced features');
    } catch (e) {
      print('❌ Error adding self as participant: $e');
      // For debugging - print the exact error
      if (e.toString().contains('document path')) {
        print('Document path error - userId: $_userId, meetingId: $_meetingId');
      }
      rethrow;
    }
  }

  // Listen for participants in mesh network with enhanced participant model
  void _listenForMeshParticipants() {
    if (_meetingId == null) return;

    print('👥 Listening for enhanced mesh participants...');

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

        // Create enhanced participant model
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

        // Create peer connection for remote participants
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

      print('👥 Updated enhanced participants: ${_participants.length}');
      notifyListeners();
    }, onError: (error) {
      print('❌ Error listening for mesh participants: $error');
    });

    _subscriptions.add(subscription);
  }

  // Create enhanced mesh connection with a peer
  Future<void> _createMeshConnection(String peerId) async {
    try {
      print("🤝 Creating enhanced mesh connection with peer: $peerId");

      // Check if we have local stream
      if (_localStream == null) {
        print('⚠️ No local stream available for peer connection');
        return;
      }

      // Create peer connection
      final pc = await createPeerConnection(_iceServers);
      _peerConnections[peerId] = pc;

      // Create renderer for remote stream
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[peerId] = renderer;

      // Add local stream to peer connection
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
        print('📡 Added ${track.kind} track to peer connection with $peerId');
      }

      // Setup enhanced event handlers
      _setupEnhancedPeerConnectionEventHandlers(pc, peerId);

      // Create and send offer
      await _createAndSendOffer(pc, peerId);

    } catch (e) {
      print('❌ Error creating mesh connection with $peerId: $e');
    }
  }

  // Setup enhanced peer connection event handlers
  void _setupEnhancedPeerConnectionEventHandlers(RTCPeerConnection pc, String peerId) {
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

      print('📤 Offer sent to $peerId');
    } catch (e) {
      print('❌ Error creating/sending offer to $peerId: $e');
    }
  }

  // Listen for signaling messages using existing structure
  void _listenForSignalingMessages() {
    if (_meetingId == null || _userId == null) return;

    print('📡 Listening for signaling messages...');

    // Use existing 'calls' collection for signaling or create new 'signaling' subcollection
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

  // Handle offer
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

      print('✅ Answer sent to $fromId');
    } catch (e) {
      print('❌ Error handling offer from $fromId: $e');
    }
  }

  // Handle answer
  Future<void> _handleAnswer(String fromId, Map<String, dynamic> message) async {
    try {
      final pc = _peerConnections[fromId];
      if (pc == null) return;

      final answer = RTCSessionDescription(message['sdp'], message['type']);
      await pc.setRemoteDescription(answer);

      print('✅ Answer processed from $fromId');
    } catch (e) {
      print('❌ Error handling answer from $fromId: $e');
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
      print('✅ ICE candidate added from $fromId');
    } catch (e) {
      print('❌ Error handling ICE candidate from $fromId: $e');
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

      print('📤 Signaling message sent successfully to $toId');
    } catch (e) {
      print('❌ Error sending signaling message: $e');
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
    print('💔 Handling connection failure with $peerId');
    // Could implement reconnection logic here
  }

  // Enhanced toggle audio with subtitle support
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
        if (_isAudioEnabled && _userId != null) {
          await _audioCaptureService?.startLocalCapture(
            _localStream!,
            _userId!,
            _displayName,
          );
        } else {
          await _audioCaptureService?.stopCapture();
        }
      }

      // Update in Firestore using existing structure
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
      print('❌ Error toggling audio: $e');
    }
  }

  // Enhanced toggle video
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

      // Update in Firestore using existing structure
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
      print('❌ Error toggling video: $e');
    }
  }

  // Toggle subtitle functionality
  Future<void> toggleSubtitles() async {
    _subtitlesEnabled = !_subtitlesEnabled;

    if (_subtitlesEnabled) {
      // Connect to Whisper service and start audio capture
      try {
        final connected = await _whisperService?.connect() ?? false;
        if (connected && _localStream != null && _userId != null) {
          await _audioCaptureService?.startLocalCapture(
            _localStream!,
            _userId!,
            _displayName,
          );
          print('✅ Subtitles enabled and audio capture started');
        } else {
          print('⚠️ Failed to enable subtitles - Whisper service not available');
          _subtitlesEnabled = false;
        }
      } catch (e) {
        print('❌ Error enabling subtitles: $e');
        _subtitlesEnabled = false;
      }
    } else {
      // Disconnect from Whisper service and stop audio capture
      await _audioCaptureService?.stopCapture();
      await _whisperService?.disconnect();
      print('🔇 Subtitles disabled');
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

  // Update language settings
  Future<void> updateDisplayLanguage(String displayLanguage) async {
    _userDisplayLanguage = displayLanguage;

    // Update Whisper service to translate everything to this language
    _whisperService?.setUserLanguages(
      nativeLanguage: 'auto',
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
        'displayLanguage': displayLanguage,
      });
    }

    print('🌍 Display language updated to: $displayLanguage');
    notifyListeners();
  }

  // Get renderer for participant
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }
    return _remoteRenderers[participantId];
  }

  // Remove mesh connection
  Future<void> _removeMeshConnection(String peerId) async {
    try {
      print('🗑️ Removing mesh connection with $peerId');

      // Close peer connection
      final pc = _peerConnections[peerId];
      if (pc != null) {
        await pc.close();
        _peerConnections.remove(peerId);
      }

      // Stop remote stream
      final stream = _remoteStreams[peerId];
      if (stream != null) {
        for (var track in stream.getTracks()) {
          await track.stop();
        }
        await stream.dispose();
        _remoteStreams.remove(peerId);
      }

      // Dispose renderer
      final renderer = _remoteRenderers[peerId];
      if (renderer != null) {
        await renderer.dispose();
        _remoteRenderers.remove(peerId);
      }

      // Remove from audio capture
      _audioCaptureService?.removeRemoteStream(peerId);

      notifyListeners();
    } catch (e) {
      print('❌ Error removing mesh connection: $e');
    }
  }

  // Leave meeting using existing structure with enhanced cleanup
  Future<void> leaveMeeting() async {
    if (_meetingId == null || _userId == null) return;

    try {
      print('🚪 Leaving enhanced mesh meeting...');

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

  // Enhanced cleanup resources
  Future<void> _cleanup() async {
    try {
      print('🧹 Cleaning up enhanced mesh resources...');

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
          print('⚠️ Error closing peer connection: $e');
        }
      }
      _peerConnections.clear();

      // Stop remote streams
      for (var stream in _remoteStreams.values) {
        try {
          for (var track in stream.getTracks()) {
            await track.stop();
          }
          await stream.dispose();
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
          print('⚠️ Error disposing renderer: $e');
        }
      }
      _remoteRenderers.clear();

      // Stop local stream
      if (_localStream != null) {
        try {
          for (var track in _localStream!.getTracks()) {
            await track.stop();
          }
          await _localStream!.dispose();
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
      print('✅ Enhanced mesh resources cleaned up successfully');
    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    print('🗑️ Disposing Enhanced WebRTC Mesh Service...');
    _cleanup();
    super.dispose();
  }
}

// Enhanced Mesh Participant Model with language support
class MeshParticipant {
  final String id;
  final String name;
  final bool isHost;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isLocal;
  final String displayLanguage; // Enhanced: Language preference

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