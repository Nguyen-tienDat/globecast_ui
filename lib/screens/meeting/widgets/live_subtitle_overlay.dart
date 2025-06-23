// lib/screens/meeting/widgets/live_subtitle_overlay.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/models/translation_models.dart';
import 'dart:async';

class LiveSubtitleOverlay extends StatefulWidget {
  const LiveSubtitleOverlay({super.key});

  @override
  State<LiveSubtitleOverlay> createState() => _LiveSubtitleOverlayState();
}

class _LiveSubtitleOverlayState extends State<LiveSubtitleOverlay>
    with TickerProviderStateMixin {
  bool _isVisible = true;
  bool _isExpanded = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Display preferences
  int _maxVisibleMessages = 3;
  bool _showSpeakerNames = true;
  bool _showLanguageFlags = true;
  bool _showTimestamps = false;
  bool _autoHide = false;

  // Auto-hide timer
  Timer? _autoHideTimer;
  static const Duration _autoHideDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _resetAutoHideTimer() {
    if (!_autoHide) return;

    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideDuration, () {
      if (mounted && _isVisible) {
        _hideSubtitles();
      }
    });
  }

  void _hideSubtitles() {
    setState(() {
      _isVisible = false;
    });

    Timer(const Duration(seconds: 3), () {
      if (mounted && !_isVisible) {
        setState(() {
          _isVisible = true;
        });
      }
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _maxVisibleMessages = 10;
      } else {
        _maxVisibleMessages = 3;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return _buildMinimizedIndicator();
    }

    return Consumer2<TranslationService, MultilingualSpeechService>(
      builder: (context, translationService, speechService, child) {
        final allTranscriptions = translationService.getTranscriptionsForUser();
        final recentTranscriptions = _getRecentTranscriptions(allTranscriptions);
        final hasLiveText = speechService.isListening && speechService.text.isNotEmpty;

        if (recentTranscriptions.isEmpty && !hasLiveText) {
          return _buildEmptyState();
        }

        _resetAutoHideTimer();

        return Positioned(
          bottom: 160,
          left: 20,
          right: 20,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildSubtitleContainer(
                translationService,
                speechService,
                recentTranscriptions,
                hasLiveText,
              ),
            ),
          ),
        );
      },
    );
  }

  List<SpeechTranscription> _getRecentTranscriptions(List<SpeechTranscription> transcriptions) {
    if (transcriptions.isEmpty) return [];

    final sorted = List<SpeechTranscription>.from(transcriptions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final recent = sorted.take(_maxVisibleMessages).toList();
    return recent.reversed.toList();
  }

  Widget _buildMinimizedIndicator() {
    return Positioned(
      bottom: 160,
      right: 20,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isVisible = true;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GcbAppTheme.primary.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.subtitles,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Consumer<TranslationService>(
                builder: (context, translationService, child) {
                  final count = translationService.transcriptions.length;
                  return Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Positioned(
      bottom: 160,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.translate,
              color: GcbAppTheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Global Live Translation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Start speaking to see real-time translations',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Consumer<TranslationService>(
              builder: (context, translationService, child) {
                final languages = translationService.getAllTargetLanguages();
                return Wrap(
                  spacing: 2,
                  children: languages.take(4).map((lang) => Text(
                    SupportedLanguages.getLanguageFlag(lang),
                    style: const TextStyle(fontSize: 12),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleContainer(
      TranslationService translationService,
      MultilingualSpeechService speechService,
      List<SpeechTranscription> recentTranscriptions,
      bool hasLiveText,
      ) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: _isExpanded ? 400 : 200,
        minHeight: 80,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GcbAppTheme.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(translationService, recentTranscriptions.length),
          Flexible(
            child: _buildMessagesArea(
              translationService,
              speechService,
              recentTranscriptions,
              hasLiveText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TranslationService translationService, int messageCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: GcbAppTheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.subtitles,
            color: GcbAppTheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'Live Translation',
            style: TextStyle(
              color: GcbAppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),

          // Active languages indicator
          Consumer<TranslationService>(
            builder: (context, translationService, child) {
              final languages = translationService.getAllTargetLanguages();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language, color: Colors.green, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      '${languages.length}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(),

          // Message count
          Text(
            '$messageCount messages',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),

          const SizedBox(width: 8),

          // Settings button
          GestureDetector(
            onTap: _showSettingsDialog,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Expand/collapse button
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Hide button
          GestureDetector(
            onTap: _hideSubtitles,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.visibility_off,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(
      TranslationService translationService,
      MultilingualSpeechService speechService,
      List<SpeechTranscription> recentTranscriptions,
      bool hasLiveText,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Historical messages
          ...recentTranscriptions.map((transcription) =>
              _buildTranscriptionItem(translationService, transcription)
          ).toList(),

          // Current live speech (if speaking)
          if (hasLiveText)
            _buildLiveSpeechItem(translationService, speechService),
        ],
      ),
    );
  }

  Widget _buildTranscriptionItem(TranslationService translationService, SpeechTranscription transcription) {
    final displayText = translationService.getTextForUser(transcription);
    final isOwnSpeech = transcription.speakerId == translationService.currentUserId;
    final userPreference = translationService.userPreference;

    final isTranslated = !isOwnSpeech &&
        userPreference != null &&
        transcription.originalLanguage != userPreference.displayLanguage &&
        transcription.hasTranslation(userPreference.displayLanguage);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOwnSpeech
            ? GcbAppTheme.primary.withOpacity(0.15)
            : Colors.grey[900]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: isOwnSpeech ? Border.all(
          color: GcbAppTheme.primary.withOpacity(0.3),
          width: 1,
        ) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speaker and language info
          if (_showSpeakerNames || _showLanguageFlags || _showTimestamps)
            Row(
              children: [
                // Speaker name
                if (_showSpeakerNames)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOwnSpeech ? GcbAppTheme.primary : Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transcription.speakerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (_showSpeakerNames && _showLanguageFlags)
                  const SizedBox(width: 6),

                // Language indicators
                if (_showLanguageFlags) ...[
                  if (!isOwnSpeech && isTranslated) ...[
                    Text(
                      SupportedLanguages.getLanguageFlag(transcription.originalLanguage),
                      style: const TextStyle(fontSize: 9),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward, color: Colors.grey, size: 6),
                    const SizedBox(width: 2),
                    Text(
                      SupportedLanguages.getLanguageFlag(userPreference!.displayLanguage),
                      style: const TextStyle(fontSize: 9),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.translate,
                      color: GcbAppTheme.primary,
                      size: 8,
                    ),
                  ] else if (!isOwnSpeech) ...[
                    Text(
                      SupportedLanguages.getLanguageFlag(transcription.originalLanguage),
                      style: const TextStyle(fontSize: 9),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'ORIG',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],

                const Spacer(),

                // Timestamp
                if (_showTimestamps)
                  Text(
                    _formatTimestamp(transcription.timestamp),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),

          if (_showSpeakerNames || _showLanguageFlags || _showTimestamps)
            const SizedBox(height: 6),

          // Main text content
          Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.3,
              fontWeight: isOwnSpeech ? FontWeight.w500 : FontWeight.w400,
            ),
            maxLines: _isExpanded ? null : 2,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),

          // Confidence indicator for low confidence
          if (transcription.confidence < 0.8) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange[400],
                  size: 10,
                ),
                const SizedBox(width: 4),
                Text(
                  'Low confidence ${(transcription.confidence * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.orange[400],
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveSpeechItem(TranslationService translationService, MultilingualSpeechService speechService) {
    final userPreference = translationService.userPreference;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),

              // Speaking language
              Text(
                SupportedLanguages.getLanguageFlag(userPreference?.speakingLanguage ?? 'vi'),
                style: const TextStyle(fontSize: 9),
              ),
              const SizedBox(width: 4),
              Text(
                SupportedLanguages.getLanguageName(userPreference?.speakingLanguage ?? 'vi'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                ),
              ),

              const Spacer(),

              // 🎯 FIXED: Simple status instead of remainingTime
              Text(
                speechService.isListening ? 'Recording...' : 'Ready',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Live text with typing effect
          Row(
            children: [
              Expanded(
                child: Text(
                  speechService.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ),

              // Typing cursor animation
              AnimatedBuilder(
                animation: _fadeController,
                builder: (context, child) {
                  return Opacity(
                    opacity: (_fadeController.value * 2) % 1.0,
                    child: const Text(
                      '|',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // Confidence and word count
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.mic,
                color: Colors.red,
                size: 10,
              ),
              const SizedBox(width: 4),
              Text(
                '${(speechService.confidence * 100).toInt()}% confidence',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${speechService.text.split(' ').where((w) => w.isNotEmpty).length} words',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Subtitle Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Max visible messages
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Max messages:',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownButton<int>(
                      value: _maxVisibleMessages,
                      dropdownColor: GcbAppTheme.surface,
                      items: [2, 3, 5, 10].map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _maxVisibleMessages = value ?? 3;
                        });
                        setState(() {
                          _maxVisibleMessages = value ?? 3;
                        });
                      },
                    ),
                  ],
                ),

                // Show speaker names
                CheckboxListTile(
                  title: const Text(
                    'Show speaker names',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  value: _showSpeakerNames,
                  onChanged: (value) {
                    setStateDialog(() {
                      _showSpeakerNames = value ?? true;
                    });
                    setState(() {
                      _showSpeakerNames = value ?? true;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),

                // Show language flags
                CheckboxListTile(
                  title: const Text(
                    'Show language flags',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  value: _showLanguageFlags,
                  onChanged: (value) {
                    setStateDialog(() {
                      _showLanguageFlags = value ?? true;
                    });
                    setState(() {
                      _showLanguageFlags = value ?? true;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),

                // Show timestamps
                CheckboxListTile(
                  title: const Text(
                    'Show timestamps',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  value: _showTimestamps,
                  onChanged: (value) {
                    setStateDialog(() {
                      _showTimestamps = value ?? false;
                    });
                    setState(() {
                      _showTimestamps = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),

                // Auto-hide
                CheckboxListTile(
                  title: const Text(
                    'Auto-hide after 5s',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  value: _autoHide,
                  onChanged: (value) {
                    setStateDialog(() {
                      _autoHide = value ?? false;
                    });
                    setState(() {
                      _autoHide = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Done',
              style: TextStyle(color: GcbAppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}