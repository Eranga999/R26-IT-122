import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_constants.dart';
import 'site_geofence.dart';

class SiteLockService {
  SiteLockService._();
  static final SiteLockService instance = SiteLockService._();
  static const MethodChannel _locationChannel =
      MethodChannel('com.example.r26_it_122/site_lock');

  List<SiteGeofence>? _cachedSites;

  Future<List<SiteGeofence>> loadSites() async {
    if (_cachedSites != null) {
      return _cachedSites!;
    }

    final raw =
        await rootBundle.loadString(AppConstants.landmarkSitesConfigPath);
    final data = jsonDecode(raw) as List<dynamic>;
    _cachedSites = data
        .map((item) => SiteGeofence.fromMap(item as Map<String, dynamic>))
        .toList();
    return _cachedSites!;
  }

  /// [requestPermission] — when false, skips the system permission dialog (used on
  /// app startup). Set true when the user explicitly taps "Verify Location".
  Future<SiteLockResult> lockSiteByGps({bool requestPermission = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const SiteLockResult(
          status: SiteLockStatus.serviceDisabled,
          message: 'Location services are turned off.',
          openSettings: true,
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        if (!requestPermission) {
          return const SiteLockResult(
            status: SiteLockStatus.permissionDenied,
            message: 'Tap Verify Location to allow GPS access.',
          );
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const SiteLockResult(
          status: SiteLockStatus.permissionDenied,
          message: 'Location permission denied. Tap Verify Location again or allow access in Settings.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const SiteLockResult(
          status: SiteLockStatus.permissionDenied,
          message:
              'Location permission blocked. Open Settings → HeritageAR → Permissions → Location → Allow.',
          openSettings: true,
        );
      }

      // 2. Attempt to get the current position with a longer timeout.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy
              .high, // Use .high for a balance of accuracy and power.
          timeLimit:
              const Duration(seconds: 28), // Increased timeout to 28 seconds.
        );
      } on TimeoutException {
        // 3. If getCurrentPosition times out, fall back to the last known position.
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          return const SiteLockResult(
            status: SiteLockStatus.timeout,
            message:
                'GPS signal is weak. Please move to an open area and try again.',
          );
        }
      }

      final sites = await loadSites();
      if (sites.isEmpty) {
        return const SiteLockResult(
          status: SiteLockStatus.error,
          message: 'No site geofences configured.',
        );
      }

      SiteGeofence? best;
      double? bestDistance;

      for (final site in sites) {
        final d = _haversineMeters(
          lat1: position.latitude,
          lon1: position.longitude,
          lat2: site.centerLat,
          lon2: site.centerLng,
        );

        // 4. Add GPS accuracy to the radius for a more lenient geofence check.
        final effectiveRadius = site.radiusMeters + position.accuracy;
        final withinGeofence = d <= effectiveRadius;

        if (!withinGeofence) {
          continue;
        }

        if (best == null ||
            d < (bestDistance ?? double.infinity) ||
            (d == bestDistance && site.priority > best.priority)) {
          best = site;
          bestDistance = d;
        }
      }

      if (best == null || bestDistance == null) {
        return SiteLockResult(
          status: SiteLockStatus.outOfRange,
          gpsAccuracyMeters: position.accuracy,
          message:
              'You are currently outside a supported heritage site. Please visit Sigiriya, Dambulla Cave Temple, or Polonnaruwa to use Heritage AR features.',
        );
      }

      // 5. The confidence score provides false-positive protection.
      final confidence = _siteConfidence(
        distanceMeters: bestDistance,
        radiusMeters: best.radiusMeters,
        gpsAccuracyMeters: position.accuracy ?? best.radiusMeters,
      );

      return SiteLockResult(
        status: SiteLockStatus.locked,
        site: best,
        distanceMeters: bestDistance,
        gpsAccuracyMeters: position.accuracy,
        confidenceScore: confidence,
      );
    } catch (e) {
      // 6. Catch any other unexpected errors during the process.
      return SiteLockResult(
        status: SiteLockStatus.error,
        message:
            'An unexpected error occurred while detecting your location: $e',
      );
    }
  }

  double _haversineMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusM = 6371000.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusM * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  double _siteConfidence({
    required double distanceMeters,
    required double radiusMeters,
    required double gpsAccuracyMeters,
  }) {
    final distanceRatio = (1 - (distanceMeters / radiusMeters)).clamp(0.0, 1.0);
    final accuracyPenalty = (gpsAccuracyMeters / 100.0).clamp(0.0, 0.3);
    final confidence = (0.7 + 0.3 * distanceRatio) - accuracyPenalty;
    return confidence.clamp(0.0, 0.99);
  }
}
