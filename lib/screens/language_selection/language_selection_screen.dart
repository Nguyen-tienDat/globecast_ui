// lib/screens/language_selection/language_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../services/whisper_streaming_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final String meetingCode;
  final String userName;

  const LanguageSelectionScreen({
    super.key,
    required this.meetingCode,
    required this.userName,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  LanguageOption? _selectedLanguage;
  bool _isJoining = false;
  final WhisperStreamingService _whisperService = WhisperStreamingService();

  @override
  void initState() {
    super.initState();
    // Default to English
    final availableLanguages = _whisperService.getAvailableLanguages();
    _selectedLanguage = availableLanguages.firstWhere(
          (lang) => lang.code == 'en',
      orElse: () => availableLanguages.first,
    );
  }

  Future<void> _joinWithSelectedLanguage() async {
    if (_selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your preferred language')),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Pass the language selection to the meeting screen
      Navigator.pushReplacementNamed(
        context,
        '/meeting',
        arguments: {
          'code': widget.meetingCode,
          'userName': widget.userName,
          'preferredLanguage': _selectedLanguage!.code,
        },
      );
    } catch (e) {
      setState(() {
        _isJoining = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableLanguages = _whisperService.getAvailableLanguages();

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
          'Choose Your Language',
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
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GcbAppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Meeting: ${widget.meetingCode}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Joining as: ${widget.userName}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Explanation
              const Text(
                'Select Your Preferred Language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose the language you want to hear subtitles in. All conversations will be automatically translated to your selected language.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // Language selection
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: GcbAppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: availableLanguages.length,
                    itemBuilder: (context, index) {
                      final language = availableLanguages[index];
                      final isSelected = _selectedLanguage?.code == language.code;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: ListTile(
                          leading: Text(
                            language.flag,
                            style: const TextStyle(fontSize: 32),
                          ),
                          title: Text(
                            language.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            language.code.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                            size: 24,
                          )
                              : const Icon(
                            Icons.radio_button_unchecked,
                            color: Colors.grey,
                            size: 24,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedLanguage = language;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Feature info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.translate,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Real-time Translation',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Powered by Whisper AI, you\'ll see live subtitles in your chosen language as people speak.',
                            style: TextStyle(
                              color: Colors.blue[200],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinWithSelectedLanguage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isJoining
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
                      const Icon(
                        Icons.video_call,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Join Meeting (${_selectedLanguage?.flag ?? ''})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Note
              Center(
                child: Text(
                  'You can change your language anytime during the meeting',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Language change dialog during meeting
class LanguageChangeDialog extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onLanguageChanged;

  const LanguageChangeDialog({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<LanguageChangeDialog> createState() => _LanguageChangeDialogState();
}

class _LanguageChangeDialogState extends State<LanguageChangeDialog> {
  late String _selectedLanguage;
  final WhisperStreamingService _whisperService = WhisperStreamingService();

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final availableLanguages = _whisperService.getAvailableLanguages();

    return Dialog(
      backgroundColor: GcbAppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.translate,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Change Language',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'Select your preferred language for subtitles',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Language list
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: availableLanguages.length,
                itemBuilder: (context, index) {
                  final language = availableLanguages[index];
                  final isSelected = _selectedLanguage == language.code;

                  return ListTile(
                    leading: Text(
                      language.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      language.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedLanguage = language.code;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedLanguage != widget.currentLanguage
                        ? () {
                      widget.onLanguageChanged(_selectedLanguage);
                      Navigator.pop(context);
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}