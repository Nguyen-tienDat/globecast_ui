// lib/screens/home/home_screen.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';

import '../test/test_screen.dart';

class EnhancedHomeScreen extends StatelessWidget {
  const EnhancedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          backgroundColor: GcbAppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top App Bar
                _buildTopAppBar(context, authService),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Section
                        _buildWelcomeSection(authService),

                        const SizedBox(height: 32),

                        // Quick Actions
                        _buildQuickActions(context),

                        const SizedBox(height: 32),

                        // Speech Translation Test Section
                        _buildSpeechTestSection(context),

                        const SizedBox(height: 32),

                        // Recent Meetings (if authenticated)
                        if (authService.isAuthenticated)
                          _buildRecentMeetings(context),

                        // Features Section (for guests)
                        if (!authService.isAuthenticated)
                          _buildFeaturesSection(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopAppBar(BuildContext context, AuthService authService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surface.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // App Logo & Name
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.language,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GlobeCast V2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Google Speech + MLKit',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // User Actions
          if (authService.isAuthenticated)
            _buildUserMenu(context, authService)
          else
            _buildGuestActions(context),
        ],
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context, AuthService authService) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            _showComingSoonDialog(context, 'Profile');
            break;
          case 'settings':
            _showComingSoonDialog(context, 'Settings');
            break;
          case 'signout':
            await _handleSignOut(context, authService);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Text(authService.displayName ?? 'Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings, color: Colors.grey, size: 20),
              SizedBox(width: 12),
              Text('Settings'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Sign Out', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: GcbAppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: GcbAppTheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: GcbAppTheme.primary,
              child: Text(
                (authService.displayName?.isNotEmpty == true)
                    ? authService.displayName![0].toUpperCase()
                    : (authService.userEmail?.isNotEmpty == true)
                    ? authService.userEmail![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              authService.displayName ?? 'User',
              style: const TextStyle(
                color: GcbAppTheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: GcbAppTheme.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestActions(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.pushNamed(context, Routes.signIn),
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: GcbAppTheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, Routes.signUp),
          style: ElevatedButton.styleFrom(
            backgroundColor: GcbAppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            'Sign Up',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(AuthService authService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          authService.isAuthenticated
              ? 'Welcome back, ${authService.displayName?.split(' ').first ?? 'User'}!'
              : 'Welcome to GlobeCast V2',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          authService.isAuthenticated
              ? 'Ready to connect with real-time translation?'
              : 'Google Speech + MLKit powered real-time translation',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context: context,
                icon: Icons.video_call,
                title: 'Join Meeting',
                subtitle: 'Enter meeting code',
                color: GcbAppTheme.primary,
                onTap: () => Navigator.pushNamed(context, Routes.joinMeeting),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context: context,
                icon: Icons.add_circle,
                title: 'Create Meeting',
                subtitle: 'Start new meeting',
                color: Colors.green,
                onTap: () => Navigator.pushNamed(context, Routes.createMeeting),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GcbAppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechTestSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Speech Translation Testing',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: GcbAppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
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
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.science,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Speech + MLKit Test',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Test real-time speech recognition and translation',
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

              const SizedBox(height: 16),

              // Features list
              _buildFeatureRow('🎤', 'Google Cloud Speech-to-Text'),
              _buildFeatureRow('🌐', 'MLKit On-device Translation'),
              _buildFeatureRow('🔄', 'Real-time Processing'),
              _buildFeatureRow('📱', 'Multi-language Support'),

              const SizedBox(height: 16),

              // Test button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SpeechTranslationTestScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Test Speech Translation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Info note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uses Google Speech API with your credentials and MLKit for on-device translation',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMeetings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Meetings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => _showComingSoonDialog(context, 'Meeting History'),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: GcbAppTheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Recent meetings list
        _buildMeetingCard(
          context: context,
          title: 'Team Weekly Standup',
          meetingId: 'GCM-123-456',
          time: 'Today, 2:00 PM',
          participants: 5,
          isActive: true,
        ),
        const SizedBox(height: 12),
        _buildMeetingCard(
          context: context,
          title: 'Global Project Review',
          meetingId: 'GCM-789-012',
          time: 'Tomorrow, 10:00 AM',
          participants: 8,
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildMeetingCard({
    required BuildContext context,
    required String title,
    required String meetingId,
    required String time,
    required int participants,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.videocam,
              color: isActive ? Colors.green : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meetingId,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.people,
                      color: Colors.grey[500],
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$participants',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showComingSoonDialog(context, 'Join Meeting'),
            icon: const Icon(
              Icons.play_arrow,
              color: GcbAppTheme.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why Choose GlobeCast V2?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),

        _buildFeatureItem(
          icon: Icons.translate,
          title: 'Real-time Translation',
          description: 'Google Speech + MLKit for accurate live translation',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.cloud,
          title: 'Powered by Google Cloud AI',
          description: 'High accuracy speech recognition with Google Speech API',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.phone_android,
          title: 'On-device Translation',
          description: 'MLKit translation works offline for privacy and speed',
          color: Colors.purple,
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.group,
          title: 'Global Collaboration',
          description: 'Connect with people worldwide without language barriers',
          color: Colors.orange,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, Routes.signUp),
            style: ElevatedButton.styleFrom(
              backgroundColor: GcbAppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Get Started - Sign Up Free',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, AuthService authService) async {
    try {
      await authService.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.welcome,
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: Text(
          '$feature Coming Soon',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'This feature is under development and will be available in the next update.',
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