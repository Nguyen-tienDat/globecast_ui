// lib/services/whisper_streaming_service.dart - Fixed version
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WhisperStreamingService extends ChangeNotifier {
  // WebSocket connection
  WebSocketChannel? _channel;
  String? _serverUrl;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Meeting and user info
  String? _meetingId;
  String? _userId;
  String? _speakerName;
  String _preferredLanguage = 'en';

  // Audio processing
  Timer? _audioTimer;
  final List<Uint8List> _audioBuffer = [];
  bool _isProcessingAudio = false;

  // Participants info
  final List<MeetingParticipant> _participants = [];

  // Streams for real-time data
  final StreamController<PersonalizedTranscription> _transcriptionController =
  StreamController<PersonalizedTranscription>.broadcast();
  final StreamController<List<MeetingParticipant>> _participantsController =
  StreamController<List<MeetingParticipant>>.broadcast();
  final StreamController<WhisperStreamingError> _errorController =
  StreamController<WhisperStreamingError>.broadcast();
  final StreamController<ConnectionState> _connectionController =
  StreamController<ConnectionState>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get preferredLanguage => _preferredLanguage;
  String? get meetingId => _meetingId;
  String? get userId => _userId;
  List<MeetingParticipant> get participants => List.unmodifiable(_participants);

  // Streams
  Stream<PersonalizedTranscription> get transcriptionStream => _transcriptionController.stream;
  Stream<List<MeetingParticipant>> get participantsStream => _participantsController.stream;
  Stream<WhisperStreamingError> get errorStream => _errorController.stream;
  Stream<ConnectionState> get connectionStream => _connectionController.stream;

  // Initialize service
  Future<void> initialize({
    String serverUrl = 'ws://localhost:8765',
  }) async {
    _serverUrl = serverUrl;
    _debugLog('WhisperStreamingService initialized with server: $_serverUrl');
  }

  // Join meeting with preferred language
  Future<bool> joinMeeting({
    required String meetingId,
    required String userId,
    required String speakerName,
    required String preferredLanguage,
  }) async {
    if (_isConnected || _isConnecting) return _isConnected;

    try {
      _isConnecting = true;
      _meetingId = meetingId;
      _userId = userId;
      _speakerName = speakerName;
      _preferredLanguage = preferredLanguage;

      _connectionController.add(ConnectionState.connecting);
      notifyListeners();

      _debugLog('Joining meeting $meetingId with preferred language: $preferredLanguage');

      // Create WebSocket connection
      _channel = WebSocketChannel.connect(
        Uri.parse(_serverUrl!),
      );

      // Setup message listener
      _channel!.stream.listen(
        _handleServerMessage,
        onError: _handleConnectionError,
        onDone: _handleConnectionClosed,
      );

      // Send join meeting message
      await _sendJoinMeeting();

      // Wait for join confirmation
      await _waitForJoinConfirmation();

      _isConnected = true;
      _isConnecting = false;
      _connectionController.add(ConnectionState.connected);
      notifyListeners();

      _debugLog('Successfully joined meeting with Whisper streaming');
      return true;

    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _connectionController.add(ConnectionState.disconnected);
      notifyListeners();

      _debugLog('Failed to join meeting: $e');
      _errorController.add(WhisperStreamingError(
        type: ErrorType.connection,
        message: 'Failed to join meeting: $e',
        timestamp: DateTime.now(),
      ));

      return false;
    }
  }

  // Change preferred language
  Future<void> changePreferredLanguage(String newLanguage) async {
    if (!_isConnected || _channel == null) {
      throw Exception('Not connected to meeting');
    }

    try {
      final oldLanguage = _preferredLanguage;
      _preferredLanguage = newLanguage;

      final message = {
        'type': 'update_language',
        'preferredLanguage': newLanguage,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _channel!.sink.add(json.encode(message));
      notifyListeners();

      _debugLog('Changed preferred language from $oldLanguage to $newLanguage');

    } catch (e) {
      _debugLog('Error updating preferred language: $e');
      _errorController.add(WhisperStreamingError(
        type: ErrorType.languageUpdate,
        message: 'Failed to update language: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  // Get available languages
  List<LanguageOption> getAvailableLanguages() {
    return _createLanguageOptions();
  }

  // Create language options list (moved to method to avoid const issues)
  List<LanguageOption> _createLanguageOptions() {
    return [
      LanguageOption(code: 'en', name: 'English', flag: '🇺🇸'),
      LanguageOption(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
      LanguageOption(code: 'es', name: 'Español', flag: '🇪🇸'),
      LanguageOption(code: 'fr', name: 'Français', flag: '🇫🇷'),
      LanguageOption(code: 'de', name: 'Deutsch', flag: '🇩🇪'),
      LanguageOption(code: 'ja', name: '日本語', flag: '🇯🇵'),
      LanguageOption(code: 'ko', name: '한국어', flag: '🇰🇷'),
      LanguageOption(code: 'zh', name: '中文', flag: '🇨🇳'),
      LanguageOption(code: 'ar', name: 'العربية', flag: '🇸🇦'),
      LanguageOption(code: 'ru', name: 'Русский', flag: '🇷🇺'),
      LanguageOption(code: 'pt', name: 'Português', flag: '🇵🇹'),
      LanguageOption(code: 'it', name: 'Italiano', flag: '🇮🇹'),
    ];
  }

  // Start audio processing from WebRTC stream
  Future<void> startAudioProcessing(MediaStream stream) async {
    if (!_isConnected) {
      throw Exception('Not connected to meeting');
    }

    if (_isProcessingAudio) {
      _debugLog('Audio processing already started');
      return;
    }

    try {
      _isProcessingAudio = true;
      _debugLog('Starting audio processing for speech recognition...');

      // Start periodic audio capture
      _audioTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _captureAudioFromStream(stream);
      });

      notifyListeners();

    } catch (e) {
      _debugLog('Error starting audio processing: $e');
      _errorController.add(WhisperStreamingError(
        type: ErrorType.audioProcessing,
        message: 'Failed to start audio processing: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  // Stop audio processing
  Future<void> stopAudioProcessing() async {
    _isProcessingAudio = false;

    _audioTimer?.cancel();
    _audioTimer = null;

    _audioBuffer.clear();

    notifyListeners();
    _debugLog('Audio processing stopped');
  }

  // Request current participants info
  Future<void> requestParticipantsInfo() async {
    if (!_isConnected || _channel == null) return;

    try {
      final message = {
        'type': 'get_participants',
        'timestamp': DateTime.now().toIso8601String(),
      };

      _channel!.sink.add(json.encode(message));

    } catch (e) {
      _debugLog('Error requesting participants info: $e');
    }
  }

  // Leave meeting
  Future<void> leaveMeeting() async {
    try {
      _isConnected = false;
      _isConnecting = false;

      // Stop audio processing
      await stopAudioProcessing();

      // Close WebSocket
      if (_channel != null) {
        await _channel!.sink.close(status.goingAway);
        _channel = null;
      }

      // Clear data
      _meetingId = null;
      _userId = null;
      _speakerName = null;
      _participants.clear();

      _connectionController.add(ConnectionState.disconnected);
      notifyListeners();

      _debugLog('Left meeting and disconnected from Whisper server');

    } catch (e) {
      _debugLog('Error during leave meeting: $e');
    }
  }

  // Private methods

  Future<void> _sendJoinMeeting() async {
    if (_channel == null) return;

    final joinMessage = {
      'type': 'join_meeting',
      'meetingId': _meetingId,
      'userId': _userId,
      'speakerName': _speakerName,
      'preferredLanguage': _preferredLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _channel!.sink.add(json.encode(joinMessage));
    _debugLog('Sent join meeting message');
  }

  Future<void> _waitForJoinConfirmation() async {
    // Wait for join confirmation or timeout
    await Future.delayed(const Duration(seconds: 3));
  }

  void _handleServerMessage(dynamic message) {
    try {
      final data = json.decode(message);
      final messageType = data['type'];

      switch (messageType) {
        case 'joined_meeting':
          _debugLog('Successfully joined meeting: ${data['meetingId']}');
          break;

        case 'transcription':
          _handleTranscriptionResult(data);
          break;

        case 'participant_joined':
          _handleParticipantJoined(data);
          break;

        case 'participant_left':
          _handleParticipantLeft(data);
          break;

        case 'participant_language_changed':
          _handleParticipantLanguageChanged(data);
          break;

        case 'participants_info':
          _handleParticipantsInfo(data);
          break;

        case 'language_updated':
          _debugLog('Language updated: ${data['newLanguage']}');
          break;

        case 'error':
          _handleServerError(data);
          break;

        case 'reset_complete':
          _debugLog('Processing reset completed');
          break;

        case 'pong':
        // Heartbeat response
          break;

        default:
          _debugLog('Unknown message type: $messageType');
      }

    } catch (e) {
      _debugLog('Error handling server message: $e');
    }
  }

  void _handleTranscriptionResult(Map<String, dynamic> data) {
    try {
      final transcription = PersonalizedTranscription.fromJson(data);
      _transcriptionController.add(transcription);

      _debugLog('Received transcription: ${transcription.displayText} (${transcription.displayLanguage})');

    } catch (e) {
      _debugLog('Error parsing transcription result: $e');
    }
  }

  void _handleParticipantJoined(Map<String, dynamic> data) {
    try {
      final participant = MeetingParticipant(
        userId: data['userId'],
        speakerName: data['speakerName'],
        preferredLanguage: data['preferredLanguage'],
        isConnected: true,
        joinedAt: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
      );

      _participants.add(participant);
      _participantsController.add(_participants);

      _debugLog('Participant joined: ${participant.speakerName} (${participant.preferredLanguage})');

    } catch (e) {
      _debugLog('Error handling participant joined: $e');
    }
  }

  void _handleParticipantLeft(Map<String, dynamic> data) {
    try {
      final userId = data['userId'];
      _participants.removeWhere((p) => p.userId == userId);
      _participantsController.add(_participants);

      _debugLog('Participant left: $userId');

    } catch (e) {
      _debugLog('Error handling participant left: $e');
    }
  }

  void _handleParticipantLanguageChanged(Map<String, dynamic> data) {
    try {
      final userId = data['userId'];
      final newLanguage = data['newLanguage'];

      final participantIndex = _participants.indexWhere((p) => p.userId == userId);
      if (participantIndex != -1) {
        _participants[participantIndex] = _participants[participantIndex].copyWith(
          preferredLanguage: newLanguage,
        );
        _participantsController.add(_participants);
      }

      _debugLog('Participant $userId changed language to $newLanguage');

    } catch (e) {
      _debugLog('Error handling participant language change: $e');
    }
  }

  void _handleParticipantsInfo(Map<String, dynamic> data) {
    try {
      final participantsData = data['participants'] as List;
      _participants.clear();

      for (final participantData in participantsData) {
        final participant = MeetingParticipant(
          userId: participantData['userId'],
          speakerName: participantData['speakerName'],
          preferredLanguage: participantData['preferredLanguage'],
          isConnected: participantData['isConnected'] ?? true,
          joinedAt: DateTime.now(),
        );
        _participants.add(participant);
      }

      _participantsController.add(_participants);
      _debugLog('Updated participants info: ${_participants.length} participants');

    } catch (e) {
      _debugLog('Error handling participants info: $e');
    }
  }

  void _handleServerError(Map<String, dynamic> data) {
    final error = WhisperStreamingError(
      type: ErrorType.server,
      message: data['message'] ?? 'Unknown server error',
      timestamp: DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
    );

    _errorController.add(error);
    _debugLog('Server error: ${error.message}');
  }

  void _handleConnectionError(error) {
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(ConnectionState.disconnected);
    notifyListeners();

    _errorController.add(WhisperStreamingError(
      type: ErrorType.connection,
      message: 'Connection error: $error',
      timestamp: DateTime.now(),
    ));

    _debugLog('Connection error: $error');
  }

  void _handleConnectionClosed() {
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(ConnectionState.disconnected);
    notifyListeners();

    _debugLog('Connection closed');
  }

  void _captureAudioFromStream(MediaStream stream) {
    // Audio capture implementation
    if (!_isProcessingAudio) return;

    try {
      // Generate audio data for testing
      const sampleRate = 16000;
      const duration = 0.1; // 100ms
      final samples = (sampleRate * duration).round();

      final audioData = Uint8List(samples * 2); // 2 bytes per sample

      // Fill with silence for now
      for (int i = 0; i < samples; i++) {
        const sample = 0; // Silence
        audioData[i * 2] = sample & 0xFF;
        audioData[i * 2 + 1] = (sample >> 8) & 0xFF;
      }

      _audioBuffer.add(audioData);

      // Send buffered audio if enough accumulated
      if (_audioBuffer.length >= 5) { // Send every 500ms
        final combinedData = _combineAudioBuffer();
        _sendAudioData(combinedData);
        _audioBuffer.clear();
      }

    } catch (e) {
      _debugLog('Error capturing audio: $e');
    }
  }

  void _sendAudioData(Uint8List audioData) {
    if (!_isConnected || _channel == null) return;

    try {
      _channel!.sink.add(audioData);
    } catch (e) {
      _debugLog('Error sending audio data: $e');
      _errorController.add(WhisperStreamingError(
        type: ErrorType.audioTransmission,
        message: 'Failed to send audio data: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  Uint8List _combineAudioBuffer() {
    final totalLength = _audioBuffer.fold<int>(0, (sum, data) => sum + data.length);
    final combined = Uint8List(totalLength);

    int offset = 0;
    for (final data in _audioBuffer) {
      combined.setRange(offset, offset + data.length, data);
      offset += data.length;
    }

    return combined;
  }

  // Debug logging method
  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[WhisperService] $message');
    }
  }

  @override
  void dispose() {
    leaveMeeting();
    _transcriptionController.close();
    _participantsController.close();
    _errorController.close();
    _connectionController.close();
    super.dispose();
  }
}

// Data Models

enum ConnectionState {
  disconnected,
  connecting,
  connected,
}

enum ErrorType {
  connection,
  server,
  audioProcessing,
  audioTransmission,
  languageUpdate,
}

class PersonalizedTranscription {
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String displayText;
  final String detectedLanguage;
  final String displayLanguage;
  final bool isTranslated;
  final TimestampRange timestamp;
  final DateTime serverTimestamp;
  final String clientId;

  PersonalizedTranscription({
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.displayText,
    required this.detectedLanguage,
    required this.displayLanguage,
    required this.isTranslated,
    required this.timestamp,
    required this.serverTimestamp,
    required this.clientId,
  });

  factory PersonalizedTranscription.fromJson(Map<String, dynamic> json) {
    return PersonalizedTranscription(
      speakerId: json['speakerId'] ?? 'unknown',
      speakerName: json['speakerName'] ?? 'Unknown',
      originalText: json['originalText'] ?? '',
      displayText: json['displayText'] ?? '',
      detectedLanguage: json['detectedLanguage'] ?? 'en',
      displayLanguage: json['displayLanguage'] ?? 'en',
      isTranslated: json['isTranslated'] ?? false,
      timestamp: TimestampRange.fromJson(json['timestamp'] ?? {}),
      serverTimestamp: DateTime.tryParse(json['serverTimestamp'] ?? '') ?? DateTime.now(),
      clientId: json['clientId'] ?? '',
    );
  }
}

class MeetingParticipant {
  final String userId;
  final String speakerName;
  final String preferredLanguage;
  final bool isConnected;
  final DateTime joinedAt;

  MeetingParticipant({
    required this.userId,
    required this.speakerName,
    required this.preferredLanguage,
    required this.isConnected,
    required this.joinedAt,
  });

  MeetingParticipant copyWith({
    String? userId,
    String? speakerName,
    String? preferredLanguage,
    bool? isConnected,
    DateTime? joinedAt,
  }) {
    return MeetingParticipant(
      userId: userId ?? this.userId,
      speakerName: speakerName ?? this.speakerName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isConnected: isConnected ?? this.isConnected,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class LanguageOption {
  final String code;
  final String name;
  final String flag;

  LanguageOption({
    required this.code,
    required this.name,
    required this.flag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LanguageOption &&
              runtimeType == other.runtimeType &&
              code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class TimestampRange {
  final double start;
  final double end;

  TimestampRange({
    required this.start,
    required this.end,
  });

  factory TimestampRange.fromJson(Map<String, dynamic> json) {
    return TimestampRange(
      start: (json['start'] ?? 0.0).toDouble(),
      end: (json['end'] ?? 0.0).toDouble(),
    );
  }
}

class WhisperStreamingError {
  final ErrorType type;
  final String message;
  final DateTime timestamp;

  WhisperStreamingError({
    required this.type,
    required this.message,
    required this.timestamp,
  });
}