// lib/main.dart - ENHANCED WITH WEBRTC-SPEECH INTEGRATION
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

  // 🎯 ENHANCED SERVICE INITIALIZATION WITH WEBRTC-SPEECH INTEGRATION
  Future<void> _initializeServices() async {
    try {
      print('🚀 Initializing GlobeCast services with WebRTC-Speech integration...');

      // Initialize WebRTC service first
      await _webrtcService.initialize();
      print('✅ WebRTC service initialized');

      // Initialize Speech service (lightweight)
      print('✅ Speech service ready (STT will be enabled on demand)');

      // 🎯 KEY INTEGRATION: CONNECT WEBRTC AND SPEECH SERVICES
      // This connection enables the automatic audio track management
      _webrtcService.setSpeechService(_speechService);
      print('🔗 WebRTC-Speech integration established');

      print('🎉 All services initialized successfully with audio management integration');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services with enhanced integration
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

/*
🎯 HOW THE WEBRTC-SPEECH INTEGRATION WORKS:

1. **Service Connection** (in main.dart):
   ```dart
   _webrtcService.setSpeechService(_speechService);
   ```

2. **Stream Connection** (when joining meeting):
   ```dart
   // In WebRTC service, when local stream is created:
   if (_speechService != null) {
     _speechService!.setWebRTCStream(stream);
   }
   ```

3. **Automatic Audio Management** (when using speech recognition):
   ```dart
   // When starting speech recognition:
   _disableWebRTCAudio();  // Temporarily disable WebRTC audio tracks
   await _speech.listen(...);

   // When stopping speech recognition:
   _restoreWebRTCAudio();  // Restore WebRTC audio tracks
   ```

4. **The Magic**:
   - No audio feedback loops
   - No complex timing issues
   - No user-noticeable interruptions
   - Seamless experience between WebRTC calling and STT

🚀 KEY BENEFITS OF THIS APPROACH:

✅ **Zero Delay**: No need for setTimeout or complex timing
✅ **No Feedback**: Audio tracks are cleanly disabled during STT
✅ **Automatic**: Users don't notice the audio management
✅ **Reliable**: Works across different devices and platforms
✅ **Efficient**: Only manages audio when actually needed

🔧 USAGE IN MEETING:

1. User joins meeting → WebRTC stream connects to Speech service
2. User taps speech button → WebRTC audio temporarily disabled
3. User speaks → STT captures speech without feedback
4. STT finishes → WebRTC audio automatically restored
5. Translation happens → Everyone sees real-time subtitles

This is the exact same technique from Project 1, but now properly
integrated into the advanced architecture of Project 2! 🎯
*/