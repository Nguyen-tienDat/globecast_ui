// lib/models/subtitle_models.dart - FIXED VERSION
import 'package:flutter/foundation.dart';

/// Language information for the application
class LanguageInfo {
  final String code;
  final String name;
  final String flag;

  const LanguageInfo({
    required this.code,
    required this.name,
    required this.flag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LanguageInfo &&
              runtimeType == other.runtimeType &&
              code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'LanguageInfo{code: $code, name: $name, flag: $flag}';

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'flag': flag,
    };
  }

  // Create from JSON
  factory LanguageInfo.fromJson(Map<String, dynamic> json) {
    return LanguageInfo(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      flag: json['flag'] ?? '',
    );
  }
}

/// Real-time subtitle entry for meeting participants
class SubtitleEntry extends ChangeNotifier {
  final String id;
  final String speakerId;
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final String targetLanguage;
  final double confidence;
  final DateTime timestamp;
  final bool isFinal;

  String? _translatedText;
  bool _isTranslating = false;
  double? _translationConfidence;

  SubtitleEntry({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.targetLanguage,
    required this.confidence,
    required this.timestamp,
    this.isFinal = false,
    String? translatedText,
    bool isTranslating = false,
    double? translationConfidence,
  }) : _translatedText = translatedText,
        _isTranslating = isTranslating,
        _translationConfidence = translationConfidence;

  // Getters
  String? get translatedText => _translatedText;
  bool get isTranslating => _isTranslating;
  double? get translationConfidence => _translationConfidence;

  // Get display text based on language preference
  String get displayText {
    if (originalLanguage == targetLanguage) {
      return originalText;
    }

    if (isTranslating) {
      return 'Translating...';
    }

    return translatedText ?? originalText;
  }

  // Get confidence for display text
  double get displayConfidence {
    if (originalLanguage == targetLanguage) {
      return confidence;
    }
    return translationConfidence ?? confidence;
  }

  // Setters that notify listeners
  set translatedText(String? value) {
    if (_translatedText != value) {
      _translatedText = value;
      notifyListeners();
    }
  }

  set isTranslating(bool value) {
    if (_isTranslating != value) {
      _isTranslating = value;
      notifyListeners();
    }
  }

  set translationConfidence(double? value) {
    if (_translationConfidence != value) {
      _translationConfidence = value;
      notifyListeners();
    }
  }

  // Check if translation is needed
  bool get needsTranslation => originalLanguage != targetLanguage;

  // Get formatted timestamp
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  // Copy with method
  SubtitleEntry copyWith({
    String? id,
    String? speakerId,
    String? speakerName,
    String? originalText,
    String? originalLanguage,
    String? targetLanguage,
    double? confidence,
    DateTime? timestamp,
    bool? isFinal,
    String? translatedText,
    bool? isTranslating,
    double? translationConfidence,
  }) {
    return SubtitleEntry(
      id: id ?? this.id,
      speakerId: speakerId ?? this.speakerId,
      speakerName: speakerName ?? this.speakerName,
      originalText: originalText ?? this.originalText,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
      translatedText: translatedText ?? this.translatedText,
      isTranslating: isTranslating ?? this.isTranslating,
      translationConfidence: translationConfidence ?? this.translationConfidence,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'speakerId': speakerId,
      'speakerName': speakerName,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'targetLanguage': targetLanguage,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'isFinal': isFinal,
      'translatedText': translatedText,
      'isTranslating': isTranslating,
      'translationConfidence': translationConfidence,
    };
  }

