// lib/router/app_router.dart - CLEAN ROUTER ARCHITECTURE
import 'package:flutter/material.dart';

// Screens - Auth
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/signin_screen.dart';
import '../screens/auth/signup_screen.dart';

// Screens - Main App
import '../screens/home/home_screen.dart';
import '../screens/create_meeting/create_meeting_screen.dart';
import '../screens/join_meeting/join_meeting_screen.dart';
import '../screens/meeting/meeting_screen.dart';
import '../screens/test/test_screen.dart';
import '../screens/language/language_settings_screen.dart';

// Widgets
import '../widgets/auth_wrapper.dart';

// Theme
import '../theme/app_theme.dart';

class Routes {
  // Global navigation key
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Route names
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String home = '/home';
  static const String createMeeting = '/create-meeting';
  static const String joinMeeting = '/join-meeting';
  static const String meeting = '/meeting';
  static const String test = '/test';
  static const String languageSettings = '/language-settings';

  // Initial route
  static const String initialRoute = splash;

  /// Generate routes based on route name
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    debugPrint('🧭 Navigating to: ${settings.name}');

    switch (settings.name) {
    // Splash/Auth Wrapper
      case splash:
        return _createRoute(const AuthWrapper());

    // Authentication Routes
      case welcome:
        return _createRoute(const WelcomeScreen());

      case signIn:
        return _createRoute(const SignInScreen());

      case signUp:
        return _createRoute(const SignUpScreen());

    // Main App Routes
      case home:
        return _createRoute(const HomeScreen());

      case createMeeting:
        return _createRoute(const EnhancedCreateMeetingScreen());

      case joinMeeting:
        return _createRoute(const EnhancedJoinMeetingScreen());

    // Meeting Route with parameters
      case meeting:
        return _createMeetingRoute(settings);

    // Test Routes
      case test:
        return _createRoute(const SpeechTranslationTestScreen());

    // Settings Routes
      case languageSettings:
        return _createRoute(const LanguageSettingsScreen());

    // Unknown route
      default:
        return unknownRoute(settings);
    }
  }

  /// Create meeting route with parameter validation
  static Route<dynamic> _createMeetingRoute(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>?;

    // Validate required parameters
    final code = args?['code'] as String?;
    final displayName = args?['displayName'] as String?;
    final targetLanguage = args?['targetLanguage'] as String?;
    final meetingId = args?['meetingId'] as String?;

    if (code == null || code.trim().isEmpty) {
      return _createRoute(_buildErrorScreen(
        'Invalid Meeting Code',
        'Please check your meeting code and try again.',
        home,
      ));
    }

    return _createRoute(
      MeetingScreen(
        code: code,
        displayName: displayName,
        targetLanguage: targetLanguage,
        meetingId: meetingId,
      ),
    );
  }

  /// Handle unknown routes
  static Route<dynamic> unknownRoute(RouteSettings settings) {
    debugPrint('❌ Unknown route: ${settings.name}');

    return _createRoute(_buildErrorScreen(
      'Page Not Found',
      'The page "${settings.name}" does not exist.',
      home,
    ));
  }

  /// Create a standard page route with animations
  static PageRoute<T> _createRoute<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide transition from right to left
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Build error screen for invalid routes or parameters
  static Widget _buildErrorScreen(String title, String message, String homeRoute) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.background,
        elevation: 0,
        title: Text(
          'Error',
          style: TextStyle(color: Colors.red[400]),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (navigatorKey.currentState?.canPop() == true) {
              navigatorKey.currentState?.pop();
            } else {
              navigatorKey.currentState?.pushReplacementNamed(homeRoute);
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 80,
              ),

              const SizedBox(height: 24),

              // Error title
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

              // Error message
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Action buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        navigatorKey.currentState?.pushNamedAndRemoveUntil(
                          homeRoute,
                              (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Go to Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GcbAppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (navigatorKey.currentState?.canPop() == true) {
                          navigatorKey.currentState?.pop();
                        } else {
                          navigatorKey.currentState?.pushReplacementNamed(homeRoute);
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation helper methods

  /// Navigate to a route and remove all previous routes
  static Future<void> pushAndClearStack(String routeName, {Object? arguments}) async {
    await navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
          (route) => false,
      arguments: arguments,
    );
  }

  /// Navigate to a route
  static Future<void> pushNamed(String routeName, {Object? arguments}) async {
    await navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
  }

  /// Replace current route
  static Future<void> pushReplacementNamed(String routeName, {Object? arguments}) async {
    await navigatorKey.currentState?.pushReplacementNamed(routeName, arguments: arguments);
  }

  /// Go back
  static void pop([Object? result]) {
    navigatorKey.currentState?.pop(result);
  }

  /// Check if can go back
  static bool canPop() {
    return navigatorKey.currentState?.canPop() ?? false;
  }

  // Convenience navigation methods

  /// Navigate to home screen
  static Future<void> goToHome() async {
    await pushAndClearStack(home);
  }

  /// Navigate to welcome screen
  static Future<void> goToWelcome() async {
    await pushAndClearStack(welcome);
  }

  /// Navigate to meeting with parameters
  static Future<void> goToMeeting({
    required String code,
    String? displayName,
    String? targetLanguage,
    String? meetingId,
  }) async {
    await pushNamed(meeting, arguments: {
      'code': code,
      'displayName': displayName,
      'targetLanguage': targetLanguage,
      'meetingId': meetingId,
    });
  }

  /// Navigate to join meeting screen
  static Future<void> goToJoinMeeting() async {
    await pushNamed(joinMeeting);
  }

  /// Navigate to create meeting screen
  static Future<void> goToCreateMeeting() async {
    await pushNamed(createMeeting);
  }

  /// Navigate to test screen
  static Future<void> goToTest() async {
    await pushNamed(test);
  }

  /// Navigate to language settings
  static Future<void> goToLanguageSettings() async {
    await pushNamed(languageSettings);
  }

  /// Show error dialog
  static Future<void> showErrorDialog(BuildContext context, String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 24),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: GcbAppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Show success dialog
  static Future<void> showSuccessDialog(BuildContext context, String title, String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: GcbAppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}