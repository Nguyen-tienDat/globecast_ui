// lib/services/whisper_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Transcription result with enhanced metadata
class TranscriptionResult {
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final double originalLanguageConfidence;
  final String translatedText;
  final String targetLanguage;
  final double transcriptionConfidence;
  final double translationConfidence;
  final bool isFinal;
  final DateTime timestamp;
  final double audioDuration;
  final double processingTime;
  final bool isVoice;
  final double audioQuality;

  TranscriptionResult({
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.originalLanguageConfidence,
    required this.translatedText,
    required this.targetLanguage,
    required this.transcriptionConfidence,
    required this.translationConfidence,
    required this.isFinal,
    required this.timestamp,
    required this.audioDuration,
    required this.processingTime,
    required this.isVoice,
    required this.audioQuality,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      speakerId: json['speaker_id'] ?? '',
      speakerName: json['speaker_name'] ?? '',
      originalText: json['original_text'] ?? '',
      originalLanguage: json['original_language'] ?? 'en',
      originalLanguageConfidence: (json['original_language_confidence'] ?? 0.0).toDouble(),
      translatedText: json['translated_text'] ?? '',
      targetLanguage: json['target_language'] ?? 'en',
      transcriptionConfidence: (json['transcription_confidence'] ?? 0.0).toDouble(),
      translationConfidence: (json['translation_confidence'] ?? 0.0).toDouble(),
      isFinal: json['is_final'] ?? true,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((json['timestamp'] ?? 0.0) * 1000).round(),
      ),
      audioDuration: (json['audio_duration'] ?? 0.0).toDouble(),
      processingTime: (json['processing_time'] ?? 0.0).toDouble(),
      isVoice: json['is_voice'] ?? true,
      audioQuality: (json['audio_quality'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker_id': speakerId,
      'speaker_name': speakerName,
      'original_text': originalText,
      'original_language': originalLanguage,
      'original_language_confidence': originalLanguageConfidence,
      'translated_text': translatedText,
      'target_language': targetLanguage,
      'transcription_confidence': transcriptionConfidence,
      'translation_confidence': translationConfidence,
      'is_final': isFinal,
      'timestamp': timestamp.millisecondsSinceEpoch / 1000.0,
      'audio_duration': audioDuration,
      'processing_time': processingTime,
      'is_voice': isVoice,
      'audio_quality': audioQuality,
    };
  }

  @override
  String toString() {
    return 'TranscriptionResult(speaker: $speakerName, text: "$translatedText")';
  }
}

/// Connection state for the Whisper service
enum WhisperConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Whisper Service for real-time speech-to-text with translation
class WhisperService extends ChangeNotifier {
  // Connection management
  WebSocketChannel? _channel;
  WhisperConnectionState _connectionState = WhisperConnectionState.disconnected;
  String? _serverUrl;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _statsTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastConnectTime;

  // Configuration
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);

  // User session
  String? _userId;
  String? _displayName;
  String _nativeLanguage = 'auto';
  String _displayLanguage = 'en';

  // Audio buffer management
  final Map<String, List<Uint8List>> _audioBuffers = {};
  final Map<String, Timer> _bufferTimers = {};
  static const Duration bufferTimeout = Duration(milliseconds: 1500);

  // Statistics and monitoring
  final Map<String, dynamic> _stats = {
    'connectTime': null,
    'lastActivity': null,
    'audioChunksSent': 0,
    'transcriptionsReceived': 0,
    'translationsReceived': 0,
    'averageProcessingTime': 0.0,
    'totalAudioDuration': 0.0,
    'errors': 0,
    'reconnects': 0,
  };

  // Stream controllers for reactive programming
  final StreamController<TranscriptionResult> _transcriptionController =
  StreamController<TranscriptionResult>.broadcast();
  final StreamController<WhisperConnectionState> _stateController =
  StreamController<WhisperConnectionState>.broadcast();
  final StreamController<String> _errorController =
  StreamController<String>.broadcast();

