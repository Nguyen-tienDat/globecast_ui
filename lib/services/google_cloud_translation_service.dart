// lib/services/google_cloud_translation_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleCloudTranslationService {
  static GoogleCloudTranslationService? _instance;
  static GoogleCloudTranslationService get instance => _instance ??= GoogleCloudTranslationService._();
  GoogleCloudTranslationService._();

  http.Client? _client;
  String? _projectId;
  bool _isInitialized = false;

  // Cache for translations
  final Map<String, String> _translationCache = {};

  // 🚀 INITIALIZE SERVICE
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      print('🌐 Initializing Google Cloud Translation service...');

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
      print('✅ Google Cloud Translation service initialized');
    } catch (e) {
      print('❌ Failed to initialize Google Cloud Translation service: $e');
      rethrow;
    }
  }

  // 🎯 TRANSLATE TEXT
  Future<String> translateText({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      // Check cache first
      final cacheKey = '${text}_${sourceLanguage}_$targetLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        print('💾 Translation from cache');
        return _translationCache[cacheKey]!;
      }

      print('🌐 Translating: "$text" → $targetLanguage');

      // Prepare request body
      final requestBody = {
        'parent': 'projects/$_projectId/locations/global',
        'contents': [text],
        'mimeType': 'text/plain',
        'targetLanguageCode': targetLanguage,
      };

      // Add source language if specified
      if (sourceLanguage != null) {
        requestBody['sourceLanguageCode'] = sourceLanguage;
      }

      // Make API call
      final response = await _client!.post(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global:translateText'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['translations'] != null && result['translations'].isNotEmpty) {
          final translatedText = result['translations'][0]['translatedText'];
          final detectedLanguage = result['translations'][0]['detectedLanguageCode'];

          print('✅ Translation successful (detected: $detectedLanguage)');

          // Cache the result
          _translationCache[cacheKey] = translatedText;

          return translatedText;
        } else {
          print('⚠️ No translation result');
          return text; // Return original text if no translation
        }
      } else {
        print('❌ Translation failed: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Translation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Translation error: $e');
      return text; // Return original text on error
    }
  }

  // 🎯 BATCH TRANSLATE (Multiple texts)
  Future<List<String>> batchTranslate({
    required List<String> texts,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      print('🌐 Batch translating ${texts.length} texts → $targetLanguage');

      // Prepare request body
      final requestBody = {
        'parent': 'projects/$_projectId/locations/global',
        'contents': texts,
        'mimeType': 'text/plain',
        'targetLanguageCode': targetLanguage,
      };

      // Add source language if specified
      if (sourceLanguage != null) {
        requestBody['sourceLanguageCode'] = sourceLanguage;
      }

      // Make API call
      final response = await _client!.post(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global:translateText'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['translations'] != null) {
          final translations = result['translations'] as List;
          final translatedTexts = translations
              .map((t) => t['translatedText'].toString())
              .toList();

          print('✅ Batch translation successful');
          return translatedTexts;
        } else {
          print('⚠️ No batch translation result');
          return texts; // Return original texts if no translation
        }
      } else {
        print('❌ Batch translation failed: ${response.statusCode}');
        throw Exception('Batch translation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Batch translation error: $e');
      return texts; // Return original texts on error
    }
  }

  // 🎯 DETECT LANGUAGE
  Future<String> detectLanguage(String text) async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      print('🔍 Detecting language for: "${text.length > 50 ? text.substring(0, 50) + '...' : text}"');

      // Prepare request body
      final requestBody = {
        'parent': 'projects/$_projectId/locations/global',
        'content': text,
        'mimeType': 'text/plain',
      };

      // Make API call
      final response = await _client!.post(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global:detectLanguage'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['languages'] != null && result['languages'].isNotEmpty) {
          final detectedLanguage = result['languages'][0]['languageCode'];
          final confidence = result['languages'][0]['confidence'];

          print('✅ Language detected: $detectedLanguage (confidence: ${(confidence * 100).toInt()}%)');
          return detectedLanguage;
        } else {
          print('⚠️ Could not detect language');
          return 'unknown';
        }
      } else {
        print('❌ Language detection failed: ${response.statusCode}');
        return 'unknown';
      }
    } catch (e) {
      print('❌ Language detection error: $e');
      return 'unknown';
    }
  }

  // 🎯 GET SUPPORTED LANGUAGES
  Future<List<Map<String, String>>> getSupportedLanguages() async {
    try {
      if (!_isInitialized || _client == null) {
        await initialize();
      }

      // Make API call
      final response = await _client!.get(
        Uri.parse('https://translation.googleapis.com/v3/projects/$_projectId/locations/global/supportedLanguages'),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['languages'] != null) {
          final languages = result['languages'] as List;
          return languages.map((lang) => {
            'code': lang['languageCode'].toString(),
            'name': lang['displayName']?.toString() ?? lang['languageCode'].toString(),
          }).toList();
        }
      }

      // Return default languages if API fails
      return _getDefaultLanguages();
    } catch (e) {
      print('❌ Get supported languages error: $e');
      return _getDefaultLanguages();
    }
  }

  // 🔧 DEFAULT SUPPORTED LANGUAGES
  List<Map<String, String>> _getDefaultLanguages() {
    return [
      {'code': 'en', 'name': 'English'},
      {'code': 'vi', 'name': 'Vietnamese'},
      {'code': 'zh', 'name': 'Chinese'},
      {'code': 'ja', 'name': 'Japanese'},
      {'code': 'ko', 'name': 'Korean'},
      {'code': 'th', 'name': 'Thai'},
      {'code': 'id', 'name': 'Indonesian'},
      {'code': 'ms', 'name': 'Malay'},
      {'code': 'es', 'name': 'Spanish'},
      {'code': 'fr', 'name': 'French'},
      {'code': 'de', 'name': 'German'},
      {'code': 'it', 'name': 'Italian'},
      {'code': 'pt', 'name': 'Portuguese'},
      {'code': 'ru', 'name': 'Russian'},
      {'code': 'ar', 'name': 'Arabic'},
      {'code': 'hi', 'name': 'Hindi'},
    ];
  }

  // 🔧 UTILITY: Check if service is ready
  bool get isReady => _isInitialized && _client != null;

  // 🔧 CLEAR CACHE
  void clearCache() {
    _translationCache.clear();
    print('🧹 Translation cache cleared');
  }

  // 🧹 CLEANUP
  void dispose() {
    _client?.close();
    _client = null;
    _isInitialized = false;
    _translationCache.clear();
    print('🧹 Google Cloud Translation service disposed');
  }
}

