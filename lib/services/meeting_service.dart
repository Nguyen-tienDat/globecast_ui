// lib/services/meeting_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:translator/translator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

class GcbMeetingService extends ChangeNotifier {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // WebRTC related variables
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;

  // Speech and translation
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final GoogleTranslator _translator = GoogleTranslator();
  bool _isListening = false;
  String _currentTranscription = '';
  bool _webRTCAudioEnabled = true;

  // Meeting data
  String? _meetingId;
  String? _userId;
  String _displayName = 'User';
  bool _isHost = false;
  bool _isMeetingActive = false;
  String _selectedSpeakingLanguage = 'english';
  String _selectedListeningLanguage = 'english';
  Map<String, String> _participantLanguages = {};

  // Meeting state observables
  final List<ParticipantModel> _participants = [];
  final List<SubtitleModel> _subtitles = [];
  final List<ChatMessage> _messages = [];
  Duration _elapsedTime = const Duration();
  Timer? _meetingTimer;

  // Getters
  String? get meetingId => _meetingId;
  String? get userId => _userId;
  bool get isHost => _isHost;
  bool get isMeetingActive => _isMeetingActive;
  List<ParticipantModel> get participants => List.unmodifiable(_participants);
  List<SubtitleModel> get subtitles => List.unmodifiable(_subtitles);
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get speakingLanguage => _selectedSpeakingLanguage;
  String get listeningLanguage => _selectedListeningLanguage;
  Duration get elapsedTime => _elapsedTime;
  bool get isListening => _isListening;
  RTCVideoRenderer? get localRenderer => _localRenderer;

  // WebRTC configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': 'b573383c24e9d31f7db',
        'credential': 'tvAyXoixqazepn0',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': 'b573383c24e9d31f7db',
        'credential': 'tvAyXoixqazepn0',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  // Initialize service
  Future<void> initialize() async {
    // Generate user ID if not present
    _userId ??= const Uuid().v4();

    // Initialize speech recognition
    try {
      await _speechToText.initialize(
          onStatus: (status) {
            if (status == 'done') {
              _isListening = false;
              _restoreWebRTCAudio();
              notifyListeners();
            }
          },
          onError: (error) {
            print('Speech recognition error: $error');
            _isListening = false;
            _restoreWebRTCAudio();
            notifyListeners();
          }
      );
    } catch (e) {
      print('Error initializing speech recognition: $e');
    }

    notifyListeners();
  }

  // Set user details
  void setUserDetails({required String displayName, String? userId}) {
    _displayName = displayName;
    if (userId != null) _userId = userId;
    notifyListeners();
  }

