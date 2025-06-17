// lib/screens/meeting/widgets/translation_overlay.dart - UPDATED with real service
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';

class TranslationOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const TranslationOverlay({
    super.key,
    required this.onClose,
  });

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _blurAnimation;

  // Real transcription data from speech service
  final List<TranscriptionItem> _transcriptions = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _closeOverlay() async {
    await _animationController.reverse();
    widget.onClose();
  }

  void _addTranscription(String text, String? translatedText, MultilingualSpeechService service) {
    final item = TranscriptionItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      speaker: 'You',
      originalText: text,
      translatedText: translatedText,
      timestamp: DateTime.now(),
      isCurrentUser: true,
      confidence: service.confidence,
      sourceLanguage: service.sourceLanguage,
      targetLanguage: service.targetLanguage,
    );

    setState(() {
      _transcriptions.add(item);
    });

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Blur background
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _blurAnimation.value,
                sigmaY: _blurAnimation.value,
              ),
              child: Container(
                color: Colors.black.withOpacity(0.3 * _animationController.value),
              ),
            ),

            // Sliding panel from bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.of(context).size.height * 0.6 * _slideAnimation.value,
                ),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHandle(),
                      _buildHeader(),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<MultilingualSpeechService>(
      builder: (context, speechService, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: speechService.isTranslationEnabled
                      ? GcbAppTheme.primary.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  speechService.isListening ? Icons.mic : Icons.translate,
                  color: speechService.isListening
                      ? Colors.red
                      : (speechService.isTranslationEnabled ? GcbAppTheme.primary : Colors.grey),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Translation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      speechService.isListening
                          ? 'Listening...'
                          : 'Real-time speech transcription & translation',
                      style: TextStyle(
                        color: speechService.isListening ? Colors.red : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _closeOverlay,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: GcbAppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Transcription'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _buildTranscriptionTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionTab() {
    return Consumer<MultilingualSpeechService>(
      builder: (context, speechService, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Language & Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: speechService.isTranslationEnabled
                      ? GcbAppTheme.primary.withOpacity(0.1)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: speechService.isTranslationEnabled
                        ? GcbAppTheme.primary.withOpacity(0.3)
                        : Colors.grey[700]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      speechService.isTranslationEnabled ? Icons.translate : Icons.mic,
                      color: speechService.isTranslationEnabled ? GcbAppTheme.primary : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        speechService.isTranslationEnabled
                            ? '${speechService.supportedLanguages[speechService.sourceLanguage]} → ${speechService.supportedLanguages[speechService.targetLanguage]}'
                            : 'Translation disabled',
                        style: TextStyle(
                          color: speechService.isTranslationEnabled ? Colors.white : Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!speechService.isTranslationEnabled)
                      TextButton(
                        onPressed: () {
                          speechService.toggleTranslation();
                        },
                        child: const Text(
                          'Enable',
                          style: TextStyle(
                            color: GcbAppTheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Current speech text (live)
              if (speechService.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            speechService.isListening ? Icons.mic : Icons.mic_off,
                            color: speechService.isListening ? Colors.red : Colors.grey,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Current (${(speechService.confidence * 100).toInt()}%)',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (speechService.isListening)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        speechService.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (speechService.isTranslationEnabled && speechService.translatedText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GcbAppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            speechService.translatedText,
                            style: const TextStyle(
                              color: GcbAppTheme.primary,
                              fontSize: 14,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Transcription list
              Expanded(
                child: _transcriptions.isEmpty
                    ? _buildEmptyState(speechService)
                    : ListView.builder(
                  controller: _scrollController,
                  itemCount: _transcriptions.length,
                  itemBuilder: (context, index) {
                    return _buildTranscriptionItem(_transcriptions[index]);
                  },
                ),
              ),

              // Control buttons
              Container(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    // Start/Stop listening button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: speechService.isListening
                            ? () => speechService.stopListening()
                            : () => speechService.startListening(),
                        icon: Icon(
                          speechService.isListening ? Icons.stop : Icons.mic,
                          size: 16,
                        ),
                        label: Text(speechService.isListening ? 'Stop' : 'Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: speechService.isListening
                              ? Colors.red
                              : GcbAppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Manual translate button
                    if (speechService.isTranslationEnabled && speechService.text.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: speechService.isTranslating
                            ? null
                            : () async {
                          await speechService.translateCurrentText();
                          // Add to transcription history
                          _addTranscription(
                            speechService.text,
                            speechService.translatedText,
                            speechService,
                          );
                        },
                        icon: speechService.isTranslating
                            ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Icon(Icons.translate, size: 16),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GcbAppTheme.primary.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),

                    const SizedBox(width: 12),

                    // Clear button
                    IconButton(
                      onPressed: speechService.text.isEmpty
                          ? null
                          : () {
                        speechService.clearText();
                      },
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Live indicator
              if (speechService.isListening)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(MultilingualSpeechService speechService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            speechService.isAvailable ? Icons.mic_outlined : Icons.mic_off_outlined,
            color: Colors.grey[600],
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            speechService.isAvailable
                ? 'No transcriptions yet'
                : 'Speech recognition unavailable',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            speechService.isAvailable
                ? 'Tap "Start" to begin speech recognition'
                : 'Please check microphone permissions',
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

  Widget _buildTranscriptionItem(TranscriptionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker info with timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isCurrentUser
                      ? GcbAppTheme.primary.withOpacity(0.2)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.speaker,
                  style: TextStyle(
                    color: item.isCurrentUser ? GcbAppTheme.primary : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(item.timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '${(item.confidence * 100).toInt()}%',
                style: TextStyle(
                  color: item.confidence > 0.8 ? Colors.green : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Original text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
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
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.sourceLanguage.toUpperCase(),
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
                  item.originalText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Translated text (if available)
          if (item.translatedText != null && item.translatedText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GcbAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GcbAppTheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.translate,
                        color: GcbAppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (item.targetLanguage ?? 'AUTO').toUpperCase(),
                        style: const TextStyle(
                          color: GcbAppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.translatedText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<MultilingualSpeechService>(
      builder: (context, speechService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Translation toggle
              _buildSettingItem(
                icon: Icons.power_settings_new,
                title: 'Enable Translation',
                subtitle: 'Real-time speech translation',
                trailing: Switch(
                  value: speechService.isTranslationEnabled,
                  onChanged: (value) {
                    speechService.toggleTranslation();
                  },
                  activeColor: GcbAppTheme.primary,
                ),
              ),

              const SizedBox(height: 16),

              // Speech recognition status
              _buildSettingItem(
                icon: speechService.isAvailable ? Icons.check_circle : Icons.error,
                title: 'Speech Recognition',
                subtitle: speechService.isAvailable
                    ? 'Available and ready'
                    : 'Not available',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: speechService.isAvailable
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    speechService.getSpeechStatus().toUpperCase(),
                    style: TextStyle(
                      color: speechService.isAvailable ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              if (speechService.isTranslationEnabled) ...[
                const SizedBox(height: 16),

                // Language selection
                _buildLanguageSelector(
                  title: 'From (Source)',
                  value: speechService.sourceLanguage,
                  languages: speechService.supportedLanguages,
                  onChanged: (value) {
                    speechService.setSourceLanguage(value);
                  },
                ),

                const SizedBox(height: 12),

                // Swap button
                Center(
                  child: IconButton(
                    onPressed: () {
                      speechService.swapLanguages();
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GcbAppTheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GcbAppTheme.primary.withOpacity(0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.swap_vert,
                        color: GcbAppTheme.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _buildLanguageSelector(
                  title: 'To (Target)',
                  value: speechService.targetLanguage,
                  languages: speechService.supportedLanguages,
                  onChanged: (value) {
                    speechService.setTargetLanguage(value);
                  },
                ),
              ],

              const SizedBox(height: 16),

              // Continuous listening
              _buildSettingItem(
                icon: Icons.loop,
                title: 'Continuous Listening',
                subtitle: speechService.continuousListening
                    ? 'Auto-restart after pause'
                    : 'Manual start/stop',
                trailing: Switch(
                  value: speechService.continuousListening,
                  onChanged: (value) {
                    speechService.setContinuousListening(value);
                  },
                  activeColor: GcbAppTheme.primary,
                ),
              ),

              const SizedBox(height: 24),

              // Export transcriptions
              _buildSettingItem(
                icon: Icons.save_alt,
                title: 'Export Transcriptions',
                subtitle: '${_transcriptions.length} items saved',
                trailing: IconButton(
                  onPressed: _transcriptions.isEmpty ? null : () {
                    _exportTranscriptions();
                  },
                  icon: Icon(
                    Icons.download,
                    color: _transcriptions.isEmpty ? Colors.grey : GcbAppTheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Clear all transcriptions
              _buildSettingItem(
                icon: Icons.delete_outline,
                title: 'Clear History',
                subtitle: 'Remove all transcriptions',
                trailing: IconButton(
                  onPressed: _transcriptions.isEmpty ? null : () {
                    _showClearConfirmDialog();
                  },
                  icon: Icon(
                    Icons.delete,
                    color: _transcriptions.isEmpty ? Colors.grey : Colors.red,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector({
    required String title,
    required String value,
    required Map<String, String> languages,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            dropdownColor: const Color(0xFF2A2A2A),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            items: languages.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
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
    } else {
      return '${difference.inHours}h ago';
    }
  }

  void _exportTranscriptions() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${_transcriptions.length} transcriptions'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Clear All Transcriptions',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all saved transcriptions. Are you sure?',
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
            onPressed: () {
              setState(() {
                _transcriptions.clear();
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All transcriptions cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}