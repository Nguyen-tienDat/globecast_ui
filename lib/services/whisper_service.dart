// lib/services/whisper_service.dart - IMPROVED FOR NEW WORKFLOW
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
  String _serverUrl = 'ws://127.0.0.1:8766';

  // NEW WORKFLOW: Only user's display language matters
  // We auto-detect what each person speaks and translate to user's preferred language
  String _userDisplayLanguage = 'en'; // What user wants to see ALL subtitles in

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

  // Initialize connection to Whisper server with auto-retry
  Future<bool> connect({String? serverUrl}) async {
    try {
      if (_isConnected) await disconnect();

      final url = serverUrl ?? _serverUrl;
      print('🌍 Connecting to Whisper server: $url');

      _channel = IOWebSocketChannel.connect(Uri.parse(url));

      // Wait for connection or timeout
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _subscription = _channel!.stream.listen(
            (data) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
          _handleMessage(data);
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          _handleConnectionError(error);
        },
        onDone: () {
          print('📴 WebSocket connection closed');
          _handleConnectionClosed();
        },
      );

      final connected = await completer.future;

      if (connected) {
        _isConnected = true;
        _reconnectAttempts = 0;
        print('✅ Connected to Whisper server');
        _sendConnectionMessage();
        onConnectionChanged?.call(true);
        notifyListeners();
        return true;
      } else {
        await disconnect();
        return false;
      }
    } catch (e) {
      print('❌ Failed to connect to Whisper server: $e');
      await disconnect();
      return false;
    }
  }

  // Disconnect from server
  Future<void> disconnect() async {
    try {
      _isConnected = false;
      _isProcessing = false;

      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      await _subscription?.cancel();
      _subscription = null;

      await _channel?.sink.close();
      _channel = null;

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
      'workflow': 'youtube_subtitles', // NEW: Indicate our workflow
      'capabilities': {
        'user_display_language': _userDisplayLanguage,
        'auto_detect_source': true, // We want to auto-detect what each person speaks
        'supported_languages': supportedLanguages.keys.toList(),
        'real_time_translation': true,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
  }

  // NEW WORKFLOW: Set user's preferred display language
  void setUserDisplayLanguage(String displayLanguage) {
    _userDisplayLanguage = displayLanguage;

    print('🌐 User display language set to: $displayLanguage');
    print('🔄 All speech will now be translated to: ${supportedLanguages[displayLanguage]?.name}');

    // Clear existing subtitles when language changes
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

  // Legacy method for compatibility - now just calls setUserDisplayLanguage
  void setUserLanguages({
    required String nativeLanguage, // Ignored in new workflow
    required String displayLanguage,
  }) {
    setUserDisplayLanguage(displayLanguage);
  }

  // Send audio data for transcription with speaker info
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
        'target_language': _userDisplayLanguage, // NEW: Always translate to user's language
        'auto_detect_source': true, // NEW: Auto-detect what the speaker is saying
        'audio_size': audioData.length,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendMessage(metadata);

      // Then send audio data as binary
      _channel!.sink.add(audioData);

      print('🎵 Sent audio data: ${audioData.length} bytes for $speakerName (→ $_userDisplayLanguage)');
    } catch (e) {
      print('❌ Error sending audio data: $e');
      onError?.call('Failed to send audio: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Handle incoming messages from server
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
          _handleConnectionMessage(message);
          break;
        case 'transcription_result':
          _handleTranscriptionResult(message);
          break;
        case 'translation_complete':
          _handleTranslationComplete(message);
          break;
        case 'processing_status':
          _handleProcessingStatus(message);
          break;
        case 'error':
          _handleErrorMessage(message);
          break;
        default:
          print('❓ Unknown message type: $type');
      }
    } catch (e) {
      print('❌ Error handling message: $e');
    }
  }

  // Handle connection acknowledgment
  void _handleConnectionMessage(Map<String, dynamic> message) {
    print('🤝 Connection acknowledged: ${message['message']}');
    final capabilities = message['server_capabilities'];
    if (capabilities != null) {
      print('🎯 Server capabilities: $capabilities');
    }
  }

  // Handle transcription result with NEW WORKFLOW
  void _handleTranscriptionResult(Map<String, dynamic> message) {
    try {
      final String text = message['text'] ?? '';
      final String detectedLanguage = message['detected_language'] ?? 'unknown';
      final double confidence = ((message['confidence'] ?? 0.0) as num).toDouble();
      final String speakerId = message['speaker_id'] ?? 'unknown';
      final String speakerName = message['speaker_name'] ?? 'Unknown Speaker';
      final bool isFinal = message['is_final'] ?? true;

      if (text.trim().isEmpty) return;

      print('📝 Transcription (${detectedLanguage}): $text (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');

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

      // NEW WORKFLOW: Check if translation is needed
      if (detectedLanguage != _userDisplayLanguage) {
        // Different language detected - translation needed
        subtitle.translatedText = 'Translating...';
        subtitle.isTranslating = true;

        print('🌍 Requesting translation: $detectedLanguage → $_userDisplayLanguage');
        _requestTranslation(text, detectedLanguage, speakerId);
      } else {
        // Same language - no translation needed
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

  // Auto-reconnect logic
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
      final success = await connect();
      if (!success) {
        _attemptReconnect();
      }
    });
  }

  // Send message to server
  void _sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) return;

    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
    } catch (e) {
      print('❌ Error sending message: $e');
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
      'isProcessing': _isProcessing,
      'userDisplayLanguage': _userDisplayLanguage,
      'supportedLanguagesCount': supportedLanguages.length,
      'currentSubtitlesCount': _currentSubtitles.length,
      'historyCount': _subtitleHistory.length,
      'reconnectAttempts': _reconnectAttempts,
      'serverUrl': _serverUrl,
    };
  }

  @override
  void dispose() {
    print('🧹 Disposing WhisperService');
    _reconnectTimer?.cancel();
    disconnect();
    super.dispose();
  }
}