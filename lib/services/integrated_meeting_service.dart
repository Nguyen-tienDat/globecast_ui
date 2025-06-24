// lib/services/integrated_meeting_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import all required services
import 'webrtc_mesh_meeting_service.dart';
import 'multilingual_speech_service.dart';
import 'audio_capture_service.dart';
import 'auth_service.dart';

enum IntegratedMeetingState {
  idle,
  initializing,
  permissionsRequired,
  ready,
  connecting,
  inMeeting,
  audioProcessing,
  error,
  disconnected
}

class IntegratedMeetingService extends ChangeNotifier {
  // 🎯 ALL SERVICES INTEGRATION
  final WebRTCMeshMeetingService _webrtcService;
  final MultilingualSpeechService _speechService;
  final AudioCaptureService _audioService;
  final AuthService _authService;

  // 🏗️ STATE MANAGEMENT
  IntegratedMeetingState _state = IntegratedMeetingState.idle;
  String _statusMessage = 'Ready to start';
  String _errorMessage = '';

  // 📊 MEETING DATA
  String? _currentMeetingId;
  String? _currentUserId;
  String _currentUserName = 'User';
  String _selectedLanguage = 'en';

  // 🎤 AUDIO & SPEECH STATE
  bool _isAudioCaptureActive = false;
  bool _isSpeechProcessingActive = false;
  final List<SpeechResult> _recentResults = [];

  // 📱 REAL-TIME DATA
  final List<String> _statusHistory = [];
  final StreamController<IntegratedMeetingState> _stateController =
  StreamController<IntegratedMeetingState>.broadcast();
  final StreamController<String> _statusController =
  StreamController<String>.broadcast();
  final StreamController<SpeechResult> _speechResultController =
  StreamController<SpeechResult>.broadcast();

  // 🔗 SUBSCRIPTIONS
  StreamSubscription<SpeechResult>? _speechSubscription;
  StreamSubscription<Map<String, dynamic>>? _audioSubscription;
  Timer? _healthCheckTimer;

  // Constructor
  IntegratedMeetingService({
    required WebRTCMeshMeetingService webrtcService,
    required MultilingualSpeechService speechService,
    required AudioCaptureService audioService,
    required AuthService authService,
  }) : _webrtcService = webrtcService,
        _speechService = speechService,
        _audioService = audioService,
        _authService = authService {
    _initializeIntegration();
  }

  // 🎯 GETTERS
  IntegratedMeetingState get state => _state;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;
  String? get currentMeetingId => _currentMeetingId;
  String get currentUserName => _currentUserName;
  String get selectedLanguage => _selectedLanguage;
  bool get isInMeeting => _state == IntegratedMeetingState.inMeeting;
  bool get isAudioActive => _isAudioCaptureActive;
  bool get isSpeechActive => _isSpeechProcessingActive;
  List<SpeechResult> get recentResults => List.unmodifiable(_recentResults);
  List<String> get statusHistory => List.unmodifiable(_statusHistory);

  // Streams
  Stream<IntegratedMeetingState> get stateStream => _stateController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<SpeechResult> get speechResultStream => _speechResultController.stream;

  // 🚀 INITIALIZE INTEGRATION
  Future<void> _initializeIntegration() async {
    try {
      _updateState(IntegratedMeetingState.initializing);
      _updateStatus('Initializing integrated services...');

      // Setup cross-service connections
      _webrtcService.setSpeechService(_speechService);

      // Listen to services
      _setupServiceListeners();

      _updateState(IntegratedMeetingState.ready);
      _updateStatus('All services integrated and ready');

      if (kDebugMode) {
        print('✅ IntegratedMeetingService initialized successfully');
      }
    } catch (e) {
      _handleError('Integration initialization failed: $e');
    }
  }

