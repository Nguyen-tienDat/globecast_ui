// lib/widgets/subtitle_widget.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/whisper_service.dart';
import '../theme/app_theme.dart';

/// Subtitle display configuration
class SubtitleConfig {
  final TextStyle textStyle;
  final TextStyle speakerStyle;
  final TextStyle timestampStyle;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Duration animationDuration;
  final Duration displayDuration;
  final Duration fadeOutDuration;
  final int maxLines;
  final int maxSubtitles;
  final bool showSpeakerName;
  final bool showOriginalText;
  final bool showConfidence;
  final bool showTimestamp;
  final bool showLanguageIndicator;
  final bool enableAnimations;
  final bool enableAutoScroll;
  final bool enableWordHighlight;
  final double opacity;
  final SubtitlePosition position;

  const SubtitleConfig({
    this.textStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Colors.white,
      height: 1.4,
      shadows: [
        Shadow(
          offset: Offset(0, 1),
          blurRadius: 3,
          color: Colors.black,
        ),
      ],
    ),
    this.speakerStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Color(0xFF64B5F6),
    ),
    this.timestampStyle = const TextStyle(
      fontSize: 10,
      color: Colors.white54,
      fontWeight: FontWeight.w400,
    ),
    this.backgroundColor = const Color(0xE6000000),
    this.borderColor = const Color(0x40FFFFFF),
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.margin = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.animationDuration = const Duration(milliseconds: 400),
    this.displayDuration = const Duration(seconds: 12),
    this.fadeOutDuration = const Duration(milliseconds: 800),
    this.maxLines = 4,
    this.maxSubtitles = 50,
    this.showSpeakerName = true,
    this.showOriginalText = false,
    this.showConfidence = false,
    this.showTimestamp = true,
    this.showLanguageIndicator = true,
    this.enableAnimations = true,
    this.enableAutoScroll = true,
    this.enableWordHighlight = false,
    this.opacity = 0.95,
    this.position = SubtitlePosition.bottom,
  });

  SubtitleConfig copyWith({
    TextStyle? textStyle,
    TextStyle? speakerStyle,
    TextStyle? timestampStyle,
    Color? backgroundColor,
    Color? borderColor,
    double? borderRadius,
    EdgeInsets? padding,
    EdgeInsets? margin,
    Duration? animationDuration,
    Duration? displayDuration,
    Duration? fadeOutDuration,
    int? maxLines,
    int? maxSubtitles,
    bool? showSpeakerName,
    bool? showOriginalText,
    bool? showConfidence,
    bool? showTimestamp,
    bool? showLanguageIndicator,
    bool? enableAnimations,
    bool? enableAutoScroll,
    bool? enableWordHighlight,
    double? opacity,
    SubtitlePosition? position,
  }) {
    return SubtitleConfig(
      textStyle: textStyle ?? this.textStyle,
      speakerStyle: speakerStyle ?? this.speakerStyle,
      timestampStyle: timestampStyle ?? this.timestampStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      animationDuration: animationDuration ?? this.animationDuration,
      displayDuration: displayDuration ?? this.displayDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
      maxLines: maxLines ?? this.maxLines,
      maxSubtitles: maxSubtitles ?? this.maxSubtitles,
      showSpeakerName: showSpeakerName ?? this.showSpeakerName,
      showOriginalText: showOriginalText ?? this.showOriginalText,
      showConfidence: showConfidence ?? this.showConfidence,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      showLanguageIndicator: showLanguageIndicator ?? this.showLanguageIndicator,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      enableAutoScroll: enableAutoScroll ?? this.enableAutoScroll,
      enableWordHighlight: enableWordHighlight ?? this.enableWordHighlight,
      opacity: opacity ?? this.opacity,
      position: position ?? this.position,
    );
  }
}

/// Subtitle position options
enum SubtitlePosition {
  top,
  center,
  bottom,
}

