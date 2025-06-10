// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';

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
                    Icons.hub,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GlobeCast Mesh',
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile screen coming soon!')),
                      );
                    } else if (value == 'signout') {
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
                    Navigator.pushNamed(context, Routes.signIn);
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
                      'Start your WebRTC mesh meeting',
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
                      'Peer-to-peer video conferencing',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // WebRTC Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      border: Border.all(color: Colors.blue, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'WebRTC Mesh Network',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Direct peer-to-peer connections with no server in between. '
                              'Ultra-low latency, end-to-end encrypted, and supports up to 6 participants.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Meeting buttons
                  _buildActionButton(
                    context: context,
                    icon: Icons.add_circle,
                    label: 'Create Mesh Meeting',
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.createMeeting);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    context: context,
                    icon: Icons.meeting_room,
                    label: 'Join Meeting',
                    color: Colors.green,
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.joinMeeting);
                    },
                  ),

                  const SizedBox(height: 32),

                  // Features section
                  Text(
                    'WebRTC Mesh Features',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView(
                      children: [
                        _buildFeatureCard(
                          icon: Icons.speed,
                          title: 'Ultra Low Latency',
                          description: 'Direct P2P connection for instant communication',
                          color: Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureCard(
                          icon: Icons.security,
                          title: 'End-to-End Encrypted',
                          description: 'Your conversations are private and secure',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureCard(
                          icon: Icons.people,
                          title: 'Up to 6 Participants',
                          description: 'Optimal mesh network performance for small teams',
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureCard(
                          icon: Icons.storage_outlined,
                          title: 'No Server Recording',
                          description: 'Nothing stored on servers, complete privacy',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ),
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
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
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
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
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