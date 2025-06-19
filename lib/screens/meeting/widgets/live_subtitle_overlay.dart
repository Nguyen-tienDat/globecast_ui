import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/models/translation_models.dart';
import 'package:globecast_ui/screens/meeting/meeting_screen.dart';
import '../../../services/multilingual_speech_service.dart';
import '../../../services/webrtc_mesh_meeting_service.dart';

class LiveSubtitleOverlay extends StatefulWidget {
  const LiveSubtitleOverlay({super.key});

  @override
  State<LiveSubtitleOverlay> createState() => _LiveSubtitleOverlayState();
}

class _LiveSubtitleOverlayState extends State<LiveSubtitleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Keep track of recent transcriptions
  final int _maxDisplayItems = 3;
  List<SpeechTranscription> _displayedTranscriptions = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        // Get recent transcriptions
        final allTranscriptions = translationService.getTranscriptionsForUser();

        // Filter recent ones (last 30 seconds)
        final now = DateTime.now();
        final recentTranscriptions = allTranscriptions
            .where((t) => now.difference(t.timestamp).inSeconds < 30)
            .toList();

        // Update displayed list
        if (recentTranscriptions.length != _displayedTranscriptions.length ||
            !_areListsEqual(recentTranscriptions, _displayedTranscriptions)) {
          setState(() {
            _displayedTranscriptions = recentTranscriptions
                .take(_maxDisplayItems)
                .toList();
          });

          if (_displayedTranscriptions.isNotEmpty) {
            _fadeController.forward();
          } else {
            _fadeController.reverse();
          }
        }

        if (_displayedTranscriptions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 20,
          right: 20,
          bottom: 140,
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    minHeight: 60,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _displayedTranscriptions.map((transcription) =>
                          _buildSubtitleLine(transcription, translationService)
                      ).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  bool _areListsEqual(List<SpeechTranscription> list1, List<SpeechTranscription> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].originalText != list2[i].originalText ||
          list1[i].isFinal != list2[i].isFinal) {
        return false;
      }
    }
    return true;
  }

  Widget _buildSubtitleLine(SpeechTranscription transcription, TranslationService translationService) {
    final bool isCurrentUser = transcription.speakerId == translationService.currentUserId;
    final String displayText = translationService.getTextForUser(transcription);
    final bool isLatest = _displayedTranscriptions.isNotEmpty &&
        _displayedTranscriptions.last.id == transcription.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? GcbAppTheme.primary.withOpacity(0.8)
                  : Colors.grey[700]?.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCurrentUser ? Icons.person : Icons.person_outline,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  isCurrentUser ? 'You' : transcription.speakerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Subtitle text
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isLatest
                    ? Colors.white.withOpacity(0.95)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                boxShadow: isLatest ? [
                  BoxShadow(
                    color: GcbAppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isLatest ? 16 : 14,
                        fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),

                  // Show loading indicator for non-final text
                  if (isLatest && !transcription.isFinal) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 20,
                      height: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(3, (index) {
                          return Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: GcbAppTheme.primary.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],

                  // Translation indicator
                  if (!isCurrentUser && transcription.originalLanguage != translationService.userPreference?.displayLanguage) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GcbAppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.translate,
                            size: 10,
                            color: GcbAppTheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            SupportedLanguages.getLanguageFlag(
                                translationService.userPreference?.displayLanguage ?? 'en'
                            ),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}