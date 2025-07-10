// lib/screens/join_meeting/enhanced_join_meeting_screen.dart - SIMPLIFIED VERSION
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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

  String _selectedLanguage = 'vi'; // User's primary language
  bool _isJoining = false;

  final Map<String, String> _languages = {
    'vi': '🇻🇳 Tiếng Việt',
    'en': '🇺🇸 English',
    'zh': '🇨🇳 Chinese',
    'ja': '🇯🇵 Japanese',
    'ko': '🇰🇷 Korean',
    'th': '🇹🇭 Thai',
    'es': '🇪🇸 Spanish',
    'fr': '🇫🇷 French',
    'de': '🇩🇪 German',
    'ar': '🇸🇦 Arabic',
    'hi': '🇮🇳 Hindi',
  };

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
      // Navigate to meeting screen with language setting
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingScreen(
              code: _meetingCodeController.text.trim().toUpperCase(),
              displayName: _displayNameController.text.trim(),
              targetLanguage: _selectedLanguage,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Meeting Code Input
                _buildInputSection(
                  title: 'Meeting Code',
                  child: TextFormField(
                    controller: _meetingCodeController,
                    decoration: InputDecoration(
                      hintText: 'Enter meeting code (e.g., GCM12345678)',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.meeting_room, color: Colors.grey),
                      filled: true,
                      fillColor: GcbAppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.person, color: Colors.grey),
                      filled: true,
                      fillColor: GcbAppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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

                // 🎯 SIMPLIFIED LANGUAGE SELECTION
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
                              Icons.public,
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
                                  'Your Language',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Language you speak & want to see',
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

                      // Language selection dropdown
                      _buildLanguageDropdown(),

                      const SizedBox(height: 16),

                      // Explanation
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'How it works:',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildExplanationItem('🎤 You speak ${_getLanguageName(_selectedLanguage)}'),
                            _buildExplanationItem('🌐 Everyone hears real-time translation to their language'),
                            _buildExplanationItem('👂 You see all conversations in ${_getLanguageName(_selectedLanguage)}'),
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
                        'Join Meeting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getLanguageFlag(_selectedLanguage),
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
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Translation Features',
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

                const SizedBox(height: 40),
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

  Widget _buildLanguageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          isExpanded: true,
          dropdownColor: GcbAppTheme.surface,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: _languages.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Row(
                children: [
                  Text(
                    _getLanguageFlag(entry.key),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getLanguageName(entry.key),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedLanguage = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildExplanationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blue[300],
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
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

  String _getLanguageFlag(String languageCode) {
    return _languages[languageCode]?.split(' ').first ?? '';
  }

  String _getLanguageName(String languageCode) {
    final fullName = _languages[languageCode] ?? '';
    return fullName.substring(fullName.indexOf(' ') + 1);
  }
}