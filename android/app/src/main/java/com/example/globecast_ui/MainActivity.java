// android/app/src/main/java/com/example/globecast_ui/MainActivity.java
package com.example.globecast_ui;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class MainActivity extends FlutterActivity {
    private static final int PERMISSION_REQUEST_CODE = 1001;

    private static final String[] REQUIRED_PERMISSIONS = {
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.CAMERA,
            Manifest.permission.MODIFY_AUDIO_SETTINGS
    };

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // TODO: Register the audio capture plugin when it's ready
        // flutterEngine.getPlugins().add(new AudioCapturePlugin());
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Check and request permissions
        checkPermissions();
    }

    /// 🔒 Check all required permissions
    private void checkPermissions() {
        List<String> missingPermissions = new ArrayList<>();

        for (String permission : REQUIRED_PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(this, permission)
                    != PackageManager.PERMISSION_GRANTED) {
                missingPermissions.add(permission);
            }
        }

        if (!missingPermissions.isEmpty()) {
            requestMissingPermissions(missingPermissions.toArray(new String[0]));
        }
    }

    /// 📋 Request missing permissions
    private void requestMissingPermissions(String[] permissions) {
        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE);
    }

    /// 📋 Handle permission request results
    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode == PERMISSION_REQUEST_CODE) {
            List<String> deniedPermissions = new ArrayList<>();

            for (int i = 0; i < permissions.length; i++) {
                if (grantResults[i] != PackageManager.PERMISSION_GRANTED) {
                    deniedPermissions.add(permissions[i]);
                }
            }

            if (deniedPermissions.isEmpty()) {
                // All permissions granted
                onAllPermissionsGranted();
            } else {
                // Some permissions denied
                onPermissionsDenied(deniedPermissions);
            }
        }
    }

    /// ✅ Handle all permissions granted
    private void onAllPermissionsGranted() {
        // Notify Flutter that permissions are ready
        System.out.println("✅ All permissions granted");
    }

    /// ❌ Handle permissions denied
    private void onPermissionsDenied(List<String> deniedPermissions) {
        // Handle denied permissions
        List<String> criticalPermissions = new ArrayList<>();

        for (String permission : deniedPermissions) {
            if (permission.equals(Manifest.permission.RECORD_AUDIO) ||
                    permission.equals(Manifest.permission.CAMERA)) {
                criticalPermissions.add(permission);
            }
        }

        if (!criticalPermissions.isEmpty()) {
            // Show explanation dialog or disable features
            System.out.println("❌ Critical permissions denied: " + criticalPermissions);
        }
    }

    /// 🔒 Check if specific permission is granted
    public boolean isPermissionGranted(String permission) {
        return ContextCompat.checkSelfPermission(this, permission)
                == PackageManager.PERMISSION_GRANTED;
    }

    /// 🔒 Check if all permissions are granted
    public boolean areAllPermissionsGranted() {
        for (String permission : REQUIRED_PERMISSIONS) {
            if (!isPermissionGranted(permission)) {
                return false;
            }
        }
        return true;
    }

    /// 📋 Get missing permissions
    public List<String> getMissingPermissions() {
        List<String> missing = new ArrayList<>();

        for (String permission : REQUIRED_PERMISSIONS) {
            if (!isPermissionGranted(permission)) {
                missing.add(permission);
            }
        }

        return missing;
    }
}