  // Callbacks (for backward compatibility)
  Function(TranscriptionResult)? onTranscriptionReceived;
  Function(String error)? onError;
  Function(WhisperConnectionState state)? onConnectionChanged;

  // Getters
  WhisperConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == WhisperConnectionState.connected;
  bool get isConnecting => _connectionState == WhisperConnectionState.connecting;
  String get nativeLanguage => _nativeLanguage;
  String get displayLanguage => _displayLanguage;
  String? get userId => _userId;
  String? get displayName => _displayName;
  Map<String, dynamic> get statistics => Map.unmodifiable(_stats);

  // Streams for reactive programming
  Stream<TranscriptionResult> get transcriptionStream => _transcriptionController.stream;
  Stream<WhisperConnectionState> get connectionStateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Supported languages mapping
  static const Map<String, String> supportedLanguages = {
    'auto': 'Auto-detect',
    'en': 'English',
    'vi': 'Vietnamese',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'ar': 'Arabic',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'it': 'Italian',
    'th': 'Thai',
    'hi': 'Hindi',
    'nl': 'Dutch',
    'pl': 'Polish',
    'tr': 'Turkish',
    'sv': 'Swedish',
  };

  WhisperService() {
    print('🌍 Whisper Service initialized');
    _startStatsTimer();
  }

