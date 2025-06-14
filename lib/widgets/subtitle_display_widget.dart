// lib/widgets/subtitle_display_widget.dart (ENHANCED VERSION)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subtitle_models.dart';
import '../services/webrtc_mesh_meeting_service.dart';
import '../theme/app_theme.dart';

class SubtitleDisplayWidget extends StatefulWidget {
  final bool isVisible;
  final double maxHeight;
  final EdgeInsets padding;
  final bool isMinimized;
  final VoidCallback? onToggleMinimize;

  const SubtitleDisplayWidget({
    Key? key,
    this.isVisible = true,
    this.maxHeight = 150.0,
    this.padding = const EdgeInsets.all(16.0),
    this.isMinimized = false,
    this.onToggleMinimize,
  }) : super(key: key);

  @override
  State<SubtitleDisplayWidget> createState() => _SubtitleDisplayWidgetState();
}

class _SubtitleDisplayWidgetState extends State<SubtitleDisplayWidget>
    with TickerProviderStateMixin {

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _minimizeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _minimizeAnimation;

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

    _minimizeController = AnimationController(
      duration: const Duration(milliseconds: 250),
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

    _minimizeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _minimizeController,
      curve: Curves.easeInOut,
    ));

    if (widget.isVisible) {
      _slideController.forward();
      _fadeController.forward();
    }

    if (widget.isMinimized) {
      _minimizeController.forward();
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

    if (widget.isMinimized != oldWidget.isMinimized) {
      if (widget.isMinimized) {
        _minimizeController.forward();
      } else {
        _minimizeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _minimizeController.dispose();
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
        child: AnimatedBuilder(
          animation: _minimizeAnimation,
          builder: (context, child) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: widget.isMinimized
                    ? 60.0
                    : widget.maxHeight,
              ),
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

                        // Subtitles content (hide when minimized)
                        if (!widget.isMinimized) ...[
                          if (subtitles.isEmpty)
                            _buildEmptyState(isConnected)
                          else
                            _buildSubtitlesList(subtitles),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
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
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: widget.isMinimized ? const Radius.circular(16) : Radius.zero,
          bottomRight: widget.isMinimized ? const Radius.circular(16) : Radius.zero,
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
              child: const CircularProgressIndicator(
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
                  : widget.isMinimized
                  ? '🌐 Live Translation'
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

          // Minimize/Maximize button
          if (widget.onToggleMinimize != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onToggleMinimize,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  widget.isMinimized ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
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

    // Show only the latest 3 entries to avoid clutter
    final displayEntries = sortedEntries.take(3).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight - 60),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: displayEntries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = displayEntries[index];
          return _buildSubtitleEntry(entry, index == 0);
        },
      ),
    );
  }

  Widget _buildSubtitleEntry(SubtitleEntry entry, bool isLatest) {
    return AnimatedBuilder(
      animation: entry,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, animation, child) {
            return Transform.scale(
              scale: isLatest ? 0.95 + (0.05 * animation) : 1.0,
              child: Opacity(
                opacity: isLatest ? animation : 0.7,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isLatest
                        ? Colors.black.withOpacity(0.7)
                        : Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: entry.isTranslating
                          ? Colors.orange.withOpacity(0.4)
                          : Colors.green.withOpacity(isLatest ? 0.4 : 0.2),
                      width: isLatest ? 1 : 0.5,
                    ),
                    boxShadow: isLatest ? [
                      BoxShadow(
                        color: (entry.isTranslating ? Colors.orange : Colors.green)
                            .withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Speaker info header (compact for older entries)
                      Row(
                        children: [
                          // Speaker avatar
                          Container(
                            width: isLatest ? 32 : 24,
                            height: isLatest ? 32 : 24,
                            decoration: BoxDecoration(
                              color: GcbAppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: isLatest ? [
                                BoxShadow(
                                  color: GcbAppTheme.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ] : null,
                            ),
                            child: Center(
                              child: Text(
                                entry.speakerName.isNotEmpty
                                    ? entry.speakerName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: isLatest ? 14 : 12,
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
                                  style: TextStyle(
                                    color: GcbAppTheme.primary,
                                    fontSize: isLatest ? 14 : 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isLatest)
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

                          // Translation status (only for latest)
                          if (isLatest && entry.needsTranslation)
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
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.orange,
                                      ),
                                    )
                                  else
                                    const Icon(
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isLatest ? 15 : 13,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: isLatest ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Confidence indicator (only for latest)
                      if (isLatest && entry.displayConfidence > 0)
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

// Quick subtitle overlay for minimal display (enhanced)
class QuickSubtitleOverlay extends StatelessWidget {
  final SubtitleEntry? currentSubtitle;
  final bool isVisible;
  final bool showSpeakerInfo;

  const QuickSubtitleOverlay({
    Key? key,
    this.currentSubtitle,
    this.isVisible = true,
    this.showSpeakerInfo = true,
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
                        // Speaker info (optional)
                        if (showSpeakerInfo)
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
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                ),
                            ],
                          ),

                        if (showSpeakerInfo) const SizedBox(height: 8),

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