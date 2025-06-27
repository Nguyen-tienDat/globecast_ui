// lib/models/translation_message.dart - SEPARATE MODEL FILE
class TranslationMessage {
  final String speakerName;
  final String originalText;
  final String originalLanguage;
  final String translation;
  final String targetLanguage;
  final int confidence;
  final String timestamp;
  final bool isCurrentUser;

  TranslationMessage({
    required this.speakerName,
    required this.originalText,
    required this.originalLanguage,
    required this.translation,
    required this.targetLanguage,
    required this.confidence,
    required this.timestamp,
    required this.isCurrentUser,
  });

  @override
  String toString() {
    return 'TranslationMessage(speaker: $speakerName, original: "$originalText", translation: "$translation")';
  }

  // Helper method to check if translation is available
  bool get hasTranslation => translation.isNotEmpty && translation != originalText;

  // Helper method to get display text based on user preference
  String getDisplayText({bool showOriginal = false}) {
    if (showOriginal || !hasTranslation) {
      return originalText;
    }
    return translation;
  }

  // Create copy with updated fields
  TranslationMessage copyWith({
    String? speakerName,
    String? originalText,
    String? originalLanguage,
    String? translation,
    String? targetLanguage,
    int? confidence,
    String? timestamp,
    bool? isCurrentUser,
  }) {
    return TranslationMessage(
      speakerName: speakerName ?? this.speakerName,
      originalText: originalText ?? this.originalText,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      translation: translation ?? this.translation,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'speakerName': speakerName,
      'originalText': originalText,
      'originalLanguage': originalLanguage,
      'translation': translation,
      'targetLanguage': targetLanguage,
      'confidence': confidence,
      'timestamp': timestamp,
      'isCurrentUser': isCurrentUser,
    };
  }

  // Create from JSON
  factory TranslationMessage.fromJson(Map<String, dynamic> json) {
    return TranslationMessage(
      speakerName: json['speakerName'] ?? '',
      originalText: json['originalText'] ?? '',
      originalLanguage: json['originalLanguage'] ?? 'unknown',
      translation: json['translation'] ?? '',
      targetLanguage: json['targetLanguage'] ?? 'en',
      confidence: json['confidence'] ?? 0,
      timestamp: json['timestamp'] ?? '',
      isCurrentUser: json['isCurrentUser'] ?? false,
    );
  }
}