// lib/services/audio_capture_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AudioCaptureService extends ChangeNotifier {
  // 📱 PLATFORM CHANNELS
  static const MethodChannel _methodChannel = MethodChannel('audio_capture_plugin');
  static const EventChannel _eventChannel = EventChannel('audio_capture_stream');

  // 🎤 RECORDING STATE
  bool _isRecording = false;
  bool _isPaused = false;
  int _totalBytesRecorded = 0;
  int _recordingDuration = 0;

  // 📊 AUDIO CONFIGURATION
  static const int SAMPLE_RATE = 16000;
  static const int BUFFER_SIZE_MS = 100; // 100ms chunks for real-time processing

  // 🎯 STREAM CONTROLLERS
  final StreamController<Uint8List> _audioDataController = StreamController<Uint8List>.broadcast();
  final StreamController<Map<String, dynamic>> _statusController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<dynamic>? _eventSubscription;

  // 🔄 AUDIO BUFFER FOR GOOGLE CLOUD
  final List<Uint8List> _audioBuffer = [];
  Timer? _processingTimer;

  // 🎯 GETTERS
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get totalBytesRecorded => _totalBytesRecorded;
  int get recordingDuration => _recordingDuration;
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  // 🚀 INITIALIZE SERVICE
  Future<void> initialize() async {
    try {
      // Setup event stream listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleAudioEvent,
        onError: _handleAudioError,
        onDone: _handleAudioDone,
      );

      // Check permissions
      await checkPermissions();

      if (kDebugMode) {
        print('✅ AudioCaptureService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing AudioCaptureService: $e');
      }
      rethrow;
    }
  }

  // 🔒 CHECK MICROPHONE PERMISSIONS
  Future<bool> checkPermissions() async {
    try {
      final bool hasPermission = await _methodChannel.invokeMethod('checkPermissions');
      return hasPermission;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking permissions: $e');
      }
      return false;
    }
  }

  // 🎤 START RECORDING
  Future<void> startRecording() async {
    if (_isRecording) {
      if (kDebugMode) {
        print('⚠️ Recording already in progress');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🎤 Starting audio recording...');
      }

      // Clear previous buffer
      _audioBuffer.clear();
      _totalBytesRecorded = 0;
      _recordingDuration = 0;

      // Start native recording
      final String result = await _methodChannel.invokeMethod('startRecording');

      _isRecording = true;
      _isPaused = false;

      // Start processing timer for buffered data
      _startProcessingTimer();

      _notifyStatusChange();

      if (kDebugMode) {
        print('✅ Audio recording started: $result');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting recording: $e');
      }
      rethrow;
    }
  }

  // 🛑 STOP RECORDING
  Future<void> stopRecording() async {
    if (!_isRecording) {
      if (kDebugMode) {
        print('⚠️ No recording in progress');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🛑 Stopping audio recording...');
      }

      // Stop native recording
      final String result = await _methodChannel.invokeMethod('stopRecording');

      _isRecording = false;
      _isPaused = false;

      // Stop processing timer
      _processingTimer?.cancel();
      _processingTimer = null;

      // Process any remaining buffered data
      await _processBufferedAudio();

      _notifyStatusChange();

      if (kDebugMode) {
        print('✅ Audio recording stopped: $result');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error stopping recording: $e');
      }
      rethrow;
    }
  }

  // ⏸️ PAUSE RECORDING
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) {
      return;
    }

    try {
      await _methodChannel.invokeMethod('pauseRecording');
      _isPaused = true;
      _notifyStatusChange();

      if (kDebugMode) {
        print('⏸️ Audio recording paused');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error pausing recording: $e');
      }
    }
  }

  // ▶️ RESUME RECORDING
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) {
      return;
    }

    try {
      await _methodChannel.invokeMethod('resumeRecording');
      _isPaused = false;
      _notifyStatusChange();

      if (kDebugMode) {
        print('▶️ Audio recording resumed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resuming recording: $e');
      }
    }
  }

  // 📊 GET RECORDING INFO
  Future<Map<String, dynamic>> getRecordingInfo() async {
    try {
      final Map<dynamic, dynamic> info = await _methodChannel.invokeMethod('getRecordingInfo');
      return Map<String, dynamic>.from(info);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting recording info: $e');
      }
      return {};
    }
  }

  // 📡 HANDLE AUDIO EVENTS FROM NATIVE
  void _handleAudioEvent(dynamic event) {
    try {
      if (event is Map) {
        final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
        final String type = eventData['type'] ?? '';

        switch (type) {
          case 'audio_data':
            _handleAudioData(eventData);
            break;
          case 'recording_stopped':
            _handleRecordingStopped(eventData);
            break;
          case 'error':
            _handleAudioError(eventData);
            break;
          default:
            if (kDebugMode) {
              print('🤷‍♂️ Unknown audio event type: $type');
            }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling audio event: $e');
      }
    }
  }

  // 🎵 HANDLE AUDIO DATA
  void _handleAudioData(Map<String, dynamic> eventData) {
    try {
      final String base64Data = eventData['data'] ?? '';
      final int length = eventData['length'] ?? 0;
      final int timestamp = eventData['timestamp'] ?? 0;

      if (base64Data.isNotEmpty) {
        // Decode base64 audio data
        final Uint8List audioData = base64Decode(base64Data);

        // Update statistics
        _totalBytesRecorded += length;

        // Add to buffer for batch processing
        _audioBuffer.add(audioData);

        // Stream individual chunks for real-time processing
        _audioDataController.add(audioData);

        // Debug logging (reduced frequency)
        if (_totalBytesRecorded % (SAMPLE_RATE * 2) == 0) { // Every ~1 second
          if (kDebugMode) {
            print('📊 Audio data: ${audioData.length} bytes, Total: $_totalBytesRecorded');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing audio data: $e');
      }
    }
  }

  // 🏁 HANDLE RECORDING STOPPED
  void _handleRecordingStopped(Map<String, dynamic> eventData) {
    _isRecording = false;
    _isPaused = false;
    _totalBytesRecorded = eventData['totalBytes'] ?? 0;
    _recordingDuration = eventData['duration'] ?? 0;

    _notifyStatusChange();

    if (kDebugMode) {
      print('🏁 Recording stopped - Total: $_totalBytesRecorded bytes, Duration: $_recordingDuration ms');
    }
  }

  // 🚨 HANDLE AUDIO ERRORS
  void _handleAudioError(dynamic error) {
    if (kDebugMode) {
      print('🚨 Audio error: $error');
    }

    _statusController.add({
      'type': 'error',
      'error': error.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ✅ HANDLE AUDIO DONE
  void _handleAudioDone() {
    if (kDebugMode) {
      print('✅ Audio stream done');
    }
    stopRecording();
  }

  // ⏰ START PROCESSING TIMER
  void _startProcessingTimer() {
    _processingTimer = Timer.periodic(Duration(milliseconds: BUFFER_SIZE_MS), (timer) {
      if (_isRecording && !_isPaused) {
        _processBufferedAudio();
      }
    });
  }

  // 🔄 PROCESS BUFFERED AUDIO FOR GOOGLE CLOUD
  Future<void> _processBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;

    try {
      // Calculate total size
      int totalSize = _audioBuffer.fold(0, (sum, chunk) => sum + chunk.length);

      // Combine all chunks into single buffer
      final Uint8List combinedBuffer = Uint8List(totalSize);
      int offset = 0;

      for (final chunk in _audioBuffer) {
        combinedBuffer.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Send combined audio data for Google Cloud processing
      if (combinedBuffer.isNotEmpty) {
        _statusController.add({
          'type': 'audio_chunk_ready',
          'data': combinedBuffer,
          'size': totalSize,
          'sampleRate': SAMPLE_RATE,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        if (kDebugMode) {
          print('🔄 Processed audio chunk: $totalSize bytes for Google Cloud');
        }
      }

      // Clear buffer after processing
      _audioBuffer.clear();

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing buffered audio: $e');
      }
    }
  }

  // 📡 NOTIFY STATUS CHANGE
  void _notifyStatusChange() {
    _statusController.add({
      'type': 'status_change',
      'isRecording': _isRecording,
      'isPaused': _isPaused,
      'totalBytes': _totalBytesRecorded,
      'duration': _recordingDuration,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    notifyListeners();
  }

  // 🎯 GET AUDIO CHUNK FOR GOOGLE CLOUD (Public method)
  Stream<Uint8List> getAudioChunksForGoogleCloud() {
    return _statusController.stream
        .where((event) => event['type'] == 'audio_chunk_ready')
        .map((event) => event['data'] as Uint8List);
  }

  // 🔧 UTILITY: Convert audio data to Google Cloud format
  static Map<String, dynamic> getGoogleCloudAudioConfig() {
    return {
      'encoding': 'LINEAR16',
      'sampleRateHertz': SAMPLE_RATE,
      'languageCode': 'en-US', // Can be overridden
      'audioChannelCount': 1,
      'enableAutomaticPunctuation': true,
      'model': 'latest_long',
    };
  }

  // 🔧 UTILITY: Calculate audio duration
  static Duration calculateDuration(int bytes) {
    // 16-bit mono: 2 bytes per sample
    int samples = bytes ~/ 2;
    int durationMs = (samples * 1000) ~/ SAMPLE_RATE;
    return Duration(milliseconds: durationMs);
  }

  // 🧹 DISPOSE
  @override
  void dispose() {
    if (kDebugMode) {
      print('🧹 Disposing AudioCaptureService...');
    }

    // Stop recording if active
    if (_isRecording) {
      stopRecording();
    }

    // Cancel timers
    _processingTimer?.cancel();

    // Cancel subscriptions
    _eventSubscription?.cancel();

    // Close controllers
    _audioDataController.close();
    _statusController.close();

    super.dispose();
  }
}