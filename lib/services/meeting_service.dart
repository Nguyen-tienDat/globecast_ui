// lib/services/webrtc_meeting_service.dart - FIXED FOR MEDIA STREAMING
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

// Abstract base class
abstract class GcbMeetingService extends ChangeNotifier {
  String? get meetingId;
  String? get userId;
  bool get isHost;
  bool get isMeetingActive;
  bool get isListening;
  Duration get elapsedTime;
  String get speakingLanguage;
  String get listeningLanguage;
  List<ParticipantModel> get participants;
  List<SubtitleModel> get subtitles;
  List<ChatMessage> get messages;
  RTCVideoRenderer? get localRenderer;

  Future<void> initialize();
  Future<String> createMeeting({required String topic, String? password, List<String> translationLanguages = const []});
  Future<void> joinMeeting({required String meetingId, String? password});
  Future<void> toggleMicrophone();
  Future<void> toggleCamera();
  Future<void> toggleScreenSharing();
  Future<void> toggleHandRaised();
  Future<void> endMeetingForAll();
  Future<void> leaveMeetingAsParticipant();
  Future<void> toggleSpeechRecognition();
  Future<void> startSpeechRecognition();
  Future<void> stopSpeechRecognition();
  Future<void> sendMessage(String message);
  RTCVideoRenderer? getRendererForParticipant(String participantId);
  void setUserDetails({required String displayName, String? userId});
  void setLanguagePreferences({required String speaking, required String listening});
}

// Fixed WebRTC implementation
class WebRTCMeetingService extends GcbMeetingService {
  // Metered SFU Configuration
  static const String _sfuHost = "https://global.sfu.metered.ca";
  static const String _sfuAppId = "684272d83a97f8dcea82abea";
  static const String _sfuSecret = "XsMrnmK6kLFO/rlA";
  static const String _stunServer = "stun:stun.metered.ca:80";

  // WebRTC Components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, MediaStream> _remoteStreams = {};

  // SFU Session Management
  String? _sessionId;
  String? _meetingId;
  String? _userId;
  String _displayName = 'User';
  bool _isHost = false;
  bool _isMeetingActive = false;
  bool _isConnected = false;

  // Published/Subscribed tracks
  final Map<String, String> _publishedTracks = {}; // kind -> trackId
  final Map<String, String> _subscribedTracks = {}; // participantId -> trackId

  // Audio/Video State
  bool _isMicrophoneMuted = false;
  bool _isCameraEnabled = true;
  bool _isScreenSharing = false;
  bool _isHandRaised = false;

  // Meeting Timer
  Timer? _elapsedTimer;
  DateTime? _meetingStartTime;
  Timer? _trackPollingTimer;

  // Dummy data for UI
  final List<ParticipantModel> _participants = [];
  final List<SubtitleModel> _subtitles = [];
  final List<ChatMessage> _messages = [];
  String _speakingLanguage = 'english';
  String _listeningLanguage = 'english';

  @override
  String? get meetingId => _meetingId;
  @override
  String? get userId => _userId;
  @override
  bool get isHost => _isHost;
  @override
  bool get isMeetingActive => _isMeetingActive;
  @override
  bool get isListening => false;
  @override
  Duration get elapsedTime {
    if (_meetingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_meetingStartTime!);
  }
  @override
  String get speakingLanguage => _speakingLanguage;
  @override
  String get listeningLanguage => _listeningLanguage;
  @override
  List<ParticipantModel> get participants => List.unmodifiable(_participants);
  @override
  List<SubtitleModel> get subtitles => List.unmodifiable(_subtitles);
  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  @override
  RTCVideoRenderer? get localRenderer => _localRenderer;

  @override
  Future<void> initialize() async {
    print('🚀 Initializing WebRTC Meeting Service...');

    _userId = 'user_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

    await _requestPermissions();
    await _initializeRenderers();

    print('✅ WebRTC Meeting Service initialized with userId: $_userId');
  }

