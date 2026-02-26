package com.example.heritage_ar

import android.os.Build
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.heritage_ar/ar_check"

    // Tracks whether we have already asked to install ARCore this session.
    private var requestedArCoreInstall = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkArSupport" -> {
                        val availability = arCoreAvailability()
                        val arCoreInstalled = availability.isSupported
                        val canInstall = availability == ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED
                                || availability == ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD
                        val is64bit = is64BitDevice()
                        val isEmulator = isRunningOnEmulator()
                        result.success(
                            mapOf(
                                "arCoreInstalled" to arCoreInstalled,
                                "canInstall" to canInstall,
                                "is64bit" to is64bit,
                                "isEmulator" to isEmulator,
                                "supported" to (arCoreInstalled && is64bit),
                                "availabilityName" to availability.name
                            )
                        )
                    }
                    "requestArCoreInstall" -> {
                        // Triggers the Google Play in-app install dialog for ARCore.
                        try {
                            val installStatus = ArCoreApk.getInstance()
                                .requestInstall(this, !requestedArCoreInstall)
                            requestedArCoreInstall = true
                            result.success(installStatus.name) // "INSTALL_REQUESTED" or "INSTALLED"
                        } catch (e: Exception) {
                            result.error("AR_INSTALL_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun arCoreAvailability(): ArCoreApk.Availability {
        return try {
            ArCoreApk.getInstance().checkAvailability(this)
        } catch (e: Exception) {
            ArCoreApk.Availability.UNKNOWN_ERROR
        }
    }

    private fun is64BitDevice(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Build.SUPPORTED_ABIS.any { it.contains("arm64") || it.contains("x86_64") }
        } else {
            false
        }
    }

    private fun isRunningOnEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.PRODUCT.startsWith("sdk")
                || Build.HARDWARE.contains("ranchu")
                || Build.HARDWARE.contains("goldfish"))
    }
}