  /// Get the appropriate server URL based on platform
  String _getServerUrl([String? customUrl]) {
    if (customUrl != null) return customUrl;

    // For Android emulator, use 10.0.2.2 to access host machine
    // For iOS simulator, use localhost
    // For real devices, use your computer's IP address
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Check if running on emulator
      return 'ws://10.0.2.2:8766';  // Android emulator special IP
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ws://localhost:8766';  // iOS simulator
    } else {
      // For real devices, you'll need to replace with your computer's actual IP
      // Example: return 'ws://192.168.1.100:8766';
      return 'ws://10.0.2.2:8766';  // Default to Android emulator IP
    }
  }

  /// Connect to Whisper server
  Future<bool> connect({
    required String userId,
    required String displayName,
    String nativeLanguage = 'auto',
    String displayLanguage = 'en',
    String? serverUrl,
  }) async {
    try {
      print('🔗 Connecting to Whisper server...');
      print('   User: $displayName ($userId)');
      print('   Languages: $nativeLanguage → $displayLanguage');

      _serverUrl = _getServerUrl(serverUrl);
      _userId = userId;
      _displayName = displayName;
      _nativeLanguage = nativeLanguage;
      _displayLanguage = displayLanguage;

      print('🌐 Target server URL: $_serverUrl');

      await _establishConnection();

      return isConnected;
    } catch (e) {
      print('❌ Connection failed: $e');
      _handleError('Connection failed: $e');
      return false;
    }
  }

  /// Establish WebSocket connection
  Future<void> _establishConnection() async {
    if (_connectionState == WhisperConnectionState.connecting) {
      return; // Already connecting
    }

    _setConnectionState(WhisperConnectionState.connecting);

    try {
      // Close existing connection
      await _closeConnection();

      // Create new WebSocket connection with timeout
      final uri = Uri.parse(_serverUrl!);
      print('🌐 Connecting to: $uri');

      _channel = WebSocketChannel.connect(uri);

      // Setup connection timeout
      final connectionCompleter = Completer<void>();
      Timer timeoutTimer = Timer(connectionTimeout, () {
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.completeError('Connection timeout');
        }
      });

      // Listen for messages
      late StreamSubscription subscription;
      subscription = _channel!.stream.listen(
            (message) {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete();
            timeoutTimer.cancel();
          }
          _handleMessage(message);
        },
        onError: (error) {
          timeoutTimer.cancel();
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(error);
          }
          _handleConnectionError(error);
        },
        onDone: () {
          timeoutTimer.cancel();
          subscription.cancel();
          _handleConnectionClosed();
        },
      );

      // Send connection message
      await _sendMessage({
        'type': 'connect',
        'userId': _userId,
        'displayName': _displayName,
        'nativeLanguage': _nativeLanguage,
        'displayLanguage': _displayLanguage,
      });

      // Wait for connection to be established or timeout
      await connectionCompleter.future;

    } catch (e) {
      print('❌ Connection establishment error: $e');
      _handleError('Failed to establish connection: $e');
      _setConnectionState(WhisperConnectionState.error);
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message) as Map<String, dynamic>;
      final messageType = data['type'] as String?;

      _stats['lastActivity'] = DateTime.now();

      switch (messageType) {
        case 'connection_established':
          _handleConnectionEstablished(data);
          break;

        case 'transcription_result':
          _handleTranscriptionResult(data);
          break;

        case 'language_updated':
          _handleLanguageUpdated(data);
          break;

        case 'error':
          _handleServerError(data);
          break;

        case 'pong':
        // Connection is alive
          break;

        case 'stats_response':
          _handleStatsResponse(data);
          break;

        default:
          print('⚠️ Unknown message type: $messageType');
      }
    } catch (e) {
      print('❌ Message handling error: $e');
      _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    }
  }

  /// Handle successful connection establishment
  void _handleConnectionEstablished(Map<String, dynamic> data) {
    print('✅ Connected to Whisper server');

    final serverInfo = data['serverInfo'] as Map<String, dynamic>?;
    if (serverInfo != null) {
      print('📦 Server Model: ${serverInfo['model']}');
      print('🔧 Features: ${serverInfo['features']}');
    }

    _setConnectionState(WhisperConnectionState.connected);
    _reconnectAttempts = 0;
    _lastConnectTime = DateTime.now();
    _stats['connectTime'] = _lastConnectTime;

    // Start ping timer
    _startPingTimer();

    notifyListeners();
  }

  /// Handle transcription results
  void _handleTranscriptionResult(Map<String, dynamic> data) {
    try {
      final resultData = data['data'] as Map<String, dynamic>;
      final result = TranscriptionResult.fromJson(resultData);

      // Update statistics
      _stats['transcriptionsReceived'] = (_stats['transcriptionsReceived'] ?? 0) + 1;
      _stats['totalAudioDuration'] = (_stats['totalAudioDuration'] ?? 0.0) + result.audioDuration;

      if (result.translatedText != result.originalText) {
        _stats['translationsReceived'] = (_stats['translationsReceived'] ?? 0) + 1;
      }

      // Update average processing time
      final currentAvg = _stats['averageProcessingTime'] ?? 0.0;
      _stats['averageProcessingTime'] = (currentAvg * 0.9) + (result.processingTime * 0.1);

      // Emit result
      _transcriptionController.add(result);
      onTranscriptionReceived?.call(result);

      print('📝 Transcription: ${result.speakerName}: "${result.translatedText}"');

    } catch (e) {
      print('❌ Transcription result handling error: $e');
      _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    }
  }

  /// Handle language update confirmation
  void _handleLanguageUpdated(Map<String, dynamic> data) {
    _nativeLanguage = data['nativeLanguage'] ?? _nativeLanguage;
    _displayLanguage = data['displayLanguage'] ?? _displayLanguage;

    print('🌍 Language updated: $_nativeLanguage → $_displayLanguage');
    notifyListeners();
  }

  /// Handle server errors
  void _handleServerError(Map<String, dynamic> data) {
    final errorMessage = data['message'] ?? 'Unknown server error';
    print('❌ Server error: $errorMessage');

    _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    _handleError(errorMessage);
  }

  /// Handle stats response
  void _handleStatsResponse(Map<String, dynamic> data) {
    final serverStats = data['data'] as Map<String, dynamic>?;
    if (serverStats != null) {
      print('📊 Server Stats: $serverStats');
    }
  }

  /// Send audio data to server with buffering
  Future<void> sendAudioData(
      Uint8List audioData,
      String speakerId,
      String speakerName,
      ) async {
    if (!isConnected) {
      print('⚠️ Cannot send audio: not connected to server');
      return;
    }

    try {
      // Add to buffer
      _audioBuffers.putIfAbsent(speakerId, () => []);
      _audioBuffers[speakerId]!.add(audioData);

      // Reset buffer timer
      _bufferTimers[speakerId]?.cancel();
      _bufferTimers[speakerId] = Timer(bufferTimeout, () {
        _flushAudioBuffer(speakerId, speakerName);
      });

      // Flush if buffer is large enough
      final buffer = _audioBuffers[speakerId]!;
      final totalSize = buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);

      if (totalSize >= 16000 * 2) { // ~1 second of 16kHz 16-bit audio
        _flushAudioBuffer(speakerId, speakerName);
      }

    } catch (e) {
      print('❌ Audio buffer error: $e');
      _stats['errors'] = (_stats['errors'] ?? 0) + 1;
      _handleError('Failed to buffer audio data: $e');
    }
  }

  /// Flush audio buffer for a speaker
  void _flushAudioBuffer(String speakerId, String speakerName) {
    final buffer = _audioBuffers[speakerId];
    if (buffer == null || buffer.isEmpty) return;

    try {
      // Combine all chunks
      final totalLength = buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedAudio = Uint8List(totalLength);

      int offset = 0;
      for (final chunk in buffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Clear buffer
      buffer.clear();
      _bufferTimers[speakerId]?.cancel();

      // Send combined audio
      _sendAudioChunk(combinedAudio, speakerId, speakerName);

    } catch (e) {
      print('❌ Buffer flush error: $e');
      _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    }
  }

  /// Send audio chunk to server
  Future<void> _sendAudioChunk(
      Uint8List audioData,
      String speakerId,
      String speakerName,
      ) async {
    try {
      print('🎵 [WHISPER DEBUG] Sending audio chunk:');
      print('   Speaker: $speakerName ($speakerId)');
      print('   Data size: ${audioData.length} bytes');
      print('   Connection state: $connectionState');

      // Verify audio data is not empty/invalid
      if (audioData.isEmpty) {
        print('   ❌ Audio data is empty, skipping');
        return;
      }

      // Check for silence (all zeros)
      var nonZeroBytes = 0;
      for (int i = 0; i < audioData.length && i < 100; i++) {
        if (audioData[i] != 0) nonZeroBytes++;
      }

      print('   Non-zero bytes in first 100: $nonZeroBytes');

      if (nonZeroBytes < 5) {
        print('   ⚠️ Mostly silent audio, but sending anyway');
      }

      final base64Audio = base64Encode(audioData);
      print('   Base64 length: ${base64Audio.length}');

      await _sendMessage({
        'type': 'audio_data',
        'audioData': base64Audio,
        'speakerId': speakerId,
        'speakerName': speakerName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sampleRate': 16000,
        'channels': 1,
        'bitsPerSample': 16,
      });

      _stats['audioChunksSent'] = (_stats['audioChunksSent'] ?? 0) + 1;
      _stats['lastActivity'] = DateTime.now();

      print('   ✅ Audio chunk sent successfully (#${_stats['audioChunksSent']})');

    } catch (e) {
      print('❌ Audio send error: $e');
      _stats['errors'] = (_stats['errors'] ?? 0) + 1;
      _handleError('Failed to send audio data: $e');
    }
  }

  /// Update user language preferences
  Future<void> setUserLanguages({
    required String nativeLanguage,
    required String displayLanguage,
  }) async {
    if (!supportedLanguages.containsKey(nativeLanguage) ||
        !supportedLanguages.containsKey(displayLanguage)) {
      throw ArgumentError('Unsupported language');
    }

    try {
      await _sendMessage({
        'type': 'language_update',
        'nativeLanguage': nativeLanguage,
        'displayLanguage': displayLanguage,
      });

      print('🌍 Language update sent: $nativeLanguage → $displayLanguage');

    } catch (e) {
      print('❌ Language update error: $e');
      _handleError('Failed to update languages: $e');
    }
  }

  /// Request server statistics
  Future<void> requestStats() async {
    if (!isConnected) return;

    try {
      await _sendMessage({'type': 'get_stats'});
    } catch (e) {
      print('❌ Stats request error: $e');
    }
  }

  /// Send message to server
  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_channel == null) {
      throw StateError('WebSocket not connected');
    }

    final messageJson = json.encode(message);
    _channel!.sink.add(messageJson);
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (timer) {
      if (isConnected) {
        _sendMessage({'type': 'ping'}).catchError((e) {
          print('❌ Ping error: $e');
        });
      }
    });
  }

  /// Start statistics timer
  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (isConnected) {
        requestStats();
      }
      _printStats();
    });
  }

  /// Print statistics
  void _printStats() {
    final connectTime = _stats['connectTime'] as DateTime?;
    final uptime = connectTime != null
        ? DateTime.now().difference(connectTime).inMinutes
        : 0;

    print('📊 Whisper Stats:');
    print('   Uptime: ${uptime}m');
    print('   Audio chunks: ${_stats['audioChunksSent']}');
    print('   Transcriptions: ${_stats['transcriptionsReceived']}');
    print('   Translations: ${_stats['translationsReceived']}');
    print('   Errors: ${_stats['errors']}');
    print('   Avg processing: ${(_stats['averageProcessingTime'] ?? 0.0).toStringAsFixed(3)}s');
  }

  /// Handle connection errors
  void _handleConnectionError(dynamic error) {
    print('❌ WebSocket error: $error');
    _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    _handleError('WebSocket error: $error');
    _setConnectionState(WhisperConnectionState.error);
  }

  /// Handle connection closed
  void _handleConnectionClosed() {
    print('🔌 WebSocket connection closed');
    _setConnectionState(WhisperConnectionState.disconnected);

    // Stop ping timer
    _pingTimer?.cancel();

    // Attempt reconnection if configured
    if (_serverUrl != null && _reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    _stats['reconnects'] = (_stats['reconnects'] ?? 0) + 1;

    final delay = Duration(seconds: reconnectDelay.inSeconds * _reconnectAttempts);

    print('🔄 Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');
    _setConnectionState(WhisperConnectionState.reconnecting);

    _reconnectTimer = Timer(delay, () async {
      if (_serverUrl != null) {
        print('🔄 Attempting reconnection...');
        await _establishConnection();
      }
    });
  }

  /// Handle errors with appropriate actions
  void _handleError(String error) {
    print('❌ Error: $error');

    _stats['errors'] = (_stats['errors'] ?? 0) + 1;
    _errorController.add(error);
    onError?.call(error);
  }

  /// Set connection state and notify listeners
  void _setConnectionState(WhisperConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _stateController.add(state);
      onConnectionChanged?.call(state);
      notifyListeners();

      print('🔄 Connection state: ${state.toString().split('.').last}');
    }
  }

  /// Close WebSocket connection
  Future<void> _closeConnection() async {
    try {
      await _channel?.sink.close(status.normalClosure);
      _channel = null;
    } catch (e) {
      print('⚠️ Error closing connection: $e');
    }
  }

  /// Disconnect from server
  Future<void> disconnect() async {
    print('🔌 Disconnecting from Whisper server...');

    // Cancel timers
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    // Prevent auto-reconnect
    _reconnectAttempts = maxReconnectAttempts;

    // Flush any remaining audio buffers
    for (final speakerId in _audioBuffers.keys.toList()) {
      final speakerName = _displayName ?? 'Unknown';
      _flushAudioBuffer(speakerId, speakerName);
    }

    // Clear buffers
    _audioBuffers.clear();
    for (final timer in _bufferTimers.values) {
      timer.cancel();
    }
    _bufferTimers.clear();

    await _closeConnection();
    _setConnectionState(WhisperConnectionState.disconnected);

    // Reset state
    _serverUrl = null;
    _userId = null;
    _displayName = null;
    _lastConnectTime = null;

    print('✅ Disconnected from Whisper server');
  }

  /// Get connection health information
  Map<String, dynamic> getConnectionHealth() {
    final connectTime = _stats['connectTime'] as DateTime?;
    final lastActivity = _stats['lastActivity'] as DateTime?;
    final now = DateTime.now();

    return {
      'state': connectionState.toString().split('.').last,
      'isHealthy': isConnected &&
          (lastActivity == null || now.difference(lastActivity).inMinutes < 2),
      'uptime': connectTime != null ? now.difference(connectTime).inMinutes : 0,
      'reconnectAttempts': _reconnectAttempts,
      'lastActivity': lastActivity?.toIso8601String(),
      'serverUrl': _serverUrl,
      'bufferedSpeakers': _audioBuffers.length,
      'statistics': _stats,
    };
  }

  /// Get display name for language code
  String getLanguageDisplayName(String languageCode) {
    return supportedLanguages[languageCode] ?? languageCode.toUpperCase();
  }

  /// Check if language is supported
  bool isLanguageSupported(String languageCode) {
    return supportedLanguages.containsKey(languageCode);
  }

  /// Get list of supported language codes
  List<String> getSupportedLanguageCodes() {
    return supportedLanguages.keys.toList();
  }

  /// Get formatted statistics for display
  Map<String, String> getFormattedStatistics() {
    final connectTime = _stats['connectTime'] as DateTime?;
    final now = DateTime.now();

    return {
      'Connection': connectionState.toString().split('.').last,
      'Audio Chunks': '${_stats['audioChunksSent'] ?? 0}',
      'Transcriptions': '${_stats['transcriptionsReceived'] ?? 0}',
      'Translations': '${_stats['translationsReceived'] ?? 0}',
      'Errors': '${_stats['errors'] ?? 0}',
      'Reconnects': '${_stats['reconnects'] ?? 0}',
      'Uptime': connectTime != null
          ? '${now.difference(connectTime).inMinutes} min'
          : '0 min',
      'Avg Processing': '${(_stats['averageProcessingTime'] ?? 0.0).toStringAsFixed(3)}s',
      'Audio Processed': '${(_stats['totalAudioDuration'] ?? 0.0).toStringAsFixed(1)}s',
      'Languages': '$_nativeLanguage → $_displayLanguage',
    };
  }
  Future<bool> connectWithUserLanguage({
    required String userId,
    required String displayName,
    required String userPreferredLanguage, // Language user muốn thấy transcript
    String nativeLanguage = 'auto', // Auto-detect người nói
  }) async {
    try {
      print('🌍 Connecting Whisper with user language preference');
      print('   User: $displayName ($userId)');
      print('   Native (auto-detect): $nativeLanguage');
      print('   Display language: $userPreferredLanguage');

      final connected = await connect(
        userId: userId,
        displayName: displayName,
        nativeLanguage: nativeLanguage, // Auto-detect speaker's language
        displayLanguage: userPreferredLanguage, // User's preferred language
      );

      if (connected) {
        print('✅ Whisper connected with user-specific language settings');
      }

      return connected;
    } catch (e) {
      print('❌ Error connecting Whisper with user language: $e');
      return false;
    }
  }

// ✅ THÊM: Update user's display language during meeting
  Future<void> updateUserDisplayLanguage(String newLanguage) async {
    if (!isConnected) {
      print('⚠️ Whisper not connected, cannot update language');
      return;
    }

    try {
      await setUserLanguages(
        nativeLanguage: 'auto', // Keep auto-detect
        displayLanguage: newLanguage, // Update display language
      );

      print('🌍 Updated user display language to: $newLanguage');
    } catch (e) {
      print('❌ Error updating user display language: $e');
      throw e;
    }
  }

  @override
  void dispose() {
    print('🗑️ Disposing Whisper Service...');

    // Cancel timers
    _statsTimer?.cancel();

    // Disconnect
    disconnect();

    // Close stream controllers
    _transcriptionController.close();
    _stateController.close();
    _errorController.close();

    super.dispose();
  }
}