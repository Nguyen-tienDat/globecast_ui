// android/app/src/main/java/com/example/globecast_ui/AudioCapturePlugin.java
package com.example.globecast_ui;

// 📱 ANDROID IMPORTS

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * 🎤 ANDROID NATIVE AUDIO CAPTURE PLUGIN
 *
 * Captures high-quality audio from microphone and streams to Flutter
 * Optimized for Google Cloud Speech-to-Text integration
 */
public class AudioCapturePlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private static final String TAG = "AudioCapturePlugin";

    // 🎯 AUDIO CONFIGURATION FOR GOOGLE CLOUD
    private static final int SAMPLE_RATE = 16000; // Google Cloud optimized
    private static final int CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO;
    private static final int AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;
    private static final int BUFFER_SIZE_FACTOR = 2;

    // 📱 PLUGIN CHANNELS
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private Context context;

    // 🎤 AUDIO RECORDING
    private AudioRecord audioRecord;
    private int bufferSize;
    private byte[] audioBuffer;
    private final AtomicBoolean isRecording = new AtomicBoolean(false);
    private final AtomicBoolean isPaused = new AtomicBoolean(false);

    // 🧵 THREADING
    private ExecutorService executorService;
    private Handler mainHandler;

    // 📊 METRICS
    private long totalBytesRecorded = 0;
    private long recordingStartTime = 0;

    // 🎯 FLUTTER PLUGIN LIFECYCLE
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.context = flutterPluginBinding.getApplicationContext();

        // Setup method channel for controls
        methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "audio_capture_plugin");
        methodChannel.setMethodCallHandler(this);

        // Setup event channel for audio stream
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "audio_capture_stream");
        eventChannel.setStreamHandler(this);

        // Initialize components
        mainHandler = new Handler(Looper.getMainLooper());
        executorService = Executors.newSingleThreadExecutor();

        Log.d(TAG, "🎤 AudioCapturePlugin attached");
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
            methodChannel = null;
        }

        if (eventChannel != null) {
            eventChannel.setStreamHandler(null);
            eventChannel = null;
        }

        stopRecording();

        if (executorService != null && !executorService.isShutdown()) {
            executorService.shutdown();
        }

        Log.d(TAG, "🧹 AudioCapturePlugin detached");
    }

    // 🎯 METHOD CHANNEL HANDLER
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "startRecording":
                handleStartRecording(result);
                break;

            case "stopRecording":
                handleStopRecording(result);
                break;

            case "pauseRecording":
                handlePauseRecording(result);
                break;

            case "resumeRecording":
                handleResumeRecording(result);
                break;

            case "getRecordingInfo":
                handleGetRecordingInfo(result);
                break;

            case "checkPermissions":
                handleCheckPermissions(result);
                break;

            default:
                result.notImplemented();
                break;
        }
    }

    // 🎯 EVENT CHANNEL HANDLER
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        this.eventSink = events;
        Log.d(TAG, "🎧 Audio stream listener attached");
    }

    @Override
    public void onCancel(Object arguments) {
        this.eventSink = null;
        stopRecording();
        Log.d(TAG, "🔇 Audio stream listener cancelled");
    }

    // 🎤 START RECORDING
    private void handleStartRecording(Result result) {
        if (isRecording.get()) {
            result.error("ALREADY_RECORDING", "Recording is already in progress", null);
            return;
        }

        // Check permissions first
        if (!hasAudioPermission()) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null);
            return;
        }

        try {
            // Calculate optimal buffer size
            int minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT);
            if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
                result.error("BUFFER_ERROR", "Cannot determine buffer size", null);
                return;
            }

            bufferSize = minBufferSize * BUFFER_SIZE_FACTOR;
            audioBuffer = new byte[bufferSize];

            Log.d(TAG, "🎤 Audio config:");
            Log.d(TAG, "   Sample Rate: " + SAMPLE_RATE + " Hz");
            Log.d(TAG, "   Buffer Size: " + bufferSize + " bytes");
            Log.d(TAG, "   Format: 16-bit PCM Mono");

            // Create AudioRecord instance
            audioRecord = new AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    SAMPLE_RATE,
                    CHANNEL_CONFIG,
                    AUDIO_FORMAT,
                    bufferSize
            );

            if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
                result.error("AUDIO_RECORD_ERROR", "Failed to initialize AudioRecord", null);
                return;
            }

            // Start recording
            audioRecord.startRecording();
            isRecording.set(true);
            isPaused.set(false);
            totalBytesRecorded = 0;
            recordingStartTime = System.currentTimeMillis();

            // Start capture thread
            executorService.execute(this::captureAudioLoop);

            result.success("Recording started successfully");
            Log.d(TAG, "✅ Audio recording started");

        } catch (SecurityException e) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", e.getMessage());
        } catch (Exception e) {
            result.error("START_ERROR", "Failed to start recording", e.getMessage());
        }
    }

    // 🛑 STOP RECORDING
    private void handleStopRecording(Result result) {
        try {
            stopRecording();
            result.success("Recording stopped successfully");
        } catch (Exception e) {
            result.error("STOP_ERROR", "Failed to stop recording", e.getMessage());
        }
    }

    // ⏸️ PAUSE RECORDING
    private void handlePauseRecording(Result result) {
        if (!isRecording.get()) {
            result.error("NOT_RECORDING", "No recording in progress", null);
            return;
        }

        isPaused.set(true);
        result.success("Recording paused");
        Log.d(TAG, "⏸️ Audio recording paused");
    }

    // ▶️ RESUME RECORDING
    private void handleResumeRecording(Result result) {
        if (!isRecording.get()) {
            result.error("NOT_RECORDING", "No recording in progress", null);
            return;
        }

        isPaused.set(false);
        result.success("Recording resumed");
        Log.d(TAG, "▶️ Audio recording resumed");
    }

    // 📊 GET RECORDING INFO
    private void handleGetRecordingInfo(Result result) {
        long duration = isRecording.get() ?
                System.currentTimeMillis() - recordingStartTime : 0;

        Map<String, Object> info = new HashMap<>();
        info.put("isRecording", isRecording.get());
        info.put("isPaused", isPaused.get());
        info.put("duration", duration);
        info.put("totalBytes", totalBytesRecorded);
        info.put("sampleRate", SAMPLE_RATE);
        info.put("bufferSize", bufferSize);

        result.success(info);
    }

    // 🔒 CHECK PERMISSIONS
    private void handleCheckPermissions(Result result) {
        boolean hasPermission = hasAudioPermission();
        result.success(hasPermission);
    }

    // 🔒 HELPER: Check audio permission
    private boolean hasAudioPermission() {
        if (context == null) {
            return false;
        }

        return ActivityCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED;
    }

    // 🎤 AUDIO CAPTURE LOOP (Core functionality)
    private void captureAudioLoop() {
        Log.d(TAG, "🎵 Audio capture loop started");

        while (isRecording.get()) {
            try {
                if (isPaused.get()) {
                    Thread.sleep(100); // Check every 100ms while paused
                    continue;
                }

                // Read audio data
                int bytesRead = audioRecord.read(audioBuffer, 0, bufferSize);

                if (bytesRead > 0) {
                    totalBytesRecorded += bytesRead;

                    // Prepare data for Flutter
                    byte[] audioChunk = new byte[bytesRead];
                    System.arraycopy(audioBuffer, 0, audioChunk, 0, bytesRead);

                    // Send to Flutter via EventSink
                    sendAudioDataToFlutter(audioChunk);

                    // Debug log (reduce frequency for performance)
                    if (totalBytesRecorded % (SAMPLE_RATE * 2) == 0) { // Every ~1 second
                        Log.d(TAG, "📊 Audio captured: " + totalBytesRecorded + " bytes");
                    }

                } else if (bytesRead == AudioRecord.ERROR_INVALID_OPERATION) {
                    Log.e(TAG, "❌ AudioRecord invalid operation");
                    break;
                } else if (bytesRead == AudioRecord.ERROR_BAD_VALUE) {
                    Log.e(TAG, "❌ AudioRecord bad value");
                    break;
                }

            } catch (InterruptedException e) {
                Log.d(TAG, "🛑 Audio capture interrupted");
                break;
            } catch (Exception e) {
                Log.e(TAG, "❌ Error in audio capture: " + e.getMessage());
                sendErrorToFlutter("CAPTURE_ERROR", e.getMessage());
                break;
            }
        }

        Log.d(TAG, "🏁 Audio capture loop ended");
    }

    // 📡 SEND AUDIO DATA TO FLUTTER
    private void sendAudioDataToFlutter(byte[] audioData) {
        if (eventSink != null) {
            mainHandler.post(() -> {
                try {
                    // Create data package for Flutter
                    Map<String, Object> audioPacket = new HashMap<>();
                    audioPacket.put("type", "audio_data");
                    audioPacket.put("data", Base64.encodeToString(audioData, Base64.NO_WRAP));
                    audioPacket.put("length", audioData.length);
                    audioPacket.put("timestamp", System.currentTimeMillis());
                    audioPacket.put("sampleRate", SAMPLE_RATE);

                    eventSink.success(audioPacket);
                } catch (Exception e) {
                    Log.e(TAG, "❌ Error sending audio to Flutter: " + e.getMessage());
                }
            });
        }
    }

    // 🚨 SEND ERROR TO FLUTTER
    private void sendErrorToFlutter(String errorCode, String errorMessage) {
        if (eventSink != null) {
            mainHandler.post(() -> {
                Map<String, Object> errorPacket = new HashMap<>();
                errorPacket.put("type", "error");
                errorPacket.put("errorCode", errorCode);
                errorPacket.put("errorMessage", errorMessage);

                eventSink.error(errorCode, errorMessage, null);
            });
        }
    }

    // 🧹 CLEANUP RECORDING RESOURCES
    private void stopRecording() {
        isRecording.set(false);
        isPaused.set(false);

        if (audioRecord != null) {
            try {
                if (audioRecord.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) {
                    audioRecord.stop();
                }
                audioRecord.release();
            } catch (Exception e) {
                Log.e(TAG, "⚠️ Error stopping AudioRecord: " + e.getMessage());
            } finally {
                audioRecord = null;
            }
        }

        // Send final status to Flutter
        if (eventSink != null) {
            mainHandler.post(() -> {
                Map<String, Object> statusPacket = new HashMap<>();
                statusPacket.put("type", "recording_stopped");
                statusPacket.put("totalBytes", totalBytesRecorded);
                statusPacket.put("duration", System.currentTimeMillis() - recordingStartTime);

                eventSink.success(statusPacket);
            });
        }

        Log.d(TAG, "🧹 Audio recording resources cleaned up");
    }

    // 🎯 UTILITY METHODS

    /**
     * Get optimal audio configuration for Google Cloud Speech
     */
    public static Map<String, Object> getGoogleCloudAudioConfig() {
        Map<String, Object> config = new HashMap<>();
        config.put("encoding", "LINEAR16");
        config.put("sampleRateHertz", SAMPLE_RATE);
        config.put("languageCode", "en-US"); // Default, can be overridden
        config.put("audioChannelCount", 1);
        config.put("enableAutomaticPunctuation", true);
        config.put("model", "latest_long");

        return config;
    }

    /**
     * Convert PCM bytes to format suitable for Google Cloud
     */
    public static byte[] preparePCMForGoogleCloud(byte[] pcmData) {
        // For LINEAR16 encoding, data is already in correct format
        // Just ensure proper endianness if needed
        return pcmData;
    }

    /**
     * Calculate audio duration from byte array
     */
    public static long calculateDurationMs(int byteLength) {
        // 16-bit mono: 2 bytes per sample
        int samples = byteLength / 2;
        return (samples * 1000L) / SAMPLE_RATE;
    }
}