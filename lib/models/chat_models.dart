// lib/models/chat_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String messageId;
  final String meetingId;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String type;

  // Additional fields for UI (not in database)
  final String? senderName;
  final MessageStatus status;

  ChatMessage({
    required this.messageId,
    required this.meetingId,
    required this.userId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.senderName,
    this.status = MessageStatus.sent,
  });

  // Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      messageId: doc.id,
      meetingId: data['meetingId'] ?? '',
      userId: data['userId'] as String,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'text',
      senderName: data['senderName'], // Optional field for UI
      status: MessageStatus.sent,
    );
  }

  // Create from Firestore data map
  factory ChatMessage.fromMap(Map<String, dynamic> data, String docId) {
    return ChatMessage(
      messageId: docId,
      meetingId: data['meetingId'] ?? '',
      userId: data['userId'] as String,
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'text',
      senderName: data['senderName'], // Optional field for UI
      status: MessageStatus.sent,
    );
  }

  // Convert to Firestore document (matching database schema)
  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'userId': userId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      // Optional UI fields
      if (senderName != null) 'senderName': senderName,
    };
  }

  // Check if message is from current user
  bool isFromUser(String userId) {
    return this.userId == userId;
  }

  // Copy with new values
  ChatMessage copyWith({
    String? messageId,
    String? meetingId,
    String? userId,
    String? content,
    DateTime? timestamp,
    String? type,
    String? senderName,
    MessageStatus? status,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      meetingId: meetingId ?? this.meetingId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      senderName: senderName ?? this.senderName,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(messageId: $messageId, meetingId: $meetingId, userId: $userId, content: $content, timestamp: $timestamp, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.messageId == messageId;
  }

  @override
  int get hashCode => messageId.hashCode;

  // Getter for backward compatibility
  String get senderId => userId;
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  failed,
}

class ChatParticipant {
  final String userId;
  final String displayName;
  final bool isOnline;
  final DateTime lastSeen;
  final bool isTyping;

  ChatParticipant({
    required this.userId,
    required this.displayName,
    this.isOnline = false,
    required this.lastSeen,
    this.isTyping = false,
  });

  factory ChatParticipant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatParticipant(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Unknown',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTyping: data['isTyping'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isTyping': isTyping,
    };
  }

  ChatParticipant copyWith({
    String? userId,
    String? displayName,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isTyping,
  }) {
    return ChatParticipant(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

class ChatRoom {
  final String meetingId;
  final List<ChatMessage> messages;
  final List<ChatParticipant> participants;
  final int unreadCount;
  final DateTime lastActivity;

  ChatRoom({
    required this.meetingId,
    this.messages = const [],
    this.participants = const [],
    this.unreadCount = 0,
    required this.lastActivity,
  });

  ChatRoom copyWith({
    String? meetingId,
    List<ChatMessage>? messages,
    List<ChatParticipant>? participants,
    int? unreadCount,
    DateTime? lastActivity,
  }) {
    return ChatRoom(
      meetingId: meetingId ?? this.meetingId,
      messages: messages ?? this.messages,
      participants: participants ?? this.participants,
      unreadCount: unreadCount ?? this.unreadCount,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}
