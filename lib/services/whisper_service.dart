// lib/services/whisper_service.dart
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

  // User's native language (what they speak)
  String _userNativeLanguage = 'en';
  // User's preferred display language (what they want to see)
  String _userDisplayLanguage = 'en';

  // Current subtitles for all participants
  final Map<String, SubtitleEntry> _currentSubtitles = {};
  final List<SubtitleEntry> _subtitleHistory = [];

  // Callbacks for real-time updates
  Function(SubtitleEntry)? onNewSubtitle;
  Function(String)? onError;
  Function(bool)? onConnectionChanged;

  // Getters
  bool get isConnected => _isConnected;
  bool get isProcessing => _isProcessing;
  String get userNativeLanguage => _userNativeLanguage;
  String get userDisplayLanguage => _userDisplayLanguage;
  Map<String, SubtitleEntry> get currentSubtitles => Map.unmodifiable(_currentSubtitles);
  List<SubtitleEntry> get subtitleHistory => List.unmodifiable(_subtitleHistory);

  // Supported languages
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
  };

  // Initialize connection to Whisper server
  Future<bool> connect({String? serverUrl}) async {
    try {
      if (_isConnected) await disconnect();

      final url = serverUrl ?? _serverUrl;
      print('🌍 Connecting to Whisper server: $url');

      _channel = IOWebSocketChannel.connect(Uri.parse(url));

      // Wait for connection or timeout
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 5), () {
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

  // Send connection message with capabilities
  void _sendConnectionMessage() {
    if (!_isConnected) return;

    final message = {
      'type': 'test',
      'message': 'Flutter client connected',
      'capabilities': {
        'native_language': _userNativeLanguage,
        'display_language': _userDisplayLanguage,
        'supported_languages': supportedLanguages.keys.toList(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
  }

  // Set user languages
  void setUserLanguages({
    required String nativeLanguage,
    required String displayLanguage,
  }) {
    _userNativeLanguage = nativeLanguage;
    _userDisplayLanguage = displayLanguage;

    print('🌐 User languages set: Native=$nativeLanguage, Display=$displayLanguage');

    // Clear existing subtitles when language changes
    _currentSubtitles.clear();
    notifyListeners();
  }

  // Send audio data for transcription
  Future<void> sendAudioData(Uint8List audioData, String speakerId, String speakerName) async {
    if (!_isConnected) {
      print('❌ Cannot send audio: not connected to Whisper server');
      return;
    }

    try {
      _isProcessing = true;
      notifyListeners();

      // Send audio data as binary
      _channel!.sink.add(audioData);

      print('🎵 Sent audio data: ${audioData.length} bytes for $speakerName');
    } catch (e) {
      print('❌ Error sending audio data: $e');
      onError?.call('Failed to send audio: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  // Request translation for existing text
  Future<void> requestTranslation({
    required String text,
    required String sourceLanguage,
    String? targetLanguage,
  }) async {
    if (!_isConnected) return;

    final message = {
      'type': 'translate_request',
      'text': text,
      'source_lang': sourceLanguage,
      'target_lang': targetLanguage ?? _userDisplayLanguage,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
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
        case 'connection':
          _handleConnectionMessage(message);
          break;
        case 'transcription':
          _handleTranscriptionResult(message);
          break;
        case 'translation_result':
          _handleTranslationResult(message);
          break;
        case 'test_response':
          print('✅ Test response: ${message['message']}');
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

  // Handle connection message
  void _handleConnectionMessage(Map<String, dynamic> message) {
    print('🤝 Connection established: ${message['message']}');
    final capabilities = message['capabilities'];
    if (capabilities != null) {
      print('🎯 Server capabilities: $capabilities');
    }
  }

  // Handle transcription result
  void _handleTranscriptionResult(Map<String, dynamic> message) {
    try {
      final String text = message['text'] ?? '';
      final String detectedLanguage = message['language'] ?? 'unknown';
      final double confidence = ((message['confidence'] ?? 0.0) as num).toDouble();
      final String speakerId = message['speaker_id'] ?? 'unknown';
      final String speakerName = message['speaker_name'] ?? 'Unknown Speaker';

      if (text.trim().isEmpty) return;

      print('📝 Transcription: [$detectedLanguage] $text (confidence: ${(confidence * 100).toStringAsFixed(1)}%)');

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
        isFinal: message['is_final'] ?? true,
      );

      // If detected language is different from user's display language, request translation
      if (detectedLanguage != _userDisplayLanguage) {
        requestTranslation(
          text: text,
          sourceLanguage: detectedLanguage,
          targetLanguage: _userDisplayLanguage,
        );

        // Store with placeholder translation
        subtitle.translatedText = 'Translating...';
        subtitle.isTranslating = true;
      } else {
        // Same language, no translation needed
        subtitle.translatedText = text;
        subtitle.isTranslating = false;
      }

      // Update current subtitles and history
      _currentSubtitles[speakerId] = subtitle;
      _subtitleHistory.add(subtitle);

      // Keep history reasonable size
      if (_subtitleHistory.length > 100) {
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

  // Handle translation result
  void _handleTranslationResult(Map<String, dynamic> message) {
    try {
      final String originalText = message['original_text'] ?? '';
      final String translatedText = message['translated_text'] ?? '';
      final String targetLanguage = message['target_language'] ?? '';
      final double confidence = ((message['confidence'] ?? 0.0) as num).toDouble();

      print('🌍 Translation: $originalText → $translatedText');

      // Find matching subtitle entry and update translation
      for (var entry in _currentSubtitles.values) {
        if (entry.originalText == originalText && entry.isTranslating) {
          entry.translatedText = translatedText;
          entry.isTranslating = false;
          entry.translationConfidence = confidence;
          break;
        }
      }

      // Also update in history
      for (var entry in _subtitleHistory.reversed) {
        if (entry.originalText == originalText && entry.isTranslating) {
          entry.translatedText = translatedText;
          entry.isTranslating = false;
          entry.translationConfidence = confidence;
          break;
        }
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error handling translation: $e');
    }
  }

  // Handle error message
  void _handleErrorMessage(Map<String, dynamic> message) {
    final String errorMsg = message['message'] ?? 'Unknown error';
    print('❌ Server error: $errorMsg');
    onError?.call(errorMsg);
    _isProcessing = false;
    notifyListeners();
  }

  // Handle connection error
  void _handleConnectionError(dynamic error) {
    _isConnected = false;
    _isProcessing = false;
    onConnectionChanged?.call(false);
    onError?.call('Connection error: $error');
    notifyListeners();
  }

  // Handle connection closed
  void _handleConnectionClosed() {
    _isConnected = false;
    _isProcessing = false;
    onConnectionChanged?.call(false);
    notifyListeners();
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

  @override
  void dispose() {
    print('🧹 Disposing WhisperService');
    disconnect();
    super.dispose();
  }
}