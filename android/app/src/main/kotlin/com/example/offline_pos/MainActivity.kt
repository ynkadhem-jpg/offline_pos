package com.example.offline_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var automaticBackupStorage: AutomaticBackupStorage
    private lateinit var deviceFingerprintBridge: DeviceFingerprintBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        automaticBackupStorage = AutomaticBackupStorage(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        deviceFingerprintBridge = DeviceFingerprintBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (::automaticBackupStorage.isInitialized &&
            automaticBackupStorage.onRequestPermissionsResult(requestCode, grantResults)
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        if (::automaticBackupStorage.isInitialized) {
            automaticBackupStorage.dispose()
        }
        if (::deviceFingerprintBridge.isInitialized) {
            deviceFingerprintBridge.dispose()
        }
        super.onDestroy()
    }
}
