// lib/services/audio_capture_service.dart (IMPROVED VERSION)
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

class AudioCaptureService extends ChangeNotifier {
  // Audio capture settings
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bytesPerSample = 2;
  static const int bufferSizeMs = 1000; // 1 second buffers
  static const int bufferSize = (sampleRate * channels * bytesPerSample * bufferSizeMs) ~/ 1000;

  // Audio capture state
  bool _isCapturing = false;
  Timer? _captureTimer;
  final List<int> _audioBuffer = [];

  // Callbacks for audio data
  Function(Uint8List audioData, String speakerId, String speakerName)? onAudioCaptured;
  Function(String error)? onError;

  // Current participant info
  String? _currentSpeakerId;
  String? _currentSpeakerName;

  // MediaStream references
  MediaStream? _localStream;
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, String> _participantNames = {};

  // Audio level monitoring
  final Map<String, double> _audioLevels = {};
  Timer? _audioLevelTimer;

  // Getters
  bool get isCapturing => _isCapturing;
  String? get currentSpeakerId => _currentSpeakerId;
  Map<String, double> get audioLevels => Map.unmodifiable(_audioLevels);

  // Start capturing audio from local stream
  Future<void> startLocalCapture(MediaStream localStream, String speakerId, String speakerName) async {
    try {
      print('🎙️ Starting local audio capture for $speakerName');

      _localStream = localStream;
      _currentSpeakerId = speakerId;
      _currentSpeakerName = speakerName;

      if (!_isCapturing) {
        await _startCapturing();
      }

      // Start audio level monitoring
      _startAudioLevelMonitoring();

      notifyListeners();
    } catch (e) {
      print('❌ Error starting local audio capture: $e');
      onError?.call('Failed to start audio capture: $e');
    }
  }

  // Add remote stream for capture
  void addRemoteStream(String participantId, String participantName, MediaStream stream) {
    try {
      print('🔊 Adding remote stream for $participantName');

      _remoteStreams[participantId] = stream;
      _participantNames[participantId] = participantName;

      // Start monitoring audio levels for remote stream
      _startRemoteAudioMonitoring(participantId, stream);

      notifyListeners();
    } catch (e) {
      print('❌ Error adding remote stream: $e');
    }
  }

  // Remove remote stream
  void removeRemoteStream(String participantId) {
    try {
      print('🔇 Removing remote stream for participant: $participantId');

      _remoteStreams.remove(participantId);
      _participantNames.remove(participantId);
      _audioLevels.remove(participantId);

      notifyListeners();
    } catch (e) {
      print('❌ Error removing remote stream: $e');
    }
  }

  // Start the audio capturing process
  Future<void> _startCapturing() async {
    if (_isCapturing) return;

    try {
      print('🎵 Starting audio capture timer...');

      _isCapturing = true;
      _audioBuffer.clear();

      // Start periodic audio capture
      _captureTimer = Timer.periodic(
        const Duration(milliseconds: bufferSizeMs),
            (timer) => _captureAudioFrame(),
      );

      print('✅ Audio capture started');
      notifyListeners();
    } catch (e) {
      print('❌ Error starting audio capture: $e');
      onError?.call('Failed to start audio capture: $e');
    }
  }

