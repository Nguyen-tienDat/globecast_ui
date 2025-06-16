// lib/main.dart - UPDATED
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/whisper_service.dart';
import 'package:globecast_ui/services/audio_capture_service.dart';
import 'package:globecast_ui/services/user_specific_transcript_service.dart'; // ✅ THÊM MỚI
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
  final WhisperService _whisperService = WhisperService();
  final EnhancedAudioCaptureService _audioCaptureService = EnhancedAudioCaptureService();
  final UserSpecificTranscriptService _transcriptService = UserSpecificTranscriptService(); // ✅ THÊM MỚI
  final Routes _routes = Routes();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _webrtcService.initialize();

    // Initialize audio capture service
    try {
      await _audioCaptureService.initialize();
      print('✅ Audio capture service initialized');
    } catch (e) {
      print('⚠️ Audio capture service initialization failed: $e');
    }

    // ✅ THÊM: Setup connection between WhisperService and UserSpecificTranscriptService
    _setupTranscriptIntegration();
  }

  // ✅ THÊM: Setup transcript integration
  void _setupTranscriptIntegration() {
    _whisperService.onTranscriptionReceived = (result) {
      // Forward transcription to user-specific service
      _transcriptService.addTranscriptEntry(result);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _webrtcService),
        ChangeNotifierProvider.value(value: _whisperService),
        ChangeNotifierProvider.value(value: _audioCaptureService),
        ChangeNotifierProvider.value(value: _transcriptService), // ✅ THÊM MỚI
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          return MaterialApp(
            title: 'GlobeCast',
            theme: GcbAppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            initialRoute: Routes.welcome,
            routes: _routes.routes,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _authService.dispose();
    _webrtcService.dispose();
    _whisperService.dispose();
    _audioCaptureService.dispose();
    _transcriptService.dispose(); // ✅ THÊM MỚI
    super.dispose();
  }
}