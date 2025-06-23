// lib/main.dart - ENHANCED WITH WEBRTC-SPEECH INTEGRATION + DEMO TRANSCRIPTS
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/services/multilingual_speech_service.dart';
import 'package:globecast_ui/services/demo_transcript_service.dart'; // Add this import
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

  // 🎯 ENHANCED SERVICE INITIALIZATION WITH WEBRTC-SPEECH INTEGRATION + DEMO SUPPORT
  Future<void> _initializeServices() async {
    try {
      print('🚀 Initializing GlobeCast services with WebRTC-Speech integration + Demo support...');

      // Initialize WebRTC service first
      await _webrtcService.initialize();
      print('✅ WebRTC service initialized');

      // Initialize Speech service (lightweight)
      print('✅ Speech service ready (STT will be enabled on demand)');

      // 🎯 KEY INTEGRATION: CONNECT WEBRTC AND SPEECH SERVICES
      // This connection enables the automatic audio track management
      _webrtcService.setSpeechService(_speechService);
      print('🔗 WebRTC-Speech integration established');

      // 🎭 Demo service is available globally but used only when needed
      print('🎭 Demo transcript service ready for meeting demos');

      print('🎉 All services initialized successfully with audio management integration + demo support');
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
        // Note: DemoTranscriptService is a static service, no provider needed
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
🎯 HOW THE WEBRTC-SPEECH INTEGRATION + DEMO TRANSCRIPTS WORK:

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

4. **🎭 Demo Transcript Generation** (when joining meeting):
   ```dart
   // In MeetingScreen, after translation service is initialized:
   await DemoTranscriptService.generateQuickDemo(
     translationService: _translationService!,
     userDisplayLanguage: userLanguage,
     currentUserId: userId,
     customUserName: userName,
   );
   ```

🚀 KEY BENEFITS OF THIS APPROACH:

✅ **Zero Delay**: No need for setTimeout or complex timing
✅ **No Feedback**: Audio tracks are cleanly disabled during STT
✅ **Automatic**: Users don't notice the audio management
✅ **Reliable**: Works across different devices and platforms
✅ **Efficient**: Only manages audio when actually needed
✅ **🎭 Demo Ready**: Automatically shows transcript demo based on user's language

🔧 USAGE IN MEETING:

1. User joins meeting → WebRTC stream connects to Speech service
2. 🎭 Demo transcripts generate based on user's selected language:
   - English: "Hello my name is Dat I am from Viet Nam"
   - Vietnamese: "Xin chào tôi là Đạt và tôi đến từ Việt Nam"
   - Spanish: "Hola mi nombre es Dat y soy de Vietnam"
   - etc.
3. User taps speech button → WebRTC audio temporarily disabled
4. User speaks → STT captures speech without feedback
5. STT finishes → WebRTC audio automatically restored
6. Translation happens → Everyone sees real-time subtitles

This is the exact same technique from Project 1, but now properly
integrated into the advanced architecture of Project 2 + Auto Demo! 🎯🎭
*/