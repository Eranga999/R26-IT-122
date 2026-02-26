import 'dart:io';
import 'package:flutter/services.dart';

/// Checks whether the current device supports ARCore (Android) and can
/// request an in-app install via Google Play.
class ArAvailability {
  static const _channel = MethodChannel('com.example.heritage_ar/ar_check');

  static Future<ArStatus> check() async {
    if (!Platform.isAndroid) {
      return const ArStatus(
        arCoreInstalled: false,
        canInstall: false,
        is64bit: false,
        isEmulator: false,
        supported: false,
      );
    }
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('checkArSupport');
      final arCoreInstalled = raw?['arCoreInstalled'] as bool? ?? false;
      final canInstall = raw?['canInstall'] as bool? ?? false;
      final is64bit = raw?['is64bit'] as bool? ?? false;
      final isEmulator = raw?['isEmulator'] as bool? ?? false;
      final supported = raw?['supported'] as bool? ?? false;
      return ArStatus(
        arCoreInstalled: arCoreInstalled,
        canInstall: canInstall,
        is64bit: is64bit,
        isEmulator: isEmulator,
        supported: supported,
      );
    } catch (_) {
      return const ArStatus(
        arCoreInstalled: false,
        canInstall: false,
        is64bit: false,
        isEmulator: false,
        supported: false,
      );
    }
  }

  /// Triggers the Google Play in-app install dialog for ARCore.
  /// Returns true if the install was requested, false if already installed.
  static Future<bool> requestInstall() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _channel.invokeMethod<String>('requestArCoreInstall');
      return result == 'INSTALL_REQUESTED';
    } catch (_) {
      return false;
    }
  }
}

class ArStatus {
  final bool arCoreInstalled;

  /// True when ARCore is supported on the device but just not installed yet.
  final bool canInstall;
  final bool is64bit;
  final bool isEmulator;
  final bool supported;

  const ArStatus({
    required this.arCoreInstalled,
    required this.canInstall,
    required this.is64bit,
    required this.isEmulator,
    required this.supported,
  });

  /// Human-readable reason why AR is not supported.
  String? get reason {
    if (supported) return null;
    if (canInstall) {
      return 'ARCore is not installed. Tap the button below to install it from Google Play.';
    }
    if (isEmulator && !arCoreInstalled) {
      return 'Running on an emulator.\n'
          'Use an x86_64 Google APIs emulator image and install '
          'ARCore via the button below, or test on a physical device.';
    }
    if (!is64bit) {
      return '32-bit device – ARCore requires a 64-bit (arm64-v8a) CPU.';
    }
    if (!arCoreInstalled) {
      return 'ARCore service is not installed on this device.';
    }
    return 'AR is not supported on this device.';
  }
}
