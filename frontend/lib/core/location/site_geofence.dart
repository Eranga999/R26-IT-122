class SiteGeofence {
  const SiteGeofence({
    required this.landmarkId,
    required this.landmarkName,
    required this.landmarkDbId,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.priority = 1,
  });

  final String landmarkId;
  final String landmarkName;
  final int landmarkDbId;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final int priority;

  factory SiteGeofence.fromMap(Map<String, dynamic> map) {
    return SiteGeofence(
      landmarkId: map['landmark_id'] as String,
      landmarkName: map['landmark_name'] as String,
      landmarkDbId: map['landmark_db_id'] as int,
      centerLat: (map['center_lat'] as num).toDouble(),
      centerLng: (map['center_lng'] as num).toDouble(),
      radiusMeters: (map['radius_m'] as num).toDouble(),
      priority: (map['priority'] as num?)?.toInt() ?? 1,
    );
  }
}

enum SiteLockStatus {
  locked,
  outOfRange,
  permissionDenied,
  serviceDisabled,
  error,
}

class SiteLockResult {
  const SiteLockResult({
    required this.status,
    this.site,
    this.distanceMeters,
    this.gpsAccuracyMeters,
    this.confidenceScore,
    this.message,
    this.source = 'gps',
  });

  final SiteLockStatus status;
  final SiteGeofence? site;
  final double? distanceMeters;
  final double? gpsAccuracyMeters;
  final double? confidenceScore;
  final String? message;
  final String source;

  bool get isLocked => status == SiteLockStatus.locked && site != null;

  factory SiteLockResult.manual({
    required SiteGeofence site,
    String source = 'manual',
  }) {
    return SiteLockResult(
      status: SiteLockStatus.locked,
      site: site,
      distanceMeters: 0,
      gpsAccuracyMeters: 0,
      confidenceScore: 1.0,
      source: source,
    );
  }
}
