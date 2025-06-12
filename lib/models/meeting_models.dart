// lib/data/models/meeting_models.dart
// Unified models for the entire application

import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for meeting topology types
enum MeetingTopology { sfu, mesh }

/// Enum for meeting status
enum MeetingStatus { waiting, active, ended }

/// Enum for participant connection status
enum ConnectionStatus { connecting, connected, disconnected, failed }

/// Main meeting model
class MeetingModel {
  final String id;
  final String topic;
  final String hostId;
  final MeetingStatus status;
  final MeetingTopology topology;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int participantCount;
  final int maxParticipants;
  final String? password;
  final Map<String, String> translationLanguages;
  final Map<String, dynamic> settings;

  const MeetingModel({
    required this.id,
    required this.topic,
    required this.hostId,
    required this.status,
    required this.topology,
    required this.createdAt,
    this.endedAt,
    required this.participantCount,
    required this.maxParticipants,
    this.password,
    this.translationLanguages = const {},
    this.settings = const {},
  });

  /// Create from Firestore document
  factory MeetingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeetingModel(
      id: doc.id,
      topic: data['topic'] ?? '',
      hostId: data['hostId'] ?? '',
      status: _parseStatus(data['status']),
      topology: _parseTopology(data['topology']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      participantCount: data['participantCount'] ?? 0,
      maxParticipants: data['maxParticipants'] ?? 50,
      password: data['password'],
      translationLanguages: Map<String, String>.from(data['translationLanguages'] ?? {}),
      settings: Map<String, dynamic>.from(data['settings'] ?? {}),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'topic': topic,
      'hostId': hostId,
      'status': status.name,
      'topology': topology.name,
      'createdAt': FieldValue.serverTimestamp(),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'participantCount': participantCount,
      'maxParticipants': maxParticipants,
      'password': password,
      'translationLanguages': translationLanguages,
      'settings': settings,
    };
  }

  /// Generate meeting ID based on topology
  static String generateMeetingId(MeetingTopology topology) {
    final prefix = topology == MeetingTopology.mesh ? 'GCM' : 'GCS';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$prefix${timestamp.toString().substring(5)}';
  }

  static MeetingStatus _parseStatus(String? status) {
    switch (status) {
      case 'waiting':
        return MeetingStatus.waiting;
      case 'active':
        return MeetingStatus.active;
      case 'ended':
        return MeetingStatus.ended;
      default:
        return MeetingStatus.waiting;
    }
  }

  static MeetingTopology _parseTopology(String? topology) {
    switch (topology) {
      case 'mesh':
        return MeetingTopology.mesh;
      case 'sfu':
        return MeetingTopology.sfu;
      default:
        return MeetingTopology.sfu;
    }
  }

  MeetingModel copyWith({
    String? id,
    String? topic,
    String? hostId,
    MeetingStatus? status,
    MeetingTopology? topology,
    DateTime? createdAt,
    DateTime? endedAt,
    int? participantCount,
    int? maxParticipants,
    String? password,
    Map<String, String>? translationLanguages,
    Map<String, dynamic>? settings,
  }) {
    return MeetingModel(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      topology: topology ?? this.topology,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      participantCount: participantCount ?? this.participantCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      password: password ?? this.password,
      translationLanguages: translationLanguages ?? this.translationLanguages,
      settings: settings ?? this.settings,
    );
  }
}

