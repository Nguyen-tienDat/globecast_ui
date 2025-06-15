// lib/widgets/language_selection_widget.dart - NEW WORKFLOW
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subtitle_models.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../../services/whisper_service.dart';
import '../../theme/app_theme.dart';

/// NEW WORKFLOW: Language Selection like YouTube Subtitles
/// Users select what language they want to see ALL subtitles in
/// All other participants' speech will be auto-translated to this language
class LanguageSelectionWidget extends StatefulWidget {
  final VoidCallback? onLanguageSelected;
  final bool showBeforeMeeting;

  const LanguageSelectionWidget({
    Key? key,
    this.onLanguageSelected,
    this.showBeforeMeeting = false,
  }) : super(key: key);

  @override
  State<LanguageSelectionWidget> createState() => _LanguageSelectionWidgetState();
}

class _LanguageSelectionWidgetState extends State<LanguageSelectionWidget>
    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String? _selectedLanguage;
  bool _isLoading = false;

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
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();

    // Get current language from service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
      setState(() {
        _selectedLanguage = webrtcService.userDisplayLanguage;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, webrtcService, child) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
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
                      _buildLanguageGrid(webrtcService),
                      if (widget.showBeforeMeeting) _buildActionButtons(webrtcService),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GcbAppTheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.subtitles,
                  color: GcbAppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Your Subtitle Language',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Like YouTube subtitles - all speech will be translated to your language',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Everyone can speak their native language. You\'ll see everything translated to your chosen language.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageGrid(WebRTCMeshMeetingService webrtcService) {
    final languages = WhisperService.supportedLanguages.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your preferred subtitle language:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final entry = languages[index];
              final languageCode = entry.key;
              final languageInfo = entry.value;
              final isSelected = _selectedLanguage == languageCode;

              return _buildLanguageCard(
                languageCode: languageCode,
                languageInfo: languageInfo,
                isSelected: isSelected,
                webrtcService: webrtcService,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String languageCode,
    required LanguageInfo languageInfo,
    required bool isSelected,
    required WebRTCMeshMeetingService webrtcService,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () => _selectLanguage(languageCode, webrtcService),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? GcbAppTheme.primary.withOpacity(0.2)
                  : GcbAppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? GcbAppTheme.primary
                    : Colors.grey.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: GcbAppTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Row(
              children: [
                // Flag
                Text(
                  languageInfo.flag,
                  style: const TextStyle(fontSize: 24),
                ),

                const SizedBox(width: 12),

                // Language name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        languageInfo.name,
                        style: TextStyle(
                          color: isSelected ? GcbAppTheme.primary : Colors.white,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        languageCode.toUpperCase(),
                        style: TextStyle(
                          color: isSelected
                              ? GcbAppTheme.primary.withOpacity(0.7)
                              : Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? GcbAppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? GcbAppTheme.primary : Colors.grey[600]!,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(WebRTCMeshMeetingService webrtcService) {
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
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey[600]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading || _selectedLanguage == null
                  ? null
                  : () => _confirmSelection(webrtcService),
              style: ElevatedButton.styleFrom(
                backgroundColor: GcbAppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLanguage(String languageCode, WebRTCMeshMeetingService webrtcService) async {
    if (_isLoading) return;

    setState(() {
      _selectedLanguage = languageCode;
    });

    // For in-meeting changes, apply immediately
    if (!widget.showBeforeMeeting) {
      setState(() {
        _isLoading = true;
      });

      try {
        await webrtcService.updateDisplayLanguage(languageCode);

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Subtitle language changed to ${WhisperService.supportedLanguages[languageCode]?.name}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        widget.onLanguageSelected?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _confirmSelection(WebRTCMeshMeetingService webrtcService) async {
    if (_selectedLanguage == null || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await webrtcService.updateDisplayLanguage(_selectedLanguage!);

      if (mounted) {
        widget.onLanguageSelected?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Quick Language Selector for in-meeting use
class QuickLanguageSelector extends StatelessWidget {
  final Function(String)? onLanguageChanged;

  const QuickLanguageSelector({
    Key? key,
    this.onLanguageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, webrtcService, child) {
        final currentLanguage = webrtcService.userDisplayLanguage;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: GcbAppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: GcbAppTheme.primary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: DropdownButton<String>(
            value: currentLanguage,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: GcbAppTheme.primary,
              size: 20,
            ),
            underline: const SizedBox(),
            dropdownColor: GcbAppTheme.surface,
            style: const TextStyle(color: Colors.white),
            items: WhisperService.supportedLanguages.entries.map((entry) {
              final languageCode = entry.key;
              final languageInfo = entry.value;

              return DropdownMenuItem<String>(
                value: languageCode,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(languageInfo.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(languageInfo.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newLanguage) async {
              if (newLanguage != null && newLanguage != currentLanguage) {
                try {
                  await webrtcService.updateDisplayLanguage(newLanguage);
                  onLanguageChanged?.call(newLanguage);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error changing language: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        );
      },
    );
  }
}

// Language Selection Dialog for quick access
class LanguageSelectionDialog extends StatelessWidget {
  const LanguageSelectionDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const LanguageSelectionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: const LanguageSelectionWidget(showBeforeMeeting: false),
      ),
    );
  }
}

// Pre-meeting Language Selection Screen
class PreMeetingLanguageSelectionScreen extends StatelessWidget {
  final VoidCallback? onCompleted;

  const PreMeetingLanguageSelectionScreen({
    Key? key,
    this.onCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: LanguageSelectionWidget(
                showBeforeMeeting: true,
                onLanguageSelected: onCompleted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}