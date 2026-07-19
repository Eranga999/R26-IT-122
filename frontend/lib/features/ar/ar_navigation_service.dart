import 'dart:math' as math;

// ── Waypoint Model ─────────────────────────────────────────────────────────────

class ArNavigationWaypoint {
  final String title;
  final String description;
  final String instruction;
  final double latitude;
  final double longitude;
  final double arrivalRadiusMeters;
  final bool requiresDetection;
  final String? detectionLabel; // YOLO label required (null if path-only)

  const ArNavigationWaypoint({
    required this.title,
    required this.description,
    required this.instruction,
    required this.latitude,
    required this.longitude,
    required this.arrivalRadiusMeters,
    required this.requiresDetection,
    this.detectionLabel,
  });
}

// ── AR Visual Components ───────────────────────────────────────────────────────

class ArFootstep {
  final double distanceMeters;
  final double relativeAngleDeg;
  const ArFootstep({required this.distanceMeters, required this.relativeAngleDeg});
}

// ── Navigation Snapshot (emitted per update) ───────────────────────────────────

enum ArGpsStatus { live, stale, degraded, unavailable }

class ArNavigationSnapshot {
  final int waypointIndex;      // 0-based current waypoint index
  final int totalWaypoints;
  final String waypointTitle;
  final String instruction;
  final double distanceMeters;
  final double relativeAngleDeg; // smoothed, −180..+180
  final bool hasGpsFix;
  final bool hasCompassFix;
  final bool hasArrived;
  final bool routeComplete;
  final String? detectionGuidance; // shown when waiting for YOLO
  final bool detectionConfirmed;   // true when centered + confident
  final bool justArrivedFlash;
  final ArGpsStatus gpsStatus;
  final List<ArFootstep> footsteps;

  const ArNavigationSnapshot({
    required this.waypointIndex,
    required this.totalWaypoints,
    required this.waypointTitle,
    required this.instruction,
    required this.distanceMeters,
    required this.relativeAngleDeg,
    required this.hasGpsFix,
    required this.hasCompassFix,
    required this.hasArrived,
    required this.routeComplete,
    this.detectionGuidance,
    required this.detectionConfirmed,
    this.justArrivedFlash = false,
    this.gpsStatus = ArGpsStatus.unavailable,
    this.footsteps = const [],
  });

  ArNavigationSnapshot copyWith({
    int? waypointIndex,
    int? totalWaypoints,
    String? waypointTitle,
    String? instruction,
    double? distanceMeters,
    double? relativeAngleDeg,
    bool? hasGpsFix,
    bool? hasCompassFix,
    bool? hasArrived,
    bool? routeComplete,
    String? detectionGuidance,
    bool? detectionConfirmed,
    bool? justArrivedFlash,
    ArGpsStatus? gpsStatus,
    List<ArFootstep>? footsteps,
  }) {
    return ArNavigationSnapshot(
      waypointIndex: waypointIndex ?? this.waypointIndex,
      totalWaypoints: totalWaypoints ?? this.totalWaypoints,
      waypointTitle: waypointTitle ?? this.waypointTitle,
      instruction: instruction ?? this.instruction,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      relativeAngleDeg: relativeAngleDeg ?? this.relativeAngleDeg,
      hasGpsFix: hasGpsFix ?? this.hasGpsFix,
      hasCompassFix: hasCompassFix ?? this.hasCompassFix,
      hasArrived: hasArrived ?? this.hasArrived,
      routeComplete: routeComplete ?? this.routeComplete,
      detectionGuidance: detectionGuidance ?? this.detectionGuidance,
      detectionConfirmed: detectionConfirmed ?? this.detectionConfirmed,
      justArrivedFlash: justArrivedFlash ?? this.justArrivedFlash,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      footsteps: footsteps ?? this.footsteps,
    );
  }
}

// ── Navigation Service ─────────────────────────────────────────────────────────

class ArNavigationService {
  final double detectionThreshold;
  final double centerTolerance;
  final int gpsStaleTimeoutMs;
  final int gpsDegradedTimeoutMs;