/// Unified participant model
class ParticipantModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool isMuted;
  final bool isCameraOn;
  final bool isHandRaised;
  final bool isScreenSharing;
  final bool isSpeaking;
  final ConnectionStatus connectionStatus;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final bool isActive;
  final Map<String, dynamic> metadata;

  const ParticipantModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isHost = false,
    this.isMuted = false,
    this.isCameraOn = true,
    this.isHandRaised = false,
    this.isScreenSharing = false,
    this.isSpeaking = false,
    this.connectionStatus = ConnectionStatus.connecting,
    required this.joinedAt,
    this.leftAt,
    this.isActive = true,
    this.metadata = const {},
  });

  /// Create from Firestore document
  factory ParticipantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParticipantModel(
      id: doc.id,
      name: data['displayName'] ?? data['name'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'],
      isHost: data['isHost'] ?? false,
      isMuted: !(data['isAudioEnabled'] ?? true),
      isCameraOn: data['isVideoEnabled'] ?? true,
      isHandRaised: data['isHandRaised'] ?? false,
      isScreenSharing: data['isScreenSharing'] ?? false,
      isSpeaking: data['isSpeaking'] ?? false,
      connectionStatus: _parseConnectionStatus(data['connectionStatus']),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      leftAt: (data['leftAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': name,
      'avatarUrl': avatarUrl,
      'isHost': isHost,
      'isAudioEnabled': !isMuted,
      'isVideoEnabled': isCameraOn,
      'isHandRaised': isHandRaised,
      'isScreenSharing': isScreenSharing,
      'isSpeaking': isSpeaking,
      'connectionStatus': connectionStatus.name,
      'joinedAt': FieldValue.serverTimestamp(),
      'leftAt': leftAt != null ? Timestamp.fromDate(leftAt!) : null,
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  static ConnectionStatus _parseConnectionStatus(String? status) {
    switch (status) {
      case 'connecting':
        return ConnectionStatus.connecting;
      case 'connected':
        return ConnectionStatus.connected;
      case 'disconnected':
        return ConnectionStatus.disconnected;
      case 'failed':
        return ConnectionStatus.failed;
      default:
        return ConnectionStatus.connecting;
    }
  }

  ParticipantModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isHost,
    bool? isMuted,
    bool? isCameraOn,
    bool? isHandRaised,
    bool? isScreenSharing,
    bool? isSpeaking,
    ConnectionStatus? connectionStatus,
    DateTime? joinedAt,
    DateTime? leftAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return ParticipantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isMuted: isMuted ?? this.isMuted,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
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
    return 'ParticipantModel{id: $id, name: $name, isHost: $isHost, isMuted: $isMuted, connectionStatus: $connectionStatus}';
  }
}

/// Chat message model
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final ChatMessageType type;
  final Map<String, dynamic> metadata;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isMe = false,
    this.type = ChatMessageType.text,
    this.metadata = const {},
  });

  /// Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMe: data['isMe'] ?? false,
      type: _parseMessageType(data['type']),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.name,
      'metadata': metadata,
    };
  }

  static ChatMessageType _parseMessageType(String? type) {
    switch (type) {
      case 'text':
        return ChatMessageType.text;
      case 'system':
        return ChatMessageType.system;
      case 'translation':
        return ChatMessageType.translation;
      default:
        return ChatMessageType.text;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ChatMessage &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Chat message types
enum ChatMessageType { text, system, translation }

/// Subtitle model for real-time transcription
class SubtitleModel {
  final String id;
  final String speakerId;
  final String speakerName;
  final String text;
  final String originalLanguage;
  final String translatedLanguage;
  final String? translatedText;
  final DateTime timestamp;
  final bool isFinal;
  final double confidence;

  const SubtitleModel({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.text,
    required this.originalLanguage,
    required this.translatedLanguage,
    this.translatedText,
    required this.timestamp,
    this.isFinal = false,
    this.confidence = 0.0,
  });

  /// Create from Firestore document
  factory SubtitleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubtitleModel(
      id: doc.id,
      speakerId: data['speakerId'] ?? '',
      speakerName: data['speakerName'] ?? 'Unknown',
      text: data['text'] ?? '',
      originalLanguage: data['originalLanguage'] ?? 'english',
      translatedLanguage: data['translatedLanguage'] ?? 'english',
      translatedText: data['translatedText'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFinal: data['isFinal'] ?? false,
      confidence: (data['confidence'] ?? 0.0).toDouble(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'speakerId': speakerId,
      'speakerName': speakerName,
      'text': text,
      'originalLanguage': originalLanguage,
      'translatedLanguage': translatedLanguage,
      'translatedText': translatedText,
      'timestamp': FieldValue.serverTimestamp(),
      'isFinal': isFinal,
      'confidence': confidence,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SubtitleModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}