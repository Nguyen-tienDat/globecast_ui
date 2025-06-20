// lib/models/translation_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// User Language Preference Model
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
    this.autoDetectSpeaking = false,
    this.enableLiveTranslation = true,
    required this.updatedAt,
  });

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayLanguage': displayLanguage,
      'speakingLanguage': speakingLanguage,
      'autoDetectSpeaking': autoDetectSpeaking,
      'enableLiveTranslation': enableLiveTranslation,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore document
  factory UserLanguagePreference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserLanguagePreference(
      userId: data['userId'] ?? doc.id,
      displayLanguage: data['displayLanguage'] ?? 'en',
      speakingLanguage: data['speakingLanguage'] ?? 'en',
      autoDetectSpeaking: data['autoDetectSpeaking'] ?? false,
      enableLiveTranslation: data['enableLiveTranslation'] ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  UserLanguagePreference copyWith({
    String? userId,
    String? displayLanguage,
    String? speakingLanguage,
    bool? autoDetectSpeaking,
    bool? enableLiveTranslation,
    DateTime? updatedAt,
  }) {
    return UserLanguagePreference(
      userId: userId ?? this.userId,
      displayLanguage: displayLanguage ?? this.displayLanguage,
      speakingLanguage: speakingLanguage ?? this.speakingLanguage,
      autoDetectSpeaking: autoDetectSpeaking ?? this.autoDetectSpeaking,
      enableLiveTranslation: enableLiveTranslation ?? this.enableLiveTranslation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Speech Transcription Model
class SpeechTranscription {
  final String id;
  final String meetingId;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final DateTime timestamp;
  final bool isFinal;
  final double confidence;
  final Map<String, String> translations;
  final bool isActive;

  SpeechTranscription({
    required this.id,
    required this.meetingId,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.timestamp,
    this.isFinal = true,
    this.confidence = 1.0,
    this.translations = const {},
    this.isActive = true,
  });

  // Check if translation exists for a language
  bool hasTranslation(String languageCode) {
    return translations.containsKey(languageCode);
  }

  // Get translation for a language, fallback to original text
  String getTranslation(String languageCode) {
    return translations[languageCode] ?? originalText;
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'meetingId': meetingId,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'timestamp': Timestamp.fromDate(timestamp),
      'isFinal': isFinal,
      'confidence': confidence,
      'translations': translations,
      'isActive': isActive,
    };
  }

  // Create from Firestore document
  factory SpeechTranscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SpeechTranscription(
      id: data['id'] ?? doc.id,
      meetingId: data['meetingId'] ?? '',
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? 'Unknown',
      originalText: data['originalText'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'en',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFinal: data['isFinal'] ?? true,
      confidence: (data['confidence'] ?? 1.0).toDouble(),
      translations: Map<String, String>.from(data['translations'] ?? {}),
      isActive: data['isActive'] ?? true,
    );
  }

  SpeechTranscription copyWith({
    String? id,
    String? meetingId,
    String? speakerId,
    String? speakerName,
    String? originalText,
    String? originalLanguage,
    DateTime? timestamp,
    bool? isFinal,
    double? confidence,
    Map<String, String>? translations,
    bool? isActive,
  }) {
    return SpeechTranscription(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      speakerId: speakerId ?? this.speakerId,
      speakerName: speakerName ?? this.speakerName,
      originalText: originalText ?? this.originalText,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      confidence: confidence ?? this.confidence,
      translations: translations ?? this.translations,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Translation Model
class Translation {
  final String id;
  final String transcriptionId;
  final String originalText;
  final String translatedText;
  final String fromLanguage;
  final String toLanguage;
  final String userId;
  final DateTime timestamp;
  final double confidence;

  Translation({
    required this.id,
    required this.transcriptionId,
    required this.originalText,
    required this.translatedText,
    required this.fromLanguage,
    required this.toLanguage,
    required this.userId,
    required this.timestamp,
    this.confidence = 1.0,
  });

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'transcriptionId': transcriptionId,
      'originalText': originalText,
      'translatedText': translatedText,
      'fromLanguage': fromLanguage,
      'toLanguage': toLanguage,
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'confidence': confidence,
    };
  }

  // Create from Firestore document
  factory Translation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Translation(
      id: data['id'] ?? doc.id,
      transcriptionId: data['transcriptionId'] ?? '',
      originalText: data['originalText'] ?? '',
      translatedText: data['translatedText'] ?? '',
      fromLanguage: data['fromLanguage'] ?? '',
      toLanguage: data['toLanguage'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confidence: (data['confidence'] ?? 1.0).toDouble(),
    );
  }
}

// Live Subtitle Model
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
    this.isFinal = true,
  });
}

