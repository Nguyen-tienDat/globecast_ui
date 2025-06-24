// android/app/src/main/java/com/example/globecast_ui/MainActivity.java
package com.example.globecast_ui;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import androidx.annotation.NonNull;

public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // 🎤 Register AudioCapturePlugin
        flutterEngine.getPlugins().add(new AudioCapturePlugin());
    }
}