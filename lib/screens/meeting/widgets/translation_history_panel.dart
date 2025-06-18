// lib/screens/meeting/widgets/translation_history_panel.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/models/translation_models.dart';

class TranslationHistoryPanel extends StatefulWidget {
  final VoidCallback onClose;

  const TranslationHistoryPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<TranslationHistoryPanel> createState() => _TranslationHistoryPanelState();
}

class _TranslationHistoryPanelState extends State<TranslationHistoryPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();

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
            Expanded(child: _buildHistoryList()),
            _buildFooter(),
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
              Icons.history,
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
                  'Translation History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'All conversation transcripts',
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

  Widget _buildHistoryList() {
    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        final transcriptions = translationService.getTranscriptionsForUser();

        if (transcriptions.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: transcriptions.length,
          itemBuilder: (context, index) {
            final transcription = transcriptions[index];
            return _buildTranscriptionItem(transcription, translationService);
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
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No conversation yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start speaking to see\ntranslations appear here',
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

  Widget _buildTranscriptionItem(SpeechTranscription transcription, TranslationService translationService) {
    final isCurrentUser = transcription.speakerId == translationService.currentUserId;
    final displayText = translationService.getTextForUser(transcription);
    final userLanguage = translationService.userPreference?.displayLanguage ?? 'en';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker info with timestamp
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
                      isCurrentUser ? Icons.person : Icons.person_outline,
                      color: isCurrentUser ? GcbAppTheme.primary : Colors.grey[400],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCurrentUser ? 'You' : transcription.speakerName,
                      style: TextStyle(
                        color: isCurrentUser ? GcbAppTheme.primary : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(transcription.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (transcription.confidence < 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: transcription.confidence > 0.8
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(transcription.confidence * 100).toInt()}%',
                    style: TextStyle(
                      color: transcription.confidence > 0.8
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Main text content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? GcbAppTheme.primary.withOpacity(0.1)
                  : GcbAppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: isCurrentUser ? Border.all(
                color: GcbAppTheme.primary.withOpacity(0.3),
                width: 1,
              ) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language indicator
                if (!isCurrentUser)
                  Row(
                    children: [
                      Icon(
                        Icons.translate,
                        color: GcbAppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${SupportedLanguages.getLanguageFlag(transcription.originalLanguage)} → ${SupportedLanguages.getLanguageFlag(userLanguage)}',
                        style: const TextStyle(
                          color: GcbAppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${SupportedLanguages.getLanguageName(transcription.originalLanguage)} → ${SupportedLanguages.getLanguageName(userLanguage)}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                if (!isCurrentUser) const SizedBox(height: 8),

                // Display text (original for current user, translated for others)
                Text(
                  displayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

                // Show original text if this is a translation
                if (!isCurrentUser && transcription.originalText != displayText) ...[
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
                              'Original (${SupportedLanguages.getLanguageName(transcription.originalLanguage)})',
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
                          transcription.originalText,
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

  Widget _buildFooter() {
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
      child: Consumer<TranslationService>(
        builder: (context, translationService, child) {
          final transcriptionCount = translationService.transcriptions.length;

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$transcriptionCount messages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Real-time translation active',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Clear history button
              TextButton.icon(
                onPressed: transcriptionCount > 0 ? () async {
                  final result = await _showClearConfirmDialog();
                  if (result == true) {
                    await translationService.clearTranscriptions();
                  }
                } : null,
                icon: Icon(
                  Icons.clear_all,
                  size: 16,
                  color: transcriptionCount > 0 ? Colors.red : Colors.grey,
                ),
                label: Text(
                  'Clear',
                  style: TextStyle(
                    color: transcriptionCount > 0 ? Colors.red : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),

              // Export button
              TextButton.icon(
                onPressed: transcriptionCount > 0 ? () {
                  _exportTranscriptions(translationService);
                } : null,
                icon: Icon(
                  Icons.download,
                  size: 16,
                  color: transcriptionCount > 0 ? GcbAppTheme.primary : Colors.grey,
                ),
                label: Text(
                  'Export',
                  style: TextStyle(
                    color: transcriptionCount > 0 ? GcbAppTheme.primary : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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

  Future<bool?> _showClearConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Clear Translation History',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all conversation transcripts. Are you sure?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _exportTranscriptions(TranslationService translationService) {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${translationService.transcriptions.length} transcriptions'),
        backgroundColor: GcbAppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}