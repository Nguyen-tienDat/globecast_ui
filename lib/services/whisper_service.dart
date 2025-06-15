// lib/services/whisper_service.dart - FIXED VERSION
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/subtitle_models.dart';

class WhisperService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isProcessing = false;

  // FIXED: Multiple server URLs to try
  final List<String> _serverUrls = [
    'ws://127.0.0.1:8766',  // Default port from server
    'ws://localhost:8766',   // Alternative localhost
    'ws://127.0.0.1:8080',  // Common alternative
    'ws://127.0.0.1:8000',  // Another common port
    'ws://127.0.0.1:3000',  // Development port
  ];

  int _currentServerIndex = 0;
  String? _connectedUrl;

  // User's display language (NEW WORKFLOW)
  String _userDisplayLanguage = 'en';

  // Current subtitles for all participants
  final Map<String, SubtitleEntry> _currentSubtitles = {};
  final List<SubtitleEntry> _subtitleHistory = [];

  // Callbacks for real-time updates
  Function(SubtitleEntry)? onNewSubtitle;
  Function(String)? onError;
  Function(bool)? onConnectionChanged;

  // Server connection retry logic
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Connection timeout
  Timer? _connectionTimeout;
  static const Duration _connectionTimeoutDuration = Duration(seconds: 10);

  // Getters
  bool get isConnected => _isConnected;
  bool get isProcessing => _isProcessing;
  String get userDisplayLanguage => _userDisplayLanguage;
  Map<String, SubtitleEntry> get currentSubtitles => Map.unmodifiable(_currentSubtitles);
  List<SubtitleEntry> get subtitleHistory => List.unmodifiable(_subtitleHistory);

  // Supported languages with enhanced metadata
  static const Map<String, LanguageInfo> supportedLanguages = {
    'en': LanguageInfo(code: 'en', name: 'English', flag: '🇺🇸'),
    'vi': LanguageInfo(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
    'zh': LanguageInfo(code: 'zh', name: '中文', flag: '🇨🇳'),
    'ja': LanguageInfo(code: 'ja', name: '日本語', flag: '🇯🇵'),
    'ko': LanguageInfo(code: 'ko', name: '한국어', flag: '🇰🇷'),
    'th': LanguageInfo(code: 'th', name: 'ไทย', flag: '🇹🇭'),
    'fr': LanguageInfo(code: 'fr', name: 'Français', flag: '🇫🇷'),
    'de': LanguageInfo(code: 'de', name: 'Deutsch', flag: '🇩🇪'),
    'es': LanguageInfo(code: 'es', name: 'Español', flag: '🇪🇸'),
    'ru': LanguageInfo(code: 'ru', name: 'Русский', flag: '🇷🇺'),
    'ar': LanguageInfo(code: 'ar', name: 'العربية', flag: '🇸🇦'),
    'hi': LanguageInfo(code: 'hi', name: 'हिन्दी', flag: '🇮🇳'),
    'pt': LanguageInfo(code: 'pt', name: 'Português', flag: '🇧🇷'),
    'it': LanguageInfo(code: 'it', name: 'Italiano', flag: '🇮🇹'),
    'nl': LanguageInfo(code: 'nl', name: 'Nederlands', flag: '🇳🇱'),
    'sv': LanguageInfo(code: 'sv', name: 'Svenska', flag: '🇸🇪'),
    'no': LanguageInfo(code: 'no', name: 'Norsk', flag: '🇳🇴'),
    'da': LanguageInfo(code: 'da', name: 'Dansk', flag: '🇩🇰'),
    'fi': LanguageInfo(code: 'fi', name: 'Suomi', flag: '🇫🇮'),
  };

  // FIXED: Improved connection with multiple URL attempts
  Future<bool> connect({String? serverUrl}) async {
    try {
      if (_isConnected) await disconnect();

      print('🌍 Attempting to connect to Whisper server...');

      // If specific URL provided, try it first
      if (serverUrl != null) {
        final success = await _tryConnectToUrl(serverUrl);
        if (success) return true;
      }

      // Try all predefined URLs
      for (int i = 0; i < _serverUrls.length; i++) {
        _currentServerIndex = i;
        final url = _serverUrls[i];

        print('🔄 Trying server URL: $url');
        final success = await _tryConnectToUrl(url);
        if (success) {
          _connectedUrl = url;
          return true;
        }

        // Small delay between attempts
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('❌ All server URLs failed');
      return false;

    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }

  // FIXED: Better single URL connection attempt
  Future<bool> _tryConnectToUrl(String url) async {
    try {
      final completer = Completer<bool>();
      bool hasCompleted = false;

      // Create WebSocket connection
      _channel = IOWebSocketChannel.connect(Uri.parse(url));

      // Set connection timeout
      _connectionTimeout = Timer(_connectionTimeoutDuration, () {
        if (!hasCompleted) {
          hasCompleted = true;
          print('⏰ Connection timeout for $url');
          _closeConnection();
          completer.complete(false);
        }
      });

      // Setup stream listener
      _subscription = _channel!.stream.listen(
            (data) {
          if (!hasCompleted) {
            hasCompleted = true;
            _connectionTimeout?.cancel();
            _isConnected = true;
            _reconnectAttempts = 0;
            print('✅ Connected to Whisper server: $url');
            _sendConnectionMessage();
            onConnectionChanged?.call(true);
            notifyListeners();
            completer.complete(true);
          }
          _handleMessage(data);
        },
        onError: (error) {
          if (!hasCompleted) {
            hasCompleted = true;
            _connectionTimeout?.cancel();
            print('❌ WebSocket error for $url: $error');
            _closeConnection();
            completer.complete(false);
          }
        },
        onDone: () {
          if (!hasCompleted) {
            hasCompleted = true;
            _connectionTimeout?.cancel();
            print('📴 WebSocket closed for $url');
            _closeConnection();
            completer.complete(false);
          } else {
            // Connection was established but then closed
            print('📴 WebSocket connection lost: $url');
            _handleConnectionClosed();
          }
        },
      );

      return await completer.future;

    } catch (e) {
      print('❌ Failed to connect to $url: $e');
      _closeConnection();
      return false;
    }
  }

  // Close connection helper
  void _closeConnection() {
    try {
      _connectionTimeout?.cancel();
      _subscription?.cancel();
      _channel?.sink.close();
    } catch (e) {
      print('⚠️ Error closing connection: $e');
    }

    _subscription = null;
    _channel = null;
    _isConnected = false;
    _isProcessing = false;
  }

  // Disconnect from server
  Future<void> disconnect() async {
    try {
      _isConnected = false;
      _isProcessing = false;

      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      _closeConnection();
      _currentSubtitles.clear();

      onConnectionChanged?.call(false);
      notifyListeners();
      print('📴 Disconnected from Whisper server');
    } catch (e) {
      print('❌ Error disconnecting: $e');
    }
  }

  // Send connection message with NEW WORKFLOW capabilities
  void _sendConnectionMessage() {
    if (!_isConnected) return;

    final message = {
      'type': 'connection_setup',
      'message': 'Flutter GlobeCast client connected',
      'workflow': 'youtube_subtitles',
      'capabilities': {
        'user_display_language': _userDisplayLanguage,
        'auto_detect_source': true,
        'supported_languages': supportedLanguages.keys.toList(),
        'real_time_translation': true,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
  }

  // Set user's preferred display language
  void setUserDisplayLanguage(String displayLanguage) {
    _userDisplayLanguage = displayLanguage;

    print('🌐 User display language set to: $displayLanguage');
    print('🔄 All speech will now be translated to: ${supportedLanguages[displayLanguage]?.name}');

    _currentSubtitles.clear();
    notifyListeners();

    // Notify server of language change
    if (_isConnected) {
      _sendMessage({
        'type': 'language_preference_update',
        'user_display_language': displayLanguage,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Legacy method for compatibility
  void setUserLanguages({
    required String nativeLanguage,
    required String displayLanguage,
  }) {
    setUserDisplayLanguage(displayLanguage);
  }

  // FIXED: Better audio data sending with retry
  Future<void> sendAudioData(Uint8List audioData, String speakerId, String speakerName) async {
    if (!_isConnected) {
      print('❌ Cannot send audio: not connected to Whisper server');
      return;
    }

    try {
      _isProcessing = true;
      notifyListeners();

      // Send metadata first
      final metadata = {
        'type': 'audio_metadata',
        'speaker_id': speakerId,
        'speaker_name': speakerName,
        'target_language': _userDisplayLanguage,
        'auto_detect_source': true,
        'audio_size': audioData.length,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final success = _sendMessage(metadata);
      if (!success) {
        throw Exception('Failed to send metadata');
      }

      // Wait a bit for metadata to be processed
      await Future.delayed(const Duration(milliseconds: 100));

      // Then send audio data as binary
      try {
        _channel!.sink.add(audioData);
        print('🎵 Sent audio data: ${audioData.length} bytes for $speakerName (→ $_userDisplayLanguage)');
      } catch (e) {
        throw Exception('Failed to send audio data: $e');
      }

    } catch (e) {
      print('❌ Error sending audio data: $e');
      onError?.call('Failed to send audio: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  // FIXED: Better message handling with error recovery
  void _handleMessage(dynamic data) {
    try {
      Map<String, dynamic> message;

      if (data is String) {
        message = jsonDecode(data);
      } else {
        print('❌ Received non-string message type: ${data.runtimeType}');
        return;
      }

      final String type = message['type'] ?? 'unknown';
      print('📨 Received message type: $type');

      switch (type) {
        case 'connection_acknowledged':
        case 'connection':
          _handleConnectionMessage(message);
          break;
        case 'transcription_result':
        case 'transcription':
          _handleTranscriptionResult(message);
          break;
        case 'translation_complete':
        case 'translation_result':
          _handleTranslationComplete(message);
          break;
        case 'processing_status':
          _handleProcessingStatus(message);
          break;
        case 'error':
          _handleErrorMessage(message);
          break;
        case 'test_response':
          print('📨 Test successful: ${message['message']}');
          break;
        default:
          print('❓ Unknown message type: $type');
      }
    } catch (e) {
      print('❌ Error handling message: $e');
      // Don't crash on message errors
    }
  }

  // Handle connection acknowledgment
  void _handleConnectionMessage(Map<String, dynamic> message) {
    print('🤝 Connection acknowledged: ${message['message']}');
    final capabilities = message['server_capabilities'] ?? message['capabilities'];
    if (capabilities != null) {
      print('🎯 Server capabilities: $capabilities');
    }
  }

  // Handle transcription result with NEW WORKFLOW
  void _handleTranscriptionResult(Map<String, dynamic> message) {
    try {
      final String text = message['text'] ?? '';
      final String detectedLanguage = message['language'] ?? message['detected_language'] ?? 'unknown';
      final double confidence = ((message['confidence'] ?? 0.0) as num).toDouble();
      final String speakerId = message['speaker_id'] ?? 'unknown';
      final String speakerName = message['speaker_name'] ?? 'Unknown Speaker';
      final bool isFinal = message['is_final'] ?? true;

      if (text.trim().isEmpty) return;

      print('📝 Transcription ($detectedLanguage): $text (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');

      // Create subtitle entry
      final subtitle = SubtitleEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        speakerId: speakerId,
        speakerName: speakerName,
        originalText: text,
        originalLanguage: detectedLanguage,
        targetLanguage: _userDisplayLanguage,
        confidence: confidence,
        timestamp: DateTime.now(),
        isFinal: isFinal,
      );

      // Check if translation is needed
      if (detectedLanguage != _userDisplayLanguage) {
        subtitle.translatedText = 'Translating...';
        subtitle.isTranslating = true;
        print('🌍 Requesting translation: $detectedLanguage → $_userDisplayLanguage');
        _requestTranslation(text, detectedLanguage, speakerId);
      } else {
        subtitle.translatedText = text;
        subtitle.isTranslating = false;
        subtitle.translationConfidence = confidence;
      }

      // Update current subtitles and history
      _currentSubtitles[speakerId] = subtitle;
      _subtitleHistory.add(subtitle);

      // Keep history reasonable size
      if (_subtitleHistory.length > 50) {
        _subtitleHistory.removeAt(0);
      }

      onNewSubtitle?.call(subtitle);
      notifyListeners();

      _isProcessing = false;
    } catch (e) {
      print('❌ Error handling transcription: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Handle translation completion
  void _handleTranslationComplete(Map<String, dynamic> message) {
    try {
      final String originalText = message['original_text'] ?? '';
      final String translatedText = message['translated_text'] ?? '';
      final String speakerId = message['speaker_id'] ?? '';
      final double confidence = ((message['confidence'] ?? 0.0) as num).toDouble();

      print('🌍 Translation complete: $originalText → $translatedText');

      // Find and update the corresponding subtitle entry
      final subtitle = _currentSubtitles[speakerId];
      if (subtitle != null && subtitle.originalText == originalText && subtitle.isTranslating) {
        subtitle.translatedText = translatedText;
        subtitle.isTranslating = false;
        subtitle.translationConfidence = confidence;

        // Also update in history
        for (var entry in _subtitleHistory.reversed) {
          if (entry.speakerId == speakerId &&
              entry.originalText == originalText &&
              entry.isTranslating) {
            entry.translatedText = translatedText;
            entry.isTranslating = false;
            entry.translationConfidence = confidence;
            break;
          }
        }

        notifyListeners();
      }
    } catch (e) {
      print('❌ Error handling translation: $e');
    }
  }

  // Handle processing status updates
  void _handleProcessingStatus(Map<String, dynamic> message) {
    final bool isProcessing = message['is_processing'] ?? false;
    final String status = message['status'] ?? 'unknown';

    _isProcessing = isProcessing;
    print('⚙️ Processing status: $status (processing: $isProcessing)');
    notifyListeners();
  }

  // Handle error message
  void _handleErrorMessage(Map<String, dynamic> message) {
    final String errorMsg = message['message'] ?? 'Unknown error';
    final String errorType = message['error_type'] ?? 'general';

    print('❌ Server error ($errorType): $errorMsg');
    onError?.call(errorMsg);
    _isProcessing = false;
    notifyListeners();
  }

  // Request translation for specific text
  void _requestTranslation(String text, String sourceLanguage, String speakerId) {
    if (!_isConnected) return;

    final message = {
      'type': 'translation_request',
      'text': text,
      'source_language': sourceLanguage,
      'target_language': _userDisplayLanguage,
      'speaker_id': speakerId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
  }

  // Handle connection error with auto-retry
  void _handleConnectionError(dynamic error) {
    _isConnected = false;
    _isProcessing = false;
    onConnectionChanged?.call(false);
    onError?.call('Connection error: $error');
    notifyListeners();

    _attemptReconnect();
  }

  // Handle connection closed with auto-retry
  void _handleConnectionClosed() {
    _isConnected = false;
    _isProcessing = false;
    onConnectionChanged?.call(false);
    notifyListeners();

    _attemptReconnect();
  }

  // FIXED: Better auto-reconnect logic
  void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2); // Exponential backoff

    print('🔄 Attempting reconnection in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      print('🔄 Reconnecting to Whisper server...');

      // Try to reconnect to the last successful URL first
      if (_connectedUrl != null) {
        final success = await _tryConnectToUrl(_connectedUrl!);
        if (success) return;
      }

      // Otherwise try all URLs again
      final success = await connect();
      if (!success) {
        _attemptReconnect();
      }
    });
  }

  // FIXED: Better message sending with error handling
  bool _sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      print('❌ Cannot send message: not connected');
      return false;
    }

    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      return true;
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  // Clear subtitles
  void clearSubtitles() {
    _currentSubtitles.clear();
    _subtitleHistory.clear();
    notifyListeners();
  }

  // Get subtitle for specific speaker
  SubtitleEntry? getSubtitleForSpeaker(String speakerId) {
    return _currentSubtitles[speakerId];
  }

  // Get latest subtitle across all speakers
  SubtitleEntry? getLatestSubtitle() {
    if (_subtitleHistory.isEmpty) return null;
    return _subtitleHistory.last;
  }

  // Get subtitles in chronological order
  List<SubtitleEntry> getRecentSubtitles({int limit = 10}) {
    final recentSubtitles = _subtitleHistory.reversed.take(limit).toList();
    return recentSubtitles.reversed.toList();
  }

  // Check if service is ready
  bool get isReady => _isConnected && !_isProcessing;

  // Get connection status info
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'connectedUrl': _connectedUrl,
      'isProcessing': _isProcessing,
      'userDisplayLanguage': _userDisplayLanguage,
      'supportedLanguagesCount': supportedLanguages.length,
      'currentSubtitlesCount': _currentSubtitles.length,
      'historyCount': _subtitleHistory.length,
      'reconnectAttempts': _reconnectAttempts,
      'maxReconnectAttempts': _maxReconnectAttempts,
    };
  }

  @override
  void dispose() {
    print('🧹 Disposing WhisperService');
    _reconnectTimer?.cancel();
    _connectionTimeout?.cancel();
    disconnect();
    super.dispose();
  }
}