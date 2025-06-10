// lib/screens/meeting/widgets/chat_panel.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

// FIXED: Import correct models and service
import '../../../models/meeting_models.dart';
import '../../../services/sfu_server/sfu_meeting_service.dart';
import '../controller.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  late MeetingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Provider.of<MeetingController>(context, listen: false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Use SFU service instead of legacy service
    final messages = Provider.of<SFUMeetingService>(context).messages;

    return Container(
      decoration: const BoxDecoration(
        color: GcbAppTheme.surface,
        border: Border(
          left: BorderSide(
            color: GcbAppTheme.surfaceLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chat (${messages.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _controller.toggleChat(); // Close chat panel
                  },
                  icon: const Icon(
                    Icons.close,
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
          ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start the conversation!',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return _ChatBubble(message: message);
              },
            ),
          ),

          // Message input
          Container(
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
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
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
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    minLines: 1,
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: GcbAppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
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
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    // Use controller to send message
    _controller.sendMessage(_messageController.text.trim());
    _messageController.clear();
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.25,
        ),
        child: Column(
          crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!message.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  message.senderName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: GcbAppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: message.isMe ? GcbAppTheme.primary : GcbAppTheme.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: message.isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: message.isMe ? Colors.white : GcbAppTheme.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, right: 12),
              child: Text(
                _formatTime(message.timestamp),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: GcbAppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}