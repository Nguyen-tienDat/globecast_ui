// lib/screens/meeting/widgets/language_settings_panel.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/services/translation_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/models/translation_models.dart';

class LanguageSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const LanguageSettingsPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<LanguageSettingsPanel> createState() => _LanguageSettingsPanelState();
}

class _LanguageSettingsPanelState extends State<LanguageSettingsPanel>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
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
    super.dispose();
  }

  Future<void> _closePanel() async {
    await _animationController.reverse();
    widget.onClose();
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

            // Settings panel
            Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 600,
                  ),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      Expanded(child: _buildContent()),
                      _buildFooter(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GcbAppTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.language,
              color: GcbAppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Configure your language preferences',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
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
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer2<TranslationService, MultilingualSpeechService>(
      builder: (context, translationService, speechService, child) {
        final userPref = translationService.userPreference;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Language Section
              _buildSectionHeader(
                icon: Icons.visibility,
                title: 'Display Language',
                subtitle: 'All conversations will be translated to this language',
              ),
              const SizedBox(height: 16),
              _buildLanguageSelector(
                currentLanguage: userPref?.displayLanguage ?? 'en',
                onLanguageSelected: (languageCode) {
                  translationService.updateDisplayLanguage(languageCode);
                },
              ),

              const SizedBox(height: 32),

              // Speaking Language Section
              _buildSectionHeader(
                icon: Icons.record_voice_over,
                title: 'Speaking Language',
                subtitle: 'The language you speak in this meeting',
              ),
              const SizedBox(height: 16),
              _buildLanguageSelector(
                currentLanguage: userPref?.speakingLanguage ?? 'en',
                onLanguageSelected: (languageCode) {
                  translationService.updateSpeakingLanguage(languageCode);
                  speechService.setSpeakingLanguage(languageCode);
                },
              ),

              const SizedBox(height: 32),

              // Speech Recognition Settings
              _buildSectionHeader(
                icon: Icons.mic,
                title: 'Speech Recognition',
                subtitle: 'Configure speech-to-text settings',
              ),
              const SizedBox(height: 16),

              // Speech recognition status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GcbAppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      speechService.isAvailable ? Icons.check_circle : Icons.error,
                      color: speechService.isAvailable ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            speechService.isAvailable ? 'Speech Recognition Available' : 'Speech Recognition Unavailable',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            speechService.getSpeechStatus().toUpperCase(),
                            style: TextStyle(
                              color: speechService.isAvailable ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (speechService.isListening)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // STT Controls
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: speechService.isListening
                          ? () => speechService.stopListening()
                          : () => speechService.startListening(continuous: true),
                      icon: Icon(
                        speechService.isListening ? Icons.stop : Icons.mic,
                        size: 18,
                      ),
                      label: Text(speechService.isListening ? 'Stop Listening' : 'Start Listening'),
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
                  ElevatedButton(
                    onPressed: speechService.isSTTEnabled
                        ? () => speechService.disableSTT()
                        : () => speechService.enableSTT(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: speechService.isSTTEnabled
                          ? Colors.orange
                          : Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(speechService.isSTTEnabled ? 'Disable' : 'Enable'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Translation Status
              _buildSectionHeader(
                icon: Icons.translate,
                title: 'Translation Status',
                subtitle: 'Current translation activity',
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GcbAppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: GcbAppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Auto-Translation Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${translationService.transcriptions.length} messages translated',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          'Real-time',
                          style: TextStyle(
                            color: GcbAppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: GcbAppTheme.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector({
    required String currentLanguage,
    required Function(String) onLanguageSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: SupportedLanguages.getAllLanguageCodes().map((languageCode) {
          final isSelected = languageCode == currentLanguage;
          final languageName = SupportedLanguages.getLanguageName(languageCode);
          final languageFlag = SupportedLanguages.getLanguageFlag(languageCode);

          return InkWell(
            onTap: () => onLanguageSelected(languageCode),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? GcbAppTheme.primary.withOpacity(0.2) : null,
                borderRadius: BorderRadius.circular(12),
                border: isSelected ? Border.all(
                  color: GcbAppTheme.primary.withOpacity(0.5),
                ) : null,
              ),
              child: Row(
                children: [
                  Text(
                    languageFlag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      languageName,
                      style: TextStyle(
                        color: isSelected ? GcbAppTheme.primary : Colors.white,
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: GcbAppTheme.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey[400],
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Changes will apply immediately to all new conversations',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _closePanel,
            style: ElevatedButton.styleFrom(
              backgroundColor: GcbAppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}