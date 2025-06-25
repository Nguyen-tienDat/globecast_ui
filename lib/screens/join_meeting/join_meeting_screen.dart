// lib/screens/join_meeting/enhanced_join_meeting_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/translation_models.dart';
import '../meeting/meeting_screen.dart';

class EnhancedJoinMeetingScreen extends StatefulWidget {
  const EnhancedJoinMeetingScreen({super.key});

  @override
  State<EnhancedJoinMeetingScreen> createState() => _EnhancedJoinMeetingScreenState();
}

class _EnhancedJoinMeetingScreenState extends State<EnhancedJoinMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingCodeController = TextEditingController();
  final _displayNameController = TextEditingController();

  String _selectedSpeakingLanguage = 'vi'; // Language user speaks
  String _selectedDisplayLanguage = 'vi';  // Language user wants to see
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
      // Navigate to enhanced meeting screen with language settings
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingScreen(
              code: _meetingCodeController.text.trim().toUpperCase(),
              displayName: _displayNameController.text.trim(),
              targetLanguage: _selectedDisplayLanguage, // What user wants to see
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
          'Join Global Meeting',
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
                // Header
                const Icon(
                  Icons.translate,
                  size: 64,
                  color: GcbAppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Real-time Translation Meeting',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Speak your language, understand everyone else\'s automatically',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Meeting Code Input
                _buildInputSection(
                  title: 'Meeting Code',
                  child: TextFormField(
                    controller: _meetingCodeController,
                    decoration: InputDecoration(
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
                ),

                const SizedBox(height: 20),

                // Display Name Input
                _buildInputSection(
                  title: 'Your Name',
                  child: TextFormField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
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
                ),

                const SizedBox(height: 32),

                // 🎯 LANGUAGE CONFIGURATION SECTION
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
                              Icons.language,
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
                                  'Language Settings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Configure your speaking and display languages',
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

                      const SizedBox(height: 20),

                      // Speaking Language Selection
                      _buildLanguageSection(
                        title: '🎤 I speak',
                        subtitle: 'Language you will speak in the meeting',
                        selectedLanguage: _selectedSpeakingLanguage,
                        onLanguageChanged: (language) {
                          setState(() {
                            _selectedSpeakingLanguage = language;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // Display Language Selection
                      _buildLanguageSection(
                        title: '👁️ I want to see everything in',
                        subtitle: 'All conversations will be translated to this language',
                        selectedLanguage: _selectedDisplayLanguage,
                        onLanguageChanged: (language) {
                          setState(() {
                            _selectedDisplayLanguage = language;
                          });
                        },
                      ),

                      const SizedBox(height: 16),

                      // Language preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You speak ${SupportedLanguages.getLanguageFlag(_selectedSpeakingLanguage)} ${SupportedLanguages.getLanguageName(_selectedSpeakingLanguage)}, see everything in ${SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage)} ${SupportedLanguages.getLanguageName(_selectedDisplayLanguage)}',
                                style: const TextStyle(
                                  color: Colors.blue,
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

                const SizedBox(height: 32),

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
                        'Join with Translation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${SupportedLanguages.getLanguageFlag(_selectedSpeakingLanguage)} → ${SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Feature highlight
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Real-time Translation Features',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem('✨ Automatic language detection'),
                      _buildFeatureItem('🗣️ Live speech-to-text transcription'),
                      _buildFeatureItem('🌐 Instant translation to your language'),
                      _buildFeatureItem('👥 See everyone\'s conversation translated'),
                      _buildFeatureItem('🎯 High accuracy with Google Cloud AI'),
                    ],
                  ),
                ),

                const SizedBox(height: 40), // Extra padding for scroll
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildLanguageSection({
    required String title,
    required String subtitle,
    required String selectedLanguage,
    required Function(String) onLanguageChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),

        // Language selection grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _getPopularLanguages().length,
          itemBuilder: (context, index) {
            final langCode = _getPopularLanguages()[index];
            final isSelected = langCode == selectedLanguage;

            return InkWell(
              onTap: () => onLanguageChanged(langCode),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? GcbAppTheme.primary.withOpacity(0.2)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
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
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        SupportedLanguages.getLanguageName(langCode),
                        style: TextStyle(
                          color: isSelected ? GcbAppTheme.primary : Colors.white,
                          fontSize: 11,
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

        const SizedBox(height: 8),

        // More languages button
        InkWell(
          onTap: () => _showAllLanguagesDialog(selectedLanguage, onLanguageChanged),
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
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getPopularLanguages() {
    return ['vi', 'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de'];
  }

  void _showAllLanguagesDialog(String currentSelection, Function(String) onChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Select Language',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: SupportedLanguages.getAllLanguageCodes().length,
            itemBuilder: (context, index) {
              final langCode = SupportedLanguages.getAllLanguageCodes()[index];
              final isSelected = langCode == currentSelection;

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
                subtitle: Text(
                  SupportedLanguages.getNativeName(langCode),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                  Icons.check_circle,
                  color: GcbAppTheme.primary,
                )
                    : null,
                onTap: () {
                  onChanged(langCode);
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