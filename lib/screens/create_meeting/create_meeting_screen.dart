// lib/screens/create_meeting/enhanced_create_meeting_screen.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../../models/translation_models.dart';
import '../meeting/meeting_screen.dart';

class EnhancedCreateMeetingScreen extends StatefulWidget {
  const EnhancedCreateMeetingScreen({super.key});

  @override
  State<EnhancedCreateMeetingScreen> createState() => _EnhancedCreateMeetingScreenState();
}

class _EnhancedCreateMeetingScreenState extends State<EnhancedCreateMeetingScreen> {
  final _topicController = TextEditingController();
  final _hostNameController = TextEditingController(text: 'Host');

  String _selectedHostLanguage = 'vi'; // Language host speaks
  String _selectedDisplayLanguage = 'vi'; // Language host wants to see
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    _hostNameController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting topic')),
      );
      return;
    }

    if (_hostNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);

      // Set user details with host name
      webrtcService.setUserDetails(displayName: '${_hostNameController.text.trim()} (Host)');

      // Create meeting
      final meetingId = await webrtcService.createMeeting(topic: _topicController.text.trim());

      if (mounted) {
        // Navigate to enhanced meeting screen with language settings
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingScreen(
              code: meetingId,
              displayName: '${_hostNameController.text.trim()} (Host)',
              targetLanguage: _selectedDisplayLanguage,
              meetingId: meetingId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create meeting: $e')),
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
          'Create Global Meeting',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_circle,
                      size: 64,
                      color: GcbAppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Start Translation Meeting',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a meeting where everyone speaks their language',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Meeting Topic
              _buildInputSection(
                title: 'Meeting Topic',
                child: TextField(
                  controller: _topicController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter meeting topic',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.topic, color: Colors.grey),
                    filled: true,
                    fillColor: GcbAppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Host Name
              _buildInputSection(
                title: 'Your Name (Host)',
                child: TextField(
                  controller: _hostNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    filled: true,
                    fillColor: GcbAppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 🎯 HOST LANGUAGE CONFIGURATION
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
                                'Host Language Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Configure your speaking and display languages as host',
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

                    // Host Speaking Language
                    _buildLanguageSection(
                      title: '🎤 I will speak',
                      subtitle: 'Language you will use to host the meeting',
                      selectedLanguage: _selectedHostLanguage,
                      onLanguageChanged: (language) {
                        setState(() {
                          _selectedHostLanguage = language;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // Host Display Language
                    _buildLanguageSection(
                      title: '👁️ I want to see everything in',
                      subtitle: 'All participants\' conversations will be translated to this',
                      selectedLanguage: _selectedDisplayLanguage,
                      onLanguageChanged: (language) {
                        setState(() {
                          _selectedDisplayLanguage = language;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.preview,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'As host: Speak ${SupportedLanguages.getLanguageFlag(_selectedHostLanguage)} ${SupportedLanguages.getLanguageName(_selectedHostLanguage)}, see everything in ${SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage)} ${SupportedLanguages.getLanguageName(_selectedDisplayLanguage)}',
                              style: const TextStyle(
                                color: Colors.green,
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

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                      const Icon(Icons.video_call, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Create & Start Meeting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${SupportedLanguages.getLanguageFlag(_selectedHostLanguage)} → ${SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info about participants
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'How it works for participants',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem('🌐 Each participant chooses their own language'),
                    _buildInfoItem('🗣️ Everyone speaks their native language'),
                    _buildInfoItem('👂 Everyone sees conversations in their chosen language'),
                    _buildInfoItem('🤝 Natural communication across all languages'),
                  ],
                ),
              ),

              const SizedBox(height: 40), // Extra padding at bottom for scroll
            ],
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

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blue[300],
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