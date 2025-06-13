// lib/services/audio_capture_service.dart
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

  // Getters
  bool get isCapturing => _isCapturing;
  String? get currentSpeakerId => _currentSpeakerId;

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

      // Note: Capturing remote audio in WebRTC is complex and may require
      // special handling depending on the platform. For now, we focus on local audio.

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

  // Capture audio frame from current streams
  void _captureAudioFrame() async {
    if (!_isCapturing) return;

    try {
      // For local stream audio capture
      if (_localStream != null && _currentSpeakerId != null && _currentSpeakerName != null) {
        await _captureFromLocalStream();
      }

      // TODO: Add remote stream capture if needed
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
  // In production, this should be replaced with real audio capture
  List<int> _generateMockAudioData() {
    // Generate a small amount of mock PCM data
    // This is just for testing - replace with real audio capture
    final random = DateTime.now().millisecondsSinceEpoch;
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

      _audioBuffer.clear();
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
    };
  }

  @override
  void dispose() {
    print('🧹 Disposing AudioCaptureService');
    stopCapture();
    clearAllStreams();
    super.dispose();
  }
}

// Audio format utility class
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
}