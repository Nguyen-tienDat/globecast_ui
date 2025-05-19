import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../services/meeting_service.dart';

@RoutePage()
class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _topicController = TextEditingController();
  String _selectedDuration = '60 hour';
  String _selectedLanguage = 'English';
  final List<String> _selectedTranslationLanguages = ['Spanish', 'French'];
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generateMeetingId() {
    const uuid = Uuid();
    return 'GCM-${uuid.v4().substring(0, 8)}';
  }

  // Phương thức tạo cuộc họp mới
  Future<void> _createMeeting() async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting topic')),
      );
      return;
    }

    try {
      final meetingService = Provider.of<GcbMeetingService>(context, listen: false);

      // Set user details
      meetingService.setUserDetails(displayName: 'You (Host)');

      // Set language preferences
      meetingService.setLanguagePreferences(
        speaking: _selectedLanguage.toLowerCase(),
        listening: _selectedLanguage.toLowerCase(),
      );

      // Create meeting
      final meetingId = await meetingService.createMeeting(
        topic: _topicController.text,
        password: _passwordController.text,
        translationLanguages: _selectedTranslationLanguages.map((e) => e.toLowerCase()).toList(),
      );

      // Navigate to meeting screen
      context.router.push(MeetingRoute(code: meetingId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create meeting: $e')),
      );
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
          onPressed: () => context.router.pop(),
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
                    items: ['30 min', '60 hour', '90 min', '2 hour']
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
                      // Show language selection dialog
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

              // Create Button - ĐÃ SỬA
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _createMeeting,  // Đã sửa: bỏ từ khóa const
                  style: ButtonStyle(  // Đã sửa: sử dụng ButtonStyle thay vì ElevatedButton.styleFrom
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  child: const Text(
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

  // Hiển thị dialog chọn ngôn ngữ
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