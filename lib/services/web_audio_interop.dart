// lib/services/web_audio_interop.dart
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Web Audio Interop for real WebRTC audio capture on web platform
class WebAudioInterop {
  static final WebAudioInterop _instance = WebAudioInterop._internal();
  factory WebAudioInterop() => _instance;
  WebAudioInterop._internal();

  bool _isInitialized = false;
  final Map<String, StreamController<Uint8List>> _audioControllers = {};
  final Map<String, String> _streamSpeakerNames = {};

  /// Check if Web Audio API is available
  bool get isSupported => kIsWeb && js.context.hasProperty('webRTCAudioCapture');

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get active stream count
  int get activeStreamsCount => _audioControllers.length;

  /// Initialize Web Audio Interop
  Future<bool> initialize() async {
    if (!kIsWeb) {
      print('⚠️ Web Audio Interop only works on web platform');
      return false;
    }

    try {
      // Check if Web Audio Helper is loaded
      if (!js.context.hasProperty('webRTCAudioCapture')) {
        print('❌ Web Audio Helper not found. Make sure web_audio_helper.html is loaded.');
        return false;
      }

      // Set up Flutter callback for audio data
      js.context['flutterAudioCallback'] = js.allowInterop(_onAudioData);

      // Initialize Web Audio API
      final success = await _callJSMethod('webRTCAudioCapture.initialize()');

      if (success == true) {
        _isInitialized = true;
        print('✅ Web Audio Interop initialized');
        return true;
      } else {
        print('❌ Failed to initialize Web Audio API');
        return false;
      }
    } catch (e) {
      print('❌ Web Audio Interop initialization error: $e');
      return false;
    }
  }

  /// Start capturing audio from MediaStream
  Future<Stream<Uint8List>?> startCapture(
      MediaStream mediaStream,
      String streamId,
      String speakerName,
      ) async {
    if (!_isInitialized) {
      print('❌ Web Audio Interop not initialized');
      return null;
    }

    try {
      print('🎙️ Starting web audio capture for: $speakerName');

      // Create stream controller for this audio stream
      final controller = StreamController<Uint8List>.broadcast();
      _audioControllers[streamId] = controller;
      _streamSpeakerNames[streamId] = speakerName;

      // Get the native MediaStream object
      final jsMediaStream = _getJSMediaStream(mediaStream);
      if (jsMediaStream == null) {
        throw Exception('Failed to get JS MediaStream object');
      }

      // Start capture via JS
      final success = await js_util.promiseToFuture(
        js_util.callMethod(
          js.context,
          'startWebRTCAudioCapture',
          [jsMediaStream, streamId, speakerName],
        ),
      );

      if (success == true) {
        print('✅ Web audio capture started for: $speakerName');
        return controller.stream;
      } else {
        // Cleanup on failure
        _audioControllers.remove(streamId);
        _streamSpeakerNames.remove(streamId);
        controller.close();
        throw Exception('Failed to start web audio capture');
      }
    } catch (e) {
      print('❌ Error starting web audio capture: $e');
      _audioControllers.remove(streamId);
      _streamSpeakerNames.remove(streamId);
      return null;
    }
  }

  /// Stop capturing audio from a stream
  Future<void> stopCapture(String streamId) async {
    try {
      print('🛑 Stopping web audio capture for stream: $streamId');

      // Stop capture via JS
      final success = js_util.callMethod(
        js.context,
        'stopWebRTCAudioCapture',
        [streamId],
      );

      // Cleanup controller
      final controller = _audioControllers.remove(streamId);
      _streamSpeakerNames.remove(streamId);
      await controller?.close();

      if (success == true) {
        print('✅ Web audio capture stopped for stream: $streamId');
      } else {
        print('⚠️ JS method returned false for stop capture');
      }
    } catch (e) {
      print('❌ Error stopping web audio capture: $e');
    }
  }

  /// Stop all audio capture
  Future<void> stopAllCapture() async {
    try {
      print('🛑 Stopping all web audio capture...');

      // Stop all streams
      final streamIds = List<String>.from(_audioControllers.keys);
      for (final streamId in streamIds) {
        await stopCapture(streamId);
      }

      print('✅ All web audio capture stopped');
    } catch (e) {
      print('❌ Error stopping all web audio capture: $e');
    }
  }

  /// Get Web Audio statistics
  Future<Map<String, dynamic>?> getStats() async {
    if (!_isInitialized) return null;

    try {
      final stats = js_util.callMethod(js.context, 'getWebRTCAudioStats', []);
      if (stats != null) {
        // Convert JS object to Dart Map
        return _jsObjectToDartMap(stats);
      }
    } catch (e) {
      print('❌ Error getting web audio stats: $e');
    }
    return null;
  }

  /// Handle audio data from JavaScript
  void _onAudioData(String streamId, String speakerName, String base64Data) {
    try {
      // Decode base64 audio data
      final audioBytes = base64Decode(base64Data);

      // Send to appropriate stream controller
      final controller = _audioControllers[streamId];
      if (controller != null && !controller.isClosed) {
        controller.add(audioBytes);
      } else {
        print('⚠️ No controller found for stream: $streamId');
      }
    } catch (e) {
      print('❌ Error processing audio data: $e');
    }
  }

