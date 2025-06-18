// lib/models/translation_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for real-time speech transcription and translation
class SpeechTranscription {
  final String id;
  final String meetingId;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final Map<String, String> translations; // languageCode -> translatedText
  final DateTime timestamp;
  final bool isFinal;
  final double confidence;
  final bool isActive;

  SpeechTranscription({
    required this.id,
    required this.meetingId,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    this.translations = const {},
    required this.timestamp,
    this.isFinal = false,
    this.confidence = 0.0,
    this.isActive = true,
  });

  factory SpeechTranscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpeechTranscription(
      id: doc.id,
      meetingId: data['meetingId'] ?? '',
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? 'Unknown',
      originalText: data['originalText'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'en',
      translations: Map<String, String>.from(data['translations'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFinal: data['isFinal'] ?? false,
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'translations': translations,
      'timestamp': FieldValue.serverTimestamp(),
      'isFinal': isFinal,
      'confidence': confidence,
      'isActive': isActive,
    };
  }

  SpeechTranscription copyWith({
    String? id,
    String? meetingId,
    String? speakerId,
    String? speakerName,
    String? originalText,
    String? originalLanguage,
    Map<String, String>? translations,
    DateTime? timestamp,
    bool? isFinal,
    double? confidence,
    bool? isActive,
  }) {
    return SpeechTranscription(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      speakerId: speakerId ?? this.speakerId,
      speakerName: speakerName ?? this.speakerName,
      originalText: originalText ?? this.originalText,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      translations: translations ?? this.translations,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      confidence: confidence ?? this.confidence,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get translation for specific language
  String getTranslation(String languageCode) {
    if (languageCode == originalLanguage) {
      return originalText;
    }
    return translations[languageCode] ?? originalText;
  }

  /// Check if translation exists for language
  bool hasTranslation(String languageCode) {
    return languageCode == originalLanguage || translations.containsKey(languageCode);
  }
}

/// Model for user language preferences
class UserLanguagePreference {
  final String userId;
  final String displayLanguage;
  final String speakingLanguage;
  final bool autoDetectSpeaking;
  final bool enableLiveTranslation;
  final DateTime updatedAt;

  UserLanguagePreference({
    required this.userId,
    required this.displayLanguage,
    required this.speakingLanguage,
    this.autoDetectSpeaking = true,
    this.enableLiveTranslation = true,
    required this.updatedAt,
  });

  factory UserLanguagePreference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserLanguagePreference(
      userId: doc.id,
      displayLanguage: data['displayLanguage'] ?? 'en',
      speakingLanguage: data['speakingLanguage'] ?? 'en',
      autoDetectSpeaking: data['autoDetectSpeaking'] ?? true,
      enableLiveTranslation: data['enableLiveTranslation'] ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayLanguage': displayLanguage,
      'speakingLanguage': speakingLanguage,
      'autoDetectSpeaking': autoDetectSpeaking,
      'enableLiveTranslation': enableLiveTranslation,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Supported language mappings
class SupportedLanguages {
  static const Map<String, String> languages = {
    'en': 'English',
    'vi': 'Tiếng Việt',
    'es': 'Español',
    'ja': '日本語',
    'ko': '한국어',
    'ar': 'العربية',
    'fr': 'Français',
    'de': 'Deutsch',
    'zh': '中文',
    'ru': 'Русский',
    'it': 'Italiano',
    'pt': 'Português',
  };

  static const Map<String, String> languageFlags = {
    'en': '🇺🇸',
    'vi': '🇻🇳',
    'es': '🇪🇸',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'ar': '🇸🇦',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'zh': '🇨🇳',
    'ru': '🇷🇺',
    'it': '🇮🇹',
    'pt': '🇵🇹',
  };

  static String getLanguageName(String code) {
    return languages[code] ?? 'Unknown';
  }

  static String getLanguageFlag(String code) {
    return languageFlags[code] ?? '🌐';
  }

  static List<String> getAllLanguageCodes() {
    return languages.keys.toList();
  }
}

/// Live subtitle item for real-time display
class LiveSubtitle {
  final String id;
  final String speakerId;
  final String speakerName;
  final String text;
  final String language;
  final DateTime timestamp;
  final bool isCurrentUser;
  final bool isFinal;

  LiveSubtitle({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.text,
    required this.language,
    required this.timestamp,
    this.isCurrentUser = false,
    this.isFinal = false,
  });

  LiveSubtitle copyWith({
    String? text,
    bool? isFinal,
  }) {
    return LiveSubtitle(
      id: id,
      speakerId: speakerId,
      speakerName: speakerName,
      text: text ?? this.text,
      language: language,
      timestamp: timestamp,
      isCurrentUser: isCurrentUser,
      isFinal: isFinal ?? this.isFinal,
    );
  }
}