/// Individual subtitle item with animation support
class SubtitleItem {
  final String id;
  final String speakerId;
  final String speakerName;
  final String text;
  final String originalText;
  final String originalLanguage;
  final String targetLanguage;
  final double confidence;
  final double translationConfidence;
  final DateTime timestamp;
  final bool isFinal;
  final Color speakerColor;
  final double audioQuality;

  // Animation state
  double opacity;
  double scale;
  double translateY;
  double blur;
  bool isExpiring;
  bool isHighlighted;

  SubtitleItem({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.text,
    required this.originalText,
    required this.originalLanguage,
    required this.targetLanguage,
    required this.confidence,
    required this.translationConfidence,
    required this.timestamp,
    required this.isFinal,
    required this.audioQuality,
    Color? speakerColor,
    this.opacity = 0.0,
    this.scale = 0.85,
    this.translateY = 30.0,
    this.blur = 0.0,
    this.isExpiring = false,
    this.isHighlighted = false,
  }) : speakerColor = speakerColor ?? _generateSpeakerColor(speakerId);

  static Color _generateSpeakerColor(String speakerId) {
    final colors = [
      const Color(0xFF64B5F6), // Blue
      const Color(0xFF81C784), // Green
      const Color(0xFFFFB74D), // Orange
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF4FC3F7), // Light Blue
      const Color(0xFFA5D6A7), // Light Green
      const Color(0xFFFFD54F), // Yellow
      const Color(0xFFFF8A65), // Deep Orange
      const Color(0xFFE57373), // Red
      const Color(0xFF9FA8DA), // Indigo
    ];
    final hash = speakerId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  factory SubtitleItem.fromTranscriptionResult(TranscriptionResult result) {
    return SubtitleItem(
      id: '${result.speakerId}_${result.timestamp.millisecondsSinceEpoch}',
      speakerId: result.speakerId,
      speakerName: result.speakerName,
      text: result.translatedText,
      originalText: result.originalText,
      originalLanguage: result.originalLanguage,
      targetLanguage: result.targetLanguage,
      confidence: result.transcriptionConfidence,
      translationConfidence: result.translationConfidence,
      timestamp: result.timestamp,
      isFinal: result.isFinal,
      audioQuality: result.audioQuality,
    );
  }

  Duration get age => DateTime.now().difference(timestamp);
  bool get isTranslated => originalText != text;
  bool get isHighQuality => confidence > 0.7 && audioQuality > 0.5;

  @override
  String toString() {
    return 'SubtitleItem($speakerName: "$text")';
  }
}

