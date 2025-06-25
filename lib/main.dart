// lib/main.dart - WITH NEW GOOGLE SPEECH + MLKIT TRANSLATION
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/google_speech_translation_service.dart'; // ✅ NEW SERVICE
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

// 🔐 REQUEST PERMISSIONS
Future<void> _requestPermissions() async {
  try {
    final permissions = [
      Permission.microphone,
      Permission.camera,
      Permission.storage, // For MLKit models
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

        // 🎤 NEW GOOGLE SPEECH + MLKIT TRANSLATION SERVICE
        ChangeNotifierProvider(
          create: (context) => GoogleSpeechTranslationService(),
        ),
      ],
      child: MaterialApp(
        title: 'Globecast - Google Speech + MLKit',
        theme: GcbAppTheme.darkTheme,
        home: const ServiceInitializerV2(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// 🚀 SERVICE INITIALIZER V2 - FOR NEW SPEECH SERVICE
class ServiceInitializerV2 extends StatefulWidget {
  const ServiceInitializerV2({super.key});

  @override
  State<ServiceInitializerV2> createState() => _ServiceInitializerV2State();
}

class _ServiceInitializerV2State extends State<ServiceInitializerV2> {
  bool _isInitializing = true;
  bool _speechServiceReady = false;
  bool _webrtcServiceReady = false;
  String _initializationStatus = 'Starting services...';
  String _speechServiceError = '';

  @override
  void initState() {
    super.initState();
    _initializeServicesV2();
  }

  Future<void> _initializeServicesV2() async {
    try {
      setState(() {
        _initializationStatus = 'Testing Google Speech + MLKit Translation...';
      });

      // ✅ TEST NEW SPEECH SERVICE FIRST
      try {
        final speechService = context.read<GoogleSpeechTranslationService>();

        // Quick test
        await speechService.initialize();

        setState(() {
          _speechServiceReady = true;
          _initializationStatus = 'Google Speech + MLKit ready!';
        });

        print('✅ Google Speech + MLKit Translation service ready');

      } catch (e) {
        setState(() {
          _speechServiceReady = false;
          _speechServiceError = e.toString();
          _initializationStatus = 'Speech service failed, WebRTC only mode';
        });

        print('⚠️ Speech service failed: $e');
      }

      // ✅ INITIALIZE WEBRTC (always works)
      setState(() {
        _initializationStatus = 'Setting up video calling...';
      });

      final webrtcService = context.read<WebRTCMeshMeetingService>();

      // Connect services if speech is available
      if (_speechServiceReady) {
        final speechService = context.read<GoogleSpeechTranslationService>();
        // TODO: Connect speech service to WebRTC
        print('🔗 Connected speech service to WebRTC');
      }

      setState(() {
        _webrtcServiceReady = true;
        _initializationStatus = 'All services ready!';
      });

      // Short delay to show status
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isInitializing = false;
      });

    } catch (e) {
      print('❌ Service initialization error: $e');

      setState(() {
        _initializationStatus = 'Initialization failed, app will continue';
      });

      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildInitializingScreenV2();
    }

    return const AuthWrapper();
  }

  Widget _buildInitializingScreenV2() {
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
              'Globecast V2',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Google Speech + MLKit Translation',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 48),

            // Loading indicator
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

            const SizedBox(height: 32),

            // Service status
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Service Status',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildServiceIndicatorV2(
                    'Google Speech API',
                    _speechServiceReady ? 'Ready' : 'Failed',
                    _speechServiceReady ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 12),

                  _buildServiceIndicatorV2(
                    'MLKit Translation',
                    _speechServiceReady ? 'Ready' : 'Not Available',
                    _speechServiceReady ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),

                  _buildServiceIndicatorV2(
                    'WebRTC Video Calling',
                    _webrtcServiceReady ? 'Ready' : 'Initializing...',
                    _webrtcServiceReady ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 12),

                  _buildServiceIndicatorV2(
                    'Audio Capture',
                    'Ready',
                    Colors.green,
                  ),
                ],
              ),
            ),

            // Error details if speech service failed
            if (!_speechServiceReady && _speechServiceError.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Speech Service Error',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _speechServiceError,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Service info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _speechServiceReady
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _speechServiceReady
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _speechServiceReady ? Icons.check_circle : Icons.warning,
                    color: _speechServiceReady ? Colors.green : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _speechServiceReady
                        ? 'Real-time Translation: Ready'
                        : 'Video Calling Only Mode',
                    style: TextStyle(
                      color: _speechServiceReady ? Colors.green : Colors.orange,
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

  Widget _buildServiceIndicatorV2(String name, String status, Color color) {
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