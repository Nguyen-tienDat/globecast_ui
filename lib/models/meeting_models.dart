// lib/models/meeting_models.dart
class ParticipantModel {
  final String id;
  final String name;
  final bool isSpeaking;
  final bool isMuted;
  final bool isHost;
  final bool isHandRaised;
  final bool isScreenSharing;
  final String? avatarUrl;

  const ParticipantModel({
    required this.id,
    required this.name,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isHost = false,
    this.isHandRaised = false,
    this.isScreenSharing = false,
    this.avatarUrl,
  });

  ParticipantModel copyWith({
    String? id,
    String? name,
    bool? isSpeaking,
    bool? isMuted,
    bool? isHost,
    bool? isHandRaised,
    bool? isScreenSharing,
    String? avatarUrl,
  }) {
    return ParticipantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      isHost: isHost ?? this.isHost,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ParticipantModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ParticipantModel{id: $id, name: $name, isSpeaking: $isSpeaking, isMuted: $isMuted, isHost: $isHost}';
  }
}

class SubtitleModel {
  final String id;
  final String speakerId;
  final String text;
  final String language;
  final DateTime timestamp;

  const SubtitleModel({
    required this.id,
    required this.speakerId,
    required this.text,
    required this.language,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SubtitleModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SubtitleModel{id: $id, speakerId: $speakerId, text: $text, language: $language}';
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isMe = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ChatMessage &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessage{id: $id, senderId: $senderId, senderName: $senderName, text: $text, isMe: $isMe}';
  }
}