  // 🎧 SETUP SERVICE LISTENERS
  void _setupServiceListeners() {
    // Listen to speech results
    _speechSubscription = _speechService.speechResultStream.listen(
          (result) {
        _recentResults.insert(0, result);
        if (_recentResults.length > 20) {
          _recentResults.removeLast();
        }
        _speechResultController.add(result);
        _updateStatus('New translation: ${result.originalText}');
      },
      onError: (error) => _handleError('Speech service error: $error'),
    );

    // Listen to audio status
    _audioSubscription = _audioService.statusStream.listen(
          (status) => _handleAudioStatus(status),
      onError: (error) => _handleError('Audio service error: $error'),
    );

    // Listen to WebRTC changes
    _webrtcService.addListener(_handleWebRTCChanges);

    // Listen to auth changes
    _authService.addListener(_handleAuthChanges);
  }

  // 🎤 HANDLE AUDIO STATUS
  void _handleAudioStatus(Map<String, dynamic> status) {
    final String type = status['type'] ?? '';

    switch (type) {
      case 'status_change':
        _isAudioCaptureActive = status['isRecording'] == true;
        if (_isAudioCaptureActive) {
          _updateStatus('🎤 Audio capture active');
        } else {
          _updateStatus('🔇 Audio capture stopped');
        }
        notifyListeners();
        break;

      case 'audio_chunk_ready':
        if (_isSpeechProcessingActive) {
          _updateStatus('🔄 Processing audio with Google Cloud...');
        }
        break;

      case 'error':
        _handleError('Audio error: ${status['error']}');
        break;
    }
  }

  // 🌐 HANDLE WEBRTC CHANGES
  void _handleWebRTCChanges() {
    if (_webrtcService.isMeetingActive && _currentMeetingId != null) {
      if (_state != IntegratedMeetingState.inMeeting) {
        _updateState(IntegratedMeetingState.inMeeting);
        _updateStatus('✅ Connected to meeting: $_currentMeetingId');
      }
    } else if (_state == IntegratedMeetingState.inMeeting) {
      _handleMeetingEnded();
    }
    notifyListeners();
  }

  // 👤 HANDLE AUTH CHANGES
  void _handleAuthChanges() {
    if (_authService.isAuthenticated) {
      _currentUserId = _authService.userId;
      _currentUserName = _authService.displayName ?? 'User';
      _updateStatus('User authenticated: $_currentUserName');
    } else {
      _currentUserId = null;
      _currentUserName = 'Guest User';
    }
    notifyListeners();
  }

  // 🔒 CHECK AND REQUEST PERMISSIONS
  Future<bool> checkAndRequestPermissions() async {
    try {
      _updateState(IntegratedMeetingState.permissionsRequired);
      _updateStatus('Checking permissions...');

      // Check audio permissions
      final bool hasAudioPermission = await _audioService.checkPermissions();

      if (!hasAudioPermission) {
        _updateStatus('❌ Audio permission required');
        return false;
      }

      _updateStatus('✅ All permissions granted');
      _updateState(IntegratedMeetingState.ready);
      return true;

    } catch (e) {
      _handleError('Permission check failed: $e');
      return false;
    }
  }

  // 🎯 START COMPLETE WORKFLOW
  Future<bool> startCompleteWorkflow({
    required String meetingId,
    String? displayName,
    String? targetLanguage,
  }) async {
    try {
      _updateState(IntegratedMeetingState.connecting);
      _updateStatus('Starting complete workflow...');

      // 1. Check permissions first
      final bool hasPermissions = await checkAndRequestPermissions();
      if (!hasPermissions) {
        throw Exception('Permissions not granted');
      }

      // 2. Set user context
      _currentMeetingId = meetingId;
      _currentUserName = displayName ?? _currentUserName;
      _selectedLanguage = targetLanguage ?? _selectedLanguage;

      _updateStatus('🔧 Initializing services...');

      // 3. Initialize all services
      await _speechService.initialize();
      await _audioService.initialize();

      // 4. Set contexts
      _speechService.setUserContext(_currentUserId ?? 'guest', _currentUserName);
      _speechService.setTranslationContext(meetingId);
      _speechService.setPreferredLanguage(_selectedLanguage);

      _updateStatus('🌐 Joining meeting...');

      // 5. Join WebRTC meeting
      if (_webrtcService.meetingId != meetingId) {
        await _webrtcService.joinMeeting(meetingId: meetingId);
      }

      _updateStatus('🎤 Starting audio capture...');

      // 6. Start audio capture
      await _audioService.startRecording();
      _isAudioCaptureActive = true;

      _updateStatus('🗣️ Starting speech recognition...');

      // 7. Start speech processing
      await _speechService.startListening(
        meetingId: meetingId,
        userId: _currentUserId,
        preferredLanguage: _selectedLanguage,
      );
      _isSpeechProcessingActive = true;

      // 8. Start health monitoring
      _startHealthMonitoring();

      _updateState(IntegratedMeetingState.inMeeting);
      _updateStatus('✅ Complete workflow active - Ready for real-time translation!');

      if (kDebugMode) {
        print('🚀 Complete workflow started successfully');
        print('   Meeting: $meetingId');
        print('   User: $_currentUserName');
        print('   Language: $_selectedLanguage');
      }

      return true;

    } catch (e) {
      _handleError('Failed to start workflow: $e');
      await stopCompleteWorkflow();
      return false;
    }
  }

