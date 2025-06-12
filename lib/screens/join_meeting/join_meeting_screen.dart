// lib/screens/join_meeting/join_meeting_screen.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../services/webrtc_mesh_meeting_service.dart';

class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({super.key});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _meetingCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _meetingCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinMeeting() async {
    if (_meetingCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final webrtcService = Provider.of<WebRTCMeshMeetingService>(context, listen: false);

      // Set user details with random ID to simulate different users
      webrtcService.setUserDetails(displayName: 'Participant');

      // Navigate to meeting screen (joining will happen there)
      Navigator.pushNamed(
          context,
          Routes.meeting,
          arguments: {'code': _meetingCodeController.text.trim()}
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare for joining: $e')),
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
          'Join Meeting',
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
              // Meeting Code Label
              const Text(
                'Meeting Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Meeting Code Input
              TextField(
                controller: _meetingCodeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter meeting code',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.numbers, color: Colors.grey),
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

              // Password Label
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
                  hintText: 'Enter meeting password if required',
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

              // Join Now Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinMeeting,
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
                    'Join Now',
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
}