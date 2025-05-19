import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/theme/app_theme.dart';

@RoutePage()
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.language,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Text(
                'GlobeCast',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome to GlobeCast',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Meeting buttons
              _buildActionButton(
                context: context,
                icon: Icons.group,
                label: 'Join Meeting',
                color: Colors.blue,
                onPressed: () {
                  // Sử dụng auto_route để điều hướng
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
                  // Sử dụng auto_route để điều hướng
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
                  // Tạm thời chưa có màn hình Schedule Meeting
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schedule Meeting coming soon!')),
                  );
                },
              ),
              const SizedBox(height: 24),
              // My Meetings section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Meetings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Meeting list
              _buildMeetingCard(
                context: context,
                title: 'Weekly Team Standup',
                meetingId: 'GCM-123-456-789',
                onJoin: () {
                  // Sử dụng auto_route để điều hướng đến màn hình meeting với code
                  context.router.push(MeetingRoute(code: 'GCM-123-456-789'));
                },
              ),
              const SizedBox(height: 12),
              _buildMeetingCard(
                context: context,
                title: 'Project Kickoff',
                meetingId: 'GCM-987-654-321',
                onJoin: () {
                  // Sử dụng auto_route để điều hướng
                  context.router.push(MeetingRoute(code: 'GCM-987-654-321'));
                },
              ),
            ],
          ),
        ),
      ),
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
    required VoidCallback onJoin,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.videocam,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meetingId,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Join Now'),
            ),
          ],
        ),
      ),
    );
  }
}