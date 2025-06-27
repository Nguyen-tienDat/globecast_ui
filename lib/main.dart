// lib/main.dart - FIXED SERVICE INTEGRATION
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:globecast_ui/screens/meeting/meeting_screen.dart';
import 'package:globecast_ui/screens/create_meeting/create_meeting_screen.dart';
import 'package:globecast_ui/screens/join_meeting/join_meeting_screen.dart';
import 'package:globecast_ui/screens/test/test_screen.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/google_speech_translation_service.dart'; // ✅ PRIMARY SERVICE
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Request permissions on startup
  await _requestPermissions();

  runApp(const GlobecastApp());
}

Future<void> _requestPermissions() async {
  try {
    final permissions = [
      Permission.microphone,
      Permission.camera,
      Permission.storage,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    for (var permission in permissions) {
      final status = statuses[permission];
      print('🔐 ${permission.toString()}: ${status.toString()}');
    }
  } catch (e) {
    print('❌ Error requesting permissions: $e');
  }
}

class GlobecastApp extends StatelessWidget {
  const GlobecastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ AUTH SERVICE
        ChangeNotifierProvider(
          create: (context) => AuthService(),
        ),

        // 🎯 WEBRTC MEETING SERVICE
        ChangeNotifierProvider(
          create: (context) => WebRTCMeshMeetingService(),
        ),

        // ✅ GOOGLE SPEECH TRANSLATION SERVICE (PRIMARY)
        ChangeNotifierProvider(
          create: (context) => GoogleSpeechTranslationService(),
        ),
      ],
      child: MaterialApp(
        title: 'Globecast - Real-time Translation Sync',
        theme: GcbAppTheme.darkTheme,
        initialRoute: '/init',
        debugShowCheckedModeBanner: false,
        routes: {
          '/init': (context) => const ServiceInitializer(),
          '/': (context) => const AuthWrapper(),
          '/test': (context) => const SpeechTranslationTestScreen(),
          '/create': (context) => const EnhancedCreateMeetingScreen(),
          '/join': (context) => const EnhancedJoinMeetingScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/meeting':
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => MeetingScreen(
                  code: args?['code'],
                  displayName: args?['displayName'],
                  targetLanguage: args?['targetLanguage'],
                  meetingId: args?['meetingId'],
                ),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}

// 🚀 SERVICE INITIALIZER - SIMPLIFIED & FIXED
class ServiceInitializer extends StatefulWidget {
  const ServiceInitializer({super.key});

  @override
  State<ServiceInitializer> createState() => _ServiceInitializerState();
}

class _ServiceInitializerState extends State<ServiceInitializer> {
  bool _isInitializing = true;
  String _initializationStatus = 'Starting services...';
  Map<String, bool> _serviceStatus = {
    'webrtc': false,
    'googleSpeech': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _initializationStatus = 'Initializing WebRTC service...';
      });

      // ✅ STEP 1: Initialize WebRTC Service
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      await webrtcService.initialize();

      setState(() {
        _serviceStatus['webrtc'] = true;
        _initializationStatus = 'Initializing Google Speech Translation...';
      });

      // ✅ STEP 2: Initialize Google Speech Translation Service
      final googleSpeechService = context.read<GoogleSpeechTranslationService>();
      await googleSpeechService.initialize();

      setState(() {
        _serviceStatus['googleSpeech'] = true;
        _initializationStatus = '✅ All services ready!';
      });

      // Wait to show success
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isInitializing = false;
      });

      // Navigate to home
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }

      print('✅ Services initialized successfully');
      print('   - WebRTC: ${_serviceStatus['webrtc']}');
      print('   - Google Speech: ${_serviceStatus['googleSpeech']}');

    } catch (e) {
      setState(() {
        _initializationStatus = '❌ Initialization failed: $e';
      });

      print('❌ Error initializing services: $e');

      // Show error and still allow app to continue
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Service status indicators
            Stack(
              alignment: Alignment.center,
              children: [
                // WebRTC ring
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _serviceStatus['webrtc']! ? Colors.blue : Colors.grey,
                      width: 3,
                    ),
                  ),
                ),
                // Google Speech ring
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _serviceStatus['googleSpeech']! ? Colors.green : Colors.grey,
                      width: 3,
                    ),
                  ),
                ),
                // Core
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _serviceStatus.values.every((status) => status)
                        ? GcbAppTheme.primary
                        : Colors.grey[700],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            const Text(
              'GlobeCast Real-time Translation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 48),

            // Progress
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                color: GcbAppTheme.primary,
                backgroundColor: Colors.grey[800],
                value: _calculateProgress(),
              ),
            ),

            const SizedBox(height: 16),

            // Status
            Text(
              _initializationStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Service status
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildServiceRow('🕸️ WebRTC Mesh', _serviceStatus['webrtc']!, Colors.blue),
                  const SizedBox(height: 8),
                  _buildServiceRow('☁️ Google Speech & Translation', _serviceStatus['googleSpeech']!, Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceRow(String name, bool isReady, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isReady ? color : Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Text(
          isReady ? 'Ready' : 'Loading...',
          style: TextStyle(
            color: isReady ? color : Colors.orange,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  double _calculateProgress() {
    int readyCount = _serviceStatus.values.where((status) => status).length;
    return readyCount / _serviceStatus.length;
  }
}