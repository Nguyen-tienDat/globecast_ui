// lib/router/app_router.dart
import 'package:flutter/material.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/signin_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/join_meeting/join_meeting_screen.dart';
import '../screens/create_meeting/create_meeting_screen.dart';
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
    home: (context) => const HomeScreen(),
    joinMeeting: (context) => const JoinMeetingScreen(),
    createMeeting: (context) => const CreateMeetingScreen(),
    meeting: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final code = args?['code'] ?? '';
      return MeetingScreen(code: code);
    },
  };

  Routes();
}