  /// Get JS MediaStream object from Flutter WebRTC MediaStream
  dynamic _getJSMediaStream(MediaStream mediaStream) {
    try {
      // Access the underlying JS MediaStream object
      // This is specific to flutter_webrtc implementation
      final jsStream = js_util.getProperty(mediaStream, 'jsStream');
      return jsStream;
    } catch (e) {
      print('❌ Error getting JS MediaStream: $e');

      // Fallback: try to access through different property names
      try {
        final jsObject = js_util.getProperty(mediaStream, '_jsMMediaStream');
        return jsObject;
      } catch (e2) {
        print('❌ Fallback also failed: $e2');
        return null;
      }
    }
  }

  /// Call JavaScript method and handle promise
  Future<dynamic> _callJSMethod(String methodPath) async {
    try {
      final parts = methodPath.split('.');
      dynamic obj = js.context;

      for (int i = 0; i < parts.length - 1; i++) {
        obj = js_util.getProperty(obj, parts[i]);
        if (obj == null) {
          throw Exception('Property ${parts[i]} not found');
        }
      }

      final methodName = parts.last.replaceAll('()', '');
      final result = js_util.callMethod(obj, methodName, []);

      // Handle promises
      if (_isPromise(result)) {
        return await js_util.promiseToFuture(result);
      }

      return result;
    } catch (e) {
      print('❌ Error calling JS method $methodPath: $e');
      return null;
    }
  }

  /// Check if object is a Promise
  bool _isPromise(dynamic obj) {
    return obj != null &&
        js_util.hasProperty(obj, 'then') &&
        js_util.hasProperty(obj, 'catch');
  }

  /// Convert JS object to Dart Map recursively
  Map<String, dynamic> _jsObjectToDartMap(dynamic jsObject) {
    final map = <String, dynamic>{};

    try {
      final keys = js_util.callMethod(js.context['Object'], 'keys', [jsObject]);
      final keysList = List<String>.from(keys);

      for (final key in keysList) {
        final value = js_util.getProperty(jsObject, key);
        map[key] = _convertJSValue(value);
      }
    } catch (e) {
      print('❌ Error converting JS object to Dart map: $e');
    }

    return map;
  }

  /// Convert JS value to appropriate Dart type
  dynamic _convertJSValue(dynamic value) {
    if (value == null) return null;

    // Check if it's a JS array
    if (js_util.hasProperty(value, 'length') &&
        js_util.hasProperty(value, 'forEach')) {
      return List<dynamic>.from(value);
    }

    // Check if it's a JS object
    if (value.runtimeType.toString().contains('JS')) {
      return _jsObjectToDartMap(value);
    }

    // Primitive types
    return value;
  }

  /// Dispose resources
  void dispose() {
    print('🗑️ Disposing Web Audio Interop...');

    stopAllCapture();

    // Clear callbacks
    if (kIsWeb && js.context.hasProperty('flutterAudioCallback')) {
      js.context.deleteProperty('flutterAudioCallback');
    }

    _isInitialized = false;
  }
}

/// Enhanced Audio Capture Service with Web Audio integration
class EnhancedAudioCaptureService {
  final WebAudioInterop _webAudioInterop = WebAudioInterop();
  final Map<String, StreamSubscription> _audioSubscriptions = {};
  final Map<String, String> _streamSpeakerNames = {};

  // Callbacks
  Function(Uint8List audioData, String speakerId, String speakerName)? onAudioCaptured;
  Function(String error)? onError;
  Function(String speakerId, String speakerName, bool isActive)? onSpeakerActivityChanged;

  bool _isInitialized = false;

