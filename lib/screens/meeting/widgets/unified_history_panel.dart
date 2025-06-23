// lib/screens/meeting/widgets/unified_history_panel.dart - COMBINED TRANSCRIPTS + CHAT
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/models/translation_models.dart';

class UnifiedHistoryPanel extends StatefulWidget {
  final VoidCallback onClose;

  const UnifiedHistoryPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<UnifiedHistoryPanel> createState() => _UnifiedHistoryPanelState();
}

class _UnifiedHistoryPanelState extends State<UnifiedHistoryPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  // Tab state
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All Activity', 'Transcriptions', 'Messages'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _closePanel() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        decoration: BoxDecoration(
          color: GcbAppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(child: _buildContent()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[700]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GcbAppTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum,
              color: GcbAppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Transcriptions & Messages',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closePanel,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[700]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: _tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          final isSelected = index == _selectedTabIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? GcbAppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? GcbAppTheme.primary : Colors.grey,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        final transcriptions = translationService.getTranscriptionsForUser();

        if (transcriptions.isEmpty) {
          return _buildEmptyState();
        }

        // Filter based on selected tab
        List<ActivityItem> items = [];

        switch (_selectedTabIndex) {
          case 0: // All Activity
            items = _combineAllActivity(transcriptions);
            break;
          case 1: // Transcriptions only
            items = transcriptions.map((t) => ActivityItem.fromTranscription(t, translationService)).toList();
            break;
          case 2: // Messages only
            items = []; // TODO: Add chat messages when implemented
            break;
        }

        if (items.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildActivityItem(item, translationService);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTabIndex == 0
                ? Icons.forum_outlined
                : _selectedTabIndex == 1
                ? Icons.transcribe_outlined
                : Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTabIndex == 0
                ? 'No activity yet'
                : _selectedTabIndex == 1
                ? 'No transcriptions yet'
                : 'No messages yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTabIndex == 0
                ? 'Start speaking or send a message\nto begin the conversation'
                : _selectedTabIndex == 1
                ? 'Tap the Speech button to start\nrecording and see transcriptions'
                : 'Send your first message\nto start chatting',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<ActivityItem> _combineAllActivity(List<SpeechTranscription> transcriptions) {
    List<ActivityItem> items = [];

    // Add transcriptions
    for (var transcription in transcriptions) {
      items.add(ActivityItem.fromTranscription(transcription,
          Provider.of<TranslationService>(context, listen: false)));
    }

    // TODO: Add chat messages here
    // items.addAll(chatMessages.map((msg) => ActivityItem.fromMessage(msg)));

    // Sort by timestamp
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return items;
  }

  Widget _buildActivityItem(ActivityItem item, TranslationService translationService) {
    final isCurrentUser = item.senderId == translationService.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sender info and timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? GcbAppTheme.primary.withOpacity(0.2)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.type == ActivityType.transcription
                          ? (isCurrentUser ? Icons.record_voice_over : Icons.hearing)
                          : Icons.chat_bubble,
                      color: isCurrentUser ? GcbAppTheme.primary : Colors.grey[400],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCurrentUser ? 'You' : item.senderName,
                      style: TextStyle(
                        color: isCurrentUser ? GcbAppTheme.primary : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.type == ActivityType.transcription && item.originalLanguage != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        SupportedLanguages.getLanguageFlag(item.originalLanguage!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(item.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (item.confidence != null && item.confidence! < 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.confidence! > 0.8
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(item.confidence! * 100).toInt()}%',
                    style: TextStyle(
                      color: item.confidence! > 0.8 ? Colors.green : Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.type == ActivityType.transcription
                  ? (isCurrentUser
                  ? GcbAppTheme.primary.withOpacity(0.1)
                  : GcbAppTheme.surfaceLight)
                  : GcbAppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: item.type == ActivityType.transcription && isCurrentUser
                  ? Border.all(
                color: GcbAppTheme.primary.withOpacity(0.3),
                width: 1,
              )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Translation language indicator for transcriptions
                if (item.type == ActivityType.transcription && !isCurrentUser &&
                    item.originalLanguage != translationService.userPreference?.displayLanguage) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.translate,
                        color: GcbAppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${SupportedLanguages.getLanguageFlag(item.originalLanguage!)} → ${SupportedLanguages.getLanguageFlag(translationService.userPreference?.displayLanguage ?? 'en')}',
                        style: const TextStyle(
                          color: GcbAppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${SupportedLanguages.getLanguageName(item.originalLanguage!)} → ${SupportedLanguages.getLanguageName(translationService.userPreference?.displayLanguage ?? 'en')}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Main text content
                Text(
                  item.displayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

                // Show original text if this is a translation
                if (item.type == ActivityType.transcription &&
                    !isCurrentUser &&
                    item.originalText != null &&
                    item.originalText != item.displayText) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800]?.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.record_voice_over,
                              color: Colors.grey[400],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Original (${SupportedLanguages.getLanguageName(item.originalLanguage!)})',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.originalText!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        border: Border(
          top: BorderSide(
            color: Colors.grey[700]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.grey),
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
              maxLines: 3,
              minLines: 1,
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
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    // TODO: Implement chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat feature will be implemented soon'),
        duration: Duration(seconds: 2),
      ),
    );

    _messageController.clear();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Activity item model for unified display
class ActivityItem {
  final String id;
  final ActivityType type;
  final String senderId;
  final String senderName;
  final String displayText;
  final String? originalText;
  final String? originalLanguage;
  final DateTime timestamp;
  final double? confidence;

  ActivityItem({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.displayText,
    this.originalText,
    this.originalLanguage,
    required this.timestamp,
    this.confidence,
  });

  factory ActivityItem.fromTranscription(SpeechTranscription transcription, TranslationService translationService) {
    return ActivityItem(
      id: transcription.id,
      type: ActivityType.transcription,
      senderId: transcription.speakerId,
      senderName: transcription.speakerName,
      displayText: translationService.getTextForUser(transcription),
      originalText: transcription.originalText,
      originalLanguage: transcription.originalLanguage,
      timestamp: transcription.timestamp,
      confidence: transcription.confidence,
    );
  }

// TODO: Add factory for chat messages
// factory ActivityItem.fromMessage(ChatMessage message) { ... }
}

enum ActivityType { transcription, message }