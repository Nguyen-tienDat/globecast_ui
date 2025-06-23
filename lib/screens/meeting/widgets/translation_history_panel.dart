// lib/screens/meeting/widgets/translation_history_panel.dart - ENHANCED GLOBAL VIEW
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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  String _filterBySpeaker = 'all';
  String _filterByLanguage = 'all';
  bool _showOriginalText = true;
  bool _autoScroll = true;

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

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: const BoxDecoration(
          color: GcbAppTheme.surface,
          border: Border(
            left: BorderSide(
              color: GcbAppTheme.surfaceLight,
              width: 1,
            ),
          ),
        ),
        child: Consumer<TranslationService>(
          builder: (context, translationService, child) {
            return Column(
              children: [
                _buildHeader(translationService),
                _buildFilters(translationService),
                Expanded(
                  child: _buildTranscriptionsList(translationService),
                ),
                _buildFooter(translationService),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(TranslationService translationService) {
    final stats = translationService.getTranslationStats();

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
      child: Column(
        children: [
          Row(
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
                      'Global Translation History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'All conversations in all languages',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
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
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Global statistics
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GcbAppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Messages',
                    '${stats['totalTranscriptions']}',
                    Icons.chat_bubble_outline,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[700]),
                Expanded(
                  child: _buildStatItem(
                    'Languages',
                    '${stats['allTargetLanguages'].length}',
                    Icons.language,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[700]),
                Expanded(
                  child: _buildStatItem(
                    'Participants',
                    '${stats['participantsCount']}',
                    Icons.people,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: GcbAppTheme.primary,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters(TranslationService translationService) {
    final allParticipants = translationService.allParticipants.values.toList();
    final allLanguages = translationService.getAllTargetLanguages();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: GcbAppTheme.surface,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Speaker filter
          Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterBySpeaker,
                    dropdownColor: GcbAppTheme.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Speakers'),
                      ),
                      ...allParticipants.map((participant) =>
                          DropdownMenuItem(
                            value: participant.userId,
                            child: Text(participant.displayName),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterBySpeaker = value ?? 'all';
                      });
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Language filter
          Row(
            children: [
              const Icon(Icons.translate, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterByLanguage,
                    dropdownColor: GcbAppTheme.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Languages'),
                      ),
                      ...allLanguages.map((lang) =>
                          DropdownMenuItem(
                            value: lang,
                            child: Row(
                              children: [
                                Text(SupportedLanguages.getLanguageFlag(lang)),
                                const SizedBox(width: 8),
                                Text(SupportedLanguages.getLanguageName(lang)),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterByLanguage = value ?? 'all';
                      });
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Options toggles
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: _showOriginalText,
                      onChanged: (value) {
                        setState(() {
                          _showOriginalText = value ?? true;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    const Expanded(
                      child: Text(
                        'Show original',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Checkbox(
                      value: _autoScroll,
                      onChanged: (value) {
                        setState(() {
                          _autoScroll = value ?? true;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    const Expanded(
                      child: Text(
                        'Auto scroll',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionsList(TranslationService translationService) {
    var transcriptions = translationService.getTranscriptionsForUser();

    // Apply filters
    if (_filterBySpeaker != 'all') {
      transcriptions =
          transcriptions.where((t) => t.speakerId == _filterBySpeaker).toList();
    }

    if (_filterByLanguage != 'all') {
      transcriptions = transcriptions.where((t) =>
      t.originalLanguage == _filterByLanguage ||
          t.translations.containsKey(_filterByLanguage)
      ).toList();
    }

    if (transcriptions.isEmpty) {
      return _buildEmptyState();
    }

    // Auto scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: transcriptions.length,
      itemBuilder: (context, index) {
        final transcription = transcriptions[index];
        return _buildTranscriptionItem(
            translationService, transcription, index);
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start speaking to see translations here',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionItem(TranslationService translationService,
      SpeechTranscription transcription, int index) {
    final isOwnSpeech = transcription.speakerId ==
        translationService.currentUserId;
    final userDisplayText = translationService.getTextForUser(transcription);
    final userDisplayLanguage = translationService.userPreference
        ?.displayLanguage ?? 'en';

    // Check if this is translated content
    final isTranslatedContent = !isOwnSpeech &&
        transcription.originalLanguage != userDisplayLanguage &&
        transcription.hasTranslation(userDisplayLanguage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOwnSpeech
            ? GcbAppTheme.primary.withOpacity(0.1)
            : GcbAppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: isOwnSpeech ? Border.all(
          color: GcbAppTheme.primary.withOpacity(0.3),
          width: 1,
        ) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with speaker info and timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOwnSpeech ? GcbAppTheme.primary : Colors.grey[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transcription.speakerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Language indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SupportedLanguages.getLanguageFlag(
                          transcription.originalLanguage),
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      SupportedLanguages.getLanguageName(
                          transcription.originalLanguage)
                          .substring(0, 3)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Message number
              Text(
                '#${index + 1}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),

              const SizedBox(width: 8),

              // Timestamp
              Text(
                _formatTimestamp(transcription.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main text (translated for user)
          Text(
            userDisplayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
              fontWeight: isOwnSpeech ? FontWeight.w500 : FontWeight.w400,
            ),
          ),

          // Show original text if this is translated and option is enabled
          if (_showOriginalText && isTranslatedContent &&
              userDisplayText != transcription.originalText) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.translate,
                    color: GcbAppTheme.primary,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Original: ${transcription.originalText}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Translation status and available languages
          if (transcription.translations.isNotEmpty || !isOwnSpeech) ...[
            const SizedBox(height: 12),
            _buildTranslationStatus(transcription, translationService),
          ],

          // Confidence indicator for low confidence
          if (transcription.confidence < 0.8) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange[400],
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Low confidence (${(transcription.confidence * 100)
                      .toInt()}%)',
                  style: TextStyle(
                    color: Colors.orange[400],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranslationStatus(SpeechTranscription transcription,
      TranslationService translationService) {
    final availableTranslations = transcription.translations.keys.toList();
    final allTargetLanguages = translationService.getAllTargetLanguages();
    final missingTranslations = allTargetLanguages.where((lang) =>
    lang != transcription.originalLanguage &&
        !transcription.hasTranslation(lang)
    ).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GcbAppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: GcbAppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available translations
          if (availableTranslations.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 12,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Available in:',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: availableTranslations.map((lang) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4,
                              vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                SupportedLanguages.getLanguageFlag(lang),
                                style: const TextStyle(fontSize: 8),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                SupportedLanguages.getLanguageName(lang)
                                    .substring(0, 3)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                  ),
                ),
              ],
            ),
          ],

          // Missing translations
          if (missingTranslations.isNotEmpty) ...[
            if (availableTranslations.isNotEmpty) const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 12,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Translating to:',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: missingTranslations.map((lang) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4,
                              vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                SupportedLanguages.getLanguageFlag(lang),
                                style: const TextStyle(fontSize: 8),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                SupportedLanguages.getLanguageName(lang)
                                    .substring(0, 3)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(TranslationService translationService) {
    final stats = translationService.getTranslationStats();
    final isTranslating = stats['isTranslating'] as bool;
    final pendingTranslations = stats['pendingTranslations'] as int;

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
      child: Column(
        children: [
          // Translation status
          if (isTranslating || pendingTranslations > 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTranslating
                              ? 'Translating conversations...'
                              : 'Processing translations...',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (pendingTranslations > 0)
                          Text(
                            '$pendingTranslations translations pending',
                            style: TextStyle(
                              color: Colors.orange[300],
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          Row(
            children: [
              // Export button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showExportDialog(translationService),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Clear button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showClearDialog(translationService),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Debug button (only in debug mode)
              if (translationService.isServiceHealthy == false)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDebugInfo(translationService),
                    icon: const Icon(Icons.bug_report, size: 16),
                    label: const Text('Debug'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.yellow,
                      side: const BorderSide(color: Colors.yellow),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Service status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: translationService.isServiceHealthy
                      ? Colors.green
                      : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  translationService.isServiceHealthy
                      ? 'Translation service active'
                      : 'Translation service degraded',
                  style: TextStyle(
                    color: translationService.isServiceHealthy
                        ? Colors.green
                        : Colors.red,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                'Updated ${_formatTimestamp(DateTime.now())}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute
          .toString().padLeft(2, '0')}';
    }
  }

  void _showExportDialog(TranslationService translationService) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: GcbAppTheme.surface,
            title: const Text(
              'Export Translation History',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Export feature will be available in a future update. You can currently view and scroll through all conversations in this panel.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: GcbAppTheme.primary),
                ),
              ),
            ],
          ),
    );
  }

  void _showClearDialog(TranslationService translationService) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: GcbAppTheme.surface,
            title: const Text(
              'Clear Translation History',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to clear all translation history? This action cannot be undone.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await translationService.clearTranscriptions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Translation history cleared'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showDebugInfo(TranslationService translationService) {
    translationService.debugCurrentState();
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            backgroundColor: GcbAppTheme.surface,
            title: const Text(
              'Debug Information',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Debug information has been printed to the console. Check the developer console for detailed service status.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: GcbAppTheme.primary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  translationService.forceRetranslateAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Force retranslation initiated'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                child: const Text(
                  'Force Retranslate',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ),
    );
  }
}