  /// Initialize the enhanced audio capture service
  Future<bool> initialize() async {
    try {
      print('🚀 Initializing Enhanced Audio Capture Service...');

      if (kIsWeb) {
        _isInitialized = await _webAudioInterop.initialize();
        if (_isInitialized) {
          print('✅ Web Audio integration enabled');
        } else {
          print('⚠️ Web Audio integration failed, falling back to basic mode');
          _isInitialized = true; // Still allow basic functionality
        }
      } else {
        print('📱 Native platform detected');
        _isInitialized = true;
      }

      return _isInitialized;
    } catch (e) {
      print('❌ Enhanced Audio Capture Service initialization failed: $e');
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
    await addStreamForCapture(speakerId, speakerName, localStream);
  }

  /// Add remote stream for audio capture
  Future<void> addRemoteStream(
      String speakerId,
      String speakerName,
      MediaStream remoteStream,
      ) async {
    await addStreamForCapture(speakerId, speakerName, remoteStream);
  }

  /// Add stream for audio capture
  Future<void> addStreamForCapture(
      String speakerId,
      String speakerName,
      MediaStream stream,
      ) async {
    if (!_isInitialized) {
      print('❌ Enhanced Audio Capture Service not initialized');
      return;
    }

    try {
      print('🎙️ Adding stream for capture: $speakerName');

      // Check if already capturing
      if (_audioSubscriptions.containsKey(speakerId)) {
        print('⚠️ Already capturing audio from: $speakerName');
        return;
      }

      _streamSpeakerNames[speakerId] = speakerName;

      if (kIsWeb && _webAudioInterop.isInitialized) {
        // Use Web Audio API for real capture
        final audioStream = await _webAudioInterop.startCapture(
          stream,
          speakerId,
          speakerName,
        );

        if (audioStream != null) {
          final subscription = audioStream.listen(
                (audioData) {
              onAudioCaptured?.call(audioData, speakerId, speakerName);
            },
            onError: (error) {
              print('❌ Audio stream error for $speakerName: $error');
              onError?.call('Audio stream error: $error');
            },
          );

          _audioSubscriptions[speakerId] = subscription as StreamSubscription;
          print('✅ Web audio capture started for: $speakerName');
        } else {
          throw Exception('Failed to start web audio capture');
        }
      } else {
        // Fallback for native platforms or when Web Audio is not available
        await _startFallbackCapture(speakerId, speakerName, stream);
      }

    } catch (e) {
      print('❌ Error adding stream for capture: $e');
      onError?.call('Failed to add audio stream: $e');
    }
  }

  /// Fallback audio capture for native platforms
  Future<void> _startFallbackCapture(
      String speakerId,
      String speakerName,
      MediaStream stream,
      ) async {
    try {
      print('📱 Starting fallback audio capture for: $speakerName');

      // For native platforms, we could use platform channels
      // For now, we'll simulate audio data
      final timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        if (!_audioSubscriptions.containsKey(speakerId)) {
          timer.cancel();
          return;
        }

        // Generate sample audio data
        final sampleRate = 16000;
        final duration = 1.0; // 1 second
        final samples = sampleRate * duration;
        final audioData = Uint8List(samples.round() * 2); // 16-bit samples

        // Simple sine wave for testing
        final byteData = ByteData.view(audioData.buffer);
        for (int i = 0; i < samples; i++) {
          final sample = (sin(2 * pi * 440 * i / sampleRate) * 32767 * 0.1).round();
          byteData.setInt16(i * 2, sample, Endian.little);
        }

        onAudioCaptured?.call(audioData, speakerId, speakerName);
      });

      // Store timer as subscription equivalent
      _audioSubscriptions[speakerId] = StreamSubscription(timer);
      print('✅ Fallback audio capture started for: $speakerName');

    } catch (e) {
      print('❌ Error starting fallback capture: $e');
      throw e;
    }
  }

  /// Remove stream from capture
  Future<void> removeRemoteStream(String speakerId) async {
    try {
      final speakerName = _streamSpeakerNames[speakerId];
      print('🗑️ Removing audio capture for: $speakerName');

      // Cancel subscription
      final subscription = _audioSubscriptions.remove(speakerId);
      await subscription?.cancel();

      // Remove from Web Audio if applicable
      if (kIsWeb && _webAudioInterop.isInitialized) {
        await _webAudioInterop.stopCapture(speakerId);
      }

      _streamSpeakerNames.remove(speakerId);
      print('✅ Audio capture removed for: $speakerName');

    } catch (e) {
      print('❌ Error removing stream: $e');
      onError?.call('Failed to remove audio stream: $e');
    }
  }

  /// Stop all audio capture
  Future<void> stopCapture() async {
    try {
      print('🛑 Stopping all audio capture...');

      // Cancel all subscriptions
      for (final subscription in _audioSubscriptions.values) {
        await subscription.cancel();
      }
      _audioSubscriptions.clear();

      // Stop Web Audio capture
      if (kIsWeb && _webAudioInterop.isInitialized) {
        await _webAudioInterop.stopAllCapture();
      }

      _streamSpeakerNames.clear();
      print('✅ All audio capture stopped');

    } catch (e) {
      print('❌ Error stopping capture: $e');
      onError?.call('Failed to stop audio capture: $e');
    }
  }

  /// Clear all streams
  Future<void> clearAllStreams() async {
    await stopCapture();
  }

  /// Get audio statistics
  Future<Map<String, dynamic>> getAudioStats() async {
    final stats = <String, dynamic>{
      'isInitialized': _isInitialized,
      'activeStreams': _audioSubscriptions.length,
      'platform': kIsWeb ? 'web' : 'native',
      'webAudioEnabled': kIsWeb && _webAudioInterop.isInitialized,
      'speakers': _streamSpeakerNames.entries.map((entry) => {
        'id': entry.key,
        'name': entry.value,
      }).toList(),
    };

    // Add Web Audio stats if available
    if (kIsWeb && _webAudioInterop.isInitialized) {
      final webStats = await _webAudioInterop.getStats();
      if (webStats != null) {
        stats['webAudioStats'] = webStats;
      }
    }

    return stats;
  }

  /// Dispose the service
  void dispose() {
    print('🗑️ Disposing Enhanced Audio Capture Service...');

    stopCapture();
    _webAudioInterop.dispose();
    _isInitialized = false;
  }
}

/// Wrapper class for Timer to match StreamSubscription interface
class StreamSubscription {
  final Timer _timer;

  StreamSubscription(this._timer);

  Future<void> cancel() async {
    _timer.cancel();
  }
}