  ArNavigationService({
    this.detectionThreshold = 0.70,
    this.centerTolerance = 0.22,
    this.gpsStaleTimeoutMs = 30000,
    this.gpsDegradedTimeoutMs = 60000,
  });
  // ── Sigiriya Waypoints ────────────────────────────────────────────────────
  // Coordinates: verified from satellite imagery; refine on-site for best accuracy.
  static const List<ArNavigationWaypoint> sigiriyaRoute = [
    ArNavigationWaypoint(
      title: 'Ticket Counter',
      description: 'Purchase your entry ticket at the main ticket counter.',
      instruction: 'Head to the ticket counter to begin the Sigiriya tour.',
      latitude: 7.9547,
      longitude: 80.7554,
      arrivalRadiusMeters: 25,
      requiresDetection: true,
      detectionLabel: 'sigiriya_ticket_counter',
    ),
    ArNavigationWaypoint(
      title: 'Main Path Entrance',
      description: 'The main pathway leading from the ticket area into the gardens.',
      instruction: 'Walk through the entrance gate and follow the main path.',
      latitude: 7.9555,
      longitude: 80.7561,
      arrivalRadiusMeters: 30,
      requiresDetection: false,
    ),
    ArNavigationWaypoint(
      title: 'Lion Rock View Direction',
      description: 'First clear viewpoint of Lion Rock from below.',
      instruction: 'Walk toward Lion Rock — keep it in front of you.',
      latitude: 7.9562,
      longitude: 80.7572,
      arrivalRadiusMeters: 35,
      requiresDetection: true,
      detectionLabel: 'sigiriya_lion_rock',
    ),
    ArNavigationWaypoint(
      title: 'Lion Paws',
      description: 'The colossal lion paw carvings at the base of Lion Rock.',
      instruction: 'Approach the giant lion paw carvings and keep them centered.',
      latitude: 7.9576,
      longitude: 80.7599,
      arrivalRadiusMeters: 20,
      requiresDetection: true,
      detectionLabel: 'sigiriya_lion_paws',
    ),
    ArNavigationWaypoint(
      title: 'Throne',
      description: 'The royal throne carved into the summit rock face.',
      instruction: 'Locate the royal stone throne and center it in the viewfinder.',
      latitude: 7.9578,
      longitude: 80.7601,
      arrivalRadiusMeters: 20,
      requiresDetection: true,
      detectionLabel: 'sigiriya_throne',
    ),
    ArNavigationWaypoint(
      title: 'Mirror Wall',
      description: 'The ancient polished plaster wall with 8th-century graffiti.',
      instruction: 'Find the Mirror Wall and center it to complete the tour.',
      latitude: 7.9571,
      longitude: 80.7605,
      arrivalRadiusMeters: 20,
      requiresDetection: true,
      detectionLabel: 'sigiriya_mirror_wall',
    ),
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  int _currentIndex = 0;
  double? _deviceLat;
  double? _deviceLon;
  double? _headingDeg;      // degrees from true north
  bool _compassReady = false;
  int _lastGpsUpdateMs = 0;     // epoch ms of last GPS update
  bool _gpsLive = true;         // false when GPS stream lost / timed out

  // Arrived / completion
  bool _detectionConfirmed = false;
  bool _routeComplete = false;
  
  // Arrow smoothing
  double? _smoothedAngle;
  static const double _smoothingAlpha = 0.25; // weight of new angle

  // Current detection state fed from camera
  String? _lastDetectedLabel;
  double _lastDetectedConfidence = 0.0;
  double? _lastBboxCenterX;  // normalised 0..1
  double? _lastBboxCenterY;

  List<ArNavigationWaypoint> get route => sigiriyaRoute;
  ArNavigationWaypoint get current => sigiriyaRoute[_currentIndex];
  bool get routeComplete => _routeComplete;

  /// Returns the current multi-stage status of the GPS signal.
  ArGpsStatus get _currentGpsStatus {
    if (_deviceLat == null || _deviceLon == null) return ArGpsStatus.unavailable;
    if (_gpsLive) return ArGpsStatus.live;
    if (_lastGpsUpdateMs == 0) return ArGpsStatus.unavailable;
    
    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastGpsUpdateMs;
    if (elapsed <= gpsStaleTimeoutMs) return ArGpsStatus.stale;
    if (elapsed <= gpsDegradedTimeoutMs) return ArGpsStatus.degraded;
    
    return ArGpsStatus.unavailable;
  }

  // ── GPS update ────────────────────────────────────────────────────────────
  ArNavigationSnapshot onGpsUpdate(double lat, double lon) {
    _deviceLat = lat;
    _deviceLon = lon;
    _gpsLive = true;
    _lastGpsUpdateMs = DateTime.now().millisecondsSinceEpoch;
    return _compute();
  }

  /// Called by the view when the GPS stream errors out or is explicitly lost.
  void onGpsLost() {
    _gpsLive = false;
  }

  // ── Heading update ────────────────────────────────────────────────────────
  ArNavigationSnapshot onHeadingUpdate(double headingDeg) {
    _headingDeg = headingDeg;
    _compassReady = headingDeg.isFinite;
    return _compute();
  }

  // ── Detection update ──────────────────────────────────────────────────────
  /// Pass each YOLO frame's best detection (or nulls if nothing detected).
  ArNavigationSnapshot onDetectionUpdate({
    required String? label,
    required double confidence,
    required double? bboxCenterX, // normalised 0..1, null if no detection
    required double? bboxCenterY,
  }) {
    _lastDetectedLabel = label;
    _lastDetectedConfidence = confidence;
    _lastBboxCenterX = bboxCenterX;
    _lastBboxCenterY = bboxCenterY;

    // ── YOLO Relocalization (Optical Anchor) ────────────────────────────────
    // If we confidently detect a known landmark and our GPS is currently stale 
    // or degraded, we instantly snap our coordinates to the landmark's location,
    // essentially getting a perfect fix without satellites!
    if (label != null && confidence >= 0.85 && _deviceLat != null && _deviceLon != null) {
      try {
        final matchedWp = sigiriyaRoute.firstWhere(
            (wp) => wp.detectionLabel != null && wp.detectionLabel == label);
            
        final status = _currentGpsStatus;
        if (status == ArGpsStatus.stale || status == ArGpsStatus.degraded) {
           _deviceLat = matchedWp.latitude;
           _deviceLon = matchedWp.longitude;
           // Reset tracking timer so we enter 'live' status again optically
           _lastGpsUpdateMs = DateTime.now().millisecondsSinceEpoch;
           _gpsLive = true;
        }
      } catch (e) {
        // Label not in route, ignore
      }
    }

    return _compute();
  }

  // ── Core computation ──────────────────────────────────────────────────────
  ArNavigationSnapshot _compute() {
    if (_routeComplete) {
      return ArNavigationSnapshot(
        waypointIndex: _currentIndex,
        totalWaypoints: sigiriyaRoute.length,
        waypointTitle: 'Tour Complete!',
        instruction: 'You have completed the Sigiriya AR Navigation route.',
        distanceMeters: 0,
        relativeAngleDeg: 0,
        hasGpsFix: _gpsLive,
        hasCompassFix: _compassReady,
        hasArrived: false,
        routeComplete: true,
        detectionGuidance: null,
        detectionConfirmed: false,
        justArrivedFlash: false,
        gpsStatus: _currentGpsStatus,
        footsteps: const [],
      );
    }

    final wp = current;

    final gpsStatus = _currentGpsStatus;

    // No GPS data available at all (never received a fix or timed out completely).
    if (gpsStatus == ArGpsStatus.unavailable) {
      return ArNavigationSnapshot(
        waypointIndex: _currentIndex,
        totalWaypoints: sigiriyaRoute.length,
        waypointTitle: wp.title,
        instruction: 'Waiting for GPS signal…',
        distanceMeters: 0,
        relativeAngleDeg: 0,
        hasGpsFix: false,
        hasCompassFix: _compassReady,
        hasArrived: false,
        routeComplete: false,
        detectionGuidance: null,
        detectionConfirmed: false,
        justArrivedFlash: false,
        gpsStatus: gpsStatus,
        footsteps: const [],
      );
    }

    // Distance — computed from live or last-known GPS position.
    final dist = _haversineMeters(_deviceLat!, _deviceLon!, wp.latitude, wp.longitude);

    // Bearing & relative angle — compass gates only the arrow rotation, not arrival.
    double relAngle = _smoothedAngle ?? 0.0; // keep last known if no compass
    if (_compassReady && _deviceLat != null && _deviceLon != null && _headingDeg != null) {
      final bearing = _bearing(_deviceLat!, _deviceLon!, wp.latitude, wp.longitude);
      relAngle = _normalizeAngle(bearing - _headingDeg!);
      // Smooth the angle (handle 179→-179 wrap-around)
      if (_smoothedAngle == null) {
        _smoothedAngle = relAngle;
      } else {
        final diff = _normalizeAngle(relAngle - _smoothedAngle!);
        _smoothedAngle = _normalizeAngle(
            _smoothedAngle! * (1 - _smoothingAlpha) +
                (_smoothedAngle! + diff) * _smoothingAlpha);
      }
      relAngle = _smoothedAngle!;
    }

    // ── Footstep Generation ────────────────────────────────────────────────
    // Generate virtual breadcrumbs along the bearing to the current waypoint.
    // They are placed every 5 meters between the user and the waypoint.
    List<ArFootstep> steps = [];
    if (dist.isFinite && dist > 5.0) {
      for (double d = 5.0; d < dist; d += 5.0) {
        // Stop generating steps if there are too many (e.g., max 10 steps visible at once)
        if (steps.length >= 10) break;
        steps.add(ArFootstep(distanceMeters: d, relativeAngleDeg: relAngle));
      }
    }

    // ── Arrival logic — compass NOT required ───────────────────────────────
    final bool withinRadius = dist.isFinite && dist <= wp.arrivalRadiusMeters;

    if (_detectionConfirmed && withinRadius && wp.requiresDetection) {
      _advance();
      return _buildArrived(wp.title, dist, gpsStatus);
    }

    if (withinRadius && !wp.requiresDetection) {
      _advance();
      return _buildArrived(wp.title, dist, gpsStatus);
    }

    // ── Detection guidance ─────────────────────────────────────────────────
    String? detGuidance;
    _detectionConfirmed = false;

    if (wp.requiresDetection) {
      if (withinRadius) {
        final labelMatch = _lastDetectedLabel != null &&
            _lastDetectedLabel!.toLowerCase().trim() ==
                wp.detectionLabel!.toLowerCase().trim();
        final confOk = _lastDetectedConfidence >= detectionThreshold;
        final hasBbox = _lastBboxCenterX != null && _lastBboxCenterY != null;

        if (labelMatch && confOk && hasBbox) {
          final dx = (_lastBboxCenterX! - 0.5).abs();
          final dy = (_lastBboxCenterY! - 0.5).abs();
          final centered = dx <= centerTolerance && dy <= centerTolerance;

          if (centered) {
            _detectionConfirmed = true;
            detGuidance = '✅ Target centered and locked';
            _advance();
            return _buildArrived(wp.title, dist, gpsStatus);
          } else {
            detGuidance = '🎯 Target detected — center it in the viewfinder';
          }
        } else {
          detGuidance = '🔍 Scanning for ${_labelDisplay(wp.detectionLabel!)}';
        }
      } else {
        detGuidance = '🔍 Scanning for ${_labelDisplay(wp.detectionLabel!)}';
      }
    } else {
      detGuidance = '🧭 Follow the waypoint direction';
    }

    // Compass calibration notice — only when far from waypoint (not already arrived).
    String instructionText = (!_compassReady && !withinRadius)
        ? 'Waiting for compass calibration…'
        : wp.instruction;

    if (gpsStatus == ArGpsStatus.stale) {
      instructionText = 'GPS signal lost. Using last known location.';
    } else if (gpsStatus == ArGpsStatus.degraded) {
      instructionText = 'GPS accuracy reduced. Waiting for GPS signal.';
    }

    return ArNavigationSnapshot(
      waypointIndex: _currentIndex,
      totalWaypoints: sigiriyaRoute.length,
      waypointTitle: wp.title,
      instruction: instructionText,
      distanceMeters: dist.isInfinite ? 0 : dist,
      relativeAngleDeg: relAngle,
      hasGpsFix: _gpsLive,
      hasCompassFix: _compassReady,
      hasArrived: false,
      routeComplete: false,
      detectionGuidance: detGuidance,
      detectionConfirmed: _detectionConfirmed,
      justArrivedFlash: false,
      gpsStatus: gpsStatus,
      footsteps: steps,
    );
  }

  // ── Advance to next waypoint ───────────────────────────────────────────────
  void _advance() {
    _currentIndex++;
    _detectionConfirmed = false;
    _lastDetectedLabel = null;
    _lastBboxCenterX = null;
    _lastBboxCenterY = null;
    _smoothedAngle = null; // reset arrow for new target
    if (_currentIndex >= sigiriyaRoute.length) {
      _routeComplete = true;
    }
  }

  ArNavigationSnapshot _buildArrived(String title, double dist, ArGpsStatus gpsStatus) {
    if (_routeComplete) {
      return ArNavigationSnapshot(
        waypointIndex: _currentIndex,
        totalWaypoints: sigiriyaRoute.length,
        waypointTitle: 'Tour Complete!',
        instruction: 'You have completed the full Sigiriya AR tour.',
        distanceMeters: 0,
        relativeAngleDeg: 0,
        hasGpsFix: _gpsLive,
        hasCompassFix: _compassReady,
        hasArrived: true,
        routeComplete: true,
        detectionGuidance: null,
        detectionConfirmed: true,
        justArrivedFlash: true,
        gpsStatus: gpsStatus,
        footsteps: const [],
      );
    }
    return ArNavigationSnapshot(
      waypointIndex: _currentIndex - 1,
      totalWaypoints: sigiriyaRoute.length,
      waypointTitle: '✅ Arrived at $title',
      instruction: 'Continuing to next waypoint…',
      distanceMeters: 0,
      relativeAngleDeg: 0,
      hasGpsFix: _gpsLive,
      hasCompassFix: _compassReady,
      hasArrived: true,
      routeComplete: false,
      detectionGuidance: null,
      detectionConfirmed: true,
      justArrivedFlash: true,
      gpsStatus: gpsStatus,
      footsteps: const [],
    );
  }

  // ── Math helpers ───────────────────────────────────────────────────────────

  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Returns initial bearing from point 1 → point 2 in degrees [0, 360).
  static double _bearing(
      double lat1, double lon1, double lat2, double lon2) {
    final dLon = _rad(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(dLon);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Normalise angle to [−180, +180].
  static double _normalizeAngle(double deg) {
    double a = deg % 360;
    if (a > 180) a -= 360;
    if (a < -180) a += 360;
    return a;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  String _labelDisplay(String label) {
    return label
        .replaceAll('sigiriya_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Reset the service back to step 0 (useful for re-entry).
  void reset() {
    _currentIndex = 0;
    _compassReady = false;
    _lastGpsUpdateMs = 0;
    _gpsLive = true;
    _deviceLat = null;
    _deviceLon = null;
    _headingDeg = null;
    _smoothedAngle = null;
    _detectionConfirmed = false;
    _routeComplete = false;
    _lastDetectedLabel = null;
    _lastDetectedConfidence = 0.0;
    _lastBboxCenterX = null;
    _lastBboxCenterY = null;
  }
}
