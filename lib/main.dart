// lib/main.dart - PROVIDER FIX
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Initializing GlobeCast...');

  // Configure system UI
  await _configureSystemUI();

  // Initialize Firebase
  await _initializeFirebase();

  runApp(const GlobeCastApp());
}

Future<void> _configureSystemUI() async {
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

   SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: GcbAppTheme.background,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    print('✅ System UI configured successfully');
  } catch (e) {
    print('⚠️ System UI configuration warning: $e');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('⚠️ Continuing without Firebase - some features may be limited');
  }
}

class GlobeCastApp extends StatelessWidget {
  const GlobeCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create services ONCE at app level
    return MultiProvider(
      providers: [
        // Auth service
        ChangeNotifierProvider<AuthService>(
          create: (_) {
            print('🔐 Creating AuthService...');
            return AuthService();
          },
          lazy: false,
        ),

        // WebRTC service - CRITICAL: Must be created here
        ChangeNotifierProvider<WebRTCMeshMeetingService>(
          create: (_) {
            print('🌐 Creating WebRTCMeshMeetingService...');
            final service = WebRTCMeshMeetingService();
            // Initialize asynchronously but don't await here
            service.initialize().then((_) {
              print('✅ WebRTC service initialized');
            }).catchError((error) {
              print('❌ WebRTC service initialization error: $error');
            });
            return service;
          },
          lazy: false, // IMPORTANT: Create immediately
        ),
      ],
      child: _GlobeCastMaterialApp(),
    );
  }
}

class _GlobeCastMaterialApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, WebRTCMeshMeetingService>(
      builder: (context, authService, webrtcService, child) {
        return MaterialApp(
          title: 'GlobeCast - Real-time Translation',
          theme: GcbAppTheme.darkTheme,
          debugShowCheckedModeBanner: false,

          // Navigation configuration
          initialRoute: Routes.welcome,
          routes: Routes().routes,

          // Global app configuration
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: 1.0,
              ),
              child: _AppWrapper(child: child),
            );
          },

          // Error handling for navigation
          onUnknownRoute: (settings) {
            print('❌ Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => const _UnknownRouteScreen(),
            );
          },
        );
      },
    );
  }
}

class _AppWrapper extends StatefulWidget {
  final Widget? child;

  const _AppWrapper({this.child});

  @override
  State<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<_AppWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('📱 App lifecycle observer added');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    print('📱 App lifecycle observer removed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print('📱 App lifecycle changed: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden();
        break;
    }
  }

  void _handleAppResumed() {
    print('🔄 App resumed - checking service connections...');
    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      if (webrtcService.isMeetingActive) {
        print('🎥 Meeting is active - maintaining connections');
      }
    } catch (e) {
      print('⚠️ Error accessing WebRTC service on resume: $e');
    }
  }

  void _handleAppPaused() {
    print('⏸️ App paused - maintaining background services');
  }

  void _handleAppInactive() {
    print('😴 App inactive');
  }

  void _handleAppHidden() {
    print('🙈 App hidden');
  }

  void _handleAppDetached() {
    print('🔌 App detached - cleaning up services');
    try {
      final webrtcService = context.read<WebRTCMeshMeetingService>();
      webrtcService.dispose();
    } catch (e) {
      print('⚠️ Service cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.background,
        title: const Text('Page Not Found'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              '404 - Page Not Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}