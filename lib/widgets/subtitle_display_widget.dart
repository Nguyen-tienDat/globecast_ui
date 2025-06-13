// lib/widgets/subtitle_display_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subtitle_models.dart';
import '../services/webrtc_mesh_meeting_service.dart';
import '../theme/app_theme.dart';

class SubtitleDisplayWidget extends StatefulWidget {
  final bool isVisible;
  final double maxHeight;
  final EdgeInsets padding;

  const SubtitleDisplayWidget({
    Key? key,
    this.isVisible = true,
    this.maxHeight = 150.0,
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  State<SubtitleDisplayWidget> createState() => _SubtitleDisplayWidgetState();
}

class _SubtitleDisplayWidgetState extends State<SubtitleDisplayWidget>
    with TickerProviderStateMixin {

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    if (widget.isVisible) {
      _slideController.forward();
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(SubtitleDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _slideController.forward();
        _fadeController.forward();
      } else {
        _slideController.reverse();
        _fadeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: Consumer<WebRTCMeshMeetingService>(
            builder: (context, webrtcService, child) {
              final whisperService = webrtcService.whisperService;
              final subtitles = whisperService?.currentSubtitles ?? <String, SubtitleEntry>{};
              final isConnected = whisperService?.isConnected ?? false;
              final isProcessing = whisperService?.isProcessing ?? false;
              final userDisplayLanguage = webrtcService.userDisplayLanguage;

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected
                        ? GcbAppTheme.primary.withOpacity(0.4)
                        : Colors.red.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with connection status
                    _buildHeader(isConnected, isProcessing, userDisplayLanguage),

                    // Subtitles content
                    if (subtitles.isEmpty)
                      _buildEmptyState(isConnected)
                    else
                      _buildSubtitlesList(subtitles),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isConnected, bool isProcessing, String displayLanguage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected
            ? GcbAppTheme.primary.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Connection status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red).withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: isProcessing
                ? Container(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
                : null,
          ),

          const SizedBox(width: 12),

          // Status text
          Expanded(
            child: Text(
              isConnected
                  ? isProcessing
                  ? '🎤 Processing speech...'
                  : '🌐 Live Translation Ready'
                  : '⚠️ Connecting to translation service...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Language indicator
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: GcbAppTheme.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GcbAppTheme.primary.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.translate,
                    color: GcbAppTheme.primary,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    displayLanguage.toUpperCase(),
                    style: const TextStyle(
                      color: GcbAppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isConnected
                  ? GcbAppTheme.primary.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.mic_outlined : Icons.mic_off_outlined,
              color: isConnected ? GcbAppTheme.primary : Colors.grey[400],
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isConnected
                ? 'Ready for live translation!'
                : 'Connecting to translation service...',
            style: TextStyle(
              color: isConnected ? Colors.white : Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isConnected
                ? 'Start speaking to see real-time subtitles appear here'
                : 'Please wait while we establish connection',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesList(Map<String, SubtitleEntry> subtitles) {
    final sortedEntries = subtitles.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight - 60),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: sortedEntries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = sortedEntries[index];
          return _buildSubtitleEntry(entry);
        },
      ),
    );
  }

  Widget _buildSubtitleEntry(SubtitleEntry entry) {
    return AnimatedBuilder(
      animation: entry,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, animation, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * animation),
              child: Opacity(
                opacity: animation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: entry.isTranslating
                          ? Colors.orange.withOpacity(0.4)
                          : Colors.green.withOpacity(0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (entry.isTranslating ? Colors.orange : Colors.green)
                            .withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Speaker info header
                      Row(
                        children: [
                          // Speaker avatar
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: GcbAppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: GcbAppTheme.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                entry.speakerName.isNotEmpty
                                    ? entry.speakerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Speaker name and language
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.speakerName,
                                  style: const TextStyle(
                                    color: GcbAppTheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${entry.originalLanguage.toUpperCase()} → ${entry.targetLanguage.toUpperCase()}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Translation status
                          if (entry.needsTranslation)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: entry.isTranslating
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: entry.isTranslating ? Colors.orange : Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (entry.isTranslating)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.orange,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.green,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.isTranslating ? 'Translating' : 'Translated',
                                    style: TextStyle(
                                      color: entry.isTranslating ? Colors.orange : Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(width: 8),

                          // Timestamp
                          Text(
                            entry.formattedTime,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Subtitle text
                      Text(
                        entry.displayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Confidence indicator
                      if (entry.displayConfidence > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: entry.displayConfidence,
                                  backgroundColor: Colors.grey[700],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    entry.displayConfidence > 0.8
                                        ? Colors.green
                                        : entry.displayConfidence > 0.6
                                        ? Colors.orange
                                        : Colors.red,
                                  ),
                                  minHeight: 3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(entry.displayConfidence * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Quick subtitle overlay for minimal display
class QuickSubtitleOverlay extends StatelessWidget {
  final SubtitleEntry? currentSubtitle;
  final bool isVisible;

  const QuickSubtitleOverlay({
    Key? key,
    this.currentSubtitle,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible || currentSubtitle == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 140,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: currentSubtitle!,
        builder: (context, child) {
          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, animation, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - animation)),
                child: Opacity(
                  opacity: animation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentSubtitle!.isTranslating
                            ? Colors.orange.withOpacity(0.6)
                            : Colors.green.withOpacity(0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Speaker info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: GcbAppTheme.primary,
                              child: Text(
                                currentSubtitle!.speakerName.isNotEmpty
                                    ? currentSubtitle!.speakerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                currentSubtitle!.speakerName,
                                style: const TextStyle(
                                  color: GcbAppTheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (currentSubtitle!.isTranslating)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Subtitle text
                        Text(
                          currentSubtitle!.displayText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}