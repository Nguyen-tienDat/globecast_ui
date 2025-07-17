// lib/main.dart - CLEAN ARCHITECTURE VERSION
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Services
import 'services/auth_service.dart';
import 'services/webrtc_mesh_meeting_service.dart';
import 'services/central_translation_service.dart';
import 'services/google_speech_translation_service.dart';
import 'services/chat_service.dart';

// Router
import 'router/app_router.dart';

// Theme
import 'theme/app_theme.dart';

// Firebase configuration
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Request permissions early
  await _requestPermissions();

  runApp(const GlobeCastApp());
}

/// Request necessary permissions for the app
Future<void> _requestPermissions() async {
  try {
    final permissions = [
      Permission.microphone,
      Permission.camera,
      Permission.storage,
    ];

    final statuses = await permissions.request();

    for (var permission in permissions) {
      final status = statuses[permission];
      debugPrint('🔐 ${permission.toString()}: ${status.toString()}');
    }
  } catch (e) {
    debugPrint('❌ Error requesting permissions: $e');
  }
}

class GlobeCastApp extends StatelessWidget {
  const GlobeCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth Service
        ChangeNotifierProvider(
          create: (context) => AuthService(),
        ),

        // WebRTC Meeting Service  
        ChangeNotifierProvider(
          create: (context) => WebRTCMeshMeetingService(),
        ),

        // Google Speech Translation Service
        ChangeNotifierProvider(
          create: (context) => GoogleSpeechTranslationService(),
        ),

        // Central Translation Service
        ChangeNotifierProvider(
          create: (context) => CentralTranslationService(),
        ),

        // Chat Service
        ChangeNotifierProvider(
          create: (context) => ChatService(),
        ),
      ],
      child: MaterialApp(
        title: 'GlobeCast - Globalize Your Connection',
        theme: GcbAppTheme.darkTheme,
        debugShowCheckedModeBanner: false,

        // Router configuration
        initialRoute: Routes.initialRoute,
        onGenerateRoute: Routes.generateRoute,
        onUnknownRoute: Routes.unknownRoute,

        // Global navigation key for programmatic navigation
        navigatorKey: Routes.navigatorKey,

        // Global error handling
        builder: (context, child) {
          return _AppWrapper(child: child);
        },
      ),
    );
  }
}

/// App wrapper for global error handling and initialization
class _AppWrapper extends StatelessWidget {
  final Widget? child;

  const _AppWrapper({this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthService, WebRTCMeshMeetingService,
        GoogleSpeechTranslationService, CentralTranslationService>(
      builder: (context, authService, webrtcService, speechService, centralService, child) {
        // Initialize services when app starts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeServices(context, webrtcService, speechService, centralService);
        });

        return child ?? const SizedBox.shrink();
      },
      child: child,
    );
  }

  /// Initialize core services
  Future<void> _initializeServices(
      BuildContext context,
      WebRTCMeshMeetingService webrtcService,
      GoogleSpeechTranslationService speechService,
      CentralTranslationService centralService,
      ) async {
    try {
      // Initialize services in order
      if (!webrtcService.isInitialized) {
        await webrtcService.initialize();
        debugPrint('✅ WebRTC Service initialized');
      }

      if (!speechService.isInitialized) {
        await speechService.initialize();
        debugPrint('✅ Speech Service initialized');
      }

      if (!centralService.isInitialized) {
        await centralService.initialize();
        debugPrint('✅ Central Translation Service initialized');
      }

    } catch (e) {
      debugPrint('❌ Error initializing services: $e');

      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service initialization failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}