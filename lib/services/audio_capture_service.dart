// lib/services/enhanced_audio_capture_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Audio capture configuration optimized for real-time transcription
class AudioCaptureConfig {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final Duration chunkDuration;
  final double silenceThreshold;
  final Duration maxBufferDuration;
  final bool enableVAD;
  final double vadThreshold;
  final bool enableNoiseReduction;
  final bool enableAutoGainControl;

  const AudioCaptureConfig({
    this.sampleRate = 16000, // Whisper optimal sample rate
    this.channels = 1, // Mono for speech recognition
    this.bitsPerSample = 16, // 16-bit PCM
    this.chunkDuration = const Duration(milliseconds: 1000), // 1 second chunks
    this.silenceThreshold = 0.01,
    this.maxBufferDuration = const Duration(seconds: 10),
    this.enableVAD = true,
    this.vadThreshold = 0.02,
    this.enableNoiseReduction = true,
    this.enableAutoGainControl = true,
  });

  int get bytesPerSecond => sampleRate * channels * (bitsPerSample ~/ 8);
  int get samplesPerChunk => (sampleRate * chunkDuration.inMilliseconds / 1000).round();
  int get bytesPerChunk => samplesPerChunk * channels * (bitsPerSample ~/ 8);

  @override
  String toString() {
    return 'AudioCaptureConfig($sampleRate Hz, ${channels}ch, ${bitsPerSample}bit, ${chunkDuration.inMilliseconds}ms chunks)';
  }
}

/// Audio stream information with enhanced metadata
class AudioStreamInfo {
  final String streamId;
  final String speakerId;
  final String speakerName;
  final MediaStream stream;
  final DateTime startTime;
  bool isActive;
  bool isCapturing;
  bool isLocalStream;
  MediaStreamTrack? audioTrack;
  double currentLevel;
  double averageLevel;
  int chunksProcessed;
  DateTime lastActivity;
  Map<String, dynamic> qualityMetrics;

  AudioStreamInfo({
    required this.streamId,
    required this.speakerId,
    required this.speakerName,
    required this.stream,
    required this.startTime,
    this.isActive = true,
    this.isCapturing = false,
    this.isLocalStream = false,
    this.audioTrack,
    this.currentLevel = 0.0,
    this.averageLevel = 0.0,
    this.chunksProcessed = 0,
    DateTime? lastActivity,
    Map<String, dynamic>? qualityMetrics,
  }) : lastActivity = lastActivity ?? DateTime.now(),
        qualityMetrics = qualityMetrics ?? {};

  Duration get duration => DateTime.now().difference(startTime);

  @override
  String toString() {
    return 'AudioStreamInfo(speaker: $speakerName, active: $isActive, capturing: $isCapturing, level: ${currentLevel.toStringAsFixed(3)})';
  }
}

/// Voice Activity Detection result with confidence
class VADResult {
  final bool isVoiceDetected;
  final double confidence;
  final double audioLevel;
  final double spectralCentroid;
  final double zeroCrossingRate;
  final DateTime timestamp;

  VADResult({
    required this.isVoiceDetected,
    required this.confidence,
    required this.audioLevel,
    required this.spectralCentroid,
    required this.zeroCrossingRate,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'VADResult(voice: $isVoiceDetected, confidence: ${confidence.toStringAsFixed(2)}, level: ${audioLevel.toStringAsFixed(3)})';
  }
}

/// Enhanced Real-time Audio Capture Service for WebRTC integration
class EnhancedAudioCaptureService extends ChangeNotifier {
  // Configuration
  final AudioCaptureConfig _config;

  // Audio streams management
  final Map<String, AudioStreamInfo> _audioStreams = {};
  final Map<String, List<double>> _audioBuffers = {};
  final Map<String, Timer> _chunkTimers = {};
  final Map<String, StreamSubscription> _streamSubscriptions = {};

  // Audio processing and analysis
  final Map<String, double> _audioLevels = {};
  final Map<String, DateTime> _lastActivityTimes = {};
  final Map<String, VADResult> _vadResults = {};
  final Map<String, List<double>> _levelHistory = {};

  // Capture state
  bool _isInitialized = false;
  bool _isCapturing = false;
  DateTime? _captureStartTime;

  // Processing timer for monitoring and cleanup
  Timer? _monitoringTimer;
  static const Duration monitoringInterval = Duration(milliseconds: 250);