// Supported Languages Utility Class
class SupportedLanguages {
  static const Map<String, String> _languageNames = {
    'en': 'English',
    'vi': 'Vietnamese',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ru': 'Russian',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'it': 'Italian',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'pl': 'Polish',
    'tr': 'Turkish',
    'hi': 'Hindi',
    'th': 'Thai',
    'id': 'Indonesian',
    'ms': 'Malay',
  };

  static const Map<String, String> _languageFlags = {
    'en': '🇺🇸',
    'vi': '🇻🇳',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'ru': '🇷🇺',
    'ar': '🇸🇦',
    'pt': '🇵🇹',
    'it': '🇮🇹',
    'nl': '🇳🇱',
    'sv': '🇸🇪',
    'pl': '🇵🇱',
    'tr': '🇹🇷',
    'hi': '🇮🇳',
    'th': '🇹🇭',
    'id': '🇮🇩',
    'ms': '🇲🇾',
  };

  // Get language name by code
  static String getLanguageName(String languageCode) {
    return _languageNames[languageCode] ?? languageCode.toUpperCase();
  }

  // Get language flag by code
  static String getLanguageFlag(String languageCode) {
    return _languageFlags[languageCode] ?? '🌐';
  }

  // Get all supported language codes
  static List<String> getAllLanguageCodes() {
    return _languageNames.keys.toList();
  }

  // Get all supported languages with names
  static Map<String, String> getAllLanguages() {
    return Map.from(_languageNames);
  }

  // Check if language is supported
  static bool isLanguageSupported(String languageCode) {
    return _languageNames.containsKey(languageCode);
  }

