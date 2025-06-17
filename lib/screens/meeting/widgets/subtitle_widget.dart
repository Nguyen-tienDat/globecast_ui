// lib/screens/meeting/widgets/subtitle_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';

class SubtitleWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const SubtitleWidget({
    super.key,
    this.isVisible = true,
    this.onToggleVisibility,
  });

  @override
  State<SubtitleWidget> createState() => _SubtitleWidgetState();
}

class _SubtitleWidgetState extends State<SubtitleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(SubtitleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MultilingualSpeechService>(
      builder: (context, speechService, child) {
        // Only show if there's text to display
        if (!widget.isVisible ||
            (speechService.text.isEmpty && speechService.translatedText.isEmpty)) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Positioned(
              left: 16,
              right: 16,
              bottom: 120 + _slideAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: _buildSubtitleContainer(speechService),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubtitleContainer(MultilingualSpeechService speechService) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 200,
        minHeight: 60,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: speechService.isListening
              ? Colors.red.withOpacity(0.5)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with controls
          _buildSubtitleHeader(speechService),

          // Content
          Flexible(
            child: _buildSubtitleContent(speechService),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleHeader(MultilingualSpeechService speechService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: speechService.isListening ? Colors.red : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Language info
          Expanded(
            child: Text(
              speechService.isTranslationEnabled
                  ? '${speechService.supportedLanguages[speechService.sourceLanguage]} → ${speechService.supportedLanguages[speechService.targetLanguage]}'
                  : speechService.supportedLanguages[speechService.sourceLanguage] ?? 'English',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Confidence indicator
          if (speechService.confidence < 1.0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: speechService.confidence > 0.8
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(speechService.confidence * 100).toInt()}%',
                style: TextStyle(
                  color: speechService.confidence > 0.8
                      ? Colors.green
                      : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Toggle visibility button
          GestureDetector(
            onTap: widget.onToggleVisibility,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleContent(MultilingualSpeechService speechService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Original text
          if (speechService.text.isNotEmpty) ...[
            _buildTextSection(
              label: speechService.isTranslationEnabled
                  ? (speechService.supportedLanguages[speechService.sourceLanguage] ?? 'Original')
                  : null,
              text: speechService.text,
              isOriginal: true,
              isListening: speechService.isListening,
            ),

            // Separator if both texts exist
            if (speechService.isTranslationEnabled &&
                speechService.translatedText.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 1,
                color: Colors.grey.withOpacity(0.3),
              ),
          ],

          // Translated text
          if (speechService.isTranslationEnabled &&
              speechService.translatedText.isNotEmpty)
            _buildTextSection(
              label: speechService.supportedLanguages[speechService.targetLanguage] ?? 'Translation',
              text: speechService.translatedText,
              isOriginal: false,
              isTranslating: speechService.isTranslating,
            ),
        ],
      ),
    );
  }

  Widget _buildTextSection({
    String? label,
    required String text,
    required bool isOriginal,
    bool isListening = false,
    bool isTranslating = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (label != null) ...[
          Row(
            children: [
              Icon(
                isOriginal ? Icons.record_voice_over : Icons.translate,
                color: isOriginal ? Colors.white : GcbAppTheme.primary,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isOriginal ? Colors.grey : GcbAppTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isListening || isTranslating) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isListening ? Colors.red : GcbAppTheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
        ],

        // Text content
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: isOriginal ? FontWeight.w500 : FontWeight.w400,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Helper widget for empty subtitle state
class EmptySubtitleWidget extends StatelessWidget {
  final VoidCallback? onTapToStart;

  const EmptySubtitleWidget({
    super.key,
    this.onTapToStart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: GestureDetector(
        onTap: onTapToStart,
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
                Icons.mic_none,
                color: Colors.grey[400],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tap to start speech recognition',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.touch_app,
                color: Colors.grey[500],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}