// lib/widgets/auth_wrapper.dart - ENHANCED FOR PRODUCTION
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
          return _buildLoadingScreen();
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

  Widget _buildLoadingScreen() {
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
              'Loading...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}