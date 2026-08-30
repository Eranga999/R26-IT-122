import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;

// ── Turn / direction ─────────────────────────────────────────────────────────
//
// The AR arrow, footsteps and PiP indicator are all driven purely by this
// enum — never by a GPS-target bearing. `none` means "no active navigation
// direction" (used before the route starts / after it ends); every real
// route segment uses straight / left / right, and the retrace leg uses
// reverse for the duration of the walk.

enum TurnDirection { none, straight, left, right, reverse }

double _angleForDirection(TurnDirection d) {
  switch (d) {
    case TurnDirection.straight:
      return 0.0;
    case TurnDirection.left:
      return -90.0;
    case TurnDirection.right:
      return 90.0;
    case TurnDirection.reverse:
      return 180.0;
    case TurnDirection.none:
      return 0.0;
  }
}

String turnDirectionLabel(TurnDirection d) {
  switch (d) {
    case TurnDirection.left:
      return 'Left';
    case TurnDirection.right:
      return 'Right';
    case TurnDirection.reverse:
      return 'Back';
    case TurnDirection.straight:
      return 'Straight';
    case TurnDirection.none:
      return '—';
  }
}

// ── Route point type ─────────────────────────────────────────────────────────

enum RoutePointType { segment, returnPoint }

// ── Measured route segment ───────────────────────────────────────────────────
//
// Every distance below was physically measured on-site. GPS is never used to
// generate this geometry — it is only used afterwards to estimate how far the
// visitor has walked along whichever segment is currently active.

class RouteSegment {
  final int number; // 1-based, matches the survey numbering
  final double distanceMeters;
  final TurnDirection
      turnAtEnd; // instruction issued once this segment completes
  final RoutePointType type;
  final String?
      landmarkLabel; // informational note shown on arrival (e.g. 'Sinhapadaya')
  final String?
      contextDetectionLabel; // opportunistic YOLO class relevant while walking this segment
  final String?
      contextAmbientNote; // shown throughout the segment, before the class is spotted
  final String?
      contextSpottedNote; // shown once the class is confidently spotted

  const RouteSegment({
    required this.number,
    required this.distanceMeters,
    required this.turnAtEnd,
    this.type = RoutePointType.segment,
    this.landmarkLabel,
    this.contextDetectionLabel,
    this.contextAmbientNote,
    this.contextSpottedNote,
  });

  bool get isReturn => type == RoutePointType.returnPoint;

  // The direction the visitor is walking *during* this segment (as opposed to
  // the turn instruction issued once it completes).
  TurnDirection get walkingDirection =>
      isReturn ? TurnDirection.reverse : TurnDirection.straight;
}

// ── AR visual components ───────────────────────────────────────────────────────

class ArFootstep {
  final double distanceMeters;
  final double relativeAngleDeg;
  const ArFootstep(
      {required this.distanceMeters, required this.relativeAngleDeg});
}

// ── Navigation phase ──────────────────────────────────────────────────────────

enum ArNavPhase { seekingTicketCounter, routing, endOfKnownRoute }

// ── GPS status ────────────────────────────────────────────────────────────────

enum ArGpsStatus { live, stale, degraded, unavailable }

// ── Heritage-site presence ───────────────────────────────────────────────────
//
// Whether the visitor is confirmed to be standing inside the Sigiriya site.
// Deliberately THREE states, not a bool: "no trustworthy fix yet" is NOT the
// same as "outside" — the UI must offer a "Verify again" retry for `locating`
// rather than wrongly telling a visitor at the entrance they are outside.

enum ArSitePresence { locating, inside, outside }

// ── Navigation snapshot (emitted per update) ────────────────────────────────────

class ArNavigationSnapshot {
  final int
      waypointIndex; // 0-based current segment index (-1 before the route starts)
  final int totalWaypoints;
  final String waypointTitle;
  final String instruction;
  final double
      distanceMeters; // remaining meters in the current segment (or to the Ticket Counter anchor)
  final double
      relativeAngleDeg; // smoothed screen-relative arrow angle, driven by [turnDirection]
  final TurnDirection turnDirection;
  final double
      compassHeadingDeg; // smoothed 0..360, phone orientation only — never gates the route
  final bool hasGpsFix;
  final bool hasCompassFix;
  final bool hasArrived;
  final bool routeComplete; // true once the currently known measured data ends
  final String?
      detectionGuidance; // shown while waiting for a route-gating YOLO detection
  final bool detectionConfirmed;
  final bool justArrivedFlash;
  final ArGpsStatus gpsStatus;
  final List<ArFootstep> footsteps;
  final String?
      contextNote; // opportunistic landmark note — never advances the route
  final ArNavPhase phase;
  final ArSitePresence
      sitePresence; // meaningful only while seeking the Ticket Counter

  const ArNavigationSnapshot({
    required this.waypointIndex,
    required this.totalWaypoints,
    required this.waypointTitle,
    required this.instruction,
    required this.distanceMeters,
    required this.relativeAngleDeg,
    this.turnDirection = TurnDirection.none,
    this.compassHeadingDeg = 0,
    required this.hasGpsFix,
    required this.hasCompassFix,
    required this.hasArrived,
    required this.routeComplete,
    this.detectionGuidance,
    required this.detectionConfirmed,
    this.justArrivedFlash = false,
    this.gpsStatus = ArGpsStatus.unavailable,
    this.footsteps = const [],
    this.contextNote,
    this.phase = ArNavPhase.seekingTicketCounter,
    this.sitePresence = ArSitePresence.locating,
  });

  ArNavigationSnapshot copyWith({
    int? waypointIndex,
    int? totalWaypoints,
    String? waypointTitle,
    String? instruction,
    double? distanceMeters,
    double? relativeAngleDeg,
    TurnDirection? turnDirection,
    double? compassHeadingDeg,
    bool? hasGpsFix,
    bool? hasCompassFix,
    bool? hasArrived,
    bool? routeComplete,
    String? detectionGuidance,
    bool? detectionConfirmed,
    bool? justArrivedFlash,
    ArGpsStatus? gpsStatus,
    List<ArFootstep>? footsteps,
    String? contextNote,
    ArNavPhase? phase,
    ArSitePresence? sitePresence,
  }) {
    return ArNavigationSnapshot(
      waypointIndex: waypointIndex ?? this.waypointIndex,
      totalWaypoints: totalWaypoints ?? this.totalWaypoints,
      waypointTitle: waypointTitle ?? this.waypointTitle,
      instruction: instruction ?? this.instruction,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      relativeAngleDeg: relativeAngleDeg ?? this.relativeAngleDeg,
      turnDirection: turnDirection ?? this.turnDirection,
      compassHeadingDeg: compassHeadingDeg ?? this.compassHeadingDeg,
      hasGpsFix: hasGpsFix ?? this.hasGpsFix,
      hasCompassFix: hasCompassFix ?? this.hasCompassFix,
      hasArrived: hasArrived ?? this.hasArrived,
      routeComplete: routeComplete ?? this.routeComplete,
      detectionGuidance: detectionGuidance ?? this.detectionGuidance,
      detectionConfirmed: detectionConfirmed ?? this.detectionConfirmed,
      justArrivedFlash: justArrivedFlash ?? this.justArrivedFlash,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      footsteps: footsteps ?? this.footsteps,
      contextNote: contextNote ?? this.contextNote,
      phase: phase ?? this.phase,
      sitePresence: sitePresence ?? this.sitePresence,
    );
  }
}

// ── Variance-based activity gate ─────────────────────────────────────────────
//
// Shared by the motion (accelerometer) and rotation (gyroscope) corroboration
// checks the software pedometer relies on — same shape of problem for both:
// "has this signal shown SUSTAINED variance (not just one spike) recently."
// A rolling window's variance must clear [threshold] and stay cleared for
// [sustainMs] before flipping active, which is what rejects a single bump/tap
// as motion; it flips back inactive the instant variance drops again.
class _VarianceGate {
  _VarianceGate(
      {required this.windowSize,
      required this.threshold,
      required this.sustainMs});

  final int windowSize;
  final double threshold;
  final int sustainMs;

  final List<double> _window = [];
  bool _active = false;
  DateTime? _aboveSince;

  /// True once the window has filled at least once — i.e. this sensor has
  /// proven it's actually delivering real samples on this device.
  bool everFilled = false;

  bool get isActive => _active;

  /// Feed one magnitude sample. Returns true iff active/inactive just flipped.
  bool feed(double value) {
    final wasActive = _active;
    _window.add(value);
    if (_window.length > windowSize) _window.removeAt(0);
    if (_window.length < windowSize) return false; // still warming up
    everFilled = true;

    final mean = _window.reduce((a, b) => a + b) / _window.length;
    final variance =
        _window.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            _window.length;

    final now = DateTime.now();
    if (variance > threshold) {
      _aboveSince ??= now;
      if (!_active &&
          now.difference(_aboveSince!).inMilliseconds >= sustainMs) {
        _active = true;
      }
    } else {
      _aboveSince = null;
      _active = false;
    }
    return wasActive != _active;
  }

