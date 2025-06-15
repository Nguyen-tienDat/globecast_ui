// lib/models/subtitle_models.dart
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

/// Meeting language preferences
class MeetingLanguageSettings {
  final String userNativeLanguage;
  final String userDisplayLanguage;
  final bool autoTranslateEnabled;
  final bool showOriginalText;
  final bool showConfidenceScores;
  final double minimumConfidenceThreshold;

  const MeetingLanguageSettings({
    this.userNativeLanguage = 'en',
    this.userDisplayLanguage = 'en',
    this.autoTranslateEnabled = true,
    this.showOriginalText = false,
    this.showConfidenceScores = false,
    this.minimumConfidenceThreshold = 0.5,
  });

  MeetingLanguageSettings copyWith({
    String? userNativeLanguage,
    String? userDisplayLanguage,
    bool? autoTranslateEnabled,
    bool? showOriginalText,
    bool? showConfidenceScores,
    double? minimumConfidenceThreshold,
  }) {
    return MeetingLanguageSettings(
      userNativeLanguage: userNativeLanguage ?? this.userNativeLanguage,
      userDisplayLanguage: userDisplayLanguage ?? this.userDisplayLanguage,
      autoTranslateEnabled: autoTranslateEnabled ?? this.autoTranslateEnabled,
      showOriginalText: showOriginalText ?? this.showOriginalText,
      showConfidenceScores: showConfidenceScores ?? this.showConfidenceScores,
      minimumConfidenceThreshold: minimumConfidenceThreshold ?? this.minimumConfidenceThreshold,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userNativeLanguage': userNativeLanguage,
      'userDisplayLanguage': userDisplayLanguage,
      'autoTranslateEnabled': autoTranslateEnabled,
      'showOriginalText': showOriginalText,
      'showConfidenceScores': showConfidenceScores,
      'minimumConfidenceThreshold': minimumConfidenceThreshold,
    };
  }

  factory MeetingLanguageSettings.fromJson(Map<String, dynamic> json) {
    return MeetingLanguageSettings(
      userNativeLanguage: json['userNativeLanguage'] ?? 'en',
      userDisplayLanguage: json['userDisplayLanguage'] ?? 'en',
      autoTranslateEnabled: json['autoTranslateEnabled'] ?? true,
      showOriginalText: json['showOriginalText'] ?? false,
      showConfidenceScores: json['showConfidenceScores'] ?? false,
      minimumConfidenceThreshold: (json['minimumConfidenceThreshold'] ?? 0.5).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MeetingLanguageSettings &&
              runtimeType == other.runtimeType &&
              userNativeLanguage == other.userNativeLanguage &&
              userDisplayLanguage == other.userDisplayLanguage &&
              autoTranslateEnabled == other.autoTranslateEnabled &&
              showOriginalText == other.showOriginalText &&
              showConfidenceScores == other.showConfidenceScores &&
              minimumConfidenceThreshold == other.minimumConfidenceThreshold;

  @override
  int get hashCode {
    return userNativeLanguage.hashCode ^
    userDisplayLanguage.hashCode ^
    autoTranslateEnabled.hashCode ^
    showOriginalText.hashCode ^
    showConfidenceScores.hashCode ^
    minimumConfidenceThreshold.hashCode;
  }

  @override
  String toString() {
    return 'MeetingLanguageSettings{native: $userNativeLanguage, '
        'display: $userDisplayLanguage, autoTranslate: $autoTranslateEnabled}';
  }
}