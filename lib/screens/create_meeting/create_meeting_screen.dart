// lib/screens/create_meeting/enhanced_create_meeting_screen.dart - SIMPLIFIED VERSION
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../meeting/meeting_screen.dart';

class EnhancedCreateMeetingScreen extends StatefulWidget {
  const EnhancedCreateMeetingScreen({super.key});

  @override
  State<EnhancedCreateMeetingScreen> createState() => _EnhancedCreateMeetingScreenState();
}

class _EnhancedCreateMeetingScreenState extends State<EnhancedCreateMeetingScreen> {
  final _topicController = TextEditingController();
  final _hostNameController = TextEditingController(text: 'Host');

  String _selectedLanguage = 'vi'; // User's primary language
  bool _isLoading = false;

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
        // Navigate to meeting screen with language setting
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MeetingScreen(
              code: meetingId,
              displayName: '${_hostNameController.text.trim()} (Host)',
              targetLanguage: _selectedLanguage,
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
          'Create Translation Meeting',
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
                      'Create a meeting with instant Google Cloud translation',
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
                                'Your Language',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Language you speak & others will see',
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

                    // Language selection
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
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
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
                          _buildExplanationItem('🎤 You speak ${_languages[_selectedLanguage]?.split(' ').last}'),
                          _buildExplanationItem('👥 Others hear real-time translation to ${_languages[_selectedLanguage]?.split(' ').last}'),
                          _buildExplanationItem('🌐 You see all conversations translated to ${_languages[_selectedLanguage]?.split(' ').last}'),
                          _buildExplanationItem('⚡ Powered by Google Cloud AI'),
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
                        'Create Meeting',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _languages[_selectedLanguage]?.split(' ').first ?? '',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Features info
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
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Meeting Features',
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
                    _buildFeatureItem('🔥 Real-time speech translation'),
                    _buildFeatureItem('☁️ Google Cloud Speech-to-Text'),
                    _buildFeatureItem('👥 Up to 6 participants'),
                    _buildFeatureItem('🎯 Auto language detection'),
                    _buildFeatureItem('📱 Works on all devices'),
                  ],
                ),
              ),

              const SizedBox(height: 40),
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
                    entry.value.split(' ').first, // Flag emoji
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value.substring(entry.value.indexOf(' ') + 1), // Language name
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
}