/// Main Enhanced Subtitle Widget
class SubtitleWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onSettingsPressed;
  final SubtitleConfig config;
  final double? height;
  final bool showControls;
  final bool isCompactMode;

  const SubtitleWidget({
    super.key,
    required this.isVisible,
    this.onToggleVisibility,
    this.onSettingsPressed,
    this.config = const SubtitleConfig(),
    this.height,
    this.showControls = true,
    this.isCompactMode = false,
  });

  @override
  State<SubtitleWidget> createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget>
    with TickerProviderStateMixin {

  // Data management
  final List<SubtitleItem> _subtitles = [];
  final Map<String, SubtitleItem> _lastSubtitleByUser = {};
  final ScrollController _scrollController = ScrollController();

  // Animation controllers
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _opacityAnimations = {};
  final Map<String, Animation<double>> _scaleAnimations = {};
  final Map<String, Animation<double>> _slideAnimations = {};
  final Map<String, Animation<double>> _blurAnimations = {};

  // Stream subscription
  StreamSubscription<TranscriptionResult>? _transcriptionSubscription;

  // Timers
  Timer? _cleanupTimer;
  Timer? _autoScrollTimer;
  Timer? _statsTimer;

  // Widget state
  bool _isExpanded = false;
  bool _isPaused = false;
  bool _showOriginal = false;
  bool _isScrolledToBottom = true;
  int _displayedCount = 0;
  int _totalReceived = 0;

  // Performance tracking
  final Map<String, dynamic> _performanceStats = {
    'totalSubtitles': 0,
    'averageConfidence': 0.0,
    'translationCount': 0,
    'lastCleanup': DateTime.now(),
  };

  @override
  void initState() {
    super.initState();
    _setupTranscriptionListener();
    _startTimers();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _transcriptionSubscription?.cancel();
    _cleanupTimer?.cancel();
    _autoScrollTimer?.cancel();
    _statsTimer?.cancel();
    _scrollController.dispose();

    // Dispose all animation controllers
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  /// Setup transcription result listener
  void _setupTranscriptionListener() {
    final whisperService = Provider.of<WhisperService>(context, listen: false);

    _transcriptionSubscription = whisperService.transcriptionStream.listen(
      _handleTranscriptionResult,
      onError: (error) {
        print('❌ Subtitle widget error: $error');
      },
    );
  }

  /// Setup scroll listener
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final isAtBottom = _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50;

        if (_isScrolledToBottom != isAtBottom) {
          setState(() {
            _isScrolledToBottom = isAtBottom;
          });
        }
      }
    });
  }

  /// Start cleanup and stats timers
  void _startTimers() {
    // Cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      _cleanupExpiredSubtitles();
    });

    // Stats timer
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      _updatePerformanceStats();
    });
  }

  /// Handle new transcription result
  void _handleTranscriptionResult(TranscriptionResult result) {
    if (!mounted || !widget.isVisible || _isPaused) return;

    _totalReceived++;

    setState(() {
      final subtitle = SubtitleItem.fromTranscriptionResult(result);

      // Handle non-final results (update existing)
      if (!result.isFinal) {
        final existingIndex = _subtitles.indexWhere(
                (s) => s.speakerId == result.speakerId && !s.isFinal
        );

        if (existingIndex != -1) {
          // Update existing subtitle
          final oldSubtitle = _subtitles[existingIndex];
          _subtitles[existingIndex] = subtitle;
          _updateSubtitleAnimation(subtitle, oldSubtitle.id);
          _disposeAnimationController(oldSubtitle.id);
        } else {
          // Add new subtitle
          _addNewSubtitle(subtitle);
        }
      } else {
        // Final result - remove any temporary ones and add final
        _subtitles.removeWhere((s) => s.speakerId == result.speakerId && !s.isFinal);
        _addNewSubtitle(subtitle);
      }

      // Store last subtitle by user
      _lastSubtitleByUser[result.speakerId] = subtitle;

      // Limit subtitle count
      while (_subtitles.length > widget.config.maxSubtitles) {
        final oldSubtitle = _subtitles.removeAt(0);
        _disposeAnimationController(oldSubtitle.id);
      }
    });

    // Auto-scroll if needed
    if (widget.config.enableAutoScroll && _isScrolledToBottom) {
      _autoScrollToBottom();
    }

    // Haptic feedback for final results
    if (result.isFinal) {
      HapticFeedback.selectionClick();
    }

    print('📝 Subtitle ${result.isFinal ? 'final' : 'update'}: ${result.speakerName}: "${result.translatedText}"');
  }

  /// Add new subtitle with animation
  void _addNewSubtitle(SubtitleItem subtitle) {
    _subtitles.add(subtitle);
    _displayedCount++;
    _createSubtitleAnimation(subtitle);
  }

  /// Create animation controller and animations for subtitle
  void _createSubtitleAnimation(SubtitleItem subtitle) {
    if (!widget.config.enableAnimations) {
      subtitle.opacity = 1.0;
      subtitle.scale = 1.0;
      subtitle.translateY = 0.0;
      return;
    }

    final controller = AnimationController(
      duration: widget.config.animationDuration,
      vsync: this,
    );

    // Create animations with different curves
    final opacityAnimation = Tween<double>(
      begin: 0.0,
      end: widget.config.opacity,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    final scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    final slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    final blurAnimation = Tween<double>(
      begin: 2.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    // Store animations
    _animationControllers[subtitle.id] = controller;
    _opacityAnimations[subtitle.id] = opacityAnimation;
    _scaleAnimations[subtitle.id] = scaleAnimation;
    _slideAnimations[subtitle.id] = slideAnimation;
    _blurAnimations[subtitle.id] = blurAnimation;

    // Update subtitle properties with animation values
    controller.addListener(() {
      if (mounted) {
        setState(() {
          subtitle.opacity = opacityAnimation.value;
          subtitle.scale = scaleAnimation.value;
          subtitle.translateY = slideAnimation.value;
          subtitle.blur = blurAnimation.value;
        });
      }
    });

    // Start animation
    controller.forward();
  }

  /// Update existing subtitle animation
  void _updateSubtitleAnimation(SubtitleItem newSubtitle, String oldId) {
    // Copy animation state from old subtitle
    final oldController = _animationControllers[oldId];
    if (oldController != null) {
      newSubtitle.opacity = oldController.value * widget.config.opacity;
      newSubtitle.scale = 1.0;
      newSubtitle.translateY = 0.0;
      newSubtitle.blur = 0.0;
    }

    // Create new animation for updated content
    _createSubtitleAnimation(newSubtitle);
  }

  /// Cleanup expired subtitles
  void _cleanupExpiredSubtitles() {
    if (!mounted) return;

    final now = DateTime.now();
    final expiredSubtitles = <SubtitleItem>[];

    for (var subtitle in _subtitles) {
      if (now.difference(subtitle.timestamp) > widget.config.displayDuration) {
        expiredSubtitles.add(subtitle);
      }
    }

    if (expiredSubtitles.isNotEmpty) {
      setState(() {
        for (var subtitle in expiredSubtitles) {
          _animateSubtitleExit(subtitle);
        }
      });

      _performanceStats['lastCleanup'] = now;
    }
  }

  /// Animate subtitle exit
  void _animateSubtitleExit(SubtitleItem subtitle) {
    if (!widget.config.enableAnimations) {
      _subtitles.remove(subtitle);
      _disposeAnimationController(subtitle.id);
      return;
    }

    subtitle.isExpiring = true;
    final controller = _animationControllers[subtitle.id];

    if (controller != null) {
      // Create fade out animation
      final fadeController = AnimationController(
        duration: widget.config.fadeOutDuration,
        vsync: this,
      );

      final fadeAnimation = Tween<double>(
        begin: subtitle.opacity,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: fadeController,
        curve: Curves.easeIn,
      ));

      fadeAnimation.addListener(() {
        if (mounted) {
          setState(() {
            subtitle.opacity = fadeAnimation.value;
            subtitle.scale = 1.0 - (1.0 - fadeAnimation.value) * 0.2;
          });
        }
      });

      fadeController.forward().then((_) {
        if (mounted) {
          setState(() {
            _subtitles.remove(subtitle);
          });
        }
        _disposeAnimationController(subtitle.id);
        fadeController.dispose();
      });
    } else {
      _subtitles.remove(subtitle);
    }
  }

  /// Dispose animation controller for subtitle
  void _disposeAnimationController(String subtitleId) {
    final controller = _animationControllers.remove(subtitleId);
    controller?.dispose();
    _opacityAnimations.remove(subtitleId);
    _scaleAnimations.remove(subtitleId);
    _slideAnimations.remove(subtitleId);
    _blurAnimations.remove(subtitleId);
  }

  /// Auto-scroll to bottom
  void _autoScrollToBottom() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Update performance statistics
  void _updatePerformanceStats() {
    if (_subtitles.isEmpty) return;

    final totalConfidence = _subtitles.fold<double>(
        0.0,
            (sum, subtitle) => sum + subtitle.confidence
    );

    final translationCount = _subtitles.where((s) => s.isTranslated).length;

    _performanceStats['totalSubtitles'] = _subtitles.length;
    _performanceStats['averageConfidence'] = totalConfidence / _subtitles.length;
    _performanceStats['translationCount'] = translationCount;
  }

  /// Build subtitle item widget
  Widget _buildSubtitleItem(SubtitleItem subtitle, int index) {
    final config = widget.config;
    final isLastItem = index == _subtitles.length - 1;

    return AnimatedBuilder(
      animation: _animationControllers[subtitle.id] ??
          AnimationController(duration: Duration.zero, vsync: this),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, subtitle.translateY),
          child: Transform.scale(
            scale: subtitle.scale,
            child: Opacity(
              opacity: subtitle.opacity,
              child: Container(
                margin: config.margin.copyWith(
                  bottom: isLastItem && !widget.isCompactMode ? 16 : config.margin.bottom,
                ),
                decoration: BoxDecoration(
                  color: config.backgroundColor.withOpacity(subtitle.opacity),
                  borderRadius: BorderRadius.circular(config.borderRadius),
                  border: Border.all(
                    color: subtitle.isHighlighted
                        ? subtitle.speakerColor.withOpacity(0.8)
                        : config.borderColor.withOpacity(subtitle.opacity * 0.5),
                    width: subtitle.isHighlighted ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4 * subtitle.opacity),
                      blurRadius: 8 + subtitle.blur,
                      spreadRadius: subtitle.isHighlighted ? 2 : 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(config.borderRadius),
                  child: Container(
                    padding: config.padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with speaker info
                        if (config.showSpeakerName)
                          _buildSubtitleHeader(subtitle, config),

                        // Main text content
                        _buildSubtitleText(subtitle, config),

                        // Footer with metadata
                        if (config.showTimestamp || config.showLanguageIndicator)
                          _buildSubtitleFooter(subtitle, config),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build subtitle header
  Widget _buildSubtitleHeader(SubtitleItem subtitle, SubtitleConfig config) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Speaker indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: subtitle.speakerColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: subtitle.speakerColor.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Speaker name
          Expanded(
            child: Text(
              subtitle.speakerName,
              style: config.speakerStyle.copyWith(
                color: subtitle.speakerColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Quality indicators
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio quality indicator
              if (subtitle.audioQuality > 0.0)
                Icon(
                  subtitle.audioQuality > 0.7
                      ? Icons.signal_cellular_alt
                      : subtitle.audioQuality > 0.4
                      ? Icons.signal_cellular_alt_2_bar
                      : Icons.signal_cellular_alt_1_bar,
                  size: 12,
                  color: subtitle.audioQuality > 0.7
                      ? Colors.green
                      : subtitle.audioQuality > 0.4
                      ? Colors.orange
                      : Colors.red,
                ),

              const SizedBox(width: 6),

              // Confidence score
              if (config.showConfidence)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(subtitle.confidence),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(subtitle.confidence * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build subtitle text content
  Widget _buildSubtitleText(SubtitleItem subtitle, SubtitleConfig config) {
    final displayText = _showOriginal ? subtitle.originalText : subtitle.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main text
        Text(
          displayText,
          style: config.textStyle.copyWith(
            color: config.textStyle.color?.withOpacity(subtitle.opacity) ??
                Colors.white.withOpacity(subtitle.opacity),
          ),
          maxLines: config.maxLines,
          overflow: TextOverflow.ellipsis,
        ),

        // Original text (if showing translated and has original)
        if (!_showOriginal &&
            config.showOriginalText &&
            subtitle.isTranslated) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              subtitle.originalText,
              style: config.textStyle.copyWith(
                fontSize: config.textStyle.fontSize! - 2,
                color: Colors.white.withOpacity(0.8 * subtitle.opacity),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// Build subtitle footer
  Widget _buildSubtitleFooter(SubtitleItem subtitle, SubtitleConfig config) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Language indicator
          if (config.showLanguageIndicator && subtitle.isTranslated) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${subtitle.originalLanguage.toUpperCase()} → ${subtitle.targetLanguage.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          const Spacer(),

          // Timestamp
          if (config.showTimestamp)
            Text(
              _formatTimestamp(subtitle.timestamp),
              style: config.timestampStyle.copyWith(
                color: config.timestampStyle.color?.withOpacity(subtitle.opacity * 0.8),
              ),
            ),
        ],
      ),
    );
  }

  /// Get confidence color based on value
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Build control bar
  Widget _buildControlBar() {
    if (!widget.showControls || widget.isCompactMode) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Statistics
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_displayedCount} subtitles',
                    style: const TextStyle(
                      fontSize: 11,
                      color: GcbAppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_performanceStats['averageConfidence'] > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(_performanceStats['averageConfidence'] * 100).round()}% avg',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Control buttons
          _buildControlButton(
            icon: _showOriginal ? Icons.translate_rounded : Icons.translate,
            tooltip: _showOriginal ? 'Show Translated' : 'Show Original',
            isActive: !_showOriginal,
            onPressed: () {
              setState(() {
                _showOriginal = !_showOriginal;
              });
              HapticFeedback.lightImpact();
            },
          ),

          _buildControlButton(
            icon: _isPaused ? Icons.play_arrow : Icons.pause,
            tooltip: _isPaused ? 'Resume' : 'Pause',
            isActive: !_isPaused,
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
              HapticFeedback.lightImpact();
            },
          ),

          _buildControlButton(
            icon: Icons.clear_all,
            tooltip: 'Clear All',
            isActive: _subtitles.isNotEmpty,
            onPressed: _subtitles.isNotEmpty ? () {
              setState(() {
                _subtitles.clear();
                _lastSubtitleByUser.clear();
                _displayedCount = 0;
              });

              // Dispose all animation controllers
              for (var controller in _animationControllers.values) {
                controller.dispose();
              }
              _animationControllers.clear();
              _opacityAnimations.clear();
              _scaleAnimations.clear();
              _slideAnimations.clear();
              _blurAnimations.clear();

              HapticFeedback.lightImpact();
            } : null,
          ),

          _buildControlButton(
            icon: _isExpanded ? Icons.expand_less : Icons.expand_more,
            tooltip: _isExpanded ? 'Collapse' : 'Expand',
            isActive: true,
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              HapticFeedback.lightImpact();
            },
          ),

          if (widget.onSettingsPressed != null)
            _buildControlButton(
              icon: Icons.settings,
              tooltip: 'Settings',
              isActive: true,
              onPressed: widget.onSettingsPressed!,
            ),

          if (widget.onToggleVisibility != null)
            _buildControlButton(
              icon: Icons.close,
              tooltip: 'Hide Subtitles',
              isActive: true,
              onPressed: widget.onToggleVisibility!,
            ),
        ],
      ),
    );
  }

  /// Build control button
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: isActive ? onPressed : null,
        icon: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white38,
          size: 18,
        ),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
  }

  /// Build scroll to bottom button
  Widget _buildScrollToBottomButton() {
    if (_isScrolledToBottom || _subtitles.length < 3) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: widget.showControls ? 60 : 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: GcbAppTheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: _autoScrollToBottom,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Scroll to latest',
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isPaused ? Icons.pause_circle_outline : Icons.subtitles_outlined,
            size: widget.isCompactMode ? 32 : 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            _isPaused
                ? 'Subtitles Paused'
                : 'Waiting for speech...',
            style: TextStyle(
              fontSize: widget.isCompactMode ? 14 : 16,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPaused
                ? 'Tap play to resume'
                : 'AI-powered real-time subtitles will appear here',
            style: TextStyle(
              fontSize: widget.isCompactMode ? 10 : 12,
              color: Colors.white.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final defaultHeight = widget.isCompactMode ? 120.0 : 220.0;
    final expandedHeight = screenHeight * 0.6;
    final effectiveHeight = widget.height ??
        (_isExpanded ? expandedHeight : defaultHeight);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: effectiveHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Control bar
          if (widget.showControls) _buildControlBar(),

          // Subtitles content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                  topLeft: widget.showControls ? Radius.zero : const Radius.circular(12),
                  topRight: widget.showControls ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  // Main content
                  _subtitles.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: widget.isCompactMode ? 4 : 8,
                    ),
                    itemCount: _subtitles.length,
                    itemBuilder: (context, index) {
                      return _buildSubtitleItem(_subtitles[index], index);
                    },
                  ),

                  // Scroll to bottom button
                  _buildScrollToBottomButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}