  // Create from JSON
  factory SubtitleEntry.fromJson(Map<String, dynamic> json) {
    return SubtitleEntry(
      id: json['id'] ?? '',
      speakerId: json['speakerId'] ?? '',
      speakerName: json['speakerName'] ?? '',
      originalText: json['originalText'] ?? '',
      originalLanguage: json['originalLanguage'] ?? '',
      targetLanguage: json['targetLanguage'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isFinal: json['isFinal'] ?? false,
      translatedText: json['translatedText'],
      isTranslating: json['isTranslating'] ?? false,
      translationConfidence: json['translationConfidence']?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SubtitleEntry &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SubtitleEntry{id: $id, speaker: $speakerName, '
        'original: $originalText, translated: $translatedText, '
        'confidence: $confidence}';
  }
}

/// Meeting language preferences - NEW WORKFLOW
class MeetingLanguageSettings {
  final String userDisplayLanguage; // NEW: Only language user wants to see
  final bool autoTranslateEnabled;
  final bool showOriginalText;
  final bool showConfidenceScores;
  final double minimumConfidenceThreshold;
  final bool subtitlesEnabled;

  const MeetingLanguageSettings({
    this.userDisplayLanguage = 'en', // NEW: Simplified to single language
    this.autoTranslateEnabled = true,
    this.showOriginalText = false,
    this.showConfidenceScores = false,
    this.minimumConfidenceThreshold = 0.5,
    this.subtitlesEnabled = true,
  });

  MeetingLanguageSettings copyWith({
    String? userDisplayLanguage,
    bool? autoTranslateEnabled,
    bool? showOriginalText,
    bool? showConfidenceScores,
    double? minimumConfidenceThreshold,
    bool? subtitlesEnabled,
  }) {
    return MeetingLanguageSettings(
      userDisplayLanguage: userDisplayLanguage ?? this.userDisplayLanguage,
      autoTranslateEnabled: autoTranslateEnabled ?? this.autoTranslateEnabled,
      showOriginalText: showOriginalText ?? this.showOriginalText,
      showConfidenceScores: showConfidenceScores ?? this.showConfidenceScores,
      minimumConfidenceThreshold: minimumConfidenceThreshold ?? this.minimumConfidenceThreshold,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userDisplayLanguage': userDisplayLanguage,
      'autoTranslateEnabled': autoTranslateEnabled,
      'showOriginalText': showOriginalText,
      'showConfidenceScores': showConfidenceScores,
      'minimumConfidenceThreshold': minimumConfidenceThreshold,
      'subtitlesEnabled': subtitlesEnabled,
    };
  }

  factory MeetingLanguageSettings.fromJson(Map<String, dynamic> json) {
    return MeetingLanguageSettings(
      userDisplayLanguage: json['userDisplayLanguage'] ?? 'en',
      autoTranslateEnabled: json['autoTranslateEnabled'] ?? true,
      showOriginalText: json['showOriginalText'] ?? false,
      showConfidenceScores: json['showConfidenceScores'] ?? false,
      minimumConfidenceThreshold: (json['minimumConfidenceThreshold'] ?? 0.5).toDouble(),
      subtitlesEnabled: json['subtitlesEnabled'] ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MeetingLanguageSettings &&
              runtimeType == other.runtimeType &&
              userDisplayLanguage == other.userDisplayLanguage &&
              autoTranslateEnabled == other.autoTranslateEnabled &&
              showOriginalText == other.showOriginalText &&
              showConfidenceScores == other.showConfidenceScores &&
              minimumConfidenceThreshold == other.minimumConfidenceThreshold &&
              subtitlesEnabled == other.subtitlesEnabled;

  @override
  int get hashCode {
    return userDisplayLanguage.hashCode ^
    autoTranslateEnabled.hashCode ^
    showOriginalText.hashCode ^
    showConfidenceScores.hashCode ^
    minimumConfidenceThreshold.hashCode ^
    subtitlesEnabled.hashCode;
  }

  @override
  String toString() {
    return 'MeetingLanguageSettings{display: $userDisplayLanguage, '
        'autoTranslate: $autoTranslateEnabled, subtitles: $subtitlesEnabled}';
  }
}

/// Subtitle display preferences
class SubtitleDisplaySettings {
  final bool showSpeakerNames;
  final bool showTimestamps;
  final double fontSize;
  final String fontFamily;
  final Duration maxDisplayDuration;
  final int maxLinesPerSubtitle;

  const SubtitleDisplaySettings({
    this.showSpeakerNames = true,
    this.showTimestamps = false,
    this.fontSize = 16.0,
    this.fontFamily = 'Inter',
    this.maxDisplayDuration = const Duration(seconds: 5),
    this.maxLinesPerSubtitle = 3,
  });

  SubtitleDisplaySettings copyWith({
    bool? showSpeakerNames,
    bool? showTimestamps,
    double? fontSize,
    String? fontFamily,
    Duration? maxDisplayDuration,
    int? maxLinesPerSubtitle,
  }) {
    return SubtitleDisplaySettings(
      showSpeakerNames: showSpeakerNames ?? this.showSpeakerNames,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      maxDisplayDuration: maxDisplayDuration ?? this.maxDisplayDuration,
      maxLinesPerSubtitle: maxLinesPerSubtitle ?? this.maxLinesPerSubtitle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showSpeakerNames': showSpeakerNames,
      'showTimestamps': showTimestamps,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'maxDisplayDurationMs': maxDisplayDuration.inMilliseconds,
      'maxLinesPerSubtitle': maxLinesPerSubtitle,
    };
  }

  factory SubtitleDisplaySettings.fromJson(Map<String, dynamic> json) {
    return SubtitleDisplaySettings(
      showSpeakerNames: json['showSpeakerNames'] ?? true,
      showTimestamps: json['showTimestamps'] ?? false,
      fontSize: (json['fontSize'] ?? 16.0).toDouble(),
      fontFamily: json['fontFamily'] ?? 'Inter',
      maxDisplayDuration: Duration(milliseconds: json['maxDisplayDurationMs'] ?? 5000),
      maxLinesPerSubtitle: json['maxLinesPerSubtitle'] ?? 3,
    );
  }
}