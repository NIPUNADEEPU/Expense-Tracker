package com.tracker.expense_tracker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.tracker.expense_tracker/sms_import"
    private val permissionRequestCode = 7031
    private var enableResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(
                        getSharedPreferences("sms_import", MODE_PRIVATE)
                            .getBoolean("enabled", false)
                    )
                    "enable" -> enableSmsImport(result)
                    "disable" -> {
                        getSharedPreferences("sms_import", MODE_PRIVATE)
                            .edit().putBoolean("enabled", false).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableSmsImport(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            getSharedPreferences("sms_import", MODE_PRIVATE)
                .edit().putBoolean("enabled", true).apply()
            result.success(true)
            return
        }
        if (enableResult != null) {
            result.error("REQUEST_IN_PROGRESS", "SMS permission request is already active", null)
            return
        }
        enableResult = result
        requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), permissionRequestCode)
    }

    @Deprecated("Deprecated in Android")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        if (granted) {
            getSharedPreferences("sms_import", MODE_PRIVATE)
                .edit().putBoolean("enabled", true).apply()
        }
        enableResult?.success(granted)
        enableResult = null
    }
}