  Future<void> _requestPermissions() async {
    print('🔑 Requesting permissions...');
    final permissions = [Permission.camera, Permission.microphone];

    for (final permission in permissions) {
      final status = await permission.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Permission $permission not granted');
      }
    }
    print('✅ Permissions granted');
  }

  Future<void> _initializeRenderers() async {
    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    print('📹 Local renderer initialized');
  }

  @override
  void setUserDetails({required String displayName, String? userId}) {
    _displayName = displayName;
    if (userId != null) _userId = userId;
    print('👤 User details set: $_displayName ($_userId)');
  }

  @override
  void setLanguagePreferences({required String speaking, required String listening}) {
    _speakingLanguage = speaking;
    _listeningLanguage = listening;
  }

  @override
  Future<String> createMeeting({
    required String topic,
    String? password,
    List<String> translationLanguages = const [],
  }) async {
    try {
      print('🎬 Creating meeting: $topic');

      final meetingId = 'GCM-${DateTime.now().millisecondsSinceEpoch}';
      _meetingId = meetingId;
      _isHost = true;

      await _initializeLocalMedia();
      await _createPeerConnection();
      await _createSfuSession();
      await _publishLocalTracks();

      _startMeeting();
      _startTrackPolling(); // Start polling for other participants

      print('🎉 Meeting created successfully: $meetingId');
      return meetingId;

    } catch (e) {
      print('❌ Error creating meeting: $e');
      throw Exception('Failed to create meeting: $e');
    }
  }

  @override
  Future<void> joinMeeting({required String meetingId, String? password}) async {
    try {
      print('🚪 Joining meeting: $meetingId');

      _meetingId = meetingId;
      _isHost = false;

      await _initializeLocalMedia();
      await _createPeerConnection();
      await _createSfuSession();
      await _publishLocalTracks();

      _startMeeting();
      _startTrackPolling(); // Start polling for other participants

      // Subscribe to existing tracks after a delay
      Timer(const Duration(seconds: 2), () {
        _subscribeToExistingTracks();
      });

      print('🎉 Successfully joined meeting: $meetingId');

    } catch (e) {
      print('❌ Error joining meeting: $e');
      throw Exception('Failed to join meeting: $e');
    }
  }

  Future<void> _initializeLocalMedia() async {
    try {
      print('📱 Initializing local media...');

      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'width': 640,
          'height': 480,
          'frameRate': 15,
          'facingMode': 'user',
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (_localRenderer != null && _localStream != null) {
        _localRenderer!.srcObject = _localStream;
        print('📹 Local video renderer set');
      }

      print('✅ Local media initialized - Audio tracks: ${_localStream?.getAudioTracks().length}, Video tracks: ${_localStream?.getVideoTracks().length}');

    } catch (e) {
      print('❌ Error initializing local media: $e');
      throw Exception('Failed to initialize camera/microphone: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      print('🔗 Creating peer connection...');

      final config = {
        'iceServers': [
          {'urls': _stunServer}
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(config);

      _peerConnection!.onIceConnectionState = (state) {
        print('🧊 ICE Connection State: $state');

        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _isConnected = true;
          print('✅ WebRTC connection established');
          notifyListeners();
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _isConnected = false;
          print('❌ WebRTC connection lost');
          notifyListeners();
        }
      };

      _peerConnection!.onTrack = (event) {
        print('📡 Received remote track: ${event.track.kind} from stream: ${event.streams.first.id}');
        _handleRemoteTrack(event);
      };

      print('✅ Peer connection created');

    } catch (e) {
      print('❌ Error creating peer connection: $e');
      throw e;
    }
  }

  Future<void> _createSfuSession() async {
    try {
      print('🌐 Creating SFU session...');

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final response = await http.post(
        Uri.parse('$_sfuHost/api/sfu/$_sfuAppId/session/new'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sfuSecret',
        },
        body: jsonEncode({
          'sessionDescription': offer.toMap(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionId = data['sessionId'];

        final remoteSdp = RTCSessionDescription(
          data['sessionDescription']['sdp'],
          data['sessionDescription']['type'],
        );

        await _peerConnection!.setRemoteDescription(remoteSdp);

        _isConnected = true;
        print('✅ SFU session created: $_sessionId');

      } else {
        throw Exception('Failed to create SFU session: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      print('❌ Error creating SFU session: $e');
      throw e;
    }
  }

  Future<void> _publishLocalTracks() async {
    if (_localStream == null || _sessionId == null) {
      print('❌ Cannot publish tracks - missing stream or session');
      return;
    }

    try {
      print('📤 Publishing local tracks...');

      // Add tracks to peer connection
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
        print('➕ Added ${track.kind} track to peer connection');
      }

      // Create new offer after adding tracks
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send renegotiation request to SFU
      final response = await http.put(
        Uri.parse('$_sfuHost/api/sfu/$_sfuAppId/session/$_sessionId/renegotiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sfuSecret',
        },
        body: jsonEncode({
          'sessionDescription': offer.toMap(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final remoteSdp = RTCSessionDescription(
          data['sessionDescription']['sdp'],
          data['sessionDescription']['type'],
        );

        await _peerConnection!.setRemoteDescription(remoteSdp);
        print('✅ Local tracks published successfully');

      } else {
        print('❌ Failed to publish tracks: ${response.statusCode} - ${response.body}');
      }

    } catch (e) {
      print('❌ Error publishing local tracks: $e');
    }
  }

  void _startTrackPolling() {
    print('🔄 Starting track polling...');

    _trackPollingTimer?.cancel();
    _trackPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _subscribeToExistingTracks();
    });
  }

  Future<void> _subscribeToExistingTracks() async {
    if (_sessionId == null) return;

    try {
      // Get available tracks from SFU
      final response = await http.get(
        Uri.parse('$_sfuHost/api/sfu/$_sfuAppId/session/$_sessionId/tracks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sfuSecret',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> tracks = jsonDecode(response.body);
        print('📋 Available tracks: ${tracks.length}');

        for (var trackData in tracks) {
          final trackId = trackData['trackId'];
          final sessionId = trackData['sessionId'];
          final kind = trackData['kind'];

          // Skip our own tracks
          if (sessionId == _sessionId) continue;

          // Skip if already subscribed
          if (_subscribedTracks.containsValue(trackId)) continue;

          print('🔔 Subscribing to $kind track: $trackId from session: $sessionId');
          await _subscribeToTrack(sessionId, trackId);

          // Add participant if not exists
          _addRemoteParticipant(sessionId, kind);
        }

      } else {
        print('❌ Failed to get tracks: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Error getting tracks: $e');
    }
  }

  Future<void> _subscribeToTrack(String remoteSessionId, String trackId) async {
    if (_sessionId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_sfuHost/api/sfu/$_sfuAppId/session/$_sessionId/track/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_sfuSecret',
        },
        body: jsonEncode({
          'tracks': [
            {
              'remoteSessionId': remoteSessionId,
              'remoteTrackId': trackId,
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final remoteSdp = RTCSessionDescription(
          data['sessionDescription']['sdp'],
          data['sessionDescription']['type'],
        );

        await _peerConnection!.setRemoteDescription(remoteSdp);

        // Create answer
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        // Send answer back to SFU
        await http.put(
          Uri.parse('$_sfuHost/api/sfu/$_sfuAppId/session/$_sessionId/renegotiate'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_sfuSecret',
          },
          body: jsonEncode({
            'sessionDescription': answer.toMap(),
          }),
        );

        _subscribedTracks[remoteSessionId] = trackId;
        print('✅ Subscribed to track: $trackId');

      } else {
        print('❌ Failed to subscribe to track: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Error subscribing to track: $e');
    }
  }

  void _handleRemoteTrack(RTCTrackEvent event) async {
    final track = event.track;
    final streams = event.streams;

    if (streams.isNotEmpty) {
      final stream = streams.first;
      final streamId = stream.id;

      print('🎯 Handling remote ${track.kind} track from stream: $streamId');

      // Create renderer for remote video
      if (track.kind == 'video') {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        _remoteRenderers[streamId] = renderer;
        print('📺 Remote video renderer created for: $streamId');
      }

      _remoteStreams[streamId] = stream;

      // Update participant status
      _updateRemoteParticipantMedia(streamId, track.kind == 'video');

      notifyListeners();
    }
  }

  void _addRemoteParticipant(String sessionId, String kind) {
    // Check if participant already exists
    final existingIndex = _participants.indexWhere((p) => p.id == sessionId);

    if (existingIndex == -1) {
      _participants.add(ParticipantModel(
        id: sessionId,
        name: 'Remote User ${sessionId.substring(0, 6)}',
        isHost: false,
        isMuted: kind != 'audio',
        isSpeaking: false,
      ));

      print('👥 Added remote participant: $sessionId');
      notifyListeners();
    }
  }

  void _updateRemoteParticipantMedia(String streamId, bool hasVideo) {
    // Find participant by stream ID and update their media status
    for (int i = 0; i < _participants.length; i++) {
      if (_participants[i].id.contains(streamId.substring(0, 6))) {
        // Update participant media status
        notifyListeners();
        break;
      }
    }
  }

  void _startMeeting() {
    _isMeetingActive = true;
    _meetingStartTime = DateTime.now();

    _addLocalParticipant();
    _startElapsedTimer();

    print('🎬 Meeting started');
    notifyListeners();
  }

  void _addLocalParticipant() {
    final localParticipant = ParticipantModel(
      id: _userId!,
      name: '$_displayName (You)',
      isHost: _isHost,
      isMuted: _isMicrophoneMuted,
      isSpeaking: false,
      isHandRaised: _isHandRaised,
      isScreenSharing: _isScreenSharing,
    );

    _participants.removeWhere((p) => p.id == _userId);
    _participants.insert(0, localParticipant);
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      notifyListeners();
    });
  }

  @override
  Future<void> toggleMicrophone() async {
    try {
      if (_localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          final track = audioTracks.first;
          track.enabled = !track.enabled;
          _isMicrophoneMuted = !track.enabled;

          print('🎤 Microphone ${_isMicrophoneMuted ? 'muted' : 'unmuted'}');
          _updateLocalParticipant();
        }
      }
    } catch (e) {
      print('❌ Error toggling microphone: $e');
    }
  }

  @override
  Future<void> toggleCamera() async {
    try {
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final track = videoTracks.first;
          track.enabled = !track.enabled;
          _isCameraEnabled = track.enabled;

          print('📹 Camera ${_isCameraEnabled ? 'enabled' : 'disabled'}');
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Error toggling camera: $e');
    }
  }

  @override
  Future<void> toggleScreenSharing() async {
    _isScreenSharing = !_isScreenSharing;
    print('🖥️ Screen sharing ${_isScreenSharing ? 'started' : 'stopped'}');
    _updateLocalParticipant();
  }

  @override
  Future<void> toggleHandRaised() async {
    _isHandRaised = !_isHandRaised;
    print('✋ Hand ${_isHandRaised ? 'raised' : 'lowered'}');
    _updateLocalParticipant();
  }

  void _updateLocalParticipant() {
    final index = _participants.indexWhere((p) => p.id == _userId);
    if (index >= 0) {
      _participants[index] = ParticipantModel(
        id: _userId!,
        name: '$_displayName (You)',
        isHost: _isHost,
        isMuted: _isMicrophoneMuted,
        isSpeaking: false,
        isHandRaised: _isHandRaised,
        isScreenSharing: _isScreenSharing,
      );
      notifyListeners();
    }
  }

  @override
  Future<void> endMeetingForAll() async {
    print('🛑 Ending meeting for all participants...');
    await _cleanup();
  }

  @override
  Future<void> leaveMeetingAsParticipant() async {
    print('🚪 Leaving meeting as participant...');
    await _cleanup();
  }

  Future<void> _cleanup() async {
    try {
      print('🧹 Cleaning up meeting resources...');

      _trackPollingTimer?.cancel();
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _meetingStartTime = null;

      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          await track.stop();
        }
        _localStream = null;
      }

      if (_localRenderer != null) {
        await _localRenderer!.dispose();
        _localRenderer = null;
      }

      for (var renderer in _remoteRenderers.values) {
        await renderer.dispose();
      }
      _remoteRenderers.clear();
      _remoteStreams.clear();
      _publishedTracks.clear();
      _subscribedTracks.clear();

      _sessionId = null;
      _isConnected = false;
      _meetingId = null;
      _isHost = false;
      _isMeetingActive = false;
      _participants.clear();
      _subtitles.clear();
      _messages.clear();

      _isMicrophoneMuted = false;
      _isCameraEnabled = true;
      _isScreenSharing = false;
      _isHandRaised = false;

      print('✅ Cleanup completed');
      notifyListeners();

    } catch (e) {
      print('❌ Error during cleanup: $e');
    }
  }

  @override
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    }

    // Look for remote renderer by participant ID
    for (var entry in _remoteRenderers.entries) {
      if (entry.key.contains(participantId.substring(0, 6))) {
        return entry.value;
      }
    }

    return null;
  }

  // Stub implementations for compatibility
  @override
  Future<void> toggleSpeechRecognition() async {}

  @override
  Future<void> startSpeechRecognition() async {}

  @override
  Future<void> stopSpeechRecognition() async {}

  @override
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final chatMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userId!,
      senderName: _displayName,
      text: message.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    _messages.add(chatMessage);
    notifyListeners();
  }

  @override
  void dispose() {
    print('🗑️ Disposing WebRTC Meeting Service...');
    _cleanup();
    super.dispose();
  }
}

// Model classes
class ParticipantModel {
  final String id;
  final String name;
  final bool isSpeaking;
  final bool isMuted;
  final bool isHost;
  final bool isHandRaised;
  final bool isScreenSharing;
  final String? avatarUrl;

  ParticipantModel({
    required this.id,
    required this.name,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isHost = false,
    this.isHandRaised = false,
    this.isScreenSharing = false,
    this.avatarUrl,
  });

  ParticipantModel copyWith({
    String? id,
    String? name,
    bool? isSpeaking,
    bool? isMuted,
    bool? isHost,
    bool? isHandRaised,
    bool? isScreenSharing,
    String? avatarUrl,
  }) {
    return ParticipantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      isHost: isHost ?? this.isHost,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class SubtitleModel {
  final String id;
  final String speakerId;
  final String text;
  final String language;
  final DateTime timestamp;

  SubtitleModel({
    required this.id,
    required this.speakerId,
    required this.text,
    required this.language,
    required this.timestamp,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}