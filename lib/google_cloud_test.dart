// lib/test/google_cloud_test.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleCloudTest {
  static Future<void> testConnection() async {
    try {
      print('🧪 Testing Google Cloud connection...');

      // Load credentials from assets
      final credentialsString = await rootBundle.loadString('assets/credentials/google-cloud-credentials.json');
      final credentialsJson = json.decode(credentialsString);

      print('✅ Credentials loaded successfully');
      print('📧 Service Account: ${credentialsJson['client_email']}');
      print('🆔 Project ID: ${credentialsJson['project_id']}');

      // Create service account credentials
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);

      // Pass project ID separately
      final projectId = credentialsJson['project_id'];

      // Test Speech-to-Text API
      await _testSpeechAPI(credentials);

      // Test Translation API
      await _testTranslationAPI(credentials, projectId);

    } catch (e) {
      print('❌ Error: $e');
    }
  }

  static Future<void> _testSpeechAPI(ServiceAccountCredentials credentials) async {
    try {
      print('\n🎤 Testing Speech-to-Text API...');

      final client = await clientViaServiceAccount(
          credentials,
          ['https://www.googleapis.com/auth/cloud-platform']
      );

      final response = await client.get(
          Uri.parse('https://speech.googleapis.com/v1/operations')
      );

      if (response.statusCode == 200) {
        print('✅ Speech-to-Text API: OK');
      } else {
        print('❌ Speech-to-Text API: ${response.statusCode}');
      }

      client.close();
    } catch (e) {
      print('❌ Speech API test failed: $e');
    }
  }

  static Future<void> _testTranslationAPI(ServiceAccountCredentials credentials, String projectId) async {
    try {
      print('🌐 Testing Translation API...');

      final client = await clientViaServiceAccount(
          credentials,
          ['https://www.googleapis.com/auth/cloud-platform']
      );

      final response = await client.get(
          Uri.parse('https://translation.googleapis.com/v3/projects/$projectId/locations')
      );

      if (response.statusCode == 200) {
        print('✅ Translation API: OK');
      } else {
        print('❌ Translation API: ${response.statusCode}');
      }

      client.close();
    } catch (e) {
      print('❌ Translation API test failed: $e');
    }
  }
}