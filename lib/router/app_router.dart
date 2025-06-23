// lib/router/app_router.dart - FIXED WITH MISSING METHODS
import 'package:flutter/material.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/signin_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/join_meeting/join_meeting_screen.dart';
import '../screens/create_meeting/create_meeting_screen.dart';
import '../screens/meeting/meeting_screen.dart';

class Routes {
  // Route constants
  static const String welcome = '/welcome';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String home = '/home';
  static const String joinMeeting = '/join';
  static const String createMeeting = '/create';
  static const String meeting = '/meeting';

  // 🎯 FIXED: Make routes getter instead of final field
  Map<String, WidgetBuilder> get routes => {
    welcome: (context) => const WelcomeScreen(),
    signIn: (context) => const SignInScreen(),
    signUp: (context) => const SignUpScreen(),
    home: (context) => const HomeScreen(),
    joinMeeting: (context) => const JoinMeetingScreen(),
    createMeeting: (context) => const CreateMeetingScreen(),

    // ✅ Simplified meeting route - no unnecessary Consumer wrapper
    meeting: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      // Extract parameters
      final code = args?['code'] ?? '';
      final displayName = args?['displayName'];
      final targetLanguage = args?['targetLanguage'];
      final meetingId = args?['meetingId'];

      // Validate required parameter
      if (code.isEmpty && meetingId == null) {
        return _buildErrorScreen(
          context,
          'Invalid Meeting Code',
          'Meeting code or ID is required to join a meeting.',
        );
      }

      // ✅ Direct MeetingScreen instantiation - Provider is available from main.dart
      return MeetingScreen(
        code: code.isNotEmpty ? code : null,
        displayName: displayName,
        targetLanguage: targetLanguage,
        meetingId: meetingId,
      );
    },
  };

  // 🎯 ADDED: Generate route for dynamic routes
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    print('🔗 Generating route for: ${settings.name}');

    switch (settings.name) {
      case meeting:
      // Handle meeting with parameters
        final args = settings.arguments as Map<String, dynamic>?;

        print('📋 Meeting route args: $args');

        return MaterialPageRoute(
          builder: (context) => MeetingScreen(
            code: args?['code'],
            displayName: args?['displayName'],
            targetLanguage: args?['targetLanguage'],
            meetingId: args?['meetingId'],
          ),
          settings: settings,
        );

      case home:
        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
          settings: settings,
        );

      case welcome:
        return MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
          settings: settings,
        );

      case signIn:
        return MaterialPageRoute(
          builder: (context) => const SignInScreen(),
          settings: settings,
        );

      case signUp:
        return MaterialPageRoute(
          builder: (context) => const SignUpScreen(),
          settings: settings,
        );

      case joinMeeting:
        return MaterialPageRoute(
          builder: (context) => const JoinMeetingScreen(),
          settings: settings,
        );

      case createMeeting:
        return MaterialPageRoute(
          builder: (context) => const CreateMeetingScreen(),
          settings: settings,
        );

      default:
        print('❌ Unknown route: ${settings.name}');
        return null;
    }
  }

  // 🎯 ADDED: Helper method to build error screens
  static Widget _buildErrorScreen(BuildContext context, String title, String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, Routes.home),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Go Home'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, Routes.joinMeeting),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Join Meeting'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 ADDED: Navigate to meeting with parameters
  static Future<void> navigateToMeeting(
      BuildContext context, {
        String? code,
        String? displayName,
        String? targetLanguage,
        String? meetingId,
      }) async {
    print('🚀 Navigating to meeting:');
    print('   Code: $code');
    print('   Display Name: $displayName');
    print('   Target Language: $targetLanguage');
    print('   Meeting ID: $meetingId');

    await Navigator.pushNamed(
      context,
      Routes.meeting,
      arguments: {
        'code': code,
        'displayName': displayName,
        'targetLanguage': targetLanguage,
        'meetingId': meetingId,
      },
    );
  }

  // 🎯 ADDED: Navigate to home and clear stack
  static Future<void> navigateToHome(BuildContext context) async {
    print('🏠 Navigating to home (clearing stack)');

    await Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.home,
          (route) => false,
    );
  }

  // 🎯 ADDED: Navigate to welcome and clear stack
  static Future<void> navigateToWelcome(BuildContext context) async {
    print('🚪 Navigating to welcome (clearing stack)');

    await Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.welcome,
          (route) => false,
    );
  }

  // 🎯 ADDED: Check if route exists
  static bool routeExists(String routeName) {
    const allRoutes = [
      welcome,
      signIn,
      signUp,
      home,
      joinMeeting,
      createMeeting,
      meeting,
    ];

    return allRoutes.contains(routeName);
  }

  // Constructor
  Routes();
}