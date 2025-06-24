// lib/main.dart - UPDATED WITH INTEGRATION SERVICE
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/services/audio_capture_service.dart';
import 'package:globecast_ui/services/integrated_meeting_service.dart';
import 'package:globecast_ui/screens/integration_test_screen.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'google_cloud_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🚀 TEST GOOGLE CLOUD
  await GoogleCloudTest.testConnection();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  final WebRTCMeshMeetingService _webrtcService = WebRTCMeshMeetingService();
  final MultilingualSpeechService _speechService = MultilingualSpeechService();
  final AudioCaptureService _audioService = AudioCaptureService();
  final Routes _routes = Routes();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _webrtcService.initialize();
      _webrtcService.setSpeechService(_speechService);
      print('✅ Services initialized');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _webrtcService),
        ChangeNotifierProvider.value(value: _speechService),
        ChangeNotifierProvider.value(value: _audioService),
      ],
      child: MaterialApp(
        title: 'GlobeCast',
        theme: GcbAppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const AppNavigator(),
        routes: _routes.routes,
      ),
    );
  }

  @override
  void dispose() {
    _authService.dispose();
    _webrtcService.dispose();
    _speechService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'GlobeCast - Integration Test',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.language,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'GlobeCast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time Translation Testing',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),

            // Navigation Buttons
            SizedBox(
              width: 280,
              child: Column(
                children: [
                  _buildNavigationButton(
                    context,
                    'Integration Test',
                    'Test complete workflow with all services',
                    Icons.science,
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IntegrationTestScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationButton(
                    context,
                    'Original Meeting',
                    'Original meeting interface',
                    Icons.video_call,
                        () => Navigator.pushNamed(context, Routes.home),
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationButton(
                    context,
                    'Join Meeting',
                    'Quick join meeting',
                    Icons.meeting_room,
                        () => Navigator.pushNamed(context, Routes.joinMeeting),
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationButton(
                    context,
                    'Create Meeting',
                    'Create new meeting',
                    Icons.add_circle,
                        () => Navigator.pushNamed(context, Routes.createMeeting),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Status Info
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: GcbAppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Integration Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow('✅ Android Audio Plugin', 'Ready'),
                  _buildStatusRow('✅ Google Cloud Speech', 'Ready'),
                  _buildStatusRow('✅ Google Cloud Translation', 'Ready'),
                  _buildStatusRow('✅ WebRTC Mesh Network', 'Ready'),
                  _buildStatusRow('✅ Firebase Integration', 'Ready'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onPressed,
      ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GcbAppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}