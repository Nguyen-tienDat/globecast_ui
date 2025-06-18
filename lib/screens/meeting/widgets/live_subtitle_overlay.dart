// lib/screens/meeting/widgets/live_subtitle_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/models/translation_models.dart';

class LiveSubtitleOverlay extends StatefulWidget {
  const LiveSubtitleOverlay({super.key});

  @override
  State<LiveSubtitleOverlay> createState() => _LiveSubtitleOverlayState();
}

class _LiveSubtitleOverlayState extends State<LiveSubtitleOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Keep track of recent subtitles (last 3 lines)
  final List<LiveSubtitle> _recentSubtitles = [];
  final int _maxRecentSubtitles = 3;

  // Cache để tránh rebuild không cần thiết
  List<SpeechTranscription>? _lastTranscriptions;
  DateTime? _lastUpdateTime;

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
        final transcriptions = translationService.getTranscriptionsForUser();

        // Kiểm tra xem có cần update không
        if (_shouldUpdateSubtitles(transcriptions)) {
          // Sử dụng SchedulerBinding để defer setState sau build phase
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateRecentSubtitles(transcriptions, translationService);
            }
          });
        }

        if (_recentSubtitles.isEmpty) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 20,
          right: 20,
          bottom: 140, // Above bottom controls
          child: _buildSubtitleContainer(),
        );
      },
    );
  }

  // Kiểm tra xem có cần update subtitles không
  bool _shouldUpdateSubtitles(List<SpeechTranscription> transcriptions) {
    // Nếu chưa có dữ liệu lần trước
    if (_lastTranscriptions == null) {
      _lastTranscriptions = List.from(transcriptions);
      return true;
    }

    // Kiểm tra xem có thay đổi không
    if (_lastTranscriptions!.length != transcriptions.length) {
      _lastTranscriptions = List.from(transcriptions);
      return true;
    }

    // Kiểm tra thời gian update cuối
    final now = DateTime.now();
    if (_lastUpdateTime == null ||
        now.difference(_lastUpdateTime!).inMilliseconds > 500) {
      // Kiểm tra content có thay đổi không
      for (int i = 0; i < transcriptions.length; i++) {
        if (i >= _lastTranscriptions!.length ||
            _lastTranscriptions![i].originalText != transcriptions[i].originalText ||
            _lastTranscriptions![i].isFinal != transcriptions[i].isFinal) {
          _lastTranscriptions = List.from(transcriptions);
          return true;
        }
      }
    }

    return false;
  }

  void _updateRecentSubtitles(List<SpeechTranscription> transcriptions, TranslationService translationService) {
    if (!mounted) return;

    _lastUpdateTime = DateTime.now();

    // Get the latest few transcriptions
    final recentTranscriptions = transcriptions
        .where((t) => t.timestamp.isAfter(DateTime.now().subtract(const Duration(seconds: 30))))
        .toList();

    // Convert to LiveSubtitle objects
    final newSubtitles = recentTranscriptions.map((transcription) {
      return LiveSubtitle(
        id: transcription.id,
        speakerId: transcription.speakerId,
        speakerName: transcription.speakerName,
        text: translationService.getTextForUser(transcription),
        language: translationService.userPreference?.displayLanguage ?? 'en',
        timestamp: transcription.timestamp,
        isCurrentUser: transcription.speakerId == translationService.currentUserId,
        isFinal: transcription.isFinal,
      );
    }).toList();

    // Update recent subtitles list
    if (mounted) {
      setState(() {
        _recentSubtitles.clear();
        _recentSubtitles.addAll(newSubtitles.take(_maxRecentSubtitles));

        if (_recentSubtitles.isNotEmpty) {
          _fadeController.forward();
        } else {
          _fadeController.reverse();
        }
      });

      // Auto-fade out after 10 seconds of no new content
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _recentSubtitles.isNotEmpty) {
          final latestTime = _recentSubtitles.last.timestamp;
          if (DateTime.now().difference(latestTime).inSeconds > 10) {
            if (mounted) {
              _fadeController.reverse();
            }
          }
        }
      });
    }
  }

  Widget _buildSubtitleContainer() {
    return AnimatedBuilder(
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
                stops: const [0.0, 0.3, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _recentSubtitles.map((subtitle) =>
                    _buildSubtitleLine(subtitle)
                ).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitleLine(LiveSubtitle subtitle) {
    final bool isLatest = _recentSubtitles.isNotEmpty && _recentSubtitles.last.id == subtitle.id;
    final bool isCurrentUser = subtitle.isCurrentUser;

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
                if (isCurrentUser)
                  const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 12,
                  )
                else
                  Icon(
                    Icons.person_outline,
                    color: Colors.grey[300],
                    size: 12,
                  ),
                const SizedBox(width: 4),
                Text(
                  isCurrentUser ? 'You' : subtitle.speakerName,
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
                      subtitle.text,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: isLatest ? 16 : 14,
                        fontWeight: isLatest ? FontWeight.w600 : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),

                  if (isLatest && !subtitle.isFinal) ...[
                    const SizedBox(width: 8),
                    _buildTypingIndicator(),
                  ],

                  if (subtitle.language != 'en') ...[
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
                          Icon(
                            Icons.translate,
                            size: 10,
                            color: GcbAppTheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            SupportedLanguages.getLanguageFlag(subtitle.language),
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

  Widget _buildTypingIndicator() {
    return SizedBox(
      width: 20,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              return Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(
                      0.3 + (0.7 * (((_fadeController.value * 3 + index) % 3) / 3))
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}