/*
🎯 USAGE EXAMPLE:

```dart
// Initialize service
final translationService = GoogleCloudTranslationService.instance;
await translationService.initialize();

// Translate text
final translated = await translationService.translateText(
  text: 'Hello, how are you?',
  targetLanguage: 'vi', // Vietnamese
  sourceLanguage: 'en', // Optional: auto-detect if not specified
);

print('Translated: $translated'); // "Xin chào, bạn khỏe không?"

// Detect language
final detectedLang = await translationService.detectLanguage('Bonjour le monde');
print('Detected: $detectedLang'); // "fr"

// Batch translate
final batchResults = await translationService.batchTranslate(
  texts: ['Hello', 'Good morning', 'Thank you'],
  targetLanguage: 'vi',
);
```

🌐 SUPPORTED LANGUAGE CODES:
- 'en' - English
- 'vi' - Vietnamese
- 'zh' - Chinese
- 'ja' - Japanese
- 'ko' - Korean
- 'th' - Thai
- 'id' - Indonesian
- 'ms' - Malay
- 'es' - Spanish
- 'fr' - French
- 'de' - German
- 'it' - Italian
- 'pt' - Portuguese
- 'ru' - Russian
- 'ar' - Arabic
- 'hi' - Hindi

🚀 FEATURES:
✅ Text translation
✅ Language detection
✅ Batch translation
✅ Translation caching
✅ Error handling
✅ Supported languages list

🎯 NEXT STEPS:
1. Integrate with existing services
2. Add real-time translation
3. Add translation confidence scores
4. Add custom model support
*/