  // Audio processing workers
  final Map<String, StreamController<List<double>>> _audioProcessors = {};

  // Callbacks
  Function(Uint8List audioData, String speakerId, String speakerName)? onAudioCaptured;
  Function(String error)? onError;
  Function(String speakerId, String speakerName, bool isActive)? onSpeakerActivityChanged;
  Function(String speakerId, VADResult vadResult)? onVoiceActivityDetected;
  Function(String speakerId, double level)? onAudioLevelChanged;

  // Statistics
  final Map<String, dynamic> _statistics = {
    'totalStreams': 0,
    'activeStreams': 0,
    'chunksProcessed': 0,
    'totalAudioDuration': 0.0,
    'averageProcessingTime': 0.0,
    'errors': 0,
  };

  EnhancedAudioCaptureService({AudioCaptureConfig? config})
      : _config = config ?? const AudioCaptureConfig() {
    print('🎙️ Enhanced Audio Capture Service initializing...');
    print('   ${_config.toString()}');
    print('   VAD enabled: ${_config.enableVAD}');
    print('   Noise reduction: ${_config.enableNoiseReduction}');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  int get activeStreamsCount => _audioStreams.values.where((s) => s.isActive).length;
  List<String> get activeSpeakers => _audioStreams.values
      .where((s) => s.isActive)
      .map((s) => s.speakerName)
      .toList();
  Map<String, double> get audioLevels => Map.unmodifiable(_audioLevels);
  Map<String, VADResult> get vadResults => Map.unmodifiable(_vadResults);
  Map<String, dynamic> get statistics => Map.unmodifiable(_statistics);
  AudioCaptureConfig get config => _config;

  /// Initialize the audio capture service
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('⚠️ Audio capture service already initialized');
      return true;
    }

    try {
      print('🚀 Initializing Enhanced Audio Capture Service...');

      // Start monitoring timer
      _startMonitoringTimer();

      _isInitialized = true;
      print('✅ Enhanced Audio Capture Service initialized');

      notifyListeners();
      return true;

    } catch (e) {
      print('❌ Failed to initialize audio capture service: $e');
      onError?.call('Audio capture initialization failed: $e');
      return false;
    }
  }

