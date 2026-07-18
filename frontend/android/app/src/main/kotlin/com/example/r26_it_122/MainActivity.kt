package com.example.r26_it_122

import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.r26_it_122/ar_check"
    private val LOCATION_CHANNEL = "com.example.r26_it_122/site_lock"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEmulator" -> {
                        result.success(isRunningOnEmulator())
                    }
                    "isLocationServiceEnabled" -> {
                        result.success(isLocationServiceEnabled())
                    }
                    "getCurrentLocation" -> {
                        val location = getCurrentLocation()
                        if (location != null) {
                            result.success(
                                mapOf(
                                    "latitude" to location.latitude,
                                    "longitude" to location.longitude,
                                    "accuracy" to location.accuracy,
                                )
                            )
                        } else {
                            result.success(
                                mapOf<String, Any?>(
                                    "error" to "Unable to determine current location."
                                )
                            )
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

    private fun isLocationServiceEnabled(): Boolean {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return try {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) {
            false
        }
    }

    private fun getCurrentLocation(): Location? {
        if (!hasLocationPermission()) return null

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val candidates = listOfNotNull(
            runCatching { locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER) }.getOrNull(),
            runCatching { locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER) }.getOrNull()
        )
        return candidates.maxByOrNull { it.time }
    }

    private fun hasLocationPermission(): Boolean {
        val fineGranted = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        val coarseGranted = checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        return fineGranted || coarseGranted
    }
}
