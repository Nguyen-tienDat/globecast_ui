// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:globecast_ui/firebase_options.dart';
import 'package:globecast_ui/router/app_router.dart';
import 'package:globecast_ui/services/auth_service.dart';
import 'package:globecast_ui/services/webrtc_mesh_meeting_service.dart';
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
  final Routes _routes = Routes();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _webrtcService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _webrtcService),
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
    super.dispose();
  }
}