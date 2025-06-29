// lib/main.dart - PRODUCTION WITH CENTRAL TRANSLATION HUB + AUTH ROUTES
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:globecast_ui/screens/meeting/meeting_screen.dart';
import 'package:globecast_ui/screens/create_meeting/create_meeting_screen.dart';
import 'package:globecast_ui/screens/join_meeting/join_meeting_screen.dart';
import 'package:globecast_ui/screens/test/test_screen.dart';
import 'package:globecast_ui/screens/auth/welcome_screen.dart';
import 'package:globecast_ui/screens/auth/signin_screen.dart';
import 'package:globecast_ui/screens/auth/signup_screen.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/central_translation_service.dart'; // ✅ CENTRAL HUB
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

        // ✅ CENTRAL TRANSLATION HUB SERVICE (PRIMARY)
        ChangeNotifierProvider(
          create: (context) => CentralTranslationService(),
        ),
      ],
      child: MaterialApp(
        title: 'Globecast - Central Translation Hub',
        theme: GcbAppTheme.darkTheme,
        initialRoute: '/init',
        debugShowCheckedModeBanner: false,
        routes: {
          '/init': (context) => const ProductionServiceInitializer(),
          '/': (context) => const AuthWrapper(),
          '/welcome': (context) => const WelcomeScreen(),
          '/signin': (context) => const SignInScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/test': (context) => const CentralTranslationTestScreen(),
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
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: const Text('Route Not Found'),
                backgroundColor: Colors.red,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Route "${settings.name}" not found',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                            (route) => false,
                      ),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// 🚀 PRODUCTION SERVICE INITIALIZER
class ProductionServiceInitializer extends StatefulWidget {
  const ProductionServiceInitializer({super.key});

  @override
  State<ProductionServiceInitializer> createState() => _ProductionServiceInitializerState();
}

class _ProductionServiceInitializerState extends State<ProductionServiceInitializer> {
  bool _isInitializing = true;
  String _initializationStatus = 'Starting Central Translation Hub...';
  Map<String, bool> _serviceStatus = {
    'webrtc': false,
    'centralHub': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeProductionServices();
  }

  Future<void> _initializeProductionServices() async {
    try {
      setState(() {
        _initializationStatus = 'Initializing WebRTC mesh network...';
      });

      // ✅ STEP 1: Initialize WebRTC Service
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      await webrtcService.initialize();

      setState(() {
        _serviceStatus['webrtc'] = true;
        _initializationStatus = 'Initializing Central Translation Hub...';
      });

      // ✅ STEP 2: Initialize Central Translation Hub
      final centralHubService = context.read<CentralTranslationService>();
      await centralHubService.initialize();

      setState(() {
        _serviceStatus['centralHub'] = true;
        _initializationStatus = '✅ Production ready with Central Translation Hub!';
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

      print('✅ Production services initialized successfully');
      print('   - WebRTC: ${_serviceStatus['webrtc']}');
      print('   - Central Translation Hub: ${_serviceStatus['centralHub']}');

    } catch (e) {
      setState(() {
        _initializationStatus = '❌ Initialization failed: $e';
      });

      print('❌ Error initializing production services: $e');

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
            // Central Hub Logo
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring - WebRTC
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _serviceStatus['webrtc']! ? Colors.blue : Colors.grey,
                      width: 4,
                    ),
                  ),
                ),
                // Inner ring - Central Hub
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _serviceStatus['centralHub']! ? Colors.green : Colors.grey,
                      width: 4,
                    ),
                  ),
                ),
                // Core Hub
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _serviceStatus.values.every((status) => status)
                          ? [Colors.blue, Colors.green]
                          : [Colors.grey[700]!, Colors.grey[600]!],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: _serviceStatus.values.every((status) => status)
                        ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                        : null,
                  ),
                  child: const Icon(
                    Icons.hub,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                // Animated pulse effect when ready
                if (_serviceStatus.values.every((status) => status))
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 40),

            const Text(
              'GlobeCast',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Central Translation Hub',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'One Speech • All Languages • Real-time Sync',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 60),

            // Progress
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(
                color: _serviceStatus.values.every((status) => status)
                    ? Colors.green
                    : GcbAppTheme.primary,
                backgroundColor: Colors.grey[800],
                value: _calculateProgress(),
              ),
            ),

            const SizedBox(height: 20),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _initializationStatus,
                style: TextStyle(
                  color: _serviceStatus.values.every((status) => status)
                      ? Colors.green
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 40),

            // Service status
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Production Services',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildServiceRow(
                    '🕸️ WebRTC Mesh Network',
                    _serviceStatus['webrtc']!,
                    Colors.blue,
                    'Video calling infrastructure',
                  ),
                  const SizedBox(height: 12),
                  _buildServiceRow(
                    '🌐 Central Translation Hub',
                    _serviceStatus['centralHub']!,
                    Colors.green,
                    'One speech → All languages',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Production features
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.1),
                    Colors.green.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Production Ready Features',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureGrid([
                    '🎤 Real-time speech capture',
                    '☁️ Google Cloud translation',
                    '🌐 16+ language support',
                    '👥 Multi-participant sync',
                    '💾 Central database hub',
                    '🎯 Personal language preferences',
                    '⚡ Cost-efficient processing',
                    '🔄 Instant real-time updates',
                  ]),
                ],
              ),
            ),

            if (_serviceStatus.values.every((status) => status)) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Production Ready!\nTap anywhere to continue...',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildServiceRow(String name, bool isReady, Color color, String description) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isReady ? color : Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isReady ? color.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isReady ? 'Ready' : 'Loading...',
                style: TextStyle(
                  color: isReady ? color : Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureGrid(List<String> features) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        return Row(
          children: [
            const Text('• ', style: TextStyle(color: Colors.blue, fontSize: 12)),
            Expanded(
              child: Text(
                features[index],
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calculateProgress() {
    int readyCount = _serviceStatus.values.where((status) => status).length;
    return readyCount / _serviceStatus.length;
  }
}

// 🎯 CENTRAL TRANSLATION TEST SCREEN (Optional)
class CentralTranslationTestScreen extends StatefulWidget {
  const CentralTranslationTestScreen({super.key});

  @override
  State<CentralTranslationTestScreen> createState() => _CentralTranslationTestScreenState();
}

class _CentralTranslationTestScreenState extends State<CentralTranslationTestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.hub, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text(
              'Central Translation Hub - Development',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.1),
                Colors.green.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hub, color: Colors.blue, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Central Translation Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Development & Testing Interface',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'The Central Translation Hub has been\nintegrated directly into the main app.\n\nUse "Create Meeting" or "Join Meeting"\nto experience the production version.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/create',
                            (route) => route.isFirst,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Meeting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/join',
                            (route) => route.isFirst,
                      ),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Join Meeting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}