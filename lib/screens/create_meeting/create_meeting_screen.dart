// lib/screens/create_meeting/create_meeting_screen.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../services/webrtc_mesh_meeting_service.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _topicController = TextEditingController();
  String _selectedDuration = '60 min';
  String _selectedLanguage = 'English';
  final List<String> _selectedTranslationLanguages = ['Spanish', 'French'];
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _topicController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createMeeting() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting topic')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);

      // Set user details
      webrtcService.setUserDetails(displayName: 'You (Host)');

      // Create meeting
      final meetingId = await webrtcService.createMeeting(topic: _topicController.text.trim());

      if (mounted) {
        Navigator.pushNamed(
            context,
            Routes.meeting,
            arguments: {'code': meetingId}
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
          'Create Meeting',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meeting Topic
              const Text(
                'Meeting Topic',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Meeting Topic Input
              TextField(
                controller: _topicController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter meeting topic',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.title, color: Colors.grey),
                  filled: true,
                  fillColor: GcbAppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // Meeting Duration
              const Text(
                'Meeting Duration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Duration Dropdown
              Container(
                decoration: BoxDecoration(
                  color: GcbAppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDuration,
                    dropdownColor: GcbAppTheme.surface,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    isExpanded: true,
                    items: ['30 min', '60 min', '90 min', '2 hour']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDuration = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Speaking Language
              const Text(
                'Speaking Language',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Language Dropdown
              Container(
                decoration: BoxDecoration(
                  color: GcbAppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: GcbAppTheme.surface,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    isExpanded: true,
                    items: ['English', 'Spanish', 'French', 'German', 'Chinese']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
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
              ),
              const SizedBox(height: 16),

              // Translation Languages
              const Text(
                'Translation Languages',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Selected Languages Chips
              Wrap(
                spacing: 8,
                children: [
                  ..._selectedTranslationLanguages.map((language) {
                    return Chip(
                      label: Text(
                        language,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: GcbAppTheme.surface,
                      deleteIcon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onDeleted: () {
                        setState(() {
                          _selectedTranslationLanguages.remove(language);
                        });
                      },
                    );
                  }).toList(),

                  // Add Language Button
                  ActionChip(
                    label: const Text(
                      'Add Language',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: Colors.blue.withOpacity(0.3),
                    onPressed: () {
                      _showLanguageSelectionDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Password
              const Text(
                'Password (optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Password Input
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Set meeting password',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  filled: true,
                  fillColor: GcbAppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              const Spacer(),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                      : const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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

  // Show language selection dialog
  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GcbAppTheme.surface,
          title: const Text(
            'Select Translation Language',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...['Spanish', 'French', 'German', 'Chinese', 'Japanese', 'Korean', 'Russian', 'Arabic']
                    .where((language) => !_selectedTranslationLanguages.contains(language) && language != _selectedLanguage)
                    .map((language) => ListTile(
                  title: Text(
                    language,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedTranslationLanguages.add(language);
                    });
                    Navigator.pop(context);
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }
}