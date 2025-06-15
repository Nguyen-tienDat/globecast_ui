// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/whisper_service.dart';           // ✅ Thêm
import 'package:globecast_ui/services/audio_capture_service.dart';     // ✅ Thêm
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
  final WhisperService _whisperService = WhisperService();                           // ✅ Thêm
  final EnhancedAudioCaptureService _audioCaptureService = EnhancedAudioCaptureService(); // ✅ Thêm
  final Routes _routes = Routes();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _webrtcService.initialize();
    // ✅ Thêm initialization cho AI services nếu cần
    try {
      await _audioCaptureService.initialize();
      print('✅ Audio capture service initialized');
    } catch (e) {
      print('⚠️ Audio capture service initialization failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _webrtcService),
        ChangeNotifierProvider.value(value: _whisperService),           // ✅ Thêm
        ChangeNotifierProvider.value(value: _audioCaptureService),      // ✅ Thêm
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
    _whisperService.dispose();           // ✅ Thêm
    _audioCaptureService.dispose();      // ✅ Thêm
    super.dispose();
  }
}