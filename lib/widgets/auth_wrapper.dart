// lib/widgets/auth_wrapper.dart - FIXED AND ENHANCED
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/home/home_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading screen while checking auth state
        if (authService.isLoading) {
          return _buildAuthLoadingScreen();
        }

        // Navigate based on authentication status
        if (authService.isAuthenticated) {
          return const EnhancedHomeScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }

  Widget _buildAuthLoadingScreen() {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: GcbAppTheme.primary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.language,
                size: 50,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // App name
            const Text(
              'GlobeCast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Tagline
            Text(
              'Real-time Translation Meetings',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 48),

            // Loading indicator
            const CircularProgressIndicator(
              color: GcbAppTheme.primary,
              strokeWidth: 2,
            ),

            const SizedBox(height: 16),

            // Loading text
            Text(
              'Checking authentication...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 32),

            // Auth status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Secure Firebase Authentication',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}