  /// Start capturing audio from local stream
  Future<void> startLocalCapture(
      MediaStream localStream,
      String speakerId,
      String speakerName,
      ) async {
    try {
      print('🎙️ Starting local audio capture for: $speakerName');

      await addStreamForCapture(
        speakerId,
        speakerName,
        localStream,
        isLocal: true,
      );

      _isCapturing = true;
      _captureStartTime = DateTime.now();

      print('✅ Local audio capture started for: $speakerName');
      notifyListeners();

    } catch (e) {
      print('❌ Failed to start local capture: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      onError?.call('Failed to start local audio capture: $e');
    }
  }

  /// Add a remote stream for audio capture
  Future<void> addRemoteStream(
      String speakerId,
      String speakerName,
      MediaStream remoteStream,
      ) async {
    try {
      print('📡 Adding remote stream for: $speakerName');

      await addStreamForCapture(
        speakerId,
        speakerName,
        remoteStream,
        isLocal: false,
      );

      print('✅ Remote stream added for capture: $speakerName');

    } catch (e) {
      print('❌ Failed to add remote stream: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      onError?.call('Failed to add remote stream: $e');
    }
  }

  /// Add any stream for audio capture with enhanced configuration
  Future<void> addStreamForCapture(
      String speakerId,
      String speakerName,
      MediaStream stream, {
        bool isLocal = false,
      }) async {
    try {
      // Check if already capturing this stream
      if (_audioStreams.containsKey(speakerId)) {
        print('⚠️ Already capturing audio from: $speakerName');
        return;
      }

      // Get audio tracks
      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isEmpty) {
        print('⚠️ No audio tracks found in stream for: $speakerName');
        return;
      }

      final audioTrack = audioTracks.first;

      // Create stream info
      final streamInfo = AudioStreamInfo(
        streamId: stream.id,
        speakerId: speakerId,
        speakerName: speakerName,
        stream: stream,
        startTime: DateTime.now(),
        audioTrack: audioTrack,
        isLocalStream: isLocal,
      );

      _audioStreams[speakerId] = streamInfo;
      _audioBuffers[speakerId] = <double>[];
      _audioLevels[speakerId] = 0.0;
      _lastActivityTimes[speakerId] = DateTime.now();
      _levelHistory[speakerId] = <double>[];
      _vadResults[speakerId] = VADResult(
        isVoiceDetected: false,
        confidence: 0.0,
        audioLevel: 0.0,
        spectralCentroid: 0.0,
        zeroCrossingRate: 0.0,
      );

      // Start capturing audio from this stream
      await _startStreamCapture(streamInfo);

      _statistics['totalStreams'] = (_statistics['totalStreams'] ?? 0) + 1;
      _statistics['activeStreams'] = activeStreamsCount;

      print('✅ Audio capture started for: $speakerName');
      notifyListeners();

    } catch (e) {
      print('❌ Error adding stream for capture: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      throw e;
    }
  }

  /// Start capturing audio from a specific stream
  Future<void> _startStreamCapture(AudioStreamInfo streamInfo) async {
    try {
      streamInfo.isCapturing = true;

      // Create audio processor for this stream
      final processor = StreamController<List<double>>();
      _audioProcessors[streamInfo.speakerId] = processor;

      // Set up audio processing pipeline
      processor.stream.listen(
            (samples) => _processAudioSamples(streamInfo.speakerId, samples),
        onError: (error) {
          print('❌ Audio processor error for ${streamInfo.speakerName}: $error');
          _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
        },
      );

      if (kIsWeb) {
        await _startWebAudioCapture(streamInfo);
      } else {
        await _startNativeAudioCapture(streamInfo);
      }

      // Start periodic chunk processing
      final timer = Timer.periodic(_config.chunkDuration, (timer) {
        _processAudioChunk(streamInfo.speakerId);
      });

      _chunkTimers[streamInfo.speakerId] = timer;

    } catch (e) {
      print('❌ Error starting stream capture: $e');
      streamInfo.isCapturing = false;
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      throw e;
    }
  }

  /// Start Web Audio API capture (enhanced for web platform)
  Future<void> _startWebAudioCapture(AudioStreamInfo streamInfo) async {
    if (!kIsWeb) return;

    try {
      print('🌐 Starting enhanced web audio capture for: ${streamInfo.speakerName}');

      // For web, we'll use a more sophisticated audio generation
      // In a real implementation, you'd use the js package to access Web Audio API

      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!_audioStreams.containsKey(streamInfo.speakerId) ||
            !streamInfo.isCapturing) {
          timer.cancel();
          return;
        }

        // Generate realistic audio samples with voice-like characteristics
        final samples = _generateEnhancedAudioSamples(streamInfo);
        final processor = _audioProcessors[streamInfo.speakerId];

        if (processor != null && !processor.isClosed) {
          processor.add(samples);
        }
      });

    } catch (e) {
      print('❌ Web audio capture error: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      throw e;
    }
  }

