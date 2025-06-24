// lib/services/google_cloud_speech_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleCloudSpeechService {
  static GoogleCloudSpeechService? _instance;
  static GoogleCloudSpeechService get instance => _instance ??= GoogleCloudSpeechService._();
  GoogleCloudSpeechService._();

  http.Client? _client;
  String? _projectId;
  bool _isInitialized = false;

  // 🚀 INITIALIZE SERVICE
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      print('🎤 Initializing Google Cloud Speech service...');

      // Load credentials
      final credentialsString = await rootBundle.loadString('assets/credentials/google-cloud-credentials.json');
      final credentialsJson = json.decode(credentialsString);

      _projectId = credentialsJson['project_id'];

      // Create authenticated client
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      _client = await clientViaServiceAccount(
          credentials,
          ['https://www.googleapis.com/auth/cloud-platform']
      );

      _isInitialized = true;
      print('✅ Google Cloud Speech service initialized');
    } catch (e) {
      print('❌ Failed to initialize Google Cloud Speech service: $e');
      rethrow;
    }
  }

  // 🎯 CONVERT SPEECH TO TEXT
  Future<String> speechToText({
    required Uint8List audioData,
    String languageCode = 'en-US',
    int sampleRateHertz = 16000,
  }) async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      print('🎤 Converting speech to text (language: $languageCode)...');

      // Prepare request body
      final requestBody = {
        'config': {
          'encoding': 'WEBM_OPUS', // For web audio
          'sampleRateHertz': sampleRateHertz,
          'languageCode': languageCode,
          'enableAutomaticPunctuation': true,
          'enableWordTimeOffsets': false,
          'model': 'latest_long', // Better for real-time
        },
        'audio': {
          'content': base64Encode(audioData),
        },
      };

      // Make API call
      final response = await _client!.post(
        Uri.parse('https://speech.googleapis.com/v1/speech:recognize'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['results'] != null && result['results'].isNotEmpty) {
          final transcript = result['results'][0]['alternatives'][0]['transcript'];
          final confidence = result['results'][0]['alternatives'][0]['confidence'];

          print('✅ Speech recognition successful (confidence: ${(confidence * 100).toInt()}%)');
          return transcript.toString();
        } else {
          print('⚠️ No speech detected');
          return '';
        }
      } else {
        print('❌ Speech recognition failed: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Speech recognition failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Speech to text error: $e');
      rethrow;
    }
  }

  // 🎯 REAL-TIME STREAMING (Advanced)
  Future<Stream<String>> startStreamingRecognition({
    String languageCode = 'en-US',
    int sampleRateHertz = 16000,
  }) async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      print('🎤 Starting streaming speech recognition...');

      // Note: This is a simplified implementation
      // Real streaming requires WebSocket connection
      // For now, we'll use the regular recognize method

      throw UnimplementedError('Streaming recognition requires WebSocket implementation');
    } catch (e) {
      print('❌ Streaming recognition error: $e');
      rethrow;
    }
  }

  // 🔧 UTILITY: Check if service is ready
  bool get isReady => _isInitialized && _client != null;

  // 🧹 CLEANUP
  void dispose() {
    _client?.close();
    _client = null;
    _isInitialized = false;
    print('🧹 Google Cloud Speech service disposed');
  }
}

/*
🎯 USAGE EXAMPLE:

```dart
// Initialize service
final speechService = GoogleCloudSpeechService.instance;
await speechService.initialize();

// Convert audio to text
final transcript = await speechService.speechToText(
  audioData: audioBytes,
  languageCode: 'vi-VN', // Vietnamese
  sampleRateHertz: 16000,
);

print('Transcript: $transcript');
```

🔧 SUPPORTED LANGUAGES:
- 'en-US' - English (US)
- 'vi-VN' - Vietnamese
- 'zh-CN' - Chinese (Simplified)
- 'ja-JP' - Japanese
- 'ko-KR' - Korean
- 'th-TH' - Thai
- 'id-ID' - Indonesian
- 'ms-MY' - Malay

📱 AUDIO FORMATS:
- WEBM_OPUS (recommended for web)
- FLAC (best quality)
- LINEAR16 (uncompressed)
- OGG_OPUS (good compression)

🚀 NEXT STEPS:
1. Integrate with existing MultilingualSpeechService
2. Add real-time streaming support
3. Add language auto-detection
4. Add noise reduction settings
*/