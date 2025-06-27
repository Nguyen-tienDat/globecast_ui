// lib/models/translation_models.dart - LANGUAGE MANAGEMENT FOR INTEGRATED TRANSLATION

/// 🌐 SUPPORTED LANGUAGES CLASS
class SupportedLanguages {
  static const Map<String, Map<String, String>> _languages = {
    'vi': {
      'name': 'Vietnamese',
      'flag': '🇻🇳',
      'native': 'Tiếng Việt',
      'googleCode': 'vi-VN',
      'mlkitCode': 'vi',
    },
    'en': {
      'name': 'English',
      'flag': '🇺🇸',
      'native': 'English',
      'googleCode': 'en-US',
      'mlkitCode': 'en',
    },
    'zh': {
      'name': 'Chinese',
      'flag': '🇨🇳',
      'native': '中文',
      'googleCode': 'zh-CN',
      'mlkitCode': 'zh',
    },
    'ja': {
      'name': 'Japanese',
      'flag': '🇯🇵',
      'native': '日本語',
      'googleCode': 'ja-JP',
      'mlkitCode': 'ja',
    },
    'ko': {
      'name': 'Korean',
      'flag': '🇰🇷',
      'native': '한국어',
      'googleCode': 'ko-KR',
      'mlkitCode': 'ko',
    },
    'th': {
      'name': 'Thai',
      'flag': '🇹🇭',
      'native': 'ไทย',
      'googleCode': 'th-TH',
      'mlkitCode': 'th',
    },
    'es': {
      'name': 'Spanish',
      'flag': '🇪🇸',
      'native': 'Español',
      'googleCode': 'es-ES',
      'mlkitCode': 'es',
    },
    'fr': {
      'name': 'French',
      'flag': '🇫🇷',
      'native': 'Français',
      'googleCode': 'fr-FR',
      'mlkitCode': 'fr',
    },
    'de': {
      'name': 'German',
      'flag': '🇩🇪',
      'native': 'Deutsch',
      'googleCode': 'de-DE',
      'mlkitCode': 'de',
    },
    'id': {
      'name': 'Indonesian',
      'flag': '🇮🇩',
      'native': 'Bahasa Indonesia',
      'googleCode': 'id-ID',
      'mlkitCode': 'id',
    },
    'ms': {
      'name': 'Malay',
      'flag': '🇲🇾',
      'native': 'Bahasa Melayu',
      'googleCode': 'ms-MY',
      'mlkitCode': 'ms',
    },
    'ar': {
      'name': 'Arabic',
      'flag': '🇸🇦',
      'native': 'العربية',
      'googleCode': 'ar-SA',
      'mlkitCode': 'ar',
    },
    'hi': {
      'name': 'Hindi',
      'flag': '🇮🇳',
      'native': 'हिन्दी',
      'googleCode': 'hi-IN',
      'mlkitCode': 'hi',
    },
    'it': {
      'name': 'Italian',
      'flag': '🇮🇹',
      'native': 'Italiano',
      'googleCode': 'it-IT',
      'mlkitCode': 'it',
    },
    'pt': {
      'name': 'Portuguese',
      'flag': '🇵🇹',
      'native': 'Português',
      'googleCode': 'pt-PT',
      'mlkitCode': 'pt',
    },
    'ru': {
      'name': 'Russian',
      'flag': '🇷🇺',
      'native': 'Русский',
      'googleCode': 'ru-RU',
      'mlkitCode': 'ru',
    },
  };

  /// Get all supported language codes
  static List<String> getAllLanguageCodes() {
    return _languages.keys.toList();
  }

  /// Get popular/commonly used languages
  static List<String> getPopularLanguages() {
    return ['vi', 'en', 'zh', 'ja', 'ko', 'th', 'es', 'fr'];
  }

  /// Get language display name in English
  static String getLanguageName(String languageCode) {
    return _languages[languageCode]?['name'] ?? languageCode.toUpperCase();
  }

  /// Get language flag emoji
  static String getLanguageFlag(String languageCode) {
    return _languages[languageCode]?['flag'] ?? '🌐';
  }

  /// Get native language name
  static String getNativeName(String languageCode) {
    return _languages[languageCode]?['native'] ?? languageCode.toUpperCase();
  }

  /// Get Google Speech API language code
  static String getGoogleSpeechCode(String languageCode) {
    return _languages[languageCode]?['googleCode'] ?? 'en-US';
  }

  /// Get MLKit translation language code
  static String getMLKitCode(String languageCode) {
    return _languages[languageCode]?['mlkitCode'] ?? 'en';
  }

  /// Check if language is supported
  static bool isSupported(String languageCode) {
    return _languages.containsKey(languageCode);
  }

  /// Get language info object
  static Map<String, String>? getLanguageInfo(String languageCode) {
    return _languages[languageCode];
  }

  /// Get all languages as list of maps
  static List<Map<String, String>> getAllLanguagesInfo() {
    return _languages.entries.map((entry) => {
      'code': entry.key,
      ...entry.value,
    }).toList();
  }
}