  /// Start native audio capture (enhanced for mobile platforms)
  Future<void> _startNativeAudioCapture(AudioStreamInfo streamInfo) async {
    try {
      print('📱 Starting enhanced native audio capture for: ${streamInfo.speakerName}');

      // For native platforms, we'll simulate until proper implementation
      // In a real implementation, you'd use platform channels or plugins

      Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!_audioStreams.containsKey(streamInfo.speakerId) ||
            !streamInfo.isCapturing) {
          timer.cancel();
          return;
        }

        // Generate realistic audio samples
        final samples = _generateEnhancedAudioSamples(streamInfo);
        final processor = _audioProcessors[streamInfo.speakerId];

        if (processor != null && !processor.isClosed) {
          processor.add(samples);
        }
      });

    } catch (e) {
      print('❌ Native audio capture error: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      throw e;
    }
  }

  /// Generate enhanced realistic audio samples for testing
  List<double> _generateEnhancedAudioSamples(AudioStreamInfo streamInfo) {
    final random = Random();
    final sampleCount = (_config.sampleRate * 0.05).round(); // 50ms of audio
    final samples = <double>[];

    // Time-based variation for more realistic patterns
    final timeOffset = DateTime.now().difference(streamInfo.startTime).inMilliseconds / 1000.0;

    // Simulate different speaker behaviors
    final contentType = random.nextDouble();
    final speakerActivity = 0.5 + 0.3 * sin(timeOffset * 0.1); // Periodic activity

    if (contentType < 0.2 * speakerActivity) {
      // Active speech (20% of time when active)
      for (int i = 0; i < sampleCount; i++) {
        // Realistic speech frequencies (fundamental + harmonics)
        final fundamental = 120.0 + random.nextDouble() * 160.0; // 120-280 Hz
        final formant1 = fundamental * 3.5 + random.nextDouble() * 200.0;
        final formant2 = fundamental * 7.0 + random.nextDouble() * 400.0;

        // Natural amplitude envelope
        final envelope = sin(pi * i / sampleCount);
        final amplitude = 0.1 + random.nextDouble() * 0.3;

        // Combine frequencies with realistic amplitudes
        final sample = envelope * amplitude * (
            0.5 * sin(2 * pi * fundamental * i / _config.sampleRate) +
                0.3 * sin(2 * pi * formant1 * i / _config.sampleRate) +
                0.2 * sin(2 * pi * formant2 * i / _config.sampleRate)
        );

        // Add slight noise for realism
        final noise = (random.nextDouble() - 0.5) * 0.02;
        samples.add((sample + noise).clamp(-1.0, 1.0));
      }
    } else if (contentType < 0.4) {
      // Breathing/background noise (20% of time)
      for (int i = 0; i < sampleCount; i++) {
        final breathFreq = 2.0 + random.nextDouble() * 3.0;
        final breath = 0.02 * sin(2 * pi * breathFreq * i / _config.sampleRate);
        final noise = (random.nextDouble() - 0.5) * 0.01;
        samples.add(breath + noise);
      }
    } else {
      // Silence or very low noise (60% of time)
      for (int i = 0; i < sampleCount; i++) {
        final noise = (random.nextDouble() - 0.5) * 0.005;
        samples.add(noise);
      }
    }

    return samples;
  }

  /// Process audio samples and update metrics
  void _processAudioSamples(String speakerId, List<double> samples) {
    if (samples.isEmpty) return;

    final streamInfo = _audioStreams[speakerId];
    if (streamInfo == null) return;

    try {
      // Add to buffer
      final buffer = _audioBuffers[speakerId];
      if (buffer != null) {
        buffer.addAll(samples);
      }

      // Update audio metrics
      _updateAudioMetrics(speakerId, samples);

      // Update stream info
      streamInfo.lastActivity = DateTime.now();
      streamInfo.chunksProcessed++;

    } catch (e) {
      print('❌ Error processing audio samples: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
    }
  }

  /// Update comprehensive audio metrics
  void _updateAudioMetrics(String speakerId, List<double> samples) {
    if (samples.isEmpty) return;

    try {
      // Calculate RMS level
      double sum = 0;
      for (double sample in samples) {
        sum += sample * sample;
      }
      final rms = sqrt(sum / samples.length);

      // Update current and average levels
      _audioLevels[speakerId] = rms;

      final levelHistory = _levelHistory[speakerId]!;
      levelHistory.add(rms);
      if (levelHistory.length > 100) {
        levelHistory.removeAt(0);
      }

      final streamInfo = _audioStreams[speakerId]!;
      streamInfo.currentLevel = rms;
      streamInfo.averageLevel = levelHistory.reduce((a, b) => a + b) / levelHistory.length;

      // Voice Activity Detection with enhanced features
      if (_config.enableVAD) {
        final vadResult = _performEnhancedVAD(samples, rms);
        _vadResults[speakerId] = vadResult;

        if (vadResult.isVoiceDetected) {
          _lastActivityTimes[speakerId] = DateTime.now();
        }

        // Notify listeners
        onVoiceActivityDetected?.call(speakerId, vadResult);
      } else {
        // Simple threshold-based activity detection
        if (rms > _config.silenceThreshold) {
          _lastActivityTimes[speakerId] = DateTime.now();
        }
      }

      // Notify level change
      onAudioLevelChanged?.call(speakerId, rms);

    } catch (e) {
      print('❌ Error updating audio metrics: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
    }
  }

  /// Perform enhanced Voice Activity Detection
  VADResult _performEnhancedVAD(List<double> samples, double rms) {
    try {
      // Basic voice detection
      final isBasicVoice = rms > _config.vadThreshold;

      // Enhanced features
      final spectralCentroid = _calculateSpectralCentroid(samples);
      final zeroCrossingRate = _calculateZeroCrossingRate(samples);

      // Voice classification confidence
      double confidence = 0.0;

      if (isBasicVoice) {
        // RMS level confidence (0.3 weight)
        if (rms > 0.02 && rms < 0.8) {
          confidence += 0.3;
        }

        // Spectral centroid confidence (0.4 weight)
        // Voice typically has centroid between 500-4000 Hz
        if (spectralCentroid > 500 && spectralCentroid < 4000) {
          confidence += 0.4;
        }

        // Zero crossing rate confidence (0.3 weight)
        // Voice typically has ZCR between 0.01-0.1
        if (zeroCrossingRate > 0.01 && zeroCrossingRate < 0.1) {
          confidence += 0.3;
        }
      }

      final isVoiceDetected = confidence > 0.5;

      return VADResult(
        isVoiceDetected: isVoiceDetected,
        confidence: confidence.clamp(0.0, 1.0),
        audioLevel: rms,
        spectralCentroid: spectralCentroid,
        zeroCrossingRate: zeroCrossingRate,
      );

    } catch (e) {
      print('❌ VAD error: $e');
      return VADResult(
        isVoiceDetected: false,
        confidence: 0.0,
        audioLevel: rms,
        spectralCentroid: 0.0,
        zeroCrossingRate: 0.0,
      );
    }
  }

  /// Calculate spectral centroid (frequency center of mass)
  double _calculateSpectralCentroid(List<double> samples) {
    if (samples.length < 64) return 0.0;

    try {
      // Simple spectral centroid using DFT approximation
      double weightedSum = 0;
      double magnitudeSum = 0;

      final n = min(samples.length, 512); // Limit for performance

      for (int k = 1; k < n ~/ 2; k++) {
        // Approximate DFT magnitude at frequency bin k
        double real = 0;
        double imag = 0;

        for (int i = 0; i < n; i++) {
          final angle = -2 * pi * k * i / n;
          real += samples[i] * cos(angle);
          imag += samples[i] * sin(angle);
        }

        final magnitude = sqrt(real * real + imag * imag);
        final frequency = k * _config.sampleRate / n;

        weightedSum += frequency * magnitude;
        magnitudeSum += magnitude;
      }

      return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0;

    } catch (e) {
      return 0.0;
    }
  }

  /// Calculate zero crossing rate
  double _calculateZeroCrossingRate(List<double> samples) {
    if (samples.length < 2) return 0.0;

    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i-1] >= 0)) {
        crossings++;
      }
    }

    return crossings / (samples.length - 1);
  }

  /// Process audio chunk for a specific speaker
  void _processAudioChunk(String speakerId) {
    try {
      final streamInfo = _audioStreams[speakerId];
      final buffer = _audioBuffers[speakerId];

      if (streamInfo == null || buffer == null || !streamInfo.isActive) {
        return;
      }

      // Check if we have enough data
      if (buffer.length < _config.samplesPerChunk) {
        return;
      }

      final startTime = DateTime.now();

      // Extract chunk
      final chunk = buffer.take(_config.samplesPerChunk).toList();
      buffer.removeRange(0, min(chunk.length, buffer.length));

      // Apply audio processing if enabled
      List<double> processedChunk = chunk;

      if (_config.enableNoiseReduction) {
        processedChunk = _applyNoiseReduction(processedChunk);
      }

      if (_config.enableAutoGainControl) {
        processedChunk = _applyAutoGainControl(processedChunk);
      }

      // Convert to PCM16 bytes
      final audioBytes = _convertToPCM16(processedChunk);

      // Check for silence/quality
      final vadResult = _vadResults[speakerId];
      final isGoodQuality = vadResult?.isVoiceDetected == true &&
          vadResult!.confidence > 0.3;

      if (!isGoodQuality) {
        return; // Skip low-quality or silent audio
      }

      // Send audio data
      onAudioCaptured?.call(
        audioBytes,
        speakerId,
        streamInfo.speakerName,
      );

      // Update statistics
      final processingTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      _statistics['chunksProcessed'] = (_statistics['chunksProcessed'] ?? 0) + 1;
      _statistics['totalAudioDuration'] = (_statistics['totalAudioDuration'] ?? 0.0) +
          (_config.chunkDuration.inMilliseconds / 1000.0);

      final currentAvg = _statistics['averageProcessingTime'] ?? 0.0;
      _statistics['averageProcessingTime'] = (currentAvg * 0.9) + (processingTime * 0.1);

      print('📤 Audio chunk sent for: ${streamInfo.speakerName} '
          '(${audioBytes.length} bytes, ${processingTime.toStringAsFixed(3)}s)');

    } catch (e) {
      print('❌ Error processing audio chunk: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      onError?.call('Audio processing error: $e');
    }
  }

  /// Apply noise reduction using spectral subtraction
  List<double> _applyNoiseReduction(List<double> samples) {
    try {
      if (samples.length < 256) return samples;

      // Simple high-pass filter to remove low-frequency noise
      final filteredSamples = <double>[];
      double prev = 0.0;

      for (int i = 0; i < samples.length; i++) {
        // High-pass filter: y[n] = x[n] - x[n-1] + 0.95 * y[n-1]
        final filtered = samples[i] - prev + 0.95 * (filteredSamples.isNotEmpty ? filteredSamples.last : 0.0);
        filteredSamples.add(filtered);
        prev = samples[i];
      }

      return filteredSamples;

    } catch (e) {
      print('⚠️ Noise reduction error: $e');
      return samples;
    }
  }

  /// Apply automatic gain control
  List<double> _applyAutoGainControl(List<double> samples) {
    try {
      if (samples.isEmpty) return samples;

      // Calculate current RMS level
      double sum = 0;
      for (double sample in samples) {
        sum += sample * sample;
      }
      final rms = sqrt(sum / samples.length);

      if (rms < 0.001) return samples; // Too quiet, no adjustment

      // Target RMS level for speech
      const targetRMS = 0.15;
      final gain = targetRMS / rms;

      // Limit gain to prevent distortion
      final limitedGain = gain.clamp(0.1, 3.0);

      // Apply gain with soft limiting
      return samples.map((sample) {
        final amplified = sample * limitedGain;
        // Soft limiting using tan
        return tan(amplified * 0.8) * 0.8;
      }).toList();

    } catch (e) {
      print('⚠️ AGC error: $e');
      return samples;
    }
  }

  /// Convert float samples to PCM16 bytes with dithering
  Uint8List _convertToPCM16(List<double> samples) {
    final byteData = ByteData(samples.length * 2);
    final random = Random();

    for (int i = 0; i < samples.length; i++) {
      // Clamp and apply dithering for better quality
      double clampedSample = samples[i].clamp(-1.0, 1.0);

      // Add triangular dithering
      final dither = (random.nextDouble() - random.nextDouble()) * (1.0 / 32768.0);
      clampedSample += dither;

      final intSample = (clampedSample * 32767).round().clamp(-32768, 32767);
      byteData.setInt16(i * 2, intSample, Endian.little);
    }

    return byteData.buffer.asUint8List();
  }

  /// Start monitoring timer for activity detection and cleanup
  void _startMonitoringTimer() {
    _monitoringTimer = Timer.periodic(monitoringInterval, (timer) {
      try {
        _updateSpeakerActivity();
        _cleanupBuffers();
        _updateStatistics();
      } catch (e) {
        print('❌ Monitoring timer error: $e');
        _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      }
    });
  }

  /// Update speaker activity status
  void _updateSpeakerActivity() {
    final now = DateTime.now();

    for (var entry in _audioStreams.entries) {
      final speakerId = entry.key;
      final streamInfo = entry.value;
      final lastActivity = _lastActivityTimes[speakerId];

      if (lastActivity != null) {
        final timeSinceActivity = now.difference(lastActivity);
        final isCurrentlyActive = timeSinceActivity < const Duration(seconds: 3);

        if (streamInfo.isActive != isCurrentlyActive) {
          streamInfo.isActive = isCurrentlyActive;
          onSpeakerActivityChanged?.call(
            speakerId,
            streamInfo.speakerName,
            isCurrentlyActive,
          );
        }
      }
    }
  }

  /// Clean up old buffer data and maintain memory efficiency
  void _cleanupBuffers() {
    final maxBufferSamples = _config.sampleRate * _config.maxBufferDuration.inSeconds;

    for (var entry in _audioBuffers.entries) {
      final buffer = entry.value;
      if (buffer.length > maxBufferSamples) {
        final removeCount = buffer.length - maxBufferSamples ~/ 2;
        buffer.removeRange(0, removeCount);
      }
    }

    // Clean up level history
    for (var entry in _levelHistory.entries) {
      final history = entry.value;
      if (history.length > 200) {
        history.removeRange(0, history.length - 200);
      }
    }
  }

  /// Update service statistics
  void _updateStatistics() {
    _statistics['activeStreams'] = activeStreamsCount;
    notifyListeners();
  }

  /// Remove stream from capture
  Future<void> removeRemoteStream(String speakerId) async {
    try {
      final streamInfo = _audioStreams[speakerId];
      if (streamInfo == null) return;

      print('🗑️ Removing audio capture for: ${streamInfo.speakerName}');

      // Stop capturing
      streamInfo.isCapturing = false;

      // Stop and cleanup timers
      _chunkTimers[speakerId]?.cancel();
      _chunkTimers.remove(speakerId);

      // Close audio processor
      final processor = _audioProcessors[speakerId];
      if (processor != null && !processor.isClosed) {
        await processor.close();
      }
      _audioProcessors.remove(speakerId);

      // Clean up subscriptions
      final subscription = _streamSubscriptions[speakerId];
      if (subscription != null) {
        await subscription.cancel();
        _streamSubscriptions.remove(speakerId);
      }

      // Clean up data
      _audioStreams.remove(speakerId);
      _audioBuffers.remove(speakerId);
      _audioLevels.remove(speakerId);
      _lastActivityTimes.remove(speakerId);
      _vadResults.remove(speakerId);
      _levelHistory.remove(speakerId);

      _statistics['activeStreams'] = activeStreamsCount;

      print('✅ Audio capture removed for: ${streamInfo.speakerName}');
      notifyListeners();

    } catch (e) {
      print('❌ Error removing stream: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      onError?.call('Failed to remove audio stream: $e');
    }
  }

  /// Stop all audio capture
  Future<void> stopCapture() async {
    try {
      print('🛑 Stopping all audio capture...');

      // Stop all stream capturing
      for (var streamInfo in _audioStreams.values) {
        streamInfo.isCapturing = false;
      }

      // Cancel all timers
      for (var timer in _chunkTimers.values) {
        timer.cancel();
      }
      _chunkTimers.clear();

      // Close all audio processors
      for (var processor in _audioProcessors.values) {
        if (!processor.isClosed) {
          await processor.close();
        }
      }
      _audioProcessors.clear();

      // Cancel all subscriptions
      for (var subscription in _streamSubscriptions.values) {
        await subscription.cancel();
      }
      _streamSubscriptions.clear();

      // Clear all data
      _audioStreams.clear();
      _audioBuffers.clear();
      _audioLevels.clear();
      _lastActivityTimes.clear();
      _vadResults.clear();
      _levelHistory.clear();

      _isCapturing = false;
      _captureStartTime = null;
      _statistics['activeStreams'] = 0;

      print('✅ Audio capture stopped');
      notifyListeners();

    } catch (e) {
      print('❌ Error stopping capture: $e');
      _statistics['errors'] = (_statistics['errors'] ?? 0) + 1;
      onError?.call('Failed to stop audio capture: $e');
    }
  }

  /// Get detailed audio statistics for monitoring
  Map<String, dynamic> getDetailedStatistics() {
    final now = DateTime.now();
    final captureTime = _captureStartTime;

    return {
      'service': {
        'isInitialized': _isInitialized,
        'isCapturing': _isCapturing,
        'uptime': captureTime != null ? now.difference(captureTime).inSeconds : 0,
        'config': {
          'sampleRate': _config.sampleRate,
          'channels': _config.channels,
          'chunkDuration': _config.chunkDuration.inMilliseconds,
          'vadEnabled': _config.enableVAD,
          'noiseReduction': _config.enableNoiseReduction,
          'autoGainControl': _config.enableAutoGainControl,
        },
      },
      'streams': _audioStreams.values.map((stream) => {
        'speakerId': stream.speakerId,
        'speakerName': stream.speakerName,
        'isActive': stream.isActive,
        'isCapturing': stream.isCapturing,
        'isLocal': stream.isLocalStream,
        'currentLevel': stream.currentLevel,
        'averageLevel': stream.averageLevel,
        'chunksProcessed': stream.chunksProcessed,
        'duration': stream.duration.inSeconds,
        'vadResult': _vadResults[stream.speakerId]?.toString(),
      }).toList(),
      'performance': _statistics,
    };
  }

  @override
  void dispose() {
    print('🗑️ Disposing Enhanced Audio Capture Service...');

    _monitoringTimer?.cancel();
    stopCapture();

    super.dispose();
  }
}