// lib/screens/home/home_screen.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

@RoutePage()
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          backgroundColor: GcbAppTheme.background,
          appBar: AppBar(
            backgroundColor: GcbAppTheme.background,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.language,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GlobeCast',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              // User profile or Sign in button
              if (authService.isAuthenticated)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'profile') {
                      // TODO: Navigate to profile screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile screen coming soon!')),
                      );
                    } else if (value == 'signout') {
                      try {
                        await authService.signOut();
                        if (context.mounted) {
                          context.router.replaceAll([const WelcomeRoute()]);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sign out failed: $e')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(authService.displayName ?? 'Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'signout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Sign Out', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue,
                      child: Text(
                        (authService.displayName?.isNotEmpty == true)
                            ? authService.displayName![0].toUpperCase()
                            : (authService.userEmail?.isNotEmpty == true)
                            ? authService.userEmail![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    context.router.push(const SignInRoute());
                  },
                  child: const Text(
                    'Sign In',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message
                  if (authService.isAuthenticated) ...[
                    Text(
                      'Welcome back, ${authService.displayName ?? 'User'}!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ready to connect globally?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Welcome to GlobeCast',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect and communicate across languages',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Meeting buttons
                  _buildActionButton(
                    context: context,
                    icon: Icons.group,
                    label: 'Join Meeting',
                    color: Colors.blue,
                    onPressed: () {
                      context.router.push(const JoinMeetingRoute());
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    context: context,
                    icon: Icons.video_call,
                    label: 'Create Meeting',
                    color: Colors.blue,
                    onPressed: () {
                      context.router.push(const CreateMeetingRoute());
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    context: context,
                    icon: Icons.calendar_today,
                    label: 'Schedule Meeting',
                    color: Colors.transparent,
                    borderColor: Colors.blue,
                    textColor: Colors.blue,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Schedule Meeting coming soon!')),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // My Meetings section (only show if authenticated)
                  if (authService.isAuthenticated) ...[
                    Text(
                      'My Meetings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Meeting list
                    Expanded(
                      child: ListView(
                        children: [
                          _buildMeetingCard(
                            context: context,
                            title: 'Weekly Team Standup',
                            meetingId: 'GCM-123-456-789',
                            time: 'Today, 2:00 PM',
                            onJoin: () {
                              context.router.push(MeetingRoute(code: 'GCM-123-456-789'));
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildMeetingCard(
                            context: context,
                            title: 'Project Kickoff',
                            meetingId: 'GCM-987-654-321',
                            time: 'Tomorrow, 10:00 AM',
                            onJoin: () {
                              context.router.push(MeetingRoute(code: 'GCM-987-654-321'));
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Guest message
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_circle_outlined,
                              size: 80,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sign in to access your meetings',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                context.router.push(const SignInRoute());
                              },
                              child: const Text(
                                'Sign In Now',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    Color? borderColor,
    Color? textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          side: borderColor != null ? BorderSide(color: borderColor) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: textColor ?? Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard({
    required BuildContext context,
    required String title,
    required String meetingId,
    required String time,
    required VoidCallback onJoin,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.videocam,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meetingId,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Join',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}