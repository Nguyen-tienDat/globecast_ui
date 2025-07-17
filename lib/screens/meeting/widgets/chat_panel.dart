// lib/screens/meeting/widgets/chat_panel.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../services/chat_service.dart';
import '../../../services/webrtc_mesh_meeting_service.dart';
import '../../../models/chat_models.dart';

class ChatPanel extends StatefulWidget {
  final VoidCallback? onToggleVisibility;

  const ChatPanel({
    super.key,
    this.onToggleVisibility,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChatService();
    });
  }

  Future<void> _initializeChatService() async {
    if (_isInitialized) return;

    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final chatService = context.read<ChatService>();

      if (webrtcService.meetingId != null &&
          webrtcService.userId != null &&
          !chatService.isInitialized) {

        // Lấy tên hiển thị từ danh sách participants
        String displayName = 'User';
        final currentParticipant = webrtcService.participants
            .where((p) => p.id == webrtcService.userId)
            .firstOrNull;

        if (currentParticipant != null) {
          displayName = currentParticipant.name.replaceAll(' (You)', '');
        }

        await chatService.initialize(
          meetingId: webrtcService.meetingId!,
          userId: webrtcService.userId!,
          userName: displayName,
        );

        // Gửi system message rằng user đã tham gia
        await chatService.sendSystemMessage('$displayName đã tham gia chat');

        _isInitialized = true;

        if (kDebugMode) {
          print('✅ Chat service đã khởi tạo cho ${webrtcService.meetingId}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi khởi tạo chat service: $e');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatService, WebRTCMeshMeetingService>(
      builder: (context, chatService, webrtcService, child) {
        // Khởi tạo nếu chưa làm
        if (!_isInitialized && webrtcService.isMeetingActive) {
          _initializeChatService();
        }

        return Container(
          width: 350,
          decoration: BoxDecoration(
            color: GcbAppTheme.surface,
            border: const Border(
              left: BorderSide(
                color: GcbAppTheme.surfaceLight,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header chat
              _buildChatHeader(chatService),

              // Danh sách tin nhắn
              Expanded(
                child: _buildMessagesList(chatService),
              ),

              // Chỉ báo đang gõ
              if (_getTypingText(chatService).isNotEmpty)
                _buildTypingIndicator(chatService),

              // Ô nhập tin nhắn
              _buildMessageInput(chatService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatHeader(ChatService chatService) {
    final participantCount = chatService.participants.length;
    final unreadCount = chatService.unreadCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: GcbAppTheme.surface,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            color: GcbAppTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chat',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (participantCount > 0)
                  Text(
                    '$participantCount người tham gia',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: GcbAppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trạng thái kết nối
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: chatService.isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),

              // Nút ẩn/hiện chat (như nút "-" của Chrome)
              IconButton(
                onPressed: _hideChat,
                icon: const Icon(
                  Icons.remove,
                  color: GcbAppTheme.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                tooltip: 'Ẩn chat',
              ),

              // Tùy chọn khác
              IconButton(
                onPressed: () => _showChatOptions(chatService),
                icon: const Icon(
                  Icons.more_vert,
                  color: GcbAppTheme.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatService chatService) {
    final messages = chatService.messages;

    if (!chatService.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: GcbAppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Đang khởi tạo chat...',
              style: TextStyle(
                color: GcbAppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (!chatService.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: GcbAppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Mất kết nối',
              style: TextStyle(
                color: GcbAppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => chatService.retryConnection(),
              style: ElevatedButton.styleFrom(
                backgroundColor: GcbAppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: GcbAppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có tin nhắn nào',
              style: TextStyle(
                color: GcbAppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Gửi tin nhắn để bắt đầu trò chuyện',
              style: TextStyle(
                color: GcbAppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.isFromUser(chatService.currentUserId ?? '');

        return ChatBubble(
          message: message,
          isMe: isMe,
        );
      },
    );
  }

  Widget _buildTypingIndicator(ChatService chatService) {
    final typingText = _getTypingText(chatService);

    if (typingText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: GcbAppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              typingText,
              style: const TextStyle(
                color: GcbAppTheme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ChatService chatService) {
    final canSend = chatService.isInitialized && chatService.isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        border: Border(
          top: BorderSide(
            color: GcbAppTheme.surface,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: canSend,
              decoration: InputDecoration(
                hintText: canSend ? 'Nhập tin nhắn...' : 'Đang kết nối...',
                hintStyle: const TextStyle(color: GcbAppTheme.textSecondary),
                filled: true,
                fillColor: GcbAppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              minLines: 1,
              onChanged: (text) {
                // Thiết lập trạng thái typing
                if (canSend) {
                  chatService.setTyping(text.isNotEmpty);
                }
              },
              onSubmitted: canSend ? (_) => _sendMessage(chatService) : null,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: canSend && _messageController.text.trim().isNotEmpty
                  ? GcbAppTheme.primary
                  : GcbAppTheme.textSecondary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: canSend ? () => _sendMessage(chatService) : null,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypingText(ChatService chatService) {
    final typingParticipants = chatService.getTypingParticipants();

    if (typingParticipants.isEmpty) return '';

    if (typingParticipants.length == 1) {
      return '${typingParticipants.first.displayName} đang gõ...';
    } else if (typingParticipants.length == 2) {
      return '${typingParticipants.first.displayName} và ${typingParticipants.last.displayName} đang gõ...';
    } else {
      return 'Nhiều người đang gõ...';
    }
  }

  Future<void> _sendMessage(ChatService chatService) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Xóa input ngay lập tức
      _messageController.clear();

      // Dừng typing
      await chatService.setTyping(false);

      // Gửi tin nhắn
      await chatService.sendMessage(text);

      // Đánh dấu tin nhắn đã đọc
      await chatService.markAsRead();

      // Cuộn xuống cuối
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Lỗi khi gửi tin nhắn: $e');
      }

      // Hiển thị lỗi cho user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi tin nhắn: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: () {
                _messageController.text = text;
                _sendMessage(chatService);
              },
            ),
          ),
        );
      }
    }
  }

  void _hideChat() {
    if (widget.onToggleVisibility != null) {
      widget.onToggleVisibility!();
    }

    if (kDebugMode) {
      print('➖ Ẩn chat - chuyển về full screen');
    }
  }

  void _showChatOptions(ChatService chatService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GcbAppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tùy chọn Chat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.mark_chat_read, color: GcbAppTheme.primary),
              title: const Text('Đánh dấu tất cả đã đọc', style: TextStyle(color: Colors.white)),
              onTap: () {
                chatService.markAsRead();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: GcbAppTheme.primary),
              title: const Text('Làm mới kết nối', style: TextStyle(color: Colors.white)),
              onTap: () {
                chatService.retryConnection();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.orange),
              title: const Text('Xóa lịch sử chat', style: TextStyle(color: Colors.white)),
              onTap: () {
                chatService.clearChatHistory();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isSystemMessage = message.type == 'system';

    if (isSystemMessage) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: GcbAppTheme.textSecondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: GcbAppTheme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.25,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  message.senderName ?? 'Không rõ',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: GcbAppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? GcbAppTheme.primary : GcbAppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isMe ? Colors.white : GcbAppTheme.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: GcbAppTheme.textSecondary,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _getStatusIcon(message.status),
                      size: 12,
                      color: _getStatusColor(message.status),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.day}/${time.month}';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Colors.grey;
      case MessageStatus.sent:
        return Colors.grey;
      case MessageStatus.delivered:
        return Colors.blue;
      case MessageStatus.failed:
        return Colors.red;
    }
  }
}