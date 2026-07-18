import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<SiteLockResult> lockSiteByGps() async {
    try {
      final isEmulator =
          await _locationChannel.invokeMethod<bool>('isEmulator') ?? false;
      if (isEmulator) {
        return const SiteLockResult(
          status: SiteLockStatus.serviceDisabled,
          message: 'GPS site lock is unavailable on the emulator.',
        );
      }

      final serviceEnabled = await _locationChannel
              .invokeMethod<bool>('isLocationServiceEnabled') ??
          false;
      if (!serviceEnabled) {
        return const SiteLockResult(
          status: SiteLockStatus.serviceDisabled,
          message: 'Location services are turned off.',
        );
      }

      var permission = await Permission.location.status;
      if (permission.isDenied) {
        permission = await Permission.location.request();
      }

      if (permission.isDenied || permission.isPermanentlyDenied) {
        return const SiteLockResult(
          status: SiteLockStatus.permissionDenied,
          message: 'Location permission denied.',
        );
      }

      final rawPosition =
          await _locationChannel.invokeMapMethod<String, Object?>(
        'getCurrentLocation',
      );
      final latitude = rawPosition?['latitude'] as num?;
      final longitude = rawPosition?['longitude'] as num?;
      final accuracy = rawPosition?['accuracy'] as num?;
      final error = rawPosition?['error'] as String?;

      if (error != null || latitude == null || longitude == null) {
        return SiteLockResult(
          status: SiteLockStatus.error,
          message: error ?? 'Unable to determine current location.',
        );
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
          lat1: latitude.toDouble(),
          lon1: longitude.toDouble(),
          lat2: site.centerLat,
          lon2: site.centerLng,
        );

        final withinGeofence = d <= site.radiusMeters;
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
          gpsAccuracyMeters: accuracy?.toDouble(),
          message: 'You are outside configured heritage site zones.',
        );
      }

      final confidence = _siteConfidence(
        distanceMeters: bestDistance,
        radiusMeters: best.radiusMeters,
        gpsAccuracyMeters: accuracy?.toDouble() ?? best.radiusMeters,
      );

      return SiteLockResult(
        status: SiteLockStatus.locked,
        site: best,
        distanceMeters: bestDistance,
        gpsAccuracyMeters: accuracy?.toDouble(),
        confidenceScore: confidence,
      );
    } catch (e) {
      return SiteLockResult(
        status: SiteLockStatus.error,
        message: 'Failed to detect site by GPS: $e',
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