/// 🎯 MEETING LANGUAGE CONFIGURATION
class MeetingLanguageConfig {
  final String meetingId;
  final String hostUserId;
  final String hostTargetLanguage;
  final List<String> supportedLanguages;
  final Map<String, String> participantLanguages; // userId -> targetLanguage
  final DateTime createdAt;
  final DateTime updatedAt;

  MeetingLanguageConfig({
    required this.meetingId,
    required this.hostUserId,
    required this.hostTargetLanguage,
    required this.supportedLanguages,
    required this.participantLanguages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MeetingLanguageConfig.create({
    required String meetingId,
    required String hostUserId,
    required String hostTargetLanguage,
  }) {
    return MeetingLanguageConfig(
      meetingId: meetingId,
      hostUserId: hostUserId,
      hostTargetLanguage: hostTargetLanguage,
      supportedLanguages: SupportedLanguages.getAllLanguageCodes(),
      participantLanguages: {hostUserId: hostTargetLanguage},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Add or update participant language preference
  MeetingLanguageConfig addParticipant(String userId, String targetLanguage) {
    final newParticipantLanguages = Map<String, String>.from(participantLanguages);
    newParticipantLanguages[userId] = targetLanguage;

    return MeetingLanguageConfig(
      meetingId: meetingId,
      hostUserId: hostUserId,
      hostTargetLanguage: hostTargetLanguage,
      supportedLanguages: supportedLanguages,
      participantLanguages: newParticipantLanguages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove participant
  MeetingLanguageConfig removeParticipant(String userId) {
    final newParticipantLanguages = Map<String, String>.from(participantLanguages);
    newParticipantLanguages.remove(userId);

    return MeetingLanguageConfig(
      meetingId: meetingId,
      hostUserId: hostUserId,
      hostTargetLanguage: hostTargetLanguage,
      supportedLanguages: supportedLanguages,
      participantLanguages: newParticipantLanguages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Get all unique target languages used in meeting
  List<String> getActiveLanguages() {
    return participantLanguages.values.toSet().toList();
  }

  /// Get participant's target language
  String getParticipantLanguage(String userId) {
    return participantLanguages[userId] ?? 'en';
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'meetingId': meetingId,
      'hostUserId': hostUserId,
      'hostTargetLanguage': hostTargetLanguage,
      'supportedLanguages': supportedLanguages,
      'participantLanguages': participantLanguages,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory MeetingLanguageConfig.fromJson(Map<String, dynamic> json) {
    return MeetingLanguageConfig(
      meetingId: json['meetingId'] ?? '',
      hostUserId: json['hostUserId'] ?? '',
      hostTargetLanguage: json['hostTargetLanguage'] ?? 'en',
      supportedLanguages: List<String>.from(json['supportedLanguages'] ?? []),
      participantLanguages: Map<String, String>.from(json['participantLanguages'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// 📊 TRANSLATION STATISTICS
class TranslationStats {
  final String meetingId;
  final int totalTranslations;
  final int totalSpeechMinutes;
  final Map<String, int> languageUsage; // languageCode -> usage count
  final Map<String, double> translationAccuracy; // languageCode -> average confidence
  final DateTime startTime;
  final DateTime? endTime;

  TranslationStats({
    required this.meetingId,
    required this.totalTranslations,
    required this.totalSpeechMinutes,
    required this.languageUsage,
    required this.translationAccuracy,
    required this.startTime,
    this.endTime,
  });

  factory TranslationStats.create(String meetingId) {
    return TranslationStats(
      meetingId: meetingId,
      totalTranslations: 0,
      totalSpeechMinutes: 0,
      languageUsage: {},
      translationAccuracy: {},
      startTime: DateTime.now(),
    );
  }

  /// Add translation result to stats
  TranslationStats addTranslation({
    required String sourceLanguage,
    required double confidence,
    required int speechDurationSeconds,
  }) {
    final newLanguageUsage = Map<String, int>.from(languageUsage);
    final newAccuracy = Map<String, double>.from(translationAccuracy);

    // Update language usage
    newLanguageUsage[sourceLanguage] = (newLanguageUsage[sourceLanguage] ?? 0) + 1;

    // Update accuracy (running average)
    final currentCount = newLanguageUsage[sourceLanguage]!;
    final currentAvg = newAccuracy[sourceLanguage] ?? 0.0;
    newAccuracy[sourceLanguage] = ((currentAvg * (currentCount - 1)) + confidence) / currentCount;

    return TranslationStats(
      meetingId: meetingId,
      totalTranslations: totalTranslations + 1,
      totalSpeechMinutes: totalSpeechMinutes + (speechDurationSeconds / 60).round(),
      languageUsage: newLanguageUsage,
      translationAccuracy: newAccuracy,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// End the meeting stats
  TranslationStats endMeeting() {
    return TranslationStats(
      meetingId: meetingId,
      totalTranslations: totalTranslations,
      totalSpeechMinutes: totalSpeechMinutes,
      languageUsage: languageUsage,
      translationAccuracy: translationAccuracy,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// Get meeting duration
  Duration get meetingDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Get most used language
  String? get mostUsedLanguage {
    if (languageUsage.isEmpty) return null;
    return languageUsage.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get overall translation accuracy
  double get overallAccuracy {
    if (translationAccuracy.isEmpty) return 0.0;
    final accuracies = translationAccuracy.values;
    return accuracies.reduce((a, b) => a + b) / accuracies.length;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'meetingId': meetingId,
      'totalTranslations': totalTranslations,
      'totalSpeechMinutes': totalSpeechMinutes,
      'languageUsage': languageUsage,
      'translationAccuracy': translationAccuracy,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory TranslationStats.fromJson(Map<String, dynamic> json) {
    return TranslationStats(
      meetingId: json['meetingId'] ?? '',
      totalTranslations: json['totalTranslations'] ?? 0,
      totalSpeechMinutes: json['totalSpeechMinutes'] ?? 0,
      languageUsage: Map<String, int>.from(json['languageUsage'] ?? {}),
      translationAccuracy: Map<String, double>.from(json['translationAccuracy'] ?? {}),
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    );
  }
}

/// 🎛️ INTEGRATION CONSTANTS
class IntegrationConstants {
  // Service timeouts
  static const Duration speechRecognitionTimeout = Duration(seconds: 30);
  static const Duration translationTimeout = Duration(seconds: 10);
  static const Duration webrtcConnectionTimeout = Duration(seconds: 45);

  // Audio configuration
  static const int audioSampleRate = 16000;
  static const int audioChannels = 1;
  static const Duration audioBufferDuration = Duration(seconds: 2);

  // Translation thresholds
  static const double minimumConfidenceThreshold = 0.3;
  static const int maximumTranslationRetries = 3;
  static const Duration translationRetryDelay = Duration(seconds: 2);

  // UI update intervals
  static const Duration realtimeUpdateInterval = Duration(milliseconds: 500);
  static const Duration statusUpdateInterval = Duration(seconds: 1);

  // Meeting limits
  static const int maxParticipants = 6;
  static const int maxSpeechResultsInMemory = 50;
  static const Duration maxMeetingDuration = Duration(hours: 4);

  // Languages that support real-time processing
  static const List<String> realtimeOptimizedLanguages = [
    'en', 'vi', 'zh', 'ja', 'ko', 'es', 'fr', 'de'
  ];

  // Default language preferences
  static const String defaultSpeechLanguage = 'vi';
  static const String defaultDisplayLanguage = 'vi';
  static const String fallbackLanguage = 'en';
}

/// 🔧 INTEGRATION UTILITIES
class IntegrationUtils {
  /// Convert short language code to Google Speech code
  static String toGoogleSpeechCode(String languageCode) {
    return SupportedLanguages.getGoogleSpeechCode(languageCode);
  }

  /// Convert short language code to MLKit code
  static String toMLKitCode(String languageCode) {
    return SupportedLanguages.getMLKitCode(languageCode);
  }

  /// Check if language supports real-time processing
  static bool isRealtimeOptimized(String languageCode) {
    return IntegrationConstants.realtimeOptimizedLanguages.contains(languageCode);
  }

  /// Get recommended languages for a region
  static List<String> getRegionalLanguages(String region) {
    switch (region.toLowerCase()) {
      case 'asia':
        return ['vi', 'zh', 'ja', 'ko', 'th', 'id', 'ms', 'hi'];
      case 'europe':
        return ['en', 'es', 'fr', 'de', 'it', 'pt', 'ru'];
      case 'americas':
        return ['en', 'es', 'pt', 'fr'];
      case 'africa':
        return ['en', 'fr', 'ar'];
      default:
        return SupportedLanguages.getPopularLanguages();
    }
  }

  /// Format confidence score for display
  static String formatConfidence(double confidence) {
    return '${(confidence * 100).round()}%';
  }

  /// Get language quality indicator
  static String getLanguageQuality(String languageCode, double confidence) {
    if (confidence >= 0.9) return 'Excellent';
    if (confidence >= 0.8) return 'Good';
    if (confidence >= 0.7) return 'Fair';
    return 'Poor';
  }

  /// Generate meeting summary
  static String generateMeetingSummary(TranslationStats stats) {
    final duration = stats.meetingDuration;
    final mostUsed = stats.mostUsedLanguage;
    final accuracy = stats.overallAccuracy;

    return '''
Meeting Summary:
Duration: ${duration.inHours}h ${duration.inMinutes % 60}m
Total Translations: ${stats.totalTranslations}
Speech Time: ${stats.totalSpeechMinutes} minutes
Most Used Language: ${mostUsed != null ? SupportedLanguages.getLanguageName(mostUsed) : 'N/A'}
Average Accuracy: ${formatConfidence(accuracy)}
''';
  }
}