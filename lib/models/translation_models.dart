// lib/models/translation_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 🎯 TRANSCRIPTION DATA MODEL
class TranscriptionData {
  final String id;
  final String userId;
  final String userName;
  final String originalText;
  final String originalLanguage;
  final DateTime timestamp;
  final double confidence;
  final bool isFinal;
  final Map<String, String> translations; // language_code -> translated_text

  TranscriptionData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.originalText,
    required this.originalLanguage,
    required this.timestamp,
    required this.confidence,
    required this.isFinal,
    required this.translations,
  });

  // Create from Firestore document
  factory TranscriptionData.fromFirestore(Map<String, dynamic> data) {
    return TranscriptionData(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      originalText: data['originalText'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'en',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      isFinal: data['isFinal'] ?? true,
      translations: Map<String, String>.from(data['translations'] ?? {}),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'timestamp': Timestamp.fromDate(timestamp),
      'confidence': confidence,
      'isFinal': isFinal,
      'translations': translations,
      'type': isFinal ? 'final' : 'partial',
    };
  }

  // Get translation for specific language
  String getTranslation(String targetLanguage) {
    if (targetLanguage == originalLanguage) {
      return originalText;
    }
    return translations[targetLanguage] ?? originalText;
  }

  // Copy with updated translations
  TranscriptionData copyWith({
    String? id,
    String? userId,
    String? userName,
    String? originalText,
    String? originalLanguage,
    DateTime? timestamp,
    double? confidence,
    bool? isFinal,
    Map<String, String>? translations,
  }) {
    return TranscriptionData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      originalText: originalText ?? this.originalText,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      isFinal: isFinal ?? this.isFinal,
      translations: translations ?? Map<String, String>.from(this.translations),
    );
  }

  @override
  String toString() {
    return 'TranscriptionData(id: $id, user: $userName, text: "$originalText", lang: $originalLanguage, final: $isFinal)';
  }
}

// 🎯 SPEECH TRANSCRIPTION MODEL (for UI widgets)
class SpeechTranscription {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final DateTime timestamp;
  final double confidence;
  final bool isFinal;
  final Map<String, String> translations;

  SpeechTranscription({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.timestamp,
    required this.confidence,
    required this.isFinal,
    required this.translations,
  });

  factory SpeechTranscription.fromTranscriptionData(TranscriptionData data) {
    return SpeechTranscription(
      id: data.id,
      speakerId: data.userId,
      speakerName: data.userName,
      originalText: data.originalText,
      originalLanguage: data.originalLanguage,
      timestamp: data.timestamp,
      confidence: data.confidence,
      isFinal: data.isFinal,
      translations: Map<String, String>.from(data.translations),
    );
  }

  String getTranslation(String targetLanguage) {
    if (targetLanguage == originalLanguage) {
      return originalText;
    }
    return translations[targetLanguage] ?? originalText;
  }
}

// 🎯 USER PREFERENCE MODEL
class UserPreference {
  final String userId;
  final String displayLanguage;
  final String speakingLanguage;

  UserPreference({
    required this.userId,
    required this.displayLanguage,
    required this.speakingLanguage,
  });

  UserPreference copyWith({
    String? userId,
    String? displayLanguage,
    String? speakingLanguage,
  }) {
    return UserPreference(
      userId: userId ?? this.userId,
      displayLanguage: displayLanguage ?? this.displayLanguage,
      speakingLanguage: speakingLanguage ?? this.speakingLanguage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayLanguage': displayLanguage,
      'speakingLanguage': speakingLanguage,
    };
  }

  factory UserPreference.fromMap(Map<String, dynamic> map) {
    return UserPreference(
      userId: map['userId'] ?? '',
      displayLanguage: map['displayLanguage'] ?? 'en',
      speakingLanguage: map['speakingLanguage'] ?? 'en',
    );
  }
}

// 🎯 LANGUAGE SUPPORT MODEL
class LanguageSupport {
  final String code;
  final String name;
  final String nativeName;
  final bool isSupported;

  const LanguageSupport({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.isSupported,
  });
}

// 🎯 SUPPORTED LANGUAGES
class SupportedLanguages {
  static const List<LanguageSupport> all = [
    LanguageSupport(code: 'en', name: 'English', nativeName: 'English', isSupported: true),
    LanguageSupport(code: 'es', name: 'Spanish', nativeName: 'Español', isSupported: true),
    LanguageSupport(code: 'fr', name: 'French', nativeName: 'Français', isSupported: true),
    LanguageSupport(code: 'de', name: 'German', nativeName: 'Deutsch', isSupported: true),
    LanguageSupport(code: 'it', name: 'Italian', nativeName: 'Italiano', isSupported: true),
    LanguageSupport(code: 'pt', name: 'Portuguese', nativeName: 'Português', isSupported: true),
    LanguageSupport(code: 'ru', name: 'Russian', nativeName: 'Русский', isSupported: true),
    LanguageSupport(code: 'ja', name: 'Japanese', nativeName: '日本語', isSupported: true),
    LanguageSupport(code: 'ko', name: 'Korean', nativeName: '한국어', isSupported: true),
    LanguageSupport(code: 'zh', name: 'Chinese', nativeName: '中文', isSupported: true),
    LanguageSupport(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', isSupported: true),
    LanguageSupport(code: 'ar', name: 'Arabic', nativeName: 'العربية', isSupported: true),
    LanguageSupport(code: 'th', name: 'Thai', nativeName: 'ไทย', isSupported: true),
    LanguageSupport(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', isSupported: true),
  ];

  static LanguageSupport getByCode(String code) {
    return all.firstWhere(
          (lang) => lang.code == code,
      orElse: () => all.first, // Default to English
    );
  }

  static String getLanguageFlag(String code) {
    const flags = {
      'en': '🇺🇸',
      'es': '🇪🇸',
      'fr': '🇫🇷',
      'de': '🇩🇪',
      'it': '🇮🇹',
      'pt': '🇵🇹',
      'ru': '🇷🇺',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
      'zh': '🇨🇳',
      'hi': '🇮🇳',
      'ar': '🇸🇦',
      'th': '🇹🇭',
      'vi': '🇻🇳',
    };
    return flags[code] ?? '🌐';
  }

  static String getLanguageName(String code) {
    return getByCode(code).name;
  }

  static String getNativeName(String code) {
    return getByCode(code).nativeName;
  }

  static List<String> getAllLanguageCodes() {
    return all.map((lang) => lang.code).toList();
  }
}

// 🎯 TRANSLATION STATUS
enum TranslationStatus {
  idle,
  translating,
  completed,
  error,
}

// 🎯 SPEECH RECOGNITION STATUS
enum SpeechStatus {
  idle,
  initializing,
  ready,
  listening,
  processing,
  error,
  permissionDenied,
}

// 🎯 REAL-TIME SUBTITLE DATA
class SubtitleData {
  final String text;
  final String language;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final bool isFinal;
  final double confidence;

  SubtitleData({
    required this.text,
    required this.language,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.isFinal,
    required this.confidence,
  });

  factory SubtitleData.fromTranscription(TranscriptionData transcription, String targetLanguage) {
    return SubtitleData(
      text: transcription.getTranslation(targetLanguage),
      language: targetLanguage,
      userId: transcription.userId,
      userName: transcription.userName,
      timestamp: transcription.timestamp,
      isFinal: transcription.isFinal,
      confidence: transcription.confidence,
    );
  }
}