  // Set language preferences
  void setLanguagePreferences({required String speaking, required String listening}) {
    _selectedSpeakingLanguage = speaking;
    _selectedListeningLanguage = listening;

    // Update user language in meeting if active
    if (_isMeetingActive && _meetingId != null && _userId != null) {
      _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'speakingLanguage': speaking,
        'listeningLanguage': listening,
      });
    }

    notifyListeners();
  }

  // Create a new meeting
  Future<String> createMeeting({
    required String topic,
    String? password,
    required List<String> translationLanguages,
  }) async {
    try {
      //Add log for password
      print('Creating meeting with password: "${password ?? ''}"');

      //Use trim to deny space in password
      String cleanPassword = password?.trim() ?? '';

      // Generate meeting ID
      final String meetingId = 'GCM-${const Uuid().v4().substring(0, 8)}';
      _meetingId = meetingId;
      _isHost = true;

      // Create meeting document
      await _firestore.collection('meetings').doc(meetingId).set({
        'meetingId': meetingId,
        'topic': topic,
        'hostId': _userId,
        'password': cleanPassword,
        'translationLanguages': translationLanguages,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'participantCount': 1,
      });

      // Add to active_meetings collection for easy querying
      await _firestore.collection('active_meetings').doc(meetingId).set({
        'meetingId': meetingId,
        'topic': topic,
        'hostId': _userId,
        'participantCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Add to user_meetings collection for easy user-meeting relation query
      await _firestore.collection('user_meetings').doc('${_userId}_$meetingId').set({
        'userId': _userId,
        'meetingId': meetingId,
        'displayName': _displayName,
        'role': 'host',
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Add host as participant
      await _firestore
          .collection('meetings')
          .doc(meetingId)
          .collection('participants')
          .doc(_userId)
          .set({
        'userId': _userId,
        'displayName': _displayName,
        'role': 'host',
        'joinedAt': FieldValue.serverTimestamp(),
        'speakingLanguage': _selectedSpeakingLanguage,
        'listeningLanguage': _selectedListeningLanguage,
        'isActive': true,
        'isMuted': false,
        'isCameraOff': false,
        'isHandRaised': false,
        'isScreenSharing': false,
      });

      await _setupLocalStream();
      await _joinMeetingRoom(meetingId);

      return meetingId;
    } catch (e) {
      print('Error creating meeting: $e');
      throw Exception('Failed to create meeting: $e');
    }
  }

  // Join an existing meeting
  Future<void> joinMeeting({required String meetingId, String? password}) async {
    try {
      //Log to checkout password
      print('Joining meeting: $meetingId with password: "${password ?? ''}"');

      //Clear that password used trim to delete space
      String cleanPassword = password?.trim() ?? '';

      // Validate meeting
      final meetingDoc = await _firestore.collection('meetings').doc(meetingId).get();

      if (!meetingDoc.exists) {
        throw Exception('Meeting not found');
      }

      final meetingData = meetingDoc.data() as Map<String, dynamic>;

      //Debug password information
      print('Meeting password in database: ${meetingData['password']}"');
      print('Submitted password: "$cleanPassword"');

      if (meetingData['password'] != null && meetingData['password'].isNotEmpty) {
        if (meetingData['password'] != cleanPassword) {
          throw Exception('Incorrect password');
        }
      }


      // Check if meeting is active
      if (meetingData['status'] != 'active') {
        throw Exception('Meeting has ended');
      }

      // Check password if required
      if (meetingData['password'] != null && meetingData['password'].isNotEmpty) {
        if (password != meetingData['password']) {
          throw Exception('Incorrect password');
        }
      }

      _meetingId = meetingId;
      _isHost = meetingData['hostId'] == _userId;

      // Add participant
      await _firestore
          .collection('meetings')
          .doc(meetingId)
          .collection('participants')
          .doc(_userId)
          .set({
        'userId': _userId,
        'displayName': _displayName,
        'role': _isHost ? 'host' : 'participant',
        'joinedAt': FieldValue.serverTimestamp(),
        'speakingLanguage': _selectedSpeakingLanguage,
        'listeningLanguage': _selectedListeningLanguage,
        'isActive': true,
        'isMuted': true,
        'isCameraOff': false,
        'isHandRaised': false,
        'isScreenSharing': false,
      });

      // Add to user_meetings collection
      await _firestore.collection('user_meetings').doc('${_userId}_$meetingId').set({
        'userId': _userId,
        'meetingId': meetingId,
        'displayName': _displayName,
        'role': _isHost ? 'host' : 'participant',
        'joinedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Update participant count
      await _firestore.collection('meetings').doc(meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      // Update active_meetings collection
      await _firestore.collection('active_meetings').doc(meetingId).update({
        'participantCount': FieldValue.increment(1),
      });

      await _setupLocalStream();
      await _joinMeetingRoom(meetingId);
    } catch (e) {
      print('Error joining meeting: $e');
      throw Exception('Failed to join meeting: $e');
    }
  }

  // Leave meeting
  Future<void> leaveMeeting() async {
    try {
      if (_meetingId == null || _userId == null) return;

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

      // Update user_meetings collection
      await _firestore
          .collection('user_meetings')
          .doc('${_userId}_${_meetingId}')
          .update({
        'isActive': false,
        'leftAt': FieldValue.serverTimestamp(),
      });

      // Update participant count
      await _firestore.collection('meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(-1),
      });

      // Update active_meetings collection
      await _firestore.collection('active_meetings').doc(_meetingId).update({
        'participantCount': FieldValue.increment(-1),
      });

      // If host is leaving, end the meeting
      if (_isHost) {
        await _firestore.collection('meetings').doc(_meetingId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });

        // Remove from active_meetings
        await _firestore.collection('active_meetings').doc(_meetingId).delete();
      }

      // Close all peer connections
      for (var pc in _peerConnections.values) {
        await pc.close();
      }
      _peerConnections.clear();

      // Dispose streams and renderers
      for (var stream in _remoteStreams.values) {
        stream.getTracks().forEach((track) => track.stop());
      }
      _remoteStreams.clear();

      for (var renderer in _remoteRenderers.values) {
        await renderer.dispose();
      }
      _remoteRenderers.clear();

      // Stop local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        _localStream = null;
      }

      // Reset meeting state
      _meetingId = null;
      _isHost = false;
      _isMeetingActive = false;
      _participants.clear();
      _subtitles.clear();
      _participantLanguages.clear();

      // Stop timer
      _meetingTimer?.cancel();
      _elapsedTime = const Duration();

      notifyListeners();
    } catch (e) {
      print('Error leaving meeting: $e');
    }
  }

  // Setup local media stream
  Future<void> _setupLocalStream() async {
    try {
      // Initialize local renderer if not already
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
      }

      // Get user media
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
        },
      });

      _localRenderer!.srcObject = _localStream;

      notifyListeners();
    } catch (e) {
      print('Error setting up local stream: $e');
      throw Exception('Could not access camera or microphone: $e');
    }
  }

  // Join a meeting room and setup connections
  Future<void> _joinMeetingRoom(String meetingId) async {
    try {
      _isMeetingActive = true;

      // Start the meeting timer
      _startMeetingTimer();

      // Listen for participant changes
      _listenForParticipants();

      // Listen for messages
      _listenForMessages();

      // Listen for subtitles
      _listenForSubtitles();

      // Listen for connection requests
      _listenForConnectionRequests();

      notifyListeners();
    } catch (e) {
      print('Error joining meeting room: $e');
      _isMeetingActive = false;
      notifyListeners();
      throw Exception('Failed to setup meeting: $e');
    }
  }

  // Listen for participants in the meeting
  void _listenForParticipants() {
    if (_meetingId == null) return;

    _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      // Update participants list
      final List<ParticipantModel> newParticipants = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participantId = doc.id;

        // Store language preferences
        _participantLanguages[participantId] = data['listeningLanguage'] ?? 'english';

        // Create or fetch peer connection for this participant if not local
        if (participantId != _userId && !_peerConnections.containsKey(participantId)) {
          await _createPeerConnection(participantId);
        }

        // Add to participants list
        newParticipants.add(ParticipantModel(
          id: participantId,
          name: data['displayName'] ?? 'Unknown',
          isSpeaking: false, // Will update based on audio activity
          isMuted: data['isMuted'] ?? false,
          isHost: data['role'] == 'host',
          isHandRaised: data['isHandRaised'] ?? false,
          isScreenSharing: data['isScreenSharing'] ?? false,
        ));
      }

      // Find local participant
      final localParticipantDoc = snapshot.docs.where((doc) => doc.id == _userId).toList();
      ParticipantModel? localParticipant;

      if (localParticipantDoc.isNotEmpty) {
        final data = localParticipantDoc[0].data();
        localParticipant = ParticipantModel(
          id: _userId!,
          name: data['displayName'] + ' (You)',
          isSpeaking: _isListening,
          isMuted: data['isMuted'] ?? true,
          isHost: data['role'] == 'host',
          isHandRaised: data['isHandRaised'] ?? false,
          isScreenSharing: data['isScreenSharing'] ?? false,
        );
      } else {
        // If not found, create default
        localParticipant = ParticipantModel(
          id: _userId!,
          name: '$_displayName (You)',
          isSpeaking: _isListening,
          isMuted: !_isListening,
          isHost: _isHost,
          isHandRaised: false,
          isScreenSharing: false,
        );
      }

      // Remove local participant if present in list already
      newParticipants.removeWhere((p) => p.id == _userId);

      // Add local participant at the beginning
      newParticipants.insert(0, localParticipant);

      // Update participants
      _participants.clear();
      _participants.addAll(newParticipants);

      notifyListeners();
    }, onError: (error) {
      print('Error listening for participants: $error');
    });
  }

  // Create WebRTC peer connection for a participant
  Future<void> _createPeerConnection(String participantId) async {
    try {
      print("Creating peer connection with $participantId");

      // Create peer connection
      final pc = await createPeerConnection(_iceServers);
      _peerConnections[participantId] = pc;

      // Create renderer for remote stream
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _remoteRenderers[participantId] = renderer;

      // Add local tracks to peer connection
      _localStream?.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });

      // Setup event handlers
      pc.onIceConnectionState = (state) {
        print("ICE connection state with $participantId: $state");
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          print("Connection with $participantId failed or disconnected, attempting to reconnect...");
          // Logic for reconnection can be added here
        }
      };

      pc.onIceCandidate = (candidate) async {
        if (_meetingId == null) return;

        await _firestore
            .collection('meetings')
            .doc(_meetingId)
            .collection('connections')
            .doc('${_userId}_$participantId')
            .collection('candidates')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'from': _userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      };

      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          _remoteStreams[participantId] = stream;
          _remoteRenderers[participantId]?.srcObject = stream;

          print("Remote stream received from $participantId");
          notifyListeners();
        }
      };

      // Create offer if we're establishing the connection
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      // Store the offer in Firestore
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('connections')
          .doc('${_userId}_$participantId')
          .set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'from': _userId,
        'to': participantId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Listen for answer
      _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('connections')
          .doc('${participantId}_${_userId}')
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists && snapshot.data()!.containsKey('answer')) {
          final answerData = snapshot.data()!['answer'];

          // Ensure peer connection still exists
          if (_peerConnections.containsKey(participantId)) {
            try {
              final answer = RTCSessionDescription(
                answerData['sdp'],
                answerData['type'],
              );

              await _peerConnections[participantId]?.setRemoteDescription(answer);
              print("Answer set from $participantId");
            } catch (e) {
              print("Error setting remote description: $e");
            }
          }
        }
      }, onError: (error) {
        print('Error listening for answer: $error');
      });

      // Listen for ICE candidates
      _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('connections')
          .doc('${participantId}_${_userId}')
          .collection('candidates')
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            if (data['from'] == participantId && _peerConnections.containsKey(participantId)) {
              try {
                final candidate = RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                );

                await _peerConnections[participantId]?.addCandidate(candidate);
                print("ICE candidate added from $participantId");
              } catch (e) {
                print("Error adding ICE candidate: $e");
              }
            }
          }
        }
      }, onError: (error) {
        print('Error listening for ICE candidates: $error');
      });
    } catch (e) {
      print('Error creating peer connection: $e');
    }
  }

  // Listen for incoming connection requests
  void _listenForConnectionRequests() {
    if (_meetingId == null || _userId == null) return;

    _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('connections')
        .where('to', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final fromUserId = data?['from'];

          // Skip if connection already exists
          if (_peerConnections.containsKey(fromUserId)) continue;

          if (data!.containsKey('offer')) {
            print("Received connection request from $fromUserId");

            // Create renderer
            final renderer = RTCVideoRenderer();
            await renderer.initialize();
            _remoteRenderers[fromUserId] = renderer;

            // Create peer connection
            final pc = await createPeerConnection(_iceServers);
            _peerConnections[fromUserId] = pc;

            // Add local stream
            _localStream?.getTracks().forEach((track) {
              pc.addTrack(track, _localStream!);
            });

            // Setup event handlers
            pc.onIceCandidate = (candidate) async {
              await _firestore
                  .collection('meetings')
                  .doc(_meetingId)
                  .collection('connections')
                  .doc('${_userId}_$fromUserId')
                  .collection('candidates')
                  .add({
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
                'from': _userId,
                'timestamp': FieldValue.serverTimestamp(),
              });
            };

            pc.onTrack = (event) {
              if (event.streams.isNotEmpty) {
                final stream = event.streams[0];
                _remoteStreams[fromUserId] = stream;
                _remoteRenderers[fromUserId]?.srcObject = stream;

                print("Remote stream received from $fromUserId");
                notifyListeners();
              }
            };

            // Set remote description (offer)
            final offerData = data?['offer'];
            try {
              final offer = RTCSessionDescription(
                offerData['sdp'],
                offerData['type'],
              );

              await pc.setRemoteDescription(offer);

              // Create answer
              final answer = await pc.createAnswer();
              await pc.setLocalDescription(answer);

              // Send answer
              await _firestore
                  .collection('meetings')
                  .doc(_meetingId)
                  .collection('connections')
                  .doc('${_userId}_$fromUserId')
                  .set({
                'answer': {
                  'type': answer.type,
                  'sdp': answer.sdp,
                },
                'from': _userId,
                'to': fromUserId,
                'timestamp': FieldValue.serverTimestamp(),
              });

              print("Answer sent to $fromUserId");
            } catch (e) {
              print("Error processing offer from $fromUserId: $e");
            }

            // Listen for ICE candidates
            _firestore
                .collection('meetings')
                .doc(_meetingId)
                .collection('connections')
                .doc('${fromUserId}_${_userId}')
                .collection('candidates')
                .snapshots()
                .listen((snapshot) async {
              for (var change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.added) {
                  final data = change.doc.data()!;
                  if (data['from'] == fromUserId && _peerConnections.containsKey(fromUserId)) {
                    try {
                      final candidate = RTCIceCandidate(
                        data['candidate'],
                        data['sdpMid'],
                        data['sdpMLineIndex'],
                      );

                      await _peerConnections[fromUserId]?.addCandidate(candidate);
                      print("ICE candidate added from $fromUserId");
                    } catch (e) {
                      print("Error adding ICE candidate: $e");
                    }
                  }
                }
              }
            }, onError: (error) {
              print('Error listening for ICE candidates: $error');
            });
          }
        }
      }
    }, onError: (error) {
      print('Error listening for connection requests: $error');
    });
  }

  // Listen for messages
  void _listenForMessages() {
    if (_meetingId == null) return;

    _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      final List<ChatMessage> newMessages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        newMessages.add(ChatMessage(
          id: doc.id,
          senderId: data['senderId'],
          senderName: data['senderName'],
          text: data['text'],
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isMe: data['senderId'] == _userId,
        ));
      }

      _messages.clear();
      _messages.addAll(newMessages);

      notifyListeners();
    }, onError: (error) {
      print('Error listening for messages: $error');
    });
  }

  // Listen for subtitles/transcriptions
  void _listenForSubtitles() {
    if (_meetingId == null) return;

    _firestore
        .collection('meetings')
        .doc(_meetingId)
        .collection('subtitles')
        .where('targetLanguage', isEqualTo: _selectedListeningLanguage)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      final List<SubtitleModel> newSubtitles = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        newSubtitles.add(SubtitleModel(
          id: doc.id,
          speakerId: data['speakerId'],
          text: data['translatedText'] ?? data['originalText'],
          language: data['targetLanguage'],
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        ));
      }

      _subtitles.clear();
      _subtitles.addAll(newSubtitles);

      notifyListeners();
    }, onError: (error) {
      print('Error listening for subtitles: $error');
    });
  }

  // Disable WebRTC audio during speech recognition
  void _disableWebRTCAudio() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      _webRTCAudioEnabled = _localStream!.getAudioTracks().first.enabled;
      _localStream!.getAudioTracks().first.enabled = false;
      print('Disabled WebRTC audio for speech recognition');
    }
  }

  // Restore WebRTC audio after speech recognition
  void _restoreWebRTCAudio() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      _localStream!.getAudioTracks().first.enabled = _webRTCAudioEnabled;
      print('Restored WebRTC audio after speech recognition');
    }
  }

  // Start speech recognition
  Future<void> startSpeechRecognition() async {
    if (!_isMeetingActive || _meetingId == null) return;

    try {
      final localeId = _getLocaleForLanguage(_selectedSpeakingLanguage);

      _isListening = true;
      _currentTranscription = '';

      // Disable WebRTC audio to prevent feedback loops
      _disableWebRTCAudio();

      // Update local participant status
      _updateLocalParticipantSpeakingStatus(true);

      notifyListeners();

      await _speechToText.listen(
        localeId: localeId,
        onResult: (result) async {
          _currentTranscription = result.recognizedWords;

          if (result.finalResult && _currentTranscription.isNotEmpty) {
            // Translate and store the transcription
            await _translateAndStoreText(_currentTranscription);

            _isListening = false;
            _currentTranscription = '';

            // Restore WebRTC audio
            _restoreWebRTCAudio();

            // Update the local participant speaking status
            _updateLocalParticipantSpeakingStatus(false);
          }

          notifyListeners();
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onSoundLevelChange: (level) {
          // Could use this to show visual feedback for voice level
        },
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      _isListening = false;
      _currentTranscription = '';

      // Restore WebRTC audio in case of error
      _restoreWebRTCAudio();

      // Update local participant status
      _updateLocalParticipantSpeakingStatus(false);

      notifyListeners();
    }
  }

  // Stop speech recognition
  Future<void> stopSpeechRecognition() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;

      // Restore WebRTC audio
      _restoreWebRTCAudio();

      // If there's text, translate and store it
      if (_currentTranscription.isNotEmpty) {
        await _translateAndStoreText(_currentTranscription);
        _currentTranscription = '';
      }

      // Update the local participant speaking status
      _updateLocalParticipantSpeakingStatus(false);

      notifyListeners();
    }
  }

  // Toggle speech recognition
  Future<void> toggleSpeechRecognition() async {
    if (_isListening) {
      await stopSpeechRecognition();
    } else {
      await startSpeechRecognition();
    }
  }

  // Translate and store text
  Future<void> _translateAndStoreText(String text) async {
    if (_meetingId == null || _userId == null || text.isEmpty) return;

    try {
      // Create the original text document
      final docRef = await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('subtitles')
          .add({
        'speakerId': _userId,
        'speakerName': _displayName,
        'originalText': text,
        'sourceLanguage': _selectedSpeakingLanguage,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Translate to all required languages
      final batch = _firestore.batch();

      // Get unique target languages (excluding source language)
      final Set<String> targetLanguages = _participantLanguages.values.toSet();
      targetLanguages.add(_selectedListeningLanguage); // Ensure our own language is included
      targetLanguages.remove(_selectedSpeakingLanguage); // Remove source language

      for (var targetLanguage in targetLanguages) {
        // Skip if same as source language
        if (targetLanguage == _selectedSpeakingLanguage) continue;

        try {
          // Translate the text
          final translation = await _translator.translate(
            text,
            from: _getTranslatorCode(_selectedSpeakingLanguage),
            to: _getTranslatorCode(targetLanguage),
          );

          // Store the translation
          final translationDoc = _firestore
              .collection('meetings')
              .doc(_meetingId)
              .collection('subtitles')
              .doc();

          batch.set(translationDoc, {
            'speakerId': _userId,
            'speakerName': _displayName,
            'originalText': text,
            'translatedText': translation.text,
            'sourceLanguage': _selectedSpeakingLanguage,
            'targetLanguage': targetLanguage,
            'originalDocId': docRef.id,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Error translating to $targetLanguage: $e');
        }
      }

      // Update the original document with translated status
      batch.update(docRef, {
        'translatedLanguages': targetLanguages.toList(),
        'isTranslated': true,
      });

      await batch.commit();
    } catch (e) {
      print('Error translating and storing text: $e');
    }
  }

  // Send a chat message
  Future<void> sendMessage(String text) async {
    if (_meetingId == null || _userId == null || text.isEmpty) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('messages')
          .add({
        'senderId': _userId,
        'senderName': _displayName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  // Toggle hand raised status
  Future<void> toggleHandRaised() async {
    if (_meetingId == null || _userId == null) return;

    try {
      // Find current status in participants list
      final index = _participants.indexWhere((p) => p.id == _userId);
      final isCurrentlyRaised = index >= 0 ? _participants[index].isHandRaised : false;

      // Toggle status
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isHandRaised': !isCurrentlyRaised,
      });

      // Update local state immediately for better UX
      if (index >= 0) {
        _participants[index] = _participants[index].copyWith(
          isHandRaised: !isCurrentlyRaised,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error toggling hand raised: $e');
    }
  }

  // Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_meetingId == null || _userId == null || _localStream == null) return;

    try {
      // Toggle audio tracks
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !track.enabled;
      }

      // Get current status
      final isMuted = !audioTracks.first.enabled;

      // Update in Firestore
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isMuted': isMuted,
      });

      // Update local state immediately
      final index = _participants.indexWhere((p) => p.id == _userId);
      if (index >= 0) {
        _participants[index] = _participants[index].copyWith(
          isMuted: isMuted,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error toggling microphone: $e');
    }
  }

  // Toggle camera
  Future<void> toggleCamera() async {
    if (_meetingId == null || _userId == null || _localStream == null) return;

    try {
      // Toggle video tracks
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }

      // Get current status
      final isCameraOff = !videoTracks.first.enabled;

      // Update in Firestore
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isCameraOff': isCameraOff,
      });

      notifyListeners();
    } catch (e) {
      print('Error toggling camera: $e');
    }
  }

  // Toggle screen sharing
  Future<void> toggleScreenSharing() async {
    if (_meetingId == null || _userId == null) return;

    try {
      // Find current status in participants list
      final index = _participants.indexWhere((p) => p.id == _userId);
      final isCurrentlySharing = index >= 0 ? _participants[index].isScreenSharing : false;

      MediaStream? screenStream; // Khai báo biến ở ngoài khối try nội bộ

      if (!isCurrentlySharing) {
        // Start screen sharing
        try {
          screenStream = await navigator.mediaDevices.getDisplayMedia({
            'audio': false,
            'video': true,
          });

          // Replace the video track in all peer connections
          for (var pc in _peerConnections.values) {
            final senders = await pc.getSenders();
            // Sửa lỗi RTCRtpSender null
            final videoSenders = senders.where(
                    (sender) => sender.track?.kind == 'video'
            ).toList();

            if (videoSenders.isNotEmpty && screenStream != null) {
              await videoSenders.first.replaceTrack(screenStream.getVideoTracks()[0]);
            }
          }

          // Update UI
          if (screenStream != null) {
            _localRenderer!.srcObject = screenStream;

            // Store old stream to restore later
            final oldStream = _localStream;
            _localStream = screenStream;

            // Listen for track ended event
            screenStream.getVideoTracks().first.onEnded = () {
              // Auto-switch back to camera when screen sharing ends
              _restoreCamera(oldStream);
            };
          }
        } catch (e) {
          print('Error starting screen sharing: $e');
          return;
        }
      } else {
        // Stop screen sharing and revert to camera
        await _setupLocalStream();

        // Replace the video track in all peer connections
        for (var pc in _peerConnections.values) {
          final senders = await pc.getSenders();
          // Sửa lỗi RTCRtpSender null
          final videoSenders = senders.where(
                  (sender) => sender.track?.kind == 'video'
          ).toList();

          if (videoSenders.isNotEmpty && _localStream != null) {
            await videoSenders.first.replaceTrack(_localStream!.getVideoTracks()[0]);
          }
        }
      }

      // Update in Firestore
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isScreenSharing': !isCurrentlySharing,
      });

      // Update local state immediately
      if (index >= 0) {
        _participants[index] = _participants[index].copyWith(
          isScreenSharing: !isCurrentlySharing,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error toggling screen sharing: $e');
    }
  }

  // Restore camera after screen sharing ends
  // Restore camera after screen sharing ends
  Future<void> _restoreCamera(MediaStream? oldStream) async {
    try {
      if (oldStream != null && oldStream.getVideoTracks().isNotEmpty) {
        // Use old stream if available
        _localStream = oldStream;
      } else {
        // Otherwise get new stream
        await _setupLocalStream();
      }

      // Replace the video track in all peer connections
      for (var pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        // Sửa lỗi RTCRtpSender null
        final videoSenders = senders.where(
                (sender) => sender.track?.kind == 'video'
        ).toList();

        if (videoSenders.isNotEmpty && _localStream != null) {
          await videoSenders.first.replaceTrack(_localStream!.getVideoTracks()[0]);
        }
      }

      // Update UI
      _localRenderer!.srcObject = _localStream;

      // Update in Firestore
      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isScreenSharing': false,
      });

      // Update local state
      final index = _participants.indexWhere((p) => p.id == _userId);
      if (index >= 0) {
        _participants[index] = _participants[index].copyWith(
          isScreenSharing: false,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error restoring camera: $e');
    }
  }

  // Get RTCVideoRenderer for a participant
  RTCVideoRenderer? getRendererForParticipant(String participantId) {
    if (participantId == _userId) {
      return _localRenderer;
    } else {
      return _remoteRenderers[participantId];
    }
  }

  // Helper method to update local participant speaking status
  void _updateLocalParticipantSpeakingStatus(bool isSpeaking) {
    try {
      if (_meetingId == null || _userId == null) return;

      // Update in the participants list for immediate UI feedback
      final index = _participants.indexWhere((p) => p.id == _userId);
      if (index >= 0) {
        _participants[index] = _participants[index].copyWith(
          isSpeaking: isSpeaking,
          isMuted: !isSpeaking,
        );
      }

      // Update in Firestore
      _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('participants')
          .doc(_userId)
          .update({
        'isSpeaking': isSpeaking,
        'isMuted': !isSpeaking,
      });
    } catch (e) {
      print('Error updating speaking status: $e');
    }
  }

  // Helper method to get locale string for a language
  String _getLocaleForLanguage(String language) {
    final Map<String, String> localeMap = {
      'english': 'en-US',
      'spanish': 'es-ES',
      'french': 'fr-FR',
      'german': 'de-DE',
      'chinese': 'zh-CN',
      'japanese': 'ja-JP',
      'korean': 'ko-KR',
      'arabic': 'ar-SA',
      'russian': 'ru-RU',
      'vietnamese': 'vi-VN',
    };

    return localeMap[language.toLowerCase()] ?? 'en-US';
  }

  // Helper method to get translator language code
  String _getTranslatorCode(String language) {
    final Map<String, String> codeMap = {
      'english': 'en',
      'spanish': 'es',
      'french': 'fr',
      'german': 'de',
      'chinese': 'zh-CN',
      'japanese': 'ja',
      'korean': 'ko',
      'arabic': 'ar',
      'russian': 'ru',
      'vietnamese': 'vi',
    };

    return codeMap[language.toLowerCase()] ?? 'en';
  }

  // Start meeting timer
  void _startMeetingTimer() {
    _meetingTimer?.cancel();
    _elapsedTime = const Duration();

    _meetingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    // Cleanup resources
    _meetingTimer?.cancel();

    for (var pc in _peerConnections.values) {
      pc.close();
    }

    for (var stream in _remoteStreams.values) {
      stream.getTracks().forEach((track) => track.stop());
    }

    for (var renderer in _remoteRenderers.values) {
      renderer.dispose();
    }

    _localStream?.getTracks().forEach((track) => track.stop());
    _localRenderer?.dispose();

    super.dispose();
  }
}

// Models
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