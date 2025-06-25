// lib/main.dart - PRODUCTION READY APP
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/services/audio_capture_service.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:globecast_ui/widgets/auth_wrapper.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const GlobeCastApp());
}

class GlobeCastApp extends StatefulWidget {
  const GlobeCastApp({super.key});

  @override
  State<GlobeCastApp> createState() => _GlobeCastAppState();
}

class _GlobeCastAppState extends State<GlobeCastApp> {
  // Core services
  final AuthService _authService = AuthService();
  final WebRTCMeshMeetingService _webrtcService = WebRTCMeshMeetingService();
  final MultilingualSpeechService _speechService = MultilingualSpeechService();
  final AudioCaptureService _audioService = AudioCaptureService();
  final Routes _routes = Routes();

  @override
  void initState() {
    super.initState();
    _initializeAppServices();
  }

  Future<void> _initializeAppServices() async {
    try {
      // Initialize WebRTC service
      await _webrtcService.initialize();

      // Connect WebRTC with Speech service for real-time translation
      _webrtcService.setSpeechService(_speechService);

      print('✅ GlobeCast services initialized successfully');
    } catch (e) {
      print('❌ Error initializing app services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication service
        ChangeNotifierProvider.value(value: _authService),

        // Meeting services
        ChangeNotifierProvider.value(value: _webrtcService),
        ChangeNotifierProvider.value(value: _speechService),
        ChangeNotifierProvider.value(value: _audioService),
      ],
      child: MaterialApp(
        title: 'GlobeCast',
        theme: GcbAppTheme.darkTheme,
        debugShowCheckedModeBanner: false,

        // 🎯 MAIN APP ENTRY POINT - AUTH WRAPPER
        home: const AuthWrapper(),

        // App routes
        routes: _routes.routes,

        // Global navigation
        navigatorKey: GlobalKey<NavigatorState>(),

        // Error handling
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: 1.0, // Prevent text scaling issues
            ),
            child: child!,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Clean up services
    _authService.dispose();
    _webrtcService.dispose();
    _speechService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}