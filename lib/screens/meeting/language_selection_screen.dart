// lib/screens/meeting/language_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/whisper_service.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../../models/subtitle_models.dart';
import '../../theme/app_theme.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final String meetingId;
  final VoidCallback? onLanguagesSelected;

  const LanguageSelectionScreen({
    Key? key,
    required this.meetingId,
    this.onLanguagesSelected,
  }) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedNativeLanguage = 'en';
  String _selectedDisplayLanguage = 'en';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Get current language settings from WebRTC service instead of WhisperService
    final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);
    _selectedNativeLanguage = webrtcService.userNativeLanguage;
    _selectedDisplayLanguage = webrtcService.userDisplayLanguage;
  }

  Future<void> _saveLanguageSettings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Access WebRTC service instead of WhisperService directly
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);

      // Update language settings through WebRTC service
      await webrtcService.updateLanguageSettings(
        nativeLanguage: _selectedNativeLanguage,
        displayLanguage: _selectedDisplayLanguage,
      );

      // Get WhisperService through WebRTC service
      final whisperService = webrtcService.whisperService;

      // Connect to Whisper server if available and not already connected
      if (whisperService != null && !whisperService.isConnected) {
        final connected = await whisperService.connect();
        if (!connected) {
          print('Warning: Failed to connect to translation service');
          // Don't throw error, just continue without subtitles
        }
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Languages updated! You speak ${WhisperService.supportedLanguages[_selectedNativeLanguage]?.name}, viewing in ${WhisperService.supportedLanguages[_selectedDisplayLanguage]?.name}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Call callback if provided
        widget.onLanguagesSelected?.call();

        // Go back to meeting
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Language Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header explanation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GcbAppTheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: GcbAppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            color: GcbAppTheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Choose the language you speak\n• Choose the language you want to see subtitles in\n• All other participants\' speech will be translated to your preferred language',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Native Language Section
              Text(
                'I speak',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Select the language you will be speaking in this meeting',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 16),

              // Native Language Grid
              _buildLanguageGrid(
                selectedLanguage: _selectedNativeLanguage,
                onLanguageSelected: (languageCode) {
                  setState(() {
                    _selectedNativeLanguage = languageCode;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Display Language Section
              Text(
                'I want to see subtitles in',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'All other languages will be translated to this language',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 16),

              // Display Language Grid
              _buildLanguageGrid(
                selectedLanguage: _selectedDisplayLanguage,
                onLanguageSelected: (languageCode) {
                  setState(() {
                    _selectedDisplayLanguage = languageCode;
                  });
                },
              ),

              const Spacer(),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLanguageSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GcbAppTheme.primary,
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
                      const Icon(Icons.check, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Save & Start Translation',
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageGrid({
    required String selectedLanguage,
    required Function(String) onLanguageSelected,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: WhisperService.supportedLanguages.length,
      itemBuilder: (context, index) {
        final entry = WhisperService.supportedLanguages.entries.elementAt(index);
        final languageCode = entry.key;
        final languageInfo = entry.value;
        final isSelected = selectedLanguage == languageCode;

        return _buildLanguageCard(
          languageCode: languageCode,
          languageInfo: languageInfo,
          isSelected: isSelected,
          onTap: () => onLanguageSelected(languageCode),
        );
      },
    );
  }

  Widget _buildLanguageCard({
    required String languageCode,
    required LanguageInfo languageInfo,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? GcbAppTheme.primary.withOpacity(0.2)
              : GcbAppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? GcbAppTheme.primary
                : Colors.transparent,
            width: 2,
          ),
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
              child: Text(
                languageInfo.name,
                style: TextStyle(
                  color: isSelected ? GcbAppTheme.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: GcbAppTheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// Language Selection Dialog for quick access
class LanguageSelectionDialog extends StatefulWidget {
  final String currentNativeLanguage;
  final String currentDisplayLanguage;
  final Function(String, String)? onLanguagesChanged;

  const LanguageSelectionDialog({
    Key? key,
    required this.currentNativeLanguage,
    required this.currentDisplayLanguage,
    this.onLanguagesChanged,
  }) : super(key: key);

  @override
  State<LanguageSelectionDialog> createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  late String _selectedNativeLanguage;
  late String _selectedDisplayLanguage;

  @override
  void initState() {
    super.initState();
    _selectedNativeLanguage = widget.currentNativeLanguage;
    _selectedDisplayLanguage = widget.currentDisplayLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GcbAppTheme.surface,
      title: Text(
        'Quick Language Change',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I speak:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildLanguageDropdown(
              value: _selectedNativeLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedNativeLanguage = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            Text(
              'Show subtitles in:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildLanguageDropdown(
              value: _selectedDisplayLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedDisplayLanguage = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onLanguagesChanged?.call(
              _selectedNativeLanguage,
              _selectedDisplayLanguage,
            );
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: GcbAppTheme.primary,
          ),
          child: Text(
            'Update',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown({
    required String value,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: GcbAppTheme.surface,
        style: TextStyle(color: Colors.white),
        underline: SizedBox(),
        padding: EdgeInsets.symmetric(horizontal: 12),
        items: WhisperService.supportedLanguages.entries.map((entry) {
          final languageCode = entry.key;
          final languageInfo = entry.value;

          return DropdownMenuItem<String>(
            value: languageCode,
            child: Row(
              children: [
                Text(languageInfo.flag, style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(languageInfo.name),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}