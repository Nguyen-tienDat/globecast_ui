// lib/router/app_router.dart - UPDATED FOR ENHANCED MEETING
import 'package:flutter/material.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/signin_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/create_meeting/create_meeting_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/join_meeting/join_meeting_screen.dart';
import '../screens/meeting/meeting_screen.dart';

class Routes {
  static const String welcome = '/welcome';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String home = '/home';
  static const String joinMeeting = '/join';
  static const String createMeeting = '/create';
  static const String meeting = '/meeting';

  final routes = {
    welcome: (context) => const WelcomeScreen(),
    signIn: (context) => const SignInScreen(),
    signUp: (context) => const SignUpScreen(),
    home: (context) => const EnhancedHomeScreen(),

    // 🎯 ENHANCED JOIN MEETING WITH LANGUAGE SETUP
    joinMeeting: (context) => const EnhancedJoinMeetingScreen(),

    // 🎯 ENHANCED CREATE MEETING WITH LANGUAGE SETUP
    createMeeting: (context) => const EnhancedCreateMeetingScreen(),

    // Enhanced meeting route
    meeting: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      // Extract parameters
      final code = args?['code'] ?? '';
      final displayName = args?['displayName'];
      final targetLanguage = args?['targetLanguage'];

      // Validate required parameter
      if (code.isEmpty) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Invalid Meeting Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, Routes.home),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Enhanced MeetingScreen with real-time translation
      return MeetingScreen(
        code: code,
        displayName: displayName,
        targetLanguage: targetLanguage,
      );
    },
  };

  Routes();
}