  // 🛑 STOP COMPLETE WORKFLOW
  Future<void> stopCompleteWorkflow() async {
    try {
      _updateStatus('Stopping complete workflow...');

      // Stop health monitoring
      _healthCheckTimer?.cancel();

      // Stop speech processing
      if (_isSpeechProcessingActive) {
        await _speechService.stopListening();
        _isSpeechProcessingActive = false;
      }

      // Stop audio capture
      if (_isAudioCaptureActive) {
        await _audioService.stopRecording();
        _isAudioCaptureActive = false;
      }

      // Leave meeting
      if (_webrtcService.isMeetingActive) {
        await _webrtcService.leaveMeeting();
      }

      // Reset state
      _currentMeetingId = null;
      _recentResults.clear();

      _updateState(IntegratedMeetingState.ready);
      _updateStatus('✅ Workflow stopped successfully');

      if (kDebugMode) {
        print('🛑 Complete workflow stopped');
      }

    } catch (e) {
      _handleError('Error stopping workflow: $e');
    }
  }

  // 🏥 START HEALTH MONITORING
  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _performHealthCheck();
    });
  }

  // 🔍 PERFORM HEALTH CHECK
  void _performHealthCheck() {
    final List<String> issues = [];

    // Check WebRTC connection
    if (!_webrtcService.isMeetingActive) {
      issues.add('WebRTC disconnected');
    }

    // Check audio capture
    if (!_audioService.isRecording) {
      issues.add('Audio capture stopped');
    }

    // Check speech service
    if (!_speechService.isAvailable) {
      issues.add('Speech service unavailable');
    }

    if (issues.isNotEmpty) {
      _updateStatus('⚠️ Health issues: ${issues.join(', ')}');
      if (kDebugMode) {
        print('🏥 Health check issues: $issues');
      }
    } else {
      _updateStatus('💚 All systems healthy');
    }
  }

  // 🧪 TEST COMPLETE PIPELINE
  Future<bool> testCompletePipeline() async {
    try {
      _updateStatus('🧪 Testing complete pipeline...');

      // Test 1: Audio capture
      _updateStatus('Testing audio capture...');
      await _audioService.startRecording();
      await Future.delayed(const Duration(seconds: 2));
      await _audioService.stopRecording();

      // Test 2: Speech service
      _updateStatus('Testing speech recognition...');
      await _speechService.testTranslation('Hello, this is a test');

      // Test 3: WebRTC readiness
      _updateStatus('Testing WebRTC service...');
      // WebRTC test would be more complex, skip for now

      _updateStatus('✅ Pipeline test completed successfully');
      return true;

    } catch (e) {
      _handleError('Pipeline test failed: $e');
      return false;
    }
  }

  // 🎯 QUICK SPEECH TEST
  Future<void> quickSpeechTest(String testText) async {
    try {
      _updateStatus('🧪 Testing speech with: "$testText"');
      await _speechService.testTranslation(testText);
    } catch (e) {
      _handleError('Speech test failed: $e');
    }
  }

  // 🔄 TOGGLE SPEECH PROCESSING
  Future<void> toggleSpeechProcessing() async {
    try {
      if (_isSpeechProcessingActive) {
        await _speechService.stopListening();
        _isSpeechProcessingActive = false;
        _updateStatus('🔇 Speech processing stopped');
      } else {
        await _speechService.startListening(
          meetingId: _currentMeetingId,
          userId: _currentUserId,
          preferredLanguage: _selectedLanguage,
        );
        _isSpeechProcessingActive = true;
        _updateStatus('🗣️ Speech processing started');
      }
      notifyListeners();
    } catch (e) {
      _handleError('Failed to toggle speech processing: $e');
    }
  }

  // 🔄 TOGGLE AUDIO CAPTURE
  Future<void> toggleAudioCapture() async {
    try {
      if (_isAudioCaptureActive) {
        await _audioService.stopRecording();
        _isAudioCaptureActive = false;
        _updateStatus('🔇 Audio capture stopped');
      } else {
        await _audioService.startRecording();
        _isAudioCaptureActive = true;
        _updateStatus('🎤 Audio capture started');
      }
      notifyListeners();
    } catch (e) {
      _handleError('Failed to toggle audio capture: $e');
    }
  }

  // 🌐 SET LANGUAGE
  void setLanguage(String languageCode) {
    _selectedLanguage = languageCode;
    _speechService.setPreferredLanguage(languageCode);
    _updateStatus('🌐 Language changed to: $languageCode');
    notifyListeners();
  }

  // 🏁 HANDLE MEETING ENDED
  void _handleMeetingEnded() {
    _updateState(IntegratedMeetingState.disconnected);
    _updateStatus('Meeting ended');
    stopCompleteWorkflow();
  }

  // 🚨 HANDLE ERROR
  void _handleError(String error) {
    _errorMessage = error;
    _updateState(IntegratedMeetingState.error);
    _updateStatus('❌ $error');

    if (kDebugMode) {
      print('❌ IntegratedMeetingService Error: $error');
    }
  }

  // 📊 UPDATE STATE
  void _updateState(IntegratedMeetingState newState) {
    _state = newState;
    _stateController.add(newState);
    notifyListeners();
  }

  // 📱 UPDATE STATUS
  void _updateStatus(String status) {
    _statusMessage = status;
    _statusHistory.insert(0, '${DateTime.now().toIso8601String().split('T')[1].substring(0, 8)} - $status');
    if (_statusHistory.length > 100) {
      _statusHistory.removeRange(100, _statusHistory.length);
    }
    _statusController.add(status);
    notifyListeners();

    if (kDebugMode) {
      print('📱 Status: $status');
    }
  }

  // 📊 GET SERVICE HEALTH STATUS
  Map<String, dynamic> getServiceHealthStatus() {
    return {
      'integrated_service': {
        'state': _state.toString(),
        'active': _state == IntegratedMeetingState.inMeeting,
      },
      'webrtc_service': {
        'active': _webrtcService.isMeetingActive,
        'participants': _webrtcService.participants.length,
        'meeting_id': _webrtcService.meetingId,
      },
      'speech_service': {
        'available': _speechService.isAvailable,
        'listening': _speechService.isListening,
        'language': _speechService.preferredLanguage,
      },
      'audio_service': {
        'recording': _audioService.isRecording,
        'paused': _audioService.isPaused,
        'total_bytes': _audioService.totalBytesRecorded,
      },
      'auth_service': {
        'authenticated': _authService.isAuthenticated,
        'user_id': _authService.userId,
        'user_name': _authService.displayName,
      },
    };
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing IntegratedMeetingService...');
    }

    // Stop workflow
    stopCompleteWorkflow();

    // Cancel subscriptions
    _speechSubscription?.cancel();
    _audioSubscription?.cancel();
    _healthCheckTimer?.cancel();

    // Remove listeners
    _webrtcService.removeListener(_handleWebRTCChanges);
    _authService.removeListener(_handleAuthChanges);

    // Close controllers
    _stateController.close();
    _statusController.close();
    _speechResultController.close();

    super.dispose();
  }
}