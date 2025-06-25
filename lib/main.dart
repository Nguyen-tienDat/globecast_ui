// lib/main.dart - REAL SERVICES INTEGRATION
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Request permissions on startup
  await _requestPermissions();

  runApp(const GlobecastApp());
}

// 🔐 REQUEST PERMISSIONS
Future<void> _requestPermissions() async {
  try {
    final permissions = [
      Permission.microphone,
      Permission.camera,
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
        // 🎯 WEBRTC MEETING SERVICE
        ChangeNotifierProvider(
          create: (context) => WebRTCMeshMeetingService(),
        ),

        // 🎤 REAL MULTILINGUAL SPEECH SERVICE WITH GOOGLE CLOUD
        ChangeNotifierProvider(
          create: (context) => MultilingualSpeechService(),
        ),
      ],
      child: MaterialApp(
        title: 'Globecast - Real-time Translation',
        theme: GcbAppTheme.darkTheme,
        home: const ServiceInitializationScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// 🚀 SERVICE INITIALIZATION SCREEN
class ServiceInitializationScreen extends StatefulWidget {
  const ServiceInitializationScreen({super.key});

  @override
  State<ServiceInitializationScreen> createState() => _ServiceInitializationScreenState();
}

class _ServiceInitializationScreenState extends State<ServiceInitializationScreen> {
  bool _isInitializing = true;
  String _initializationStatus = 'Starting services...';
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _initializationStatus = 'Initializing Google Cloud services...';
      });

      // Initialize Speech Service first (contains Google Cloud auth)
      final speechService = context.read<MultilingualSpeechService>();
      await speechService.initialize();

      setState(() {
        _initializationStatus = 'Setting up WebRTC service...';
      });

      // Initialize WebRTC Service
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      // WebRTC will be initialized when joining meeting

      setState(() {
        _initializationStatus = 'Connecting services...';
      });

      // Connect services
      webrtcService.setSpeechService(speechService);

      setState(() {
        _initializationStatus = 'Services ready!';
        _isInitializing = false;
      });

      // Navigate to home after short delay
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EnhancedHomeScreen()),
        );
      }

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isInitializing = false;
      });
      print('❌ Service initialization error: $e');
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
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: GcbAppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.translate,
                size: 64,
                color: GcbAppTheme.primary,
              ),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'Globecast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Real-time Translation Meetings',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 48),

            // Status or Error
            if (_isInitializing) ...[
              const CircularProgressIndicator(color: GcbAppTheme.primary),
              const SizedBox(height: 24),
              Text(
                _initializationStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Connecting to Google Cloud...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ] else if (_hasError) ...[
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Initialization Failed',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isInitializing = true;
                    _initializationStatus = 'Retrying...';
                  });
                  _initializeServices();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GcbAppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Services Ready!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Navigating to home...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Service status indicators
            if (_isInitializing || !_hasError) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildServiceStatus(
                      'Google Cloud Speech',
                      _isInitializing ? 'Connecting...' : 'Ready',
                      _isInitializing ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildServiceStatus(
                      'Google Cloud Translation',
                      _isInitializing ? 'Connecting...' : 'Ready',
                      _isInitializing ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildServiceStatus(
                      'WebRTC Service',
                      _isInitializing ? 'Initializing...' : 'Ready',
                      _isInitializing ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildServiceStatus(
                      'Audio Capture',
                      'Ready',
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatus(String name, String status, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}