  void reset() {
    _window.clear();
    _active = false;
    _aboveSince = null;
    everFilled = false;
  }
}

// ── Navigation service ──────────────────────────────────────────────────────────

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

  // ── Starting anchor ─────────────────────────────────────────────────────
  // Used ONLY to help the visitor reach the Ticket Counter before the
  // measured route begins. Never used to generate route geometry afterwards.
  static const double ticketCounterAnchorLat = 7.9577313;
  static const double ticketCounterAnchorLon = 80.7535045;
  static const String ticketCounterLabel = 'sigiriya_ticket_counter';

  // ── GPS route-start trigger ─────────────────────────────────────────────
  // Physically surveyed spot where Segment 1 begins. Standing here with a
  // trustworthy fix for [_gpsArrivalConfirmFixes] consecutive updates starts
  // the measured route WITHOUT a YOLO camera confirmation — the two triggers
  // are co-equal (whichever fires first wins). Distinct from the seek anchor
  // above (~10 m away): the anchor is the "aim here from far off" beacon,
  // this is the "you're standing at the counter, start measuring" fix.
  static const double routeStartLat = 7.957651;
  static const double routeStartLon = 80.753466;
  // Reported position must sit within this radius of the route-start point,
  // with a fix at least this accurate, for [_gpsArrivalConfirmFixes]
  // consecutive updates. The streak — not a tight radius — is what rejects a
  // single wild fix; keep the radius forgiving since the plaza fix near the
  // entrance still drifts ~15-25 m. YOLO + the manual button remain fallbacks.
  static const double _gpsArrivalRadiusM = 15.0;
  static const double _gpsArrivalMaxAccuracyM = 25.0;
  static const int _gpsArrivalConfirmFixes = 4;

  // ── Range band for the camera-search prompt (from the seek anchor) ──────
  // Inside this radius the visitor is close enough that pointing the camera
  // at the Ticket Counter is the useful next step.
  static const double cameraSearchRadiusMeters = 120.0;

  // ── Heritage-site geofence ("are you at Sigiriya?") ────────────────────
  // Defaults mirror assets/config/landmark_sites.json's Sigiriya entry;
  // ArCameraView overrides them from that file at startup (one source of
  // truth). A fix coarser than [_siteFixTrustAccuracyM] is never used to
  // assert `outside` — it downgrades to `locating` so the UI shows "Verify
  // again" instead of wrongly declaring the visitor outside the site.
  double _siteCenterLat = 7.9573;
  double _siteCenterLon = 80.7566;
  double _siteRadiusM = 1000.0;
  static const double _siteFixTrustAccuracyM = 60.0;

  /// One-time (or on-change) override of the site geofence from
  /// landmark_sites.json. See [_computeSitePresence].
  void configureSiteGeofence({
    required double lat,
    required double lon,
    required double radiusMeters,
  }) {
    _siteCenterLat = lat;
    _siteCenterLon = lon;
    _siteRadiusM = radiusMeters;
  }

  // ── Long-segment GPS drift correction ─────────────────────────────────
  // The one deliberate exception to "GPS never writes `_walkedInSegment`"
  // (see the GPS doc below): on segments long enough for step drift to
  // accumulate (Segments 11 & 12 — 376 m / 214 m on today's route), when the
  // fix is genuinely good and a trend is established, bleed the step-based
  // estimate a small fraction of the way toward the GPS-walked estimate.
  // Steps stay the source of truth; this only trims accumulated error.
  static const double _gpsCorrectionMinSegmentM = 100.0;
  static const double _gpsCorrectionMaxAccuracyM = 10.0;
  static const double _gpsCorrectionDeadbandM = 8.0;
  static const double _gpsCorrectionGain = 0.06;
  static const int _gpsCorrectionMinFixes = 5;

  /// Every class the on-device YOLO model actually knows. Used to scan
  /// opportunistically for ANY landmark (bounding box + info popup) once the
  /// measured route is underway, independent of which one (if any) the
  /// current segment cares about for route logic.
  static const Set<String> allDetectionLabels = {
    'sigiriya_ticket_counter',
    'sigiriya_mirror_wall',
    'sigiriya_lion_paws',
    'sigiriya_lion_rock',
    'sigiriya_throne',
  };

  // ── Measured Sigiriya walking route ─────────────────────────────────────
  // Every value below is a physically surveyed distance/turn. Do not modify
  // or extend this list without new survey data — see ar_navigation_service
  // spec notes. The route intentionally stops after segment 36; there is no
  // further measured data yet.
  static const List<RouteSegment> _segments = [
    RouteSegment(number: 1, distanceMeters: 6, turnAtEnd: TurnDirection.right),
    RouteSegment(number: 2, distanceMeters: 3, turnAtEnd: TurnDirection.left),
    RouteSegment(number: 3, distanceMeters: 8, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 4, distanceMeters: 1.94, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 5, distanceMeters: 1.05, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 6, distanceMeters: 8.86, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 7, distanceMeters: 9.46, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 8, distanceMeters: 4.91, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 9, distanceMeters: 4.73, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 10, distanceMeters: 9.48, turnAtEnd: TurnDirection.straight),
    RouteSegment(
      number: 11,
      distanceMeters: 376.07,
      turnAtEnd: TurnDirection.straight,
      contextDetectionLabel: 'sigiriya_lion_rock',
      contextAmbientNote: 'Lion Rock viewpoint nearby',
      contextSpottedNote: 'Sigiriya Lion Rock spotted',
    ),
    RouteSegment(
        number: 12, distanceMeters: 214.26, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 13, distanceMeters: 3.63, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 14, distanceMeters: 2.34, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 15, distanceMeters: 14.71, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 16, distanceMeters: 17.81, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 17, distanceMeters: 12.81, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 18, distanceMeters: 11.37, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 19, distanceMeters: 75.75, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 20, distanceMeters: 26.70, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 21, distanceMeters: 27.67, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 22, distanceMeters: 3.65, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 23, distanceMeters: 3.93, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 24, distanceMeters: 13.19, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 25, distanceMeters: 4.95, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 26, distanceMeters: 7.44, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 27, distanceMeters: 5.92, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 28, distanceMeters: 43.49, turnAtEnd: TurnDirection.left),
    RouteSegment(
      number: 29,
      distanceMeters: 19.25,
      turnAtEnd: TurnDirection.straight,
      landmarkLabel: 'Sinhapadaya',
      contextDetectionLabel: 'sigiriya_lion_paws',
      contextSpottedNote: 'Sigiriya Lion Paws spotted',
    ),
    RouteSegment(
        number: 30, distanceMeters: 20.47, turnAtEnd: TurnDirection.right),
    RouteSegment(
      number: 31,
      distanceMeters: 8.27,
      turnAtEnd: TurnDirection.straight,
      type: RoutePointType.returnPoint,
    ),
    RouteSegment(
        number: 32, distanceMeters: 13.02, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 33, distanceMeters: 6.15, turnAtEnd: TurnDirection.right),
    RouteSegment(
        number: 34, distanceMeters: 1.29, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 35, distanceMeters: 10.23, turnAtEnd: TurnDirection.left),
    RouteSegment(
        number: 36, distanceMeters: 10.01, turnAtEnd: TurnDirection.straight),
  ];

  List<RouteSegment> get segments => _segments;

  // ── GPS: validation/logging ONLY — never credits distance ────────────────
  // GPS position noise is never reliable evidence of walking distance — a
  // stationary phone's fix legitimately drifts several meters between reads
  // (common indoors and near rock faces, exactly Sigiriya's terrain), and
  // even "slow" drift eventually adds up over a long segment. No real
  // walking-nav app trusts raw position deltas for distance; they estimate
  // it from the device's own motion sensors and use GPS only to sanity-check
  // the result. So here: GPS is computed and logged (`_gpsWalkedInSegment`)
  // purely as a diagnostic comparison figure — it is architecturally
  // incapable of writing to `_walkedInSegment`, see `_ingestRoutingGps`.
  // These thresholds just keep that comparison figure itself sane.
  static const double _maxAcceptableAccuracyM = 30.0;
  static const double _maxPlausibleWalkSpeedMps = 2.6; // brisk walk ceiling
  static const double _maxSingleUpdateMovementM = 15.0; // hard clamp per fix

  // ── Distance estimation: sensor fusion, GPS-independent ──────────────────
  // `_walkedInSegment` is driven ONLY by physical steps, from one of two
  // sources, in priority order:
  //   1. Native step-detector (Android TYPE_STEP_DETECTOR / iOS CMPedometer)
  //      — OS/hardware-fused, the most reliable source once it proves it's
  //      actually delivering events (see `enableStepMode`).
  //   2. Software pedometer (below) — a peak-detection algorithm over the
  //      raw accelerometer stream, active by DEFAULT from segment 1 onward
  //      so there is never a GPS-dependent gap while waiting on native
  //      steps/permissions. Once native steps prove themselves, this source
  //      permanently steps aside (matches the rest of this file's "prove it
  //      works once, trust it from then on" pattern).
  // Both sources feed the exact same `_stepsInSegment` counter (see
  // `_creditStep`), so switching sources mid-segment is seamless.

  // Motion/rotation corroboration for the SOFTWARE pedometer only (native
  // steps are already OS-vetted and don't need this): a rolling-window
  // variance classifier on linear (gravity-removed) accelerometer magnitude,
  // and a second one on gyroscope rotation-rate magnitude. A single sharp
  // bump/tap can cross the pedometer's peak threshold once, but it won't
  // produce the SUSTAINED variance — in BOTH the accelerometer's bounce and
  // the gyroscope's rotation — that a genuine walking gait does (arm/torso
  // sway alongside the vertical bounce). Both must agree before a
  // software-detected step is credited.
  static const int _motionWindowSize =
      40; // ~800ms at SensorInterval.gameInterval (50Hz)
  static const double _motionVarianceThreshold =
      0.20; // (m/s²)² — empirical; retune on-device
  static const int _gyroWindowSize = 40;
  static const double _gyroVarianceThreshold =
      0.02; // (rad/s)² — empirical; retune on-device
  static const int _gateSustainMs = 400; // debounce: ignore single spikes/taps

  // The pedometer's own peak detector: a rising-edge (Schmitt-trigger style)
  // threshold crossing on the smoothed acceleration magnitude counts as one
  // step once it's re-armed by dipping back below the fall threshold —
  // standard shape for a software pedometer, same idea as the OS's own
  // TYPE_STEP_DETECTOR, just implemented here as the always-warm fallback.
  static const double _pedometerRiseThreshold =
      1.6; // m/s² — empirical; retune on-device
  static const double _pedometerFallThreshold = 0.9; // hysteresis re-arm floor
  static const int _accelSmoothingWindowSize =
      3; // light denoise, short enough not to smear real peaks

  // Same "optional sensor, graceful fallback" shape as step mode: if a
  // device's accelerometer/gyroscope never produce a single full window of
  // real samples within this grace period after routing starts, that gate
  // is presumed unusable on that device and stops blocking the pedometer —
  // a broken/absent sensor must never *permanently* halt navigation (the
  // manual simulation panel is also always available as a last resort).
  static const int _pedometerGateGraceMs = 6000;

  // ── Step-based segment progress ──────────────────────────────────────────
  // Surveyed distance stays the fixed source of truth (_segments above is
  // never touched). Steps × calibrated step length is the ONLY input that
  // drives `_walkedInSegment` — from the native sensor once it proves
  // itself, the software pedometer until then (see `_stepSourceLabel`).
  // `_defaultStepLengthM` is the starting estimate used before Segment 1
  // calibrates it against the known surveyed distance.
  static const double _defaultStepLengthM = 0.72;
  static const double _minStepLengthM = 0.40;
  static const double _maxStepLengthM = 1.00;
  static const int _minCalibrationSteps = 6;
  // Debounce floor: normal walking cadence is ~400-800ms/step, so anything
  // faster is almost certainly a duplicate/noisy re-fire, not a real step.
  static const int _minStepIntervalMs = 250;

  // ── Temporal detection confirmation ─────────────────────────────────────
  static const int _ticketCounterConfirmFrames = 5;
  static const int _contextConfirmFrames = 3;

  // ── Smoothing ─────────────────────────────────────────────────────────────
  static const double _arrowSmoothingAlpha = 0.28;
  static const double _headingSmoothingAlpha = 0.18;

  // ── Segment heading reference (compass-locked "forward") ────────────────
  // A fresh compass snapshot is captured ~1.5s after each segment starts —
  // long enough for the visitor to have physically executed whatever turn
  // instruction was just shown (the arrival banner itself holds the screen
  // for ~2s — see ar_camera_view.dart's _flashBannerTimer). From that lock
  // onward the arrow tracks LIVE compass rotation relative to this one
  // reading, the way a real AR nav app's arrow swings as you turn the
  // phone. Each segment gets its own independent reference — never
  // inherited from the previous one — so heading error can never compound
  // across the ~30 turns on the measured route; the worst case is a single
  // segment's arrow being off by whatever the compass read at lock time.
  // Before the lock (or whenever the compass isn't ready) this falls back
  // to the original turn-only angle, unchanged.
  static const int _segmentHeadingLockDelayMs = 1500;

  // ── State ──────────────────────────────────────────────────────────────────
  ArNavPhase _phase = ArNavPhase.seekingTicketCounter;
  int _currentSegmentIndex = 0;

  double? _deviceLat;
  double? _deviceLon;
  double?
      _lastGpsAccuracyM; // most recent reported horizontal accuracy, for the site-presence check
  double? _headingDeg;
  bool _compassReady = false;
  double? _smoothedHeadingDeg;

  // See `_segmentHeadingLockDelayMs` above.
  double? _segmentReferenceBearing;
  DateTime? _segmentStartTime;

  // Corroboration gates for the software pedometer (see constants above).
  // Starts inactive (no free rides until the sensor actually confirms
  // sustained motion/rotation) rather than active, since a false-positive
  // default would reopen the exact "stationary phone advances anyway" bug
  // this whole architecture exists to close.
  final _VarianceGate _motionGate = _VarianceGate(
      windowSize: _motionWindowSize,
      threshold: _motionVarianceThreshold,
      sustainMs: _gateSustainMs);
  final _VarianceGate _rotationGate = _VarianceGate(
      windowSize: _gyroWindowSize,
      threshold: _gyroVarianceThreshold,
      sustainMs: _gateSustainMs);
  DateTime? _pedometerGateGraceDeadline; // see `_pedometerGateGraceMs`

  // Software pedometer's own peak-detector state (see `_pedometerRiseThreshold`).
  final List<double> _accelSmoothingBuffer = [];
  bool _pedometerArmed = true;
  DateTime? _lastSoftwareStepTime;

  int _lastGpsUpdateMs = 0;
  bool _gpsLive = true;

  double? _lastAcceptedLat;
  double? _lastAcceptedLon;
  DateTime? _lastAcceptedTime;
  double _walkedInSegment =
      0.0; // authoritative — fed ONLY by steps (native or software), never GPS

  // Step-based progress (see constants above for tuning).
  bool _nativeStepSensorActive = false;
  double _calibratedStepLength = _defaultStepLengthM;
  int _stepsInSegment = 0;
  int _calibrationStepCount = 0;
  bool _calibrationComplete = false;
  DateTime? _lastStepEventTime;

  // Debug-only shadow tracking, purely for comparison against the
  // sensor-driven `_walkedInSegment` — see the GPS section above.
  double _gpsWalkedInSegment = 0.0;
  int _gpsFixesThisSegment =
      0; // accepted routing fixes this segment (drift-correction trend gate)
  double?
      _segmentStartLat; // first accepted fix of the current segment — anchor for
  double?
      _segmentStartLon; // straight-line displacement in the drift correction
  int? _cumulativeStepBaseline;
  int _lastLoggedCumulativeDelta = 0;

  double? _smoothedArrowAngle;

  int _ticketCounterHitStreak = 0;
  int _gpsArrivalStreak = 0; // consecutive close fixes to the route-start point
  int _contextHitStreak = 0;
  bool _contextSpotted = false;

  int? _lastLoggedSegmentIndex;
  String? _lastLoggedInstruction;
  int _lastCompassLogMs = 0;

  ArNavPhase get phase => _phase;
  bool get routeComplete => _phase == ArNavPhase.endOfKnownRoute;
  double? get headingDeg =>
      _headingDeg; // raw phone orientation, for diagnostics only
  bool get usingNativeStepSensor => _nativeStepSensorActive;
  double get calibratedStepLength => _calibratedStepLength;

  RouteSegment? get currentSegment =>
      (_phase == ArNavPhase.routing && _currentSegmentIndex < _segments.length)
          ? _segments[_currentSegmentIndex]
          : null;

  /// YOLO classes worth running inference for right now. Empty ⇒ skip
  /// inference entirely for this frame. Before the Ticket Counter is
  /// confirmed only that one class matters; once the measured route is
  /// underway every known class is scanned opportunistically (bounding
  /// box + info popup for whatever the camera happens to see) — route
  /// progression itself still only reacts to the CURRENT segment's own
  /// `contextDetectionLabel` (see [onDetectionUpdate]), so scanning wider
  /// here never lets an unrelated detection skip the route.
  Set<String> get activeYoloLabels {
    if (_phase == ArNavPhase.seekingTicketCounter) return {ticketCounterLabel};
    if (_phase == ArNavPhase.routing) return allDetectionLabels;
    return const {};
  }

  ArGpsStatus get _currentGpsStatus {
    if (_deviceLat == null || _deviceLon == null)
      return ArGpsStatus.unavailable;
    if (_gpsLive) return ArGpsStatus.live;
    if (_lastGpsUpdateMs == 0) return ArGpsStatus.unavailable;

    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastGpsUpdateMs;
    if (elapsed <= gpsStaleTimeoutMs) return ArGpsStatus.stale;
    if (elapsed <= gpsDegradedTimeoutMs) return ArGpsStatus.degraded;
    return ArGpsStatus.unavailable;
  }

  // ── GPS update ────────────────────────────────────────────────────────────
  ArNavigationSnapshot onGpsUpdate(double lat, double lon,
      {double? accuracyMeters}) {
    _deviceLat = lat;
    _deviceLon = lon;
    _lastGpsAccuracyM = accuracyMeters;
    _gpsLive = true;
    _lastGpsUpdateMs = DateTime.now().millisecondsSinceEpoch;

    if (_phase == ArNavPhase.seekingTicketCounter) {
      final started = _maybeStartRouteFromGps(lat, lon, accuracyMeters);
      if (started != null) return started;
    } else if (_phase == ArNavPhase.routing) {
      _ingestRoutingGps(lat, lon, accuracyMeters);
    }
    return _compute();
  }

  void onGpsLost() {
    _gpsLive = false;
  }

  /// Co-equal with the YOLO camera trigger: if the visitor is standing on the
  /// surveyed Segment-1 start point ([routeStartLat]/[routeStartLon]) with a
  /// trustworthy fix for [_gpsArrivalConfirmFixes] consecutive updates, begin
  /// the measured route without needing a camera lock. Returns the
  /// confirmation-banner snapshot when it fires, else null.
  ArNavigationSnapshot? _maybeStartRouteFromGps(
      double lat, double lon, double? accuracyMeters) {
    if (accuracyMeters == null || accuracyMeters > _gpsArrivalMaxAccuracyM) {
      _gpsArrivalStreak = 0;
      return null;
    }
    final d = _haversineMeters(lat, lon, routeStartLat, routeStartLon);
    _gpsArrivalStreak = d <= _gpsArrivalRadiusM ? _gpsArrivalStreak + 1 : 0;
    if (_gpsArrivalStreak >= _gpsArrivalConfirmFixes) {
      _gpsArrivalStreak = 0;
      _log('Route start confirmed by GPS arrival '
          '(${d.toStringAsFixed(1)}m from Segment 1 start, '
          'accuracy=${accuracyMeters.toStringAsFixed(1)}m)');
      _beginRoute();
      return _buildTicketCounterConfirmedBanner();
    }
    return null;
  }

  void _ingestRoutingGps(double lat, double lon, double? accuracyMeters) {
    if (accuracyMeters != null && accuracyMeters > _maxAcceptableAccuracyM) {
      _log('GPS rejected (accuracy=${accuracyMeters.toStringAsFixed(1)}m)');
      return;
    }

    if (_lastAcceptedLat == null || _lastAcceptedLon == null) {
      _lastAcceptedLat = lat;
      _lastAcceptedLon = lon;
      _lastAcceptedTime = DateTime.now();
      _segmentStartLat ??= lat;
      _segmentStartLon ??= lon;
      _log('GPS accepted (baseline) movement=0.00m');
      return;
    }
    _segmentStartLat ??= _lastAcceptedLat;
    _segmentStartLon ??= _lastAcceptedLon;

    final rawMovement =
        _haversineMeters(_lastAcceptedLat!, _lastAcceptedLon!, lat, lon);
    final now = DateTime.now();
    final dtSeconds = _lastAcceptedTime == null
        ? 1.0
        : math.max(
            0.2, now.difference(_lastAcceptedTime!).inMilliseconds / 1000.0);
    final impliedSpeed = rawMovement / dtSeconds;

    if (impliedSpeed > _maxPlausibleWalkSpeedMps) {
      _log('GPS rejected (implausible jump=${rawMovement.toStringAsFixed(2)}m '
          'in ${dtSeconds.toStringAsFixed(1)}s)');
      return;
    }

    final acceptedMovement = math.min(rawMovement, _maxSingleUpdateMovementM);
    _lastAcceptedLat = lat;
    _lastAcceptedLon = lon;
    _lastAcceptedTime = now;

    // Only ever accumulate against the CURRENT segment. For short segments
    // this stays pure diagnostics — the debug log shows "sensor distance vs
    // GPS distance" side by side for on-device sanity checking. The ONLY
    // place it is allowed to influence `_walkedInSegment` is the tightly
    // gated long-segment drift correction below (see the class-level GPS doc
    // and `_gpsCorrectionGain`).
    _gpsWalkedInSegment += acceptedMovement;
    _gpsFixesThisSegment++;
    _log('GPS movement=${acceptedMovement.toStringAsFixed(2)}m '
        'gpsWalked=${_gpsWalkedInSegment.toStringAsFixed(2)}m vs '
        'sensorWalked=${_walkedInSegment.toStringAsFixed(2)}m '
        '(steps=$_stepsInSegment × ${_calibratedStepLength.toStringAsFixed(3)}m, '
        'source=$_stepSourceLabel)');

    _maybeCorrectDriftFromGps(accuracyMeters);
  }

  /// The single sanctioned path for GPS to write `_walkedInSegment` (see the
  /// GPS doc above). Only on long segments (≥ [_gpsCorrectionMinSegmentM] —
  /// Segments 11 & 12 on today's route), only with a genuinely good fix, and
  /// only once enough fixes have established a trend: nudge the step-based
  /// estimate a small fraction of the way toward the GPS estimate whenever
  /// the two have drifted past [_gpsCorrectionDeadbandM]. The gentle gain
  /// plus the segment-length clamp keep the countdown from jumping.
  ///
  /// The GPS estimate here is the straight-line displacement from the
  /// segment's first fix — NOT `_gpsWalkedInSegment` (summed inter-fix path
  /// length), which random GPS jitter inflates without bound and would bias
  /// the countdown forward. Displacement is a sound proxy because Segments 11
  /// & 12 run essentially straight.
  void _maybeCorrectDriftFromGps(double? accuracyMeters) {
    final seg = currentSegment;
    if (seg == null) return;
    if (seg.distanceMeters < _gpsCorrectionMinSegmentM) return;
    if (accuracyMeters == null || accuracyMeters > _gpsCorrectionMaxAccuracyM)
      return;
    if (_gpsFixesThisSegment < _gpsCorrectionMinFixes) return;
    if (_segmentStartLat == null ||
        _segmentStartLon == null ||
        _lastAcceptedLat == null ||
        _lastAcceptedLon == null) {
      return;
    }

    final gpsDisplacement = _haversineMeters(_segmentStartLat!,
        _segmentStartLon!, _lastAcceptedLat!, _lastAcceptedLon!);
    final discrepancy = gpsDisplacement - _walkedInSegment;
    if (discrepancy.abs() <= _gpsCorrectionDeadbandM) return;

    final before = _walkedInSegment;
    _walkedInSegment = _clampD(
        _walkedInSegment + discrepancy * _gpsCorrectionGain,
        0,
        seg.distanceMeters);
    // Keep the step counter consistent with the corrected distance so the
    // next `_creditStep` recompute (steps × stepLength) doesn't undo this.
    if (_calibratedStepLength > 0) {
      _stepsInSegment = (_walkedInSegment / _calibratedStepLength).round();
    }
    _log('GPS drift correction on Segment ${seg.number}: '
        'walked ${before.toStringAsFixed(2)}m → ${_walkedInSegment.toStringAsFixed(2)}m '
        '(gpsDisplacement=${gpsDisplacement.toStringAsFixed(2)}m, '
        'discrepancy=${discrepancy.toStringAsFixed(2)}m, gain=$_gpsCorrectionGain)');
  }

  String get _stepSourceLabel =>
      _nativeStepSensorActive ? 'native-step-sensor' : 'software-pedometer';

  // ── Step-based progress: the ONLY distance source ─────────────────────────
  // The caller (ar_camera_view.dart) calls enableStepMode() once it has
  // confirmed the platform's native step sensor is actually delivering
  // events. Until then — including the first few seconds of every route,
  // and permanently on a device where native steps never work — the
  // software pedometer (see onAccelerometerSample) is what drives
  // `_walkedInSegment`. GPS is never in this picture at all.
  void enableStepMode() {
    if (_nativeStepSensorActive) return;
    _nativeStepSensorActive = true;
    _log(
        'Native step sensor CONFIRMED — takes over from the software pedometer '
        '(steps × ${_calibratedStepLength.toStringAsFixed(2)}m keeps driving the countdown either way)');
  }

  /// Feed one low-latency per-step event (Android TYPE_STEP_DETECTOR, or one
  /// iOS CMPedometer increment). Debounced against implausibly rapid re-fires.
  ArNavigationSnapshot onStepDetected() {
    if (_phase != ArNavPhase.routing) return _compute();

    final now = DateTime.now();
    if (_lastStepEventTime != null &&
        now.difference(_lastStepEventTime!).inMilliseconds <
            _minStepIntervalMs) {
      return _compute(); // debounce: not a plausible new step
    }
    _lastStepEventTime = now;
    return _creditStep('native');
  }

  /// Cumulative step-counter reading (TYPE_STEP_COUNTER / CMPedometer total).
  /// Debug/reconciliation only — logs how it compares to the fast per-step
  /// stream, never feeds `_walkedInSegment` directly (it can lag several
  /// seconds behind, which would make the countdown feel stuck again).
  ArNavigationSnapshot onStepCountUpdate(int cumulativeSteps) {
    if (_phase != ArNavPhase.routing) return _compute();
    _cumulativeStepBaseline ??= cumulativeSteps;
    final delta = cumulativeSteps - _cumulativeStepBaseline!;
    if (delta != _lastLoggedCumulativeDelta) {
      _lastLoggedCumulativeDelta = delta;
      _log(
          'cumulative step-counter delta=$delta (detector-stream count=$_stepsInSegment)');
    }
    return _compute();
  }

  /// One step, from whichever source (native or software), credited exactly
  /// the same way — see the class-level "Distance estimation" doc above.
  ArNavigationSnapshot _creditStep(String source) {
    _stepsInSegment++;
    final seg = _currentSegmentIndex < _segments.length
        ? _segments[_currentSegmentIndex]
        : null;
    if (!_calibrationComplete && seg?.number == 1) {
      _calibrationStepCount++;
    }
    _walkedInSegment = _stepsInSegment * _calibratedStepLength;
    _log('step detected ($source) stepsInSegment=$_stepsInSegment '
        'stepLength=${_calibratedStepLength.toStringAsFixed(3)}m '
        'stepWalked=${_walkedInSegment.toStringAsFixed(2)}m');
    return _compute();
  }

  /// Returns whether [gate] currently permits crediting a software-detected
  /// step: either it's proven itself and is actively reporting sustained
  /// motion/rotation, or it hasn't proven itself yet and we're still within
  /// its startup grace window (safe default: don't credit until we know),
  /// or the grace window has expired with the sensor never once reporting
  /// real data — in which case it's presumed unavailable on this device and
  /// stops blocking the pedometer (see `_pedometerGateGraceMs`).
  bool _gateSatisfied(_VarianceGate gate) {
    if (gate.everFilled) return gate.isActive;
    final deadline = _pedometerGateGraceDeadline;
    if (deadline != null && DateTime.now().isBefore(deadline)) return false;
    return true;
  }

  // ── Software pedometer + motion/rotation corroboration ───────────────────
  /// Feed one linear (gravity-removed) accelerometer sample — x/y/z in
  /// m/s², as reported by e.g. `sensors_plus`'s `userAccelerometerEventStream`.
  /// This is the PRIMARY distance source for the app (see class-level doc):
  /// a peak-detection pedometer that credits a step whenever the smoothed
  /// magnitude rises through `_pedometerRiseThreshold`, corroborated by
  /// sustained motion+rotation variance so an isolated bump/tap can't be
  /// mistaken for a footstep. No-ops once the native step sensor has taken
  /// over. Returns a fresh snapshot only when a step was actually credited
  /// (state the UI needs to see) — null otherwise, so ~50Hz sampling doesn't
  /// force ~50 rebuilds/sec.
  ArNavigationSnapshot? onAccelerometerSample(double x, double y, double z) {
    if (_phase != ArNavPhase.routing || _nativeStepSensorActive) return null;

    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (_motionGate.feed(magnitude)) {
      _log(_motionGate.isActive
          ? 'Motion CONFIRMED (accelerometer variance) — software pedometer eligible'
          : 'Device STATIONARY (accelerometer variance) — software pedometer paused');
    }

    _accelSmoothingBuffer.add(magnitude);
    if (_accelSmoothingBuffer.length > _accelSmoothingWindowSize) {
      _accelSmoothingBuffer.removeAt(0);
    }
    final smoothed = _accelSmoothingBuffer.reduce((a, b) => a + b) /
        _accelSmoothingBuffer.length;

    final now = DateTime.now();
    if (_pedometerArmed && smoothed > _pedometerRiseThreshold) {
      final tooSoon = _lastSoftwareStepTime != null &&
          now.difference(_lastSoftwareStepTime!).inMilliseconds <
              _minStepIntervalMs;
      if (!tooSoon &&
          _gateSatisfied(_motionGate) &&
          _gateSatisfied(_rotationGate)) {
        _pedometerArmed = false;
        _lastSoftwareStepTime = now;
        return _creditStep('software-pedometer');
      }
    } else if (!_pedometerArmed && smoothed < _pedometerFallThreshold) {
      _pedometerArmed = true;
    }
    return null;
  }

  /// Feed one gyroscope sample — x/y/z rotation rate in rad/s. Never credits
  /// distance on its own; purely corroborates the software pedometer above
  /// (see `_gyroVarianceThreshold`'s doc for why). No-ops once native steps
  /// have taken over, same as the accelerometer path.
  void onGyroscopeSample(double x, double y, double z) {
    if (_phase != ArNavPhase.routing || _nativeStepSensorActive) return;
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (_rotationGate.feed(magnitude)) {
      _log(_rotationGate.isActive
          ? 'Rotation CONFIRMED (gyroscope variance) — corroborates walking gait'
          : 'Rotation settled (gyroscope variance) — pedometer needs renewed corroboration');
    }
  }

  void _maybeCalibrateStepLength(RouteSegment completed) {
    if (_calibrationComplete || completed.number != 1) return;
    _calibrationComplete = true; // only ever attempted once, using Segment 1
    if (_calibrationStepCount >= _minCalibrationSteps) {
      final raw = completed.distanceMeters / _calibrationStepCount;
      _calibratedStepLength = _clampD(raw, _minStepLengthM, _maxStepLengthM);
      _log(
          'Step length CALIBRATED: ${completed.distanceMeters}m / $_calibrationStepCount steps '
          '= ${raw.toStringAsFixed(3)}m → clamped to ${_calibratedStepLength.toStringAsFixed(3)}m');
    } else {
      _log(
          'Calibration skipped (only $_calibrationStepCount steps observed on Segment 1, '
          'need ≥$_minCalibrationSteps) — keeping default ${_calibratedStepLength.toStringAsFixed(2)}m');
    }
  }

  // ── Heading update ────────────────────────────────────────────────────────
  ArNavigationSnapshot onHeadingUpdate(double headingDeg) {
    _headingDeg = headingDeg;
    _compassReady = headingDeg.isFinite;
    if (_compassReady) {
      final target = _normalizeTo360(headingDeg);
      _smoothedHeadingDeg = _smoothedHeadingDeg == null
          ? target
          : _smoothCircular(
              _smoothedHeadingDeg!, target, _headingSmoothingAlpha);

      if (_phase == ArNavPhase.routing &&
          _segmentReferenceBearing == null &&
          _segmentStartTime != null &&
          DateTime.now().difference(_segmentStartTime!).inMilliseconds >=
              _segmentHeadingLockDelayMs) {
        _segmentReferenceBearing = _smoothedHeadingDeg;
        _log('Segment ${currentSegment?.number} heading reference locked at '
            '${_segmentReferenceBearing!.toStringAsFixed(0)}° — arrow now tracks live phone rotation');
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastCompassLogMs > 1000) {
        _lastCompassLogMs = nowMs;
        _log(
            'compass=${headingDeg.toStringAsFixed(0)}° smoothed=${_smoothedHeadingDeg!.toStringAsFixed(0)}°');
      }
    }
    return _compute();
  }

  // ── Detection update ──────────────────────────────────────────────────────
  /// Pass each YOLO frame's best detection (or nulls if nothing detected).
  ArNavigationSnapshot onDetectionUpdate({
    required String? label,
    required double confidence,
    required double? bboxCenterX,
    required double? bboxCenterY,
  }) {
    final normLabel = label?.trim().toLowerCase();

    if (_phase == ArNavPhase.seekingTicketCounter) {
      final labelMatch = normLabel == ticketCounterLabel;
      final confOk = confidence >= detectionThreshold;
      bool centered = false;
      if (labelMatch && confOk && bboxCenterX != null && bboxCenterY != null) {
        final dx = (bboxCenterX - 0.5).abs();
        final dy = (bboxCenterY - 0.5).abs();
        centered = dx <= centerTolerance && dy <= centerTolerance;
      }
      final match = labelMatch && confOk && centered;
      _ticketCounterHitStreak = match ? _ticketCounterHitStreak + 1 : 0;

      if (_ticketCounterHitStreak >= _ticketCounterConfirmFrames) {
        _ticketCounterHitStreak = 0;
        _log(
            'Ticket Counter confirmed after $_ticketCounterConfirmFrames stable frames');
        _beginRoute();
        return _buildTicketCounterConfirmedBanner();
      }
    } else if (_phase == ArNavPhase.routing) {
      final seg = currentSegment;
      if (seg?.contextDetectionLabel != null) {
        final match = normLabel == seg!.contextDetectionLabel!.toLowerCase() &&
            confidence >= detectionThreshold;
        _contextHitStreak = match ? _contextHitStreak + 1 : 0;
        final wasSpotted = _contextSpotted;
        _contextSpotted = _contextHitStreak >= _contextConfirmFrames;
        if (_contextSpotted && !wasSpotted) {
          _log('contextDetection=${seg.contextDetectionLabel}');
        }
      } else {
        _contextHitStreak = 0;
        _contextSpotted = false;
      }
    }

    return _compute();
  }

  void _beginRoute() {
    _phase = ArNavPhase.routing;
    _currentSegmentIndex = 0;
    _walkedInSegment = 0;
    _gpsArrivalStreak = 0;
    _contextHitStreak = 0;
    _contextSpotted = false;
    _lastLoggedSegmentIndex = null;
    _lastLoggedInstruction = null;
    _resetStepSegmentState();
    _calibrationStepCount = 0;
    _calibrationComplete = false;
    _segmentReferenceBearing = null;
    _segmentStartTime = DateTime.now();
    _pedometerGateGraceDeadline ??=
        DateTime.now().add(const Duration(milliseconds: _pedometerGateGraceMs));
    if (_deviceLat != null && _deviceLon != null) {
      _lastAcceptedLat = _deviceLat;
      _lastAcceptedLon = _deviceLon;
      _lastAcceptedTime = DateTime.now();
    } else {
      _lastAcceptedLat = null;
      _lastAcceptedLon = null;
      _lastAcceptedTime = null;
    }
  }

  void _advance() {
    _currentSegmentIndex++;
    _walkedInSegment = 0;
    _contextHitStreak = 0;
    _contextSpotted = false;
    _resetStepSegmentState();
    _segmentReferenceBearing = null;
    _segmentStartTime = DateTime.now();
    if (_currentSegmentIndex >= _segments.length) {
      _phase = ArNavPhase.endOfKnownRoute;
    }
  }

  /// Per-segment step bookkeeping only — deliberately leaves calibration
  /// (`_calibratedStepLength`/`_calibrationComplete`) untouched, since that
  /// stays valid for the rest of the route once set. Also guards against
  /// stale step events from the segment just left incorrectly crediting the
  /// new one (every ingest path resets this before the new segment can
  /// receive any progress).
  void _resetStepSegmentState() {
    _stepsInSegment = 0;
    _gpsWalkedInSegment = 0;
    _gpsFixesThisSegment = 0;
    _segmentStartLat = null;
    _segmentStartLon = null;
    _cumulativeStepBaseline = null;
    _lastLoggedCumulativeDelta = 0;
  }

  // ── Manual testing / simulation ─────────────────────────────────────────
  // Preserves the app's manual-simulation capability now that the route is
  // measured-distance based rather than GPS-waypoint based.

  ArNavigationSnapshot simulateTicketCounterConfirmed() {
    _log('Manual simulation: Ticket Counter confirmed');
    _beginRoute();
    return _buildTicketCounterConfirmedBanner();
  }

  ArNavigationSnapshot simulateJumpToSegment(int number) {
    final idx = _segments.indexWhere((s) => s.number == number);
    if (idx < 0) return _compute();
    _phase = ArNavPhase.routing;
    _currentSegmentIndex = idx;
    _walkedInSegment = 0;
    _contextHitStreak = 0;
    _contextSpotted = false;
    _lastLoggedSegmentIndex = null;
    _lastLoggedInstruction = null;
    _resetStepSegmentState();
    _segmentReferenceBearing = null;
    _segmentStartTime = DateTime.now();
    if (_deviceLat != null && _deviceLon != null) {
      _lastAcceptedLat = _deviceLat;
      _lastAcceptedLon = _deviceLon;
      _lastAcceptedTime = DateTime.now();
    }
    _log('Manual simulation: jumped to segment ${_segments[idx].number}');
    return _compute();
  }

  ArNavigationSnapshot simulateWalk(double meters) {
    if (_phase != ArNavPhase.routing) return _compute();
    _walkedInSegment += meters;
    _log('Manual simulation: walked +${meters.toStringAsFixed(2)}m');
    return _compute();
  }

  // ── Core computation ──────────────────────────────────────────────────────
  ArNavigationSnapshot _compute() {
    final gpsStatus = _currentGpsStatus;
    switch (_phase) {
      case ArNavPhase.seekingTicketCounter:
        return _computeSeekingTicketCounter(gpsStatus);
      case ArNavPhase.routing:
        return _computeRouting(gpsStatus);
      case ArNavPhase.endOfKnownRoute:
        return _buildEndOfRoute(gpsStatus);
    }
  }

  ArNavigationSnapshot _computeSeekingTicketCounter(ArGpsStatus gpsStatus) {
    double? dist;
    // This phase (unlike the measured route, which deliberately never uses
    // GPS bearing) DOES have real coordinates for its one anchor — so a live
    // GPS bearing to it is the correct, honest source here. The arrow points
    // at the actual Ticket Counter and swings as the phone rotates, just
    // like the compass-relative arrow once routing starts (see `_liveAngle`).
    double rawAngle = 0;
    if (_deviceLat != null && _deviceLon != null) {
      dist = _haversineMeters(_deviceLat!, _deviceLon!, ticketCounterAnchorLat,
          ticketCounterAnchorLon);
      if (_smoothedHeadingDeg != null) {
        final bearing = _bearingDegrees(_deviceLat!, _deviceLon!,
            ticketCounterAnchorLat, ticketCounterAnchorLon);
        rawAngle = _normalizeAngle(bearing - _smoothedHeadingDeg!);
      }
    }
    final angle = _smoothArrow(rawAngle);

    // Heritage-site presence drives what the visitor is told. `locating` (no
    // trustworthy fix yet) is NEVER reported as `outside` — the UI shows a
    // "Verify again" retry instead.
    final ArSitePresence presence = _computeSitePresence();
    String title = 'Ticket Counter';
    String instruction;
    switch (presence) {
      case ArSitePresence.locating:
        title = 'Confirming location';
        instruction = _deviceLat == null
            ? 'Getting your GPS location — move to open sky if this takes a while.'
            : 'Confirming you are at Sigiriya…';
        break;
      case ArSitePresence.outside:
        title = 'Head to Sigiriya';
        instruction = dist == null
            ? 'You appear to be outside Sigiriya. Travel to the site entrance, then Verify again.'
            : 'You appear to be outside Sigiriya — about ${(dist / 1000).toStringAsFixed(1)} km to the entrance.';
        break;
      case ArSitePresence.inside:
        if (dist != null && dist <= cameraSearchRadiusMeters) {
          instruction =
              'Almost there — point your camera at the Ticket Counter.';
        } else if (dist != null) {
          instruction =
              'You are at Sigiriya — Ticket Counter ${dist.toStringAsFixed(0)} m ahead. Follow the arrow.';
        } else {
          instruction =
              'You are at Sigiriya — follow the arrow to the Ticket Counter.';
        }
        break;
    }

    final detGuidance = _ticketCounterHitStreak > 0
        ? '🎯 Ticket Counter detected — hold steady'
        : '🔍 Scanning for Ticket Counter';

    return ArNavigationSnapshot(
      waypointIndex: -1,
      totalWaypoints: _segments.length,
      waypointTitle: title,
      instruction: instruction,
      distanceMeters: dist ?? 0,
      relativeAngleDeg: angle,
      turnDirection: TurnDirection.none,
      compassHeadingDeg: _smoothedHeadingDeg ?? 0,
      hasGpsFix: _gpsLive,
      hasCompassFix: _compassReady,
      hasArrived: false,
      routeComplete: false,
      detectionGuidance: detGuidance,
      detectionConfirmed: false,
      justArrivedFlash: false,
      gpsStatus: gpsStatus,
      footsteps: const [],
      contextNote: null,
      phase: ArNavPhase.seekingTicketCounter,
      sitePresence: presence,
    );
  }

  /// Is the visitor confirmed to be standing inside the Sigiriya site?
  ///
  ///  * No device fix at all               → `locating`
  ///  * Fix coarser than the trust ceiling → `locating` (never "outside" on a
  ///    bad fix — the entrance sits under tree/rock cover where accuracy is
  ///    routinely poor; the UI offers "Verify again")
  ///  * Within the geofence (radius padded by the fix's own accuracy) → `inside`
  ///  * Otherwise                          → `outside`
  ArSitePresence _computeSitePresence() {
    if (_deviceLat == null || _deviceLon == null)
      return ArSitePresence.locating;
    final acc = _lastGpsAccuracyM ?? 0;
    if (acc > _siteFixTrustAccuracyM) return ArSitePresence.locating;
    final toCenter = _haversineMeters(
        _deviceLat!, _deviceLon!, _siteCenterLat, _siteCenterLon);
    return toCenter <= _siteRadiusM + acc
        ? ArSitePresence.inside
        : ArSitePresence.outside;
  }

  ArNavigationSnapshot _buildTicketCounterConfirmedBanner() {
    final gpsStatus = _currentGpsStatus;
    return ArNavigationSnapshot(
      waypointIndex: 0,
      totalWaypoints: _segments.length,
      waypointTitle: 'Ticket Counter Confirmed',
      instruction: 'Starting the measured walking route.',
      distanceMeters: 0,
      relativeAngleDeg: 0,
      turnDirection: TurnDirection.straight,
      compassHeadingDeg: _smoothedHeadingDeg ?? 0,
      hasGpsFix: _gpsLive,
      hasCompassFix: _compassReady,
      hasArrived: true,
      routeComplete: false,
      detectionGuidance: '✅ Ticket Counter confirmed',
      detectionConfirmed: true,
      justArrivedFlash: true,
      gpsStatus: gpsStatus,
      footsteps: const [],
      contextNote: null,
      phase: ArNavPhase.routing,
    );
  }

  ArNavigationSnapshot _computeRouting(ArGpsStatus gpsStatus) {
    final seg = _segments[_currentSegmentIndex];
    final remaining =
        _clampD(seg.distanceMeters - _walkedInSegment, 0, seg.distanceMeters);
    final arrivalTol = _arrivalTolerance(seg.distanceMeters);
    final prepTol = _prepThreshold(seg.distanceMeters);

    if (remaining <= arrivalTol) {
      final completed = seg;
      _log(
          'waypoint=${completed.number} SEGMENT COMPLETE remaining=${remaining.toStringAsFixed(2)}m '
          'tolerance=${arrivalTol.toStringAsFixed(2)}m '
          'source=$_stepSourceLabel');
      _maybeCalibrateStepLength(completed);
      _advance();
      return _buildSegmentArrival(completed, gpsStatus);
    }

    String? contextNote;
    if (seg.contextDetectionLabel != null) {
      contextNote = _contextSpotted
          ? (seg.contextSpottedNote ??
              '${_labelDisplay(seg.contextDetectionLabel!)} spotted')
          : seg.contextAmbientNote;
    }

    final bool preparing = remaining <= prepTol &&
        (seg.turnAtEnd == TurnDirection.left ||
            seg.turnAtEnd == TurnDirection.right ||
            seg.turnAtEnd == TurnDirection.reverse);

    // Friendly, distance-aware phrasing: always name the direction, and lead
    // with the remaining metres so "In 4 m, turn left" counts the visitor in.
    final int remainingWhole = remaining.round();
    String instruction;
    if (seg.isReturn) {
      instruction = 'Go back — retrace your steps for $remainingWhole m';
    } else if (preparing) {
      instruction = seg.turnAtEnd == TurnDirection.reverse
          ? 'In $remainingWhole m, turn around'
          : 'In $remainingWhole m, turn ${turnDirectionLabel(seg.turnAtEnd).toLowerCase()}';
    } else {
      instruction = 'Continue straight for $remainingWhole m';
    }

    if (gpsStatus == ArGpsStatus.stale) {
      instruction = 'GPS signal lost. Using last known location.';
    } else if (gpsStatus == ArGpsStatus.degraded) {
      instruction = 'GPS accuracy reduced. Waiting for GPS signal.';
    }

    // The arrow + turn icon follow the segment's walking direction (straight,
    // or retrace on a return leg) for most of the segment, then swing to the
    // upcoming turn the moment the "In X m, turn left/right" instruction
    // appears — so the arrow always matches the words on screen instead of
    // only flashing the turn for ~2 s after the segment ends. It settles back
    // to straight on its own once the next segment starts (not preparing).
    final walkDir = seg.walkingDirection;
    final showTurnArrow = preparing && !seg.isReturn;
    final targetDir = showTurnArrow ? seg.turnAtEnd : walkDir;
    final targetAngle = _liveAngle(_angleForDirection(targetDir), walkDir);
    final smoothedAngle = _smoothArrow(targetAngle);
    final footsteps = _buildFootsteps(remaining, walkDir, seg.turnAtEnd);

    _maybeLogRouteState(
        seg, remaining, instruction, targetDir, smoothedAngle, arrivalTol);

    return ArNavigationSnapshot(
      waypointIndex: _currentSegmentIndex,
      totalWaypoints: _segments.length,
      waypointTitle: seg.isReturn ? 'Return Path' : 'Sigiriya Walking Route',
      instruction: instruction,
      distanceMeters: remaining,
      relativeAngleDeg: smoothedAngle,
      turnDirection: targetDir,
      compassHeadingDeg: _smoothedHeadingDeg ?? 0,
      hasGpsFix: _gpsLive,
      hasCompassFix: _compassReady,
      hasArrived: false,
      routeComplete: false,
      detectionGuidance: null,
      detectionConfirmed: false,
      justArrivedFlash: false,
      gpsStatus: gpsStatus,
      footsteps: footsteps,
      contextNote: contextNote,
      phase: ArNavPhase.routing,
    );
  }

  ArNavigationSnapshot _buildSegmentArrival(
      RouteSegment completed, ArGpsStatus gpsStatus) {
    if (_phase == ArNavPhase.endOfKnownRoute) {
      return _buildEndOfRoute(gpsStatus);
    }

    if (completed.landmarkLabel != null) {
      _smoothedArrowAngle = 0;
      return ArNavigationSnapshot(
        waypointIndex: _currentSegmentIndex,
        totalWaypoints: _segments.length,
        waypointTitle: completed.landmarkLabel!,
        instruction: 'You have reached ${completed.landmarkLabel}.',
        distanceMeters: 0,
        relativeAngleDeg: 0,
        turnDirection: TurnDirection.none,
        compassHeadingDeg: _smoothedHeadingDeg ?? 0,
        hasGpsFix: _gpsLive,
        hasCompassFix: _compassReady,
        hasArrived: true,
        routeComplete: false,
        detectionGuidance: null,
        detectionConfirmed: false,
        justArrivedFlash: true,
        gpsStatus: gpsStatus,
        footsteps: const [],
        contextNote: null,
        phase: ArNavPhase.routing,
      );
    }

    final turn = completed.turnAtEnd;
    if (turn == TurnDirection.left ||
        turn == TurnDirection.right ||
        turn == TurnDirection.reverse) {
      final angle = _angleForDirection(turn);
      _smoothedArrowAngle = angle; // snap decisively at the turn instant
      _log(
          'waypoint=${completed.number} instruction=Turn direction=${turn.name} arrowAngle=${angle.toStringAsFixed(0)}°');
      return ArNavigationSnapshot(
        waypointIndex: _currentSegmentIndex,
        totalWaypoints: _segments.length,
        waypointTitle: turn == TurnDirection.reverse
            ? 'Go Back'
            : 'Turn ${turnDirectionLabel(turn)}',
        instruction: turn == TurnDirection.reverse
            ? 'Retrace your steps.'
            : 'Turn ${turnDirectionLabel(turn).toLowerCase()} and continue.',
        distanceMeters: 0,
        relativeAngleDeg: angle,
        turnDirection: turn,
        compassHeadingDeg: _smoothedHeadingDeg ?? 0,
        hasGpsFix: _gpsLive,
        hasCompassFix: _compassReady,
        hasArrived: true,
        routeComplete: false,
        detectionGuidance: null,
        detectionConfirmed: false,
        justArrivedFlash: true,
        gpsStatus: gpsStatus,
        footsteps: const [],
        contextNote: null,
        phase: ArNavPhase.routing,
      );
    }

    // No turn/landmark to announce (straight-through transition) — continue
    // silently into the next segment's normal walking state.
    return _computeRouting(gpsStatus);
  }

  ArNavigationSnapshot _buildEndOfRoute(ArGpsStatus gpsStatus) {
    return ArNavigationSnapshot(
      waypointIndex: _segments.length,
      totalWaypoints: _segments.length,
      waypointTitle: 'End of Mapped Route',
      instruction:
          'You have reached the end of the currently measured route. More segments will be added as they are surveyed.',
      distanceMeters: 0,
      relativeAngleDeg: 0,
      turnDirection: TurnDirection.none,
      compassHeadingDeg: _smoothedHeadingDeg ?? 0,
      hasGpsFix: _gpsLive,
      hasCompassFix: _compassReady,
      hasArrived: false,
      routeComplete: true,
      detectionGuidance: null,
      detectionConfirmed: false,
      justArrivedFlash: false,
      gpsStatus: gpsStatus,
      footsteps: const [],
      contextNote: null,
      phase: ArNavPhase.endOfKnownRoute,
    );
  }

  // ── Compass-fused pointing angle ─────────────────────────────────────────
  /// Converts a "legacy" turn-only screen angle (the flat 0/±90/180 values
  /// `_angleForDirection` returns) into one that also tracks how far the
  /// visitor has physically rotated the phone away from this segment's
  /// locked heading reference — the live "AR" part of the arrow, the same
  /// way a real walking-nav app's arrow swings as you turn around. Before
  /// the reference locks (see `_segmentHeadingLockDelayMs`) this is a
  /// no-op and returns [legacyAngle] unchanged.
  double _liveAngle(double legacyAngle, TurnDirection walkingDir) {
    if (_segmentReferenceBearing == null || _smoothedHeadingDeg == null) {
      return legacyAngle;
    }
    final legacyWalkAngle = _angleForDirection(walkingDir);
    final compassForward =
        _normalizeAngle(_segmentReferenceBearing! - _smoothedHeadingDeg!);
    return _normalizeAngle(legacyAngle + (compassForward - legacyWalkAngle));
  }

  // ── Arrow smoothing ────────────────────────────────────────────────────────
  double _smoothArrow(double targetAngle) {
    if (_smoothedArrowAngle == null) {
      _smoothedArrowAngle = targetAngle;
    } else {
      final diff = _normalizeAngle(targetAngle - _smoothedArrowAngle!);
      _smoothedArrowAngle =
          _normalizeAngle(_smoothedArrowAngle! + diff * _arrowSmoothingAlpha);
    }
    return _smoothedArrowAngle!;
  }

  // ── Footstep generation ────────────────────────────────────────────────────
  // Footsteps are a purely visual aid: they curve gradually toward the
  // upcoming turn as the visitor gets closer to it, and never affect GPS
  // distance accumulation.
  List<ArFootstep> _buildFootsteps(
      double remaining, TurnDirection walkingDir, TurnDirection turnAtEnd) {
    if (remaining <= 5.0) return const [];
    final preview = math.min(remaining, 40.0);
    // Compass-fused, matching the arrow (see `_liveAngle`) — so the whole
    // breadcrumb trail rotates together with the arrow as the phone turns,
    // rather than the two visually disagreeing with each other.
    final walkAngle = _liveAngle(_angleForDirection(walkingDir), walkingDir);
    final turnAngle = _liveAngle(_angleForDirection(turnAtEnd), walkingDir);

    final steps = <ArFootstep>[];
    for (double d = 5.0; d < preview; d += 5.0) {
      if (steps.length >= 10) break;
      double angle;
      if (walkingDir == TurnDirection.reverse) {
        angle = walkAngle; // constant, no curve while retracing
      } else {
        final curveFactor = _clampD(d / preview, 0.0, 1.0);
        angle = walkAngle + (turnAngle - walkAngle) * curveFactor;
      }
      steps.add(ArFootstep(distanceMeters: d, relativeAngleDeg: angle));
    }
    return steps;
  }

  // ── Timing thresholds ─────────────────────────────────────────────────────
  static double _arrivalTolerance(double segLen) {
    if (segLen <= 5.0) return _clampD(segLen * 0.35, 0.4, 1.8);
    return _clampD(segLen * 0.12, 1.2, 3.0);
  }

  static double _prepThreshold(double segLen) {
    final arr = _arrivalTolerance(segLen);
    final raw = segLen * 0.4;
    return _clampD(raw, arr + 0.5, 6.0);
  }

  // ── Debug logging ─────────────────────────────────────────────────────────
  void _maybeLogRouteState(
      RouteSegment seg,
      double remaining,
      String instruction,
      TurnDirection dir,
      double arrowAngle,
      double tolerance) {
    if (_lastLoggedSegmentIndex == _currentSegmentIndex &&
        _lastLoggedInstruction == instruction) {
      return;
    }
    _lastLoggedSegmentIndex = _currentSegmentIndex;
    _lastLoggedInstruction = instruction;
    _log(
        'waypoint=${seg.number} instruction=$instruction segment=${seg.distanceMeters.toStringAsFixed(2)}m '
        'walked=${_walkedInSegment.toStringAsFixed(2)}m remaining=${remaining.toStringAsFixed(2)}m '
        'direction=${dir.name} arrowAngle=${arrowAngle.toStringAsFixed(0)}° '
        'tolerance=${tolerance.toStringAsFixed(2)}m '
        'source=$_stepSourceLabel '
        'steps=$_stepsInSegment stepLength=${_calibratedStepLength.toStringAsFixed(3)}m '
        'gpsWalked(validationOnly)=${_gpsWalkedInSegment.toStringAsFixed(2)}m '
        'accelMotion=${_motionGate.isActive} gyroRotation=${_rotationGate.isActive}');
  }

  void _log(String message) => debugPrint('[AR NAV] $message');

  // ── Math helpers ───────────────────────────────────────────────────────────

  static double _clampD(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

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

  /// Initial great-circle bearing from point 1 to point 2, 0..360° (0 = due
  /// north). Only ever used for the Ticket Counter anchor above, which is a
  /// real fixed coordinate — never for the measured route itself.
  static double _bearingDegrees(
      double lat1, double lon1, double lat2, double lon2) {
    final phi1 = _rad(lat1);
    final phi2 = _rad(lat2);
    final dLon = _rad(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
    return _normalizeTo360(math.atan2(y, x) * 180.0 / math.pi);
  }

  /// Normalise angle to [−180, +180], always taking the shortest rotation.
  static double _normalizeAngle(double deg) {
    double a = deg % 360;
    if (a > 180) a -= 360;
    if (a < -180) a += 360;
    return a;
  }

  static double _normalizeTo360(double deg) {
    double a = deg % 360;
    if (a < 0) a += 360;
    return a;
  }

  /// Circular-aware smoothing: handles the 359° → 0° wrap as a small step.
  static double _smoothCircular(double current, double target, double alpha) {
    final diff = _normalizeAngle(target - current);
    return _normalizeTo360(current + diff * alpha);
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  String _labelDisplay(String label) {
    return label
        .replaceAll('sigiriya_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Reset the service back to the start (useful for re-entry).
  void reset() {
    _phase = ArNavPhase.seekingTicketCounter;
    _currentSegmentIndex = 0;
    _compassReady = false;
    _smoothedHeadingDeg = null;
    _segmentReferenceBearing = null;
    _segmentStartTime = null;
    _lastGpsUpdateMs = 0;
    _gpsLive = true;
    _deviceLat = null;
    _deviceLon = null;
    _lastGpsAccuracyM = null;
    _headingDeg = null;
    _smoothedArrowAngle = null;
    _lastAcceptedLat = null;
    _lastAcceptedLon = null;
    _lastAcceptedTime = null;
    _walkedInSegment = 0;
    _ticketCounterHitStreak = 0;
    _gpsArrivalStreak = 0;
    _contextHitStreak = 0;
    _contextSpotted = false;
    _lastLoggedSegmentIndex = null;
    _lastLoggedInstruction = null;
    _nativeStepSensorActive = false;
    _calibratedStepLength = _defaultStepLengthM;
    _calibrationStepCount = 0;
    _calibrationComplete = false;
    _lastStepEventTime = null;
    _resetStepSegmentState();
    _motionGate.reset();
    _rotationGate.reset();
    _pedometerGateGraceDeadline = null;
    _accelSmoothingBuffer.clear();
    _pedometerArmed = true;
    _lastSoftwareStepTime = null;
  }
}
