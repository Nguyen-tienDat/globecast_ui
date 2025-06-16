// lib/widgets/enhanced_subtitle_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/user_specific_transcript_service.dart';
import '../theme/app_theme.dart';

/// Enhanced subtitle widget cho user-specific experience
class EnhancedSubtitleWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onLanguagePressed;
  final String userDisplayLanguage;
  final double? height;
  final bool showControls;
  final bool isCompactMode;

  const EnhancedSubtitleWidget({
    super.key,
    required this.isVisible,
    required this.userDisplayLanguage,
    this.onToggleVisibility,
    this.onLanguagePressed,
    this.height,
    this.showControls = true,
    this.isCompactMode = false,
  });

  @override
  State<EnhancedSubtitleWidget> createState() => _EnhancedSubtitleWidgetState();
}

class _EnhancedSubtitleWidgetState extends State<EnhancedSubtitleWidget>
    with TickerProviderStateMixin {

  // Service reference
  late UserSpecificTranscriptService _transcriptService;

  // UI State
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToBottom = true;
  bool _isPaused = false;
  bool _isExpanded = false;
  bool _showStats = false;

  // Animation controllers
  final Map<String, AnimationController> _entryControllers = {};
  late AnimationController _statsController;

  // Performance tracking
  int _displayedCount = 0;
  Map<String, dynamic> _meetingStats = {};

  @override
  void initState() {
    super.initState();
    _setupService();
    _setupScrollListener();
    _setupStatsController();
    _loadMeetingStats();
  }

  void _setupService() {
    _transcriptService = Provider.of<UserSpecificTranscriptService>(context, listen: false);
  }

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

  void _setupStatsController() {
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _loadMeetingStats() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateMeetingStats();
    });
  }

  void _updateMeetingStats() async {
    final stats = await _transcriptService.getMeetingStatsForUser();
    if (mounted) {
      setState(() {
        _meetingStats = stats;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _statsController.dispose();
    for (var controller in _entryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final defaultHeight = widget.isCompactMode ? 140.0 : 250.0;
    final expandedHeight = screenHeight * 0.7;
    final effectiveHeight = widget.height ??
        (_isExpanded ? expandedHeight : defaultHeight);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Enhanced header with language indicator
          _buildEnhancedHeader(),

          // Main content area
          Expanded(
            child: _buildMainContent(),
          ),

          // Bottom controls
          if (widget.showControls) _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.2),
            _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.1),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          // Main header row
          Row(
            children: [
              // Language indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getLanguageColor(widget.userDisplayLanguage),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getLanguageFlag(widget.userDisplayLanguage),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getLanguageName(widget.userDisplayLanguage),
                      style: TextStyle(
                        color: _getLanguageColor(widget.userDisplayLanguage),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Stats display
              if (_meetingStats.isNotEmpty) ...[
                _buildStatsChip('${_meetingStats['totalTranscripts'] ?? 0}', 'messages'),
                const SizedBox(width: 8),
                _buildStatsChip('${_meetingStats['uniqueSpeakers'] ?? 0}', 'speakers'),
                const SizedBox(width: 12),
              ],

              // Action buttons
              _buildHeaderButton(
                icon: _showStats ? Icons.show_chart : Icons.show_chart_outlined,
                onPressed: () {
                  setState(() {
                    _showStats = !_showStats;
                  });
                  _showStats ? _statsController.forward() : _statsController.reverse();
                },
                tooltip: 'Toggle Stats',
              ),

              _buildHeaderButton(
                icon: _isExpanded ? Icons.expand_less : Icons.expand_more,
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  HapticFeedback.lightImpact();
                },
                tooltip: _isExpanded ? 'Collapse' : 'Expand',
              ),

              if (widget.onLanguagePressed != null)
                _buildHeaderButton(
                  icon: Icons.language,
                  onPressed: widget.onLanguagePressed!,
                  tooltip: 'Change Language',
                ),

              if (widget.onToggleVisibility != null)
                _buildHeaderButton(
                  icon: Icons.close,
                  onPressed: widget.onToggleVisibility!,
                  tooltip: 'Hide Subtitles',
                ),
            ],
          ),

          // Expandable stats section
          AnimatedBuilder(
            animation: _statsController,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _statsController,
                child: _buildStatsSection(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_meetingStats.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meeting Statistics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildStatItem(
                'Transcripts',
                '${_meetingStats['totalTranscripts'] ?? 0}',
                Icons.transcribe,
              ),
              _buildStatItem(
                'Speakers',
                '${_meetingStats['uniqueSpeakers'] ?? 0}',
                Icons.people,
              ),
              _buildStatItem(
                'Languages',
                '${_meetingStats['languagesHeard'] ?? 0}',
                Icons.language,
              ),
              _buildStatItem(
                'Accuracy',
                '${((_meetingStats['averageConfidence'] ?? 0.0) * 100).round()}%',
                Icons.check_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[400], size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        // Transcript stream
        StreamBuilder<List<UserTranscriptEntry>>(
          stream: _transcriptService.getUserTranscriptStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final transcripts = snapshot.data ?? [];

            if (transcripts.isEmpty) {
              return _buildEmptyState();
            }

            _displayedCount = transcripts.length;

            return _buildTranscriptList(transcripts);
          },
        ),

        // Scroll to bottom button
        _buildScrollToBottomButton(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _getLanguageColor(widget.userDisplayLanguage),
          ),
          const SizedBox(height: 16),
          Text(
            'Setting up real-time translation...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Translation Error',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPaused ? Icons.pause_circle_outline : Icons.mic_none,
              size: 40,
              color: _getLanguageColor(widget.userDisplayLanguage),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isPaused
                ? 'Subtitles Paused'
                : 'Listening for speech...',
            style: TextStyle(
              fontSize: widget.isCompactMode ? 14 : 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPaused
                ? 'Tap play to resume'
                : 'AI will translate everything to ${_getLanguageName(widget.userDisplayLanguage)}',
            style: TextStyle(
              fontSize: widget.isCompactMode ? 10 : 12,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptList(List<UserTranscriptEntry> transcripts) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(widget.isCompactMode ? 8 : 12),
      itemCount: transcripts.length,
      itemBuilder: (context, index) {
        final transcript = transcripts[index];
        return _buildTranscriptItem(transcript, index);
      },
    );
  }

  Widget _buildTranscriptItem(UserTranscriptEntry transcript, int index) {
    final isRecent = DateTime.now().difference(transcript.timestamp).inSeconds < 5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: widget.isCompactMode ? 8 : 12),
      child: Container(
        padding: EdgeInsets.all(widget.isCompactMode ? 12 : 16),
        decoration: BoxDecoration(
          color: isRecent
              ? _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.1)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: isRecent
              ? Border.all(
            color: _getLanguageColor(widget.userDisplayLanguage).withOpacity(0.3),
            width: 1,
          )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speaker info
            Row(
              children: [
                CircleAvatar(
                  radius: widget.isCompactMode ? 12 : 16,
                  backgroundColor: _getSpeakerColor(transcript.speakerId),
                  child: Text(
                    transcript.speakerName.isNotEmpty
                        ? transcript.speakerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: widget.isCompactMode ? 10 : 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transcript.speakerName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.isCompactMode ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (transcript.originalLanguage != transcript.userLanguage)
                        Text(
                          'Speaking ${_getLanguageName(transcript.originalLanguage)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: widget.isCompactMode ? 9 : 10,
                          ),
                        ),
                    ],
                  ),
                ),

                // Timestamp
                Text(
                  _formatTimestamp(transcript.timestamp),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: widget.isCompactMode ? 9 : 10,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Translated text
            GestureDetector(
              onTap: () => _showTranscriptDetails(transcript),
              child: Text(
                transcript.translatedText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isCompactMode ? 13 : 15,
                  height: 1.4,
                ),
              ),
            ),

            // Quality indicator
            if (transcript.confidence > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    transcript.confidence > 0.8
                        ? Icons.check_circle
                        : transcript.confidence > 0.6
                        ? Icons.warning
                        : Icons.error,
                    size: 12,
                    color: transcript.confidence > 0.8
                        ? Colors.green
                        : transcript.confidence > 0.6
                        ? Colors.orange
                        : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(transcript.confidence * 100).round()}% confidence',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    if (_isScrolledToBottom) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.small(
        onPressed: _scrollToBottom,
        backgroundColor: _getLanguageColor(widget.userDisplayLanguage),
        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Language info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Language: ${_getLanguageName(widget.userDisplayLanguage)}',
                  style: TextStyle(
                    color: _getLanguageColor(widget.userDisplayLanguage),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'All speech translated automatically',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Control buttons
          _buildControlButton(
            icon: _isPaused ? Icons.play_arrow : Icons.pause,
            tooltip: _isPaused ? 'Resume' : 'Pause',
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
              HapticFeedback.lightImpact();
            },
          ),

          _buildControlButton(
            icon: Icons.file_download,
            tooltip: 'Export Transcript',
            onPressed: _exportTranscript,
          ),

          _buildControlButton(
            icon: Icons.clear_all,
            tooltip: 'Clear All',
            onPressed: _clearTranscripts,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showTranscriptDetails(UserTranscriptEntry transcript) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: Text(
          transcript.speakerName,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transcript.originalText != transcript.translatedText) ...[
              const Text(
                'Original:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                transcript.originalText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Translated:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              transcript.translatedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Time: ${_formatTimestamp(transcript.timestamp)}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            Text(
              'Confidence: ${(transcript.confidence * 100).round()}%',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: transcript.translatedText));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy', style: TextStyle(color: GcbAppTheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTranscript() async {
    try {
      final transcriptText = await _transcriptService.exportTranscriptsAsText();

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: transcriptText));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transcript copied to clipboard'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearTranscripts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Clear Transcripts',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to clear all transcripts? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement clear functionality
              Navigator.pop(context);
              setState(() {
                _displayedCount = 0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transcripts cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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

  Color _getLanguageColor(String languageCode) {
    const colors = {
      'en': Color(0xFF1E88E5),
      'vi': Color(0xFFD32F2F),
      'fr': Color(0xFF1976D2),
      'es': Color(0xFFFF8F00),
      'de': Color(0xFF424242),
      'zh': Color(0xFFD32F2F),
      'ja': Color(0xFFE53935),
      'ko': Color(0xFF1565C0),
    };
    return colors[languageCode] ?? const Color(0xFF64B5F6);
  }

  String _getLanguageFlag(String languageCode) {
    const flags = {
      'en': '🇺🇸',
      'vi': '🇻🇳',
      'fr': '🇫🇷',
      'es': '🇪🇸',
      'de': '🇩🇪',
      'zh': '🇨🇳',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
    };
    return flags[languageCode] ?? '🌍';
  }

  String _getLanguageName(String languageCode) {
    const names = {
      'en': 'English',
      'vi': 'Tiếng Việt',
      'fr': 'Français',
      'es': 'Español',
      'de': 'Deutsch',
      'zh': '中文',
      'ja': '日本語',
      'ko': '한국어',
    };
    return names[languageCode] ?? languageCode.toUpperCase();
  }

  Color _getSpeakerColor(String speakerId) {
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
}

/// Floating language indicator for quick reference
class FloatingLanguageIndicator extends StatelessWidget {
  final String currentLanguage;
  final VoidCallback? onTap;
  final bool isActive;

  const FloatingLanguageIndicator({
    super.key,
    required this.currentLanguage,
    this.onTap,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? _getLanguageColor(currentLanguage).withOpacity(0.9)
                : Colors.grey[800],
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
              Text(
                _getLanguageFlag(currentLanguage),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                _getLanguageName(currentLanguage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLanguageColor(String languageCode) {
    const colors = {
      'en': Color(0xFF1E88E5),
      'vi': Color(0xFFD32F2F),
      'fr': Color(0xFF1976D2),
      'es': Color(0xFFFF8F00),
      'de': Color(0xFF424242),
      'zh': Color(0xFFD32F2F),
      'ja': Color(0xFFE53935),
      'ko': Color(0xFF1565C0),
    };
    return colors[languageCode] ?? const Color(0xFF64B5F6);
  }

  String _getLanguageFlag(String languageCode) {
    const flags = {
      'en': '🇺🇸',
      'vi': '🇻🇳',
      'fr': '🇫🇷',
      'es': '🇪🇸',
      'de': '🇩🇪',
      'zh': '🇨🇳',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
    };
    return flags[languageCode] ?? '🌍';
  }

  String _getLanguageName(String languageCode) {
    const names = {
      'en': 'English',
      'vi': 'Việt',
      'fr': 'Français',
      'es': 'Español',
      'de': 'Deutsch',
      'zh': '中文',
      'ja': '日本語',
      'ko': '한국어',
    };
    return names[languageCode] ?? languageCode.toUpperCase();
  }
}