  // Start audio level monitoring
  void _startAudioLevelMonitoring() {
    _audioLevelTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (timer) => _updateAudioLevels(),
    );
  }

  // Update audio levels for all streams
  void _updateAudioLevels() {
    try {
      // Monitor local stream
      if (_localStream != null && _currentSpeakerId != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          // Simulate audio level detection
          final level = _simulateAudioLevel();
          _audioLevels[_currentSpeakerId!] = level;
        }
      }

      // Monitor remote streams
      for (var entry in _remoteStreams.entries) {
        final participantId = entry.key;
        final stream = entry.value;
        final audioTracks = stream.getAudioTracks();

        if (audioTracks.isNotEmpty) {
          final level = _simulateAudioLevel();
          _audioLevels[participantId] = level;
        }
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error updating audio levels: $e');
    }
  }

  // Simulate audio level for demonstration
  double _simulateAudioLevel() {
    // In a real implementation, you would analyze the actual audio data
    // This is just a simulation for UI feedback
    return (DateTime.now().millisecondsSinceEpoch % 100) / 100.0;
  }

  // Start monitoring remote audio
  void _startRemoteAudioMonitoring(String participantId, MediaStream stream) {
    try {
      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isEmpty) return;

      // In a real implementation, you would set up audio analysis here
      print('📊 Started audio monitoring for $participantId');
    } catch (e) {
      print('❌ Error starting remote audio monitoring: $e');
    }
  }

  // Capture audio frame from current streams
  void _captureAudioFrame() async {
    if (!_isCapturing) return;

    try {
      // For local stream audio capture
      if (_localStream != null && _currentSpeakerId != null && _currentSpeakerName != null) {
        await _captureFromLocalStream();
      }

      // Capture from remote streams if needed
      // Note: Remote audio capture in WebRTC requires special handling
      // and may not be possible directly due to security restrictions

    } catch (e) {
      print('❌ Error capturing audio frame: $e');
    }
  }

  // Capture audio from local stream
  Future<void> _captureFromLocalStream() async {
    try {
      if (_localStream == null) return;

      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isEmpty) return;

      final audioTrack = audioTracks.first;
      if (!audioTrack.enabled) return;

      // Check if user is speaking (audio level above threshold)
      final currentLevel = _audioLevels[_currentSpeakerId] ?? 0.0;
      if (currentLevel < 0.1) return; // Silence threshold

      // Generate mock audio data for demonstration
      // In a real implementation, you would need to use platform-specific
      // audio capture methods or WebRTC extensions
      final mockAudioData = _generateMockAudioData();

      if (mockAudioData.isNotEmpty) {
        onAudioCaptured?.call(
          Uint8List.fromList(mockAudioData),
          _currentSpeakerId!,
          _currentSpeakerName!,
        );
      }

    } catch (e) {
      print('❌ Error capturing from local stream: $e');
    }
  }

  // Generate mock audio data for testing
  List<int> _generateMockAudioData() {
    // Generate a small amount of mock PCM data
    // This is just for testing - replace with real audio capture
    final List<int> mockData = [];

    // Generate 1 second of mock 16kHz mono audio
    for (int i = 0; i < sampleRate; i++) {
      // Simple sine wave for testing
      final double sample = 0.1 * (((i * 440.0 * 2.0 * 3.14159) / sampleRate) % (2 * 3.14159));
      final int intSample = (sample * 32767).round().clamp(-32767, 32767);

      // Convert to 16-bit PCM (little endian)
      mockData.add(intSample & 0xFF);
      mockData.add((intSample >> 8) & 0xFF);
    }

    return mockData;
  }

  // Stop audio capture
  Future<void> stopCapture() async {
    try {
      print('⏹️ Stopping audio capture...');

      _isCapturing = false;

      _captureTimer?.cancel();
      _captureTimer = null;

      _audioLevelTimer?.cancel();
      _audioLevelTimer = null;

      _audioBuffer.clear();
      _audioLevels.clear();
      _currentSpeakerId = null;
      _currentSpeakerName = null;

      print('✅ Audio capture stopped');
      notifyListeners();
    } catch (e) {
      print('❌ Error stopping audio capture: $e');
    }
  }

  // Clear all streams and stop capture
  Future<void> clearAllStreams() async {
    try {
      await stopCapture();

      _localStream = null;
      _remoteStreams.clear();
      _participantNames.clear();
      _audioLevels.clear();

      notifyListeners();
    } catch (e) {
      print('❌ Error clearing streams: $e');
    }
  }

  // Test audio capture with file data
  Future<void> testWithAudioFile(Uint8List audioFileData, String speakerId, String speakerName) async {
    try {
      print('🧪 Testing audio capture with file data');

      onAudioCaptured?.call(audioFileData, speakerId, speakerName);

      print('✅ Test audio data sent');
    } catch (e) {
      print('❌ Error testing with audio file: $e');
      onError?.call('Test failed: $e');
    }
  }

  // Get current capture status
  Map<String, dynamic> getCaptureStatus() {
    return {
      'isCapturing': _isCapturing,
      'currentSpeaker': _currentSpeakerName,
      'localStreamActive': _localStream != null,
      'remoteStreamsCount': _remoteStreams.length,
      'bufferSize': _audioBuffer.length,
      'audioLevels': _audioLevels,
    };
  }

  // Get speaking status
  bool isSpeaking(String participantId) {
    final level = _audioLevels[participantId] ?? 0.0;
    return level > 0.15; // Speaking threshold
  }

  // Get current speaker
  String? getCurrentSpeaker() {
    String? currentSpeaker;
    double maxLevel = 0.15; // Minimum level to be considered speaking

    for (var entry in _audioLevels.entries) {
      if (entry.value > maxLevel) {
        maxLevel = entry.value;
        currentSpeaker = entry.key;
      }
    }

    return currentSpeaker;
  }

  @override
  void dispose() {
    print('🧹 Disposing AudioCaptureService');
    stopCapture();
    clearAllStreams();
    super.dispose();
  }
}

// Audio format utility class (enhanced)
class AudioFormat {
  static const int pcm16BitMono16kHz = 1;
  static const int pcm16BitStereo44kHz = 2;
  static const int webmOpus = 3;

  static Map<String, dynamic> getPCM16Mono16kHzFormat() {
    return {
      'format': 'pcm',
      'sampleRate': 16000,
      'channels': 1,
      'bitDepth': 16,
      'encoding': 'signed',
      'byteOrder': 'little-endian',
    };
  }

  static Map<String, dynamic> getWebMFormat() {
    return {
      'format': 'webm',
      'codec': 'opus',
      'sampleRate': 48000,
      'channels': 1,
      'bitrate': 64000,
    };
  }

  // Convert audio data between formats
  static Uint8List convertTo16kHz(Uint8List audioData, int sourceSampleRate) {
    // Simple downsampling implementation
    // In production, use a proper audio processing library
    if (sourceSampleRate == 16000) return audioData;

    final ratio = sourceSampleRate / 16000;
    final newLength = (audioData.length / ratio).round();
    final result = Uint8List(newLength);

    for (int i = 0; i < newLength; i += 2) {
      final sourceIndex = (i * ratio).round();
      if (sourceIndex < audioData.length - 1) {
        result[i] = audioData[sourceIndex];
        result[i + 1] = audioData[sourceIndex + 1];
      }
    }

    return result;
  }
}