  // Get language code from name
  static String? getLanguageCodeFromName(String languageName) {
    for (var entry in _languageNames.entries) {
      if (entry.value.toLowerCase() == languageName.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  // Normalize language code (handle common variations)
  static String normalizeLanguageCode(String code) {
    final normalized = code.toLowerCase().trim();

    // Handle common variations
    switch (normalized) {
      case 'english':
      case 'eng':
        return 'en';
      case 'vietnamese':
      case 'tiếng việt':
      case 'vn':
        return 'vi';
      case 'chinese':
      case 'mandarin':
      case 'cn':
        return 'zh';
      case 'japanese':
      case 'jp':
        return 'ja';
      case 'korean':
      case 'kr':
        return 'ko';
      case 'spanish':
      case 'español':
        return 'es';
      case 'french':
      case 'français':
        return 'fr';
      case 'german':
      case 'deutsch':
        return 'de';
      case 'russian':
      case 'русский':
        return 'ru';
      case 'arabic':
      case 'العربية':
        return 'ar';
      case 'portuguese':
      case 'português':
        return 'pt';
      case 'italian':
      case 'italiano':
        return 'it';
      case 'dutch':
      case 'nederlands':
        return 'nl';
      case 'swedish':
      case 'svenska':
        return 'sv';
      case 'polish':
      case 'polski':
        return 'pl';
      case 'turkish':
      case 'türkçe':
        return 'tr';
      case 'hindi':
      case 'हिन्दी':
        return 'hi';
      case 'thai':
      case 'ไทย':
        return 'th';
      case 'indonesian':
      case 'bahasa indonesia':
        return 'id';
      case 'malay':
      case 'bahasa melayu':
        return 'ms';
      default:
        return normalized;
    }
  }

  // Get display name for language selection UI
  static String getDisplayName(String languageCode) {
    final flag = getLanguageFlag(languageCode);
    final name = getLanguageName(languageCode);
    return '$flag $name';
  }

  // Get popular languages for quick selection
  static List<String> getPopularLanguages() {
    return ['en', 'vi', 'zh', 'ja', 'ko', 'es', 'fr', 'de', 'ar'];
  }

  // Get Asian languages
  static List<String> getAsianLanguages() {
    return ['vi', 'zh', 'ja', 'ko', 'th', 'id', 'ms', 'hi'];
  }

  // Get European languages
  static List<String> getEuropeanLanguages() {
    return ['en', 'es', 'fr', 'de', 'it', 'nl', 'sv', 'pl', 'ru'];
  }

  // Language detection confidence thresholds
  static const double minConfidenceThreshold = 0.7;
  static const double highConfidenceThreshold = 0.9;

  // Check if confidence is acceptable for auto-detection
  static bool isConfidenceAcceptable(double confidence) {
    return confidence >= minConfidenceThreshold;
  }

  // Check if confidence is high for auto-switching
  static bool isHighConfidence(double confidence) {
    return confidence >= highConfidenceThreshold;
  }
}

// Translation Quality Metrics
class TranslationQuality {
  final double accuracy;
  final double fluency;
  final double coherence;
  final double overall;
  final DateTime measuredAt;

  TranslationQuality({
    required this.accuracy,
    required this.fluency,
    required this.coherence,
    required this.overall,
    required this.measuredAt,
  });

  bool get isAcceptable => overall >= 0.7;
  bool get isGood => overall >= 0.8;
  bool get isExcellent => overall >= 0.9;

  String get qualityLabel {
    if (isExcellent) return 'Excellent';
    if (isGood) return 'Good';
    if (isAcceptable) return 'Acceptable';
    return 'Poor';
  }

  Map<String, dynamic> toMap() {
    return {
      'accuracy': accuracy,
      'fluency': fluency,
      'coherence': coherence,
      'overall': overall,
      'measuredAt': Timestamp.fromDate(measuredAt),
    };
  }

  factory TranslationQuality.fromMap(Map<String, dynamic> map) {
    return TranslationQuality(
      accuracy: (map['accuracy'] ?? 0.0).toDouble(),
      fluency: (map['fluency'] ?? 0.0).toDouble(),
      coherence: (map['coherence'] ?? 0.0).toDouble(),
      overall: (map['overall'] ?? 0.0).toDouble(),
      measuredAt: (map['measuredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// Meeting Translation Statistics
class MeetingTranslationStats {
  final String meetingId;
  final int totalTranscriptions;
  final int totalTranslations;
  final Map<String, int> languageDistribution;
  final Map<String, double> translationAccuracy;
  final Duration totalDuration;
  final DateTime generatedAt;

  MeetingTranslationStats({
    required this.meetingId,
    required this.totalTranscriptions,
    required this.totalTranslations,
    required this.languageDistribution,
    required this.translationAccuracy,
    required this.totalDuration,
    required this.generatedAt,
  });

  double get averageAccuracy {
    if (translationAccuracy.isEmpty) return 0.0;
    final sum = translationAccuracy.values.reduce((a, b) => a + b);
    return sum / translationAccuracy.length;
  }

  int get uniqueLanguages => languageDistribution.keys.length;

  bool get meetsQualityStandard => averageAccuracy >= 0.8;

  Map<String, dynamic> toMap() {
    return {
      'meetingId': meetingId,
      'totalTranscriptions': totalTranscriptions,
      'totalTranslations': totalTranslations,
      'languageDistribution': languageDistribution,
      'translationAccuracy': translationAccuracy,
      'totalDurationMs': totalDuration.inMilliseconds,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory MeetingTranslationStats.fromMap(Map<String, dynamic> map) {
    return MeetingTranslationStats(
      meetingId: map['meetingId'] ?? '',
      totalTranscriptions: map['totalTranscriptions'] ?? 0,
      totalTranslations: map['totalTranslations'] ?? 0,
      languageDistribution: Map<String, int>.from(map['languageDistribution'] ?? {}),
      translationAccuracy: Map<String, double>.from(map['translationAccuracy'] ?? {}),
      totalDuration: Duration(milliseconds: map['totalDurationMs'] ?? 0),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// User Translation History
class UserTranslationHistory {
  final String userId;
  final List<String> meetingIds;
  final Map<String, int> languageUsage;
  final int totalTranslations;
  final double averageQuality;
  final DateTime lastUpdated;

  UserTranslationHistory({
    required this.userId,
    required this.meetingIds,
    required this.languageUsage,
    required this.totalTranslations,
    required this.averageQuality,
    required this.lastUpdated,
  });

  String get preferredLanguage {
    if (languageUsage.isEmpty) return 'en';
    return languageUsage.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  List<String> get recentLanguages {
    final sorted = languageUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'meetingIds': meetingIds,
      'languageUsage': languageUsage,
      'totalTranslations': totalTranslations,
      'averageQuality': averageQuality,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory UserTranslationHistory.fromMap(Map<String, dynamic> map) {
    return UserTranslationHistory(
      userId: map['userId'] ?? '',
      meetingIds: List<String>.from(map['meetingIds'] ?? []),
      languageUsage: Map<String, int>.from(map['languageUsage'] ?? {}),
      totalTranslations: map['totalTranslations'] ?? 0,
      averageQuality: (map['averageQuality'] ?? 0.0).toDouble(),
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}