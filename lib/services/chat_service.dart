// lib/services/chat_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_models.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Current state
  String? _currentMeetingId;
  String? _currentUserId;
  String? _currentUserName;
  bool _isInitialized = false;
  bool _isConnected = false;

  // Chat data
  final List<ChatMessage> _messages = [];
  final List<ChatParticipant> _participants = [];
  int _unreadCount = 0;
  bool _isTyping = false;
  Timer? _typingTimer;

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Getters
  String? get currentMeetingId => _currentMeetingId;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ChatParticipant> get participants => List.unmodifiable(_participants);
  int get unreadCount => _unreadCount;
  bool get isTyping => _isTyping;

  // Initialize chat service
  Future<void> initialize({
    required String meetingId,
    required String userId,
    required String userName,
  }) async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ Chat service đã được khởi tạo rồi');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔧 Đang khởi tạo Chat Service...');
        print('   Meeting: $meetingId');
        print('   User: $userName ($userId)');
      }

      _currentMeetingId = meetingId;
      _currentUserId = userId;
      _currentUserName = userName;

      // Thêm user hiện tại vào danh sách participants
      await _addParticipant();

      // Bắt đầu lắng nghe messages và participants
      _listenForMessages();
      _listenForParticipants();

      _isInitialized = true;
      _isConnected = true;

      if (kDebugMode) {
        print('✅ Chat Service khởi tạo thành công');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi khởi tạo Chat Service: $e');
      }
      throw Exception('Không thể khởi tạo chat service: $e');
    }
  }

  // Thêm user hiện tại vào participants theo cấu trúc Firebase rules
  Future<void> _addParticipant() async {
    if (_currentMeetingId == null || _currentUserId == null || _currentUserName == null) {
      return;
    }

    try {
      // Cập nhật participant data theo cấu trúc Firebase rules
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('participants')
          .doc(_currentUserId)
          .set({
        'userId': _currentUserId,
        'displayName': _currentUserName,
        'isOnline': true,
        'isActive': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'isTyping': false,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ Đã thêm chat participant: $_currentUserName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi thêm chat participant: $e');
      }
    }
  }

  // Lắng nghe messages theo cấu trúc Firebase rules đúng
  void _listenForMessages() {
    if (_currentMeetingId == null) return;

    if (kDebugMode) {
      print('👂 Đang lắng nghe chat messages...');
    }

    // Lắng nghe messages subcollection trong meeting
    final subscription = _firestore
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final message = ChatMessage.fromFirestore(change.doc);

            // Thêm message nếu chưa tồn tại
            if (!_messages.any((m) => m.messageId == message.messageId)) {
              _messages.insert(0, message);

              // Tăng số lượng tin nhắn chưa đọc nếu không phải từ user hiện tại
              if (message.userId != _currentUserId) {
                _unreadCount++;
              }

              if (kDebugMode) {
                print('📨 Tin nhắn mới từ ${message.senderName ?? message.userId}: ${message.content}');
              }
            }
          }
        }

        // Sắp xếp messages theo thời gian (mới nhất trước)
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Chỉ giữ lại 100 tin nhắn gần nhất
        if (_messages.length > 100) {
          _messages.removeRange(100, _messages.length);
        }

        notifyListeners();
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Lỗi khi lắng nghe messages: $error');
        }
        _isConnected = false;
        notifyListeners();
      },
    );

    _subscriptions.add(subscription);
  }

  // Lắng nghe participants
  void _listenForParticipants() {
    if (_currentMeetingId == null) return;

    if (kDebugMode) {
      print('👂 Đang lắng nghe chat participants...');
    }

    final subscription = _firestore
        .collection('meetings')
        .doc(_currentMeetingId)
        .collection('participants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
        _participants.clear();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final participant = ChatParticipant(
            userId: data['userId'] ?? doc.id,
            displayName: data['displayName'] ?? 'Unknown',
            isOnline: data['isOnline'] ?? false,
            lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
            isTyping: data['isTyping'] ?? false,
          );
          _participants.add(participant);
        }

        if (kDebugMode) {
          print('👥 Cập nhật chat participants: ${_participants.length}');
        }

        notifyListeners();
      },
      onError: (error) {
        if (kDebugMode) {
          print('❌ Lỗi khi lắng nghe participants: $error');
        }
      },
    );

    _subscriptions.add(subscription);
  }

  // Gửi tin nhắn text theo cấu trúc Firebase rules
  Future<void> sendMessage(String content) async {
    if (_currentMeetingId == null || _currentUserId == null || _currentUserName == null) {
      throw Exception('Chat service chưa được khởi tạo');
    }

    if (content.trim().isEmpty) {
      throw Exception('Tin nhắn không được để trống');
    }

    try {
      final messageId = _uuid.v4();
      final now = DateTime.now();

      final message = ChatMessage(
        messageId: messageId,
        meetingId: _currentMeetingId!,
        userId: _currentUserId!,
        content: content.trim(),
        timestamp: now,
        type: 'text',
        senderName: _currentUserName!,
        status: MessageStatus.sending,
      );

      // Thêm vào local messages ngay lập tức (optimistic update)
      _messages.insert(0, message);
      notifyListeners();

      // Gửi lên Firestore theo cấu trúc Firebase rules
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('messages')
          .doc(messageId)
          .set(message.toFirestore());

      // Cập nhật trạng thái message thành sent
      final sentMessage = message.copyWith(status: MessageStatus.sent);
      final index = _messages.indexWhere((m) => m.messageId == messageId);
      if (index != -1) {
        _messages[index] = sentMessage;
        notifyListeners();
      }

      if (kDebugMode) {
        print('📤 Tin nhắn đã gửi: $content');
      }

    } catch (e) {
      // Cập nhật trạng thái message thành failed
      final index = _messages.indexWhere((m) => m.userId == _currentUserId && m.content == content.trim());
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
        notifyListeners();
      }

      if (kDebugMode) {
        print('❌ Lỗi khi gửi tin nhắn: $e');
      }
      throw Exception('Không thể gửi tin nhắn: $e');
    }
  }

  // Gửi system message (như user tham gia/rời khỏi)
  Future<void> sendSystemMessage(String content) async {
    if (_currentMeetingId == null) return;

    try {
      final messageId = _uuid.v4();
      final now = DateTime.now();

      final message = ChatMessage(
        messageId: messageId,
        meetingId: _currentMeetingId!,
        userId: 'system',
        content: content,
        timestamp: now,
        type: 'system',
        senderName: 'System',
        status: MessageStatus.sent,
      );

      // Gửi lên Firestore theo cấu trúc Firebase rules
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('messages')
          .doc(messageId)
          .set(message.toFirestore());

      if (kDebugMode) {
        print('📢 System message đã gửi: $content');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi gửi system message: $e');
      }
    }
  }

  // Thiết lập trạng thái typing
  Future<void> setTyping(bool isTyping) async {
    if (_currentMeetingId == null || _currentUserId == null) return;

    if (_isTyping == isTyping) return; // Không thay đổi

    _isTyping = isTyping;

    try {
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('participants')
          .doc(_currentUserId)
          .update({
        'isTyping': isTyping,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // Tự động dừng typing sau 3 giây
      if (isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          setTyping(false);
        });
      } else {
        _typingTimer?.cancel();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi thiết lập trạng thái typing: $e');
      }
    }
  }

  // Đánh dấu tin nhắn đã đọc
  Future<void> markAsRead() async {
    if (_unreadCount == 0) return;

    _unreadCount = 0;
    notifyListeners();

    if (kDebugMode) {
      print('✅ Các tin nhắn đã được đánh dấu đã đọc');
    }
  }

  // Lấy danh sách participants đang typing (trừ user hiện tại)
  List<ChatParticipant> getTypingParticipants() {
    return _participants
        .where((p) => p.isTyping && p.userId != _currentUserId)
        .toList();
  }

  // Xóa lịch sử chat (chỉ cho user hiện tại)
  Future<void> clearChatHistory() async {
    _messages.clear();
    _unreadCount = 0;
    notifyListeners();

    if (kDebugMode) {
      print('🗑️ Lịch sử chat đã được xóa');
    }
  }

  // Rời khỏi phòng chat (đặt user thành offline)
  Future<void> leaveChatRoom() async {
    if (_currentMeetingId == null || _currentUserId == null) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(_currentMeetingId)
          .collection('participants')
          .doc(_currentUserId)
          .update({
        'isOnline': false,
        'isTyping': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('👋 Đã rời khỏi phòng chat');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi rời khỏi phòng chat: $e');
      }
    }
  }

  // Dọn dẹp tài nguyên
  Future<void> dispose() async {
    if (kDebugMode) {
      print('🧹 Đang dọn dẹp Chat Service...');
    }

    // Dừng typing timer
    _typingTimer?.cancel();

    // Đặt user thành offline
    await leaveChatRoom();

    // Hủy các subscriptions
    for (var subscription in _subscriptions) {
      try {
        await subscription.cancel();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Lỗi khi hủy subscription: $e');
        }
      }
    }
    _subscriptions.clear();

    // Xóa dữ liệu
    _messages.clear();
    _participants.clear();
    _unreadCount = 0;
    _isTyping = false;

    // Reset trạng thái
    _currentMeetingId = null;
    _currentUserId = null;
    _currentUserName = null;
    _isInitialized = false;
    _isConnected = false;

    super.dispose();
  }

  // Thử kết nối lại
  Future<void> retryConnection() async {
    if (_currentMeetingId == null || _currentUserId == null || _currentUserName == null) {
      return;
    }

    try {
      if (kDebugMode) {
        print('🔄 Đang thử kết nối lại chat...');
      }

      _isConnected = false;
      notifyListeners();

      // Hủy các subscriptions hiện tại
      for (var subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();

      // Khởi động lại listeners
      _listenForMessages();
      _listenForParticipants();

      _isConnected = true;
      notifyListeners();

      if (kDebugMode) {
        print('✅ Kết nối chat đã được khôi phục');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi thử kết nối lại: $e');
      }
    }
  }
}