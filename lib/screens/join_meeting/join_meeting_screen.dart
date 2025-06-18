// lib/screens/join_meeting/join_meeting_screen.dart - FIXED LAYOUT
import 'package:flutter/material.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../models/translation_models.dart';
import '../meeting/meeting_screen.dart';

class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({super.key});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingCodeController = TextEditingController();
  final _displayNameController = TextEditingController();

  String _selectedTargetLanguage = 'en'; // Default to English
  bool _isJoining = false;

  @override
  void dispose() {
    _meetingCodeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _joinMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
    });

    try {
      // Navigate to meeting with selected language
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingScreen(
              code: _meetingCodeController.text.trim().toUpperCase(),
              displayName: _displayNameController.text.trim(),
              targetLanguage: _selectedTargetLanguage,
              meetingId: '',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Join Meeting',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with new description
                const Icon(
                  Icons.video_call,
                  size: 64,
                  color: GcbAppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Join a Global Meeting',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect with people worldwide and communicate in your language with real-time translation',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Meeting Code Input
                TextFormField(
                  controller: _meetingCodeController,
                  decoration: InputDecoration(
                    labelText: 'Meeting Code',
                    hintText: 'Enter meeting code (e.g., GCM12345678)',
                    prefixIcon: const Icon(Icons.meeting_room),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: GcbAppTheme.surface,
                  ),
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a meeting code';
                    }
                    if (value.trim().length < 6) {
                      return 'Meeting code is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Display Name Input
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your display name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: GcbAppTheme.surface,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Enhanced Language Selection Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: GcbAppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GcbAppTheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: GcbAppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Display Language',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'All conversations will be translated to this language automatically',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Language Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _getPopularLanguages().length,
                        itemBuilder: (context, index) {
                          final langCode = _getPopularLanguages()[index];
                          final isSelected = langCode == _selectedTargetLanguage;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTargetLanguage = langCode;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? GcbAppTheme.primary.withOpacity(0.2)
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected ? Border.all(
                                  color: GcbAppTheme.primary,
                                  width: 2,
                                ) : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    SupportedLanguages.getLanguageFlag(langCode),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      SupportedLanguages.getLanguageName(langCode),
                                      style: TextStyle(
                                        color: isSelected ? GcbAppTheme.primary : Colors.white,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // More languages button
                      InkWell(
                        onTap: _showAllLanguagesDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[600]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.more_horiz,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'More languages',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Join Button
                ElevatedButton(
                  onPressed: _isJoining ? null : _joinMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GcbAppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isJoining
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_call, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Join Meeting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        SupportedLanguages.getLanguageFlag(_selectedTargetLanguage),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Feature highlight
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: GcbAppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: GcbAppTheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Real-time Translation',
                              style: TextStyle(
                                color: GcbAppTheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Speak your language, understand everyone else\'s language automatically',
                              style: TextStyle(
                                color: GcbAppTheme.primary.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Make sure you have camera and microphone permissions enabled. You can change your language settings anytime during the meeting.',
                          style: TextStyle(
                            color: Colors.orange[300],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getPopularLanguages() {
    // Return most popular languages for quick selection
    return ['en', 'vi', 'zh', 'ja', 'ko', 'es', 'fr', 'de'];
  }

  void _showAllLanguagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Select Your Language',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: SupportedLanguages.getAllLanguageCodes().length,
            itemBuilder: (context, index) {
              final langCode = SupportedLanguages.getAllLanguageCodes()[index];
              final isSelected = langCode == _selectedTargetLanguage;

              return ListTile(
                leading: Text(
                  SupportedLanguages.getLanguageFlag(langCode),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  SupportedLanguages.getLanguageName(langCode),
                  style: TextStyle(
                    color: isSelected ? GcbAppTheme.primary : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                  Icons.check_circle,
                  color: GcbAppTheme.primary,
                )
                    : null,
                onTap: () {
                  setState(() {
                    _selectedTargetLanguage = langCode;
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}