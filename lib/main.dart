// lib/main.dart - IMPROVED VERSION with Translation Service
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  final Routes _routes = Routes();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      print('🚀 Initializing GlobeCast services...');

      // Initialize WebRTC service
      await _webrtcService.initialize();
      print('✅ WebRTC service initialized');

      // Speech service is lightweight initialized (STT enabled only when needed)
      print('✅ Speech service ready (STT will be enabled on demand)');

      print('🎉 All services initialized successfully');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _webrtcService),
        ChangeNotifierProvider.value(value: _speechService),

        // Note: TranslationService is initialized per-meeting in MeetingScreen
        // to avoid unnecessary resource usage when not in a meeting
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          return MaterialApp(
            title: 'GlobeCast - Global Communication Made Easy',
            theme: GcbAppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            initialRoute: Routes.welcome,
            routes: _routes.routes,
            builder: (context, child) {
              // Global error boundary
              return Builder(
                builder: (context) {
                  return child ?? const SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    print('🧹 Disposing MyApp services...');
    _authService.dispose();
    _webrtcService.dispose();
    _speechService.dispose();
    super.dispose();
  }
}