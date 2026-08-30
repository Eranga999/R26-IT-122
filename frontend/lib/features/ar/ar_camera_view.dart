import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show EventChannel, HapticFeedback;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../database/landmark_model.dart';
import '../database/sub_landmark_model.dart';
import '../database/database_helper.dart';
import '../recognition/recognition_service.dart';
import '../../core/theme/app_theme.dart';
import '../rag/rag_screen.dart';
import '../home/home_screen.dart' show LandmarkDetailScreen;
import '../../core/location/site_lock_service.dart';
import 'ar_navigation_service.dart';

enum ArGpsFailure { none, serviceDisabled, permissionDenied, permissionDeniedForever }

/// Live-camera AR overlay view.
///
/// For Sigiriya: provides full camera-based AR waypoint navigation. Walking
/// distance is estimated from accelerometer/gyroscope/step sensors (see
/// ArNavigationService); GPS + compass + YOLO landmark confirmation handle
/// everything else (Ticket Counter direction, arrow orientation, detection).
///
/// For other sites: shows the original hotspot/info-panel overlay.
class ArCameraView extends StatefulWidget {
  final LandmarkModel landmark;

  const ArCameraView({super.key, required this.landmark});

  @override
  State<ArCameraView> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCameraView>
    with TickerProviderStateMixin {
  // ── Camera ───────────────────────────────────────────────────────────────
  CameraController? _controller;
  String? _error;

  // ── Sub-landmarks (non-Sigiriya overlay) ─────────────────────────────────
  List<SubLandmarkModel> _subLandmarks = [];
  bool _overlayVisible = false;
  bool _infoPanelExpanded = false;
  int _selectedHotspot = -1;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _scanAnim;
  late final AnimationController _pulseAnim;
  late final AnimationController _fadeAnim;
  late final Animation<double> _fadeIn;

  // ── AR Navigation (Sigiriya only) ─────────────────────────────────────────
  bool get _isSigiriya =>
      widget.landmark.name.toLowerCase().contains('sigiriya');

  final ArNavigationService _navService = ArNavigationService();
  ArNavigationSnapshot? _navSnapshot;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;

  // Feed ArNavigationService's sensor-fused distance estimator — GPS is
  // validation-only there; these two streams (plus native step events
  // below) are what actually drive the route countdown. See
  // ArNavigationService's "Distance estimation" doc for the full picture.
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // ── Step-based segment progress ─────────────────────────────────────────
  // Android: raw TYPE_STEP_DETECTOR events (see `_startStepDetection` for
  // why this bypasses the pedometer package's own debounced Dart stream).
  // iOS: the package's documented cumulative stepCountStream (CMPedometer).
  StreamSubscription? _stepDetectionSub;
  StreamSubscription<StepCount>? _stepCountSub;

  // Frame throttle for YOLO in nav mode
  bool _isProcessingFrame = false;
  int _lastFrameMs = 0;
  // 200 ms (5 fps) – enough for smooth box updates without overwhelming the isolate.
  static const int _frameThrottleMs = 200;
  List<DetectionResult> _liveDetections = [];

  // ── Nav-mode bounding-box smoothing & stale-box timeout ────────────────
  Rect? _smoothedNavBox;
  int _lastNavDetectionMs = 0;
  /// 0.35 → 35% toward new position per frame – glides without snapping.
  static const double _navBoxAlpha = 0.35;
  /// After 1 s with no detection the box is cleared to avoid stale ghosts.
  static const int _navBoxHoldMs = 1000;


  // GPS accuracy warning
  double? _gpsAccuracyM;
  ArGpsFailure _gpsFailure = ArGpsFailure.none;
  bool _reverifying = false; // a "Verify again" location re-check is in flight

  // ── Arrival/turn banner hold ────────────────────────────────────────────
  // The nav snapshot stream can tick many times per second (compass events
  // alone fire fast), so a justArrivedFlash snapshot is only ever "current"
  // for a single tick. Latch it locally for a couple of seconds so the user
  // actually gets to read "Turn Right" / "Sinhapadaya" / etc.
  String? _flashBannerTitle;
  Timer? _flashBannerTimer;

  // ── Opportunistic landmark popup (bounding box + info card) ─────────────
  // Same stable-detection pattern as camera_screen.dart's scan mode: a
  // detection must clear a confidence bar for several consecutive frames
  // before it earns a popup, so a single noisy frame can't flash one in.
  // This is purely informational — it never feeds route progression, which
  // stays driven only by ArNavigationService's own segment-scoped matching.
  String? _arCandidateLabel;
  int _arCandidateCount = 0;
  int _arLastConfirmedTime = 0;
  static const double _arCardThreshold = 0.78;
  static const int _arRequiredFrames = 3;
  static const int _arPopupHoldMs = 6000;
  DetectionResult? _arPopupDetection;

  // ── Arrow .glb load tracking ─────────────────────────────────────────────
  // model_viewer_plus's WebView can silently fail to render on some devices
  // (blocked loopback socket, WebView quirks, etc.) with no visible error —
  // that's what left the arrow spot blank before. A fallback Material icon
  // arrow is shown by default and only fades out once the model's own JS
  // 'load' event actually fires (see _buildArrowModel/_onArrowModelStatus),
  // so navigation is never left with nothing on screen.
  bool _arrowModelReady = false;
  Timer? _arrowModelTimeoutTimer;

  @override
  void initState() {
    super.initState();

    _scanAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    _pulseAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _fadeAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeIn = CurvedAnimation(parent: _fadeAnim, curve: Curves.easeIn);

    _initCamera();
    if (_isSigiriya) {
      _configureSiteGeofence();
      _startNavigation();
      _arrowModelTimeoutTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_arrowModelReady) {
          debugPrint('[AR NAV] Arrow .glb did not report a load event within '
              '5s — staying on the fallback icon arrow.');
        }
      });
    } else {
      _loadSubLandmarks();
      // Legacy simulated lock-on for non-Sigiriya sites
      Future.delayed(const Duration(seconds: 2), _showOverlay);
    }
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});

      if (_isSigiriya) {
        // Start YOLO image stream for navigation detection
        _controller!.startImageStream(_processNavFrame);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: ${e.toString()}');
    }
  }

  // ── Navigation Startup ────────────────────────────────────────────────────

  void _retryGps() {
    if (mounted) {
      setState(() => _gpsFailure = ArGpsFailure.none);
      _startNavigation();
    }
  }

  /// Pull the Sigiriya geofence (centre + radius) from the same
  /// assets/config/landmark_sites.json every other screen uses, so the
  /// "are you at Sigiriya?" check has one source of truth.
  Future<void> _configureSiteGeofence() async {
    try {
      final sites = await SiteLockService.instance.loadSites();
      final match = sites.where(
          (s) => s.landmarkName.toLowerCase().contains('sigiriya'));
      if (match.isNotEmpty) {
        final s = match.first;
        _navService.configureSiteGeofence(
          lat: s.centerLat,
          lon: s.centerLng,
          radiusMeters: s.radiusMeters,
        );
      }
    } catch (_) {
      // Keep the service's built-in defaults.
    }
  }

  /// "Verify again" — force one fresh high-accuracy fix and feed it straight
  /// into the nav service so the site-presence state re-evaluates now instead
  /// of waiting for the next stream tick.
  Future<void> _reverify() async {
    if (_reverifying) return;
    setState(() => _reverifying = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      _gpsAccuracyM = pos.accuracy;
      _applySnapshot(_navService.onGpsUpdate(
        pos.latitude,
        pos.longitude,
        accuracyMeters: pos.accuracy,
      ));
    } catch (_) {
      // The live position stream keeps running; leave it to recover.
    } finally {
      if (mounted) setState(() => _reverifying = false);
    }
  }

  Future<void> _startNavigation() async {
    if (!mounted) return;
    setState(() => _gpsFailure = ArGpsFailure.none);

    // --- GPS stream ---
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsFailure = ArGpsFailure.serviceDisabled);
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    
    if (perm == LocationPermission.denied) {
      if (mounted) setState(() => _gpsFailure = ArGpsFailure.permissionDenied);
      return;
    } else if (perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsFailure = ArGpsFailure.permissionDeniedForever);
      return;
    }

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen(
      (pos) {
        _gpsAccuracyM = pos.accuracy;
        final snap = _navService.onGpsUpdate(
          pos.latitude,
          pos.longitude,
          accuracyMeters: pos.accuracy,
        );
        _applySnapshot(snap);
      },
      onError: (dynamic error) {
        _navService.onGpsLost();
        if (mounted) {
          setState(() {
            _gpsFailure = ArGpsFailure.serviceDisabled;
          });
        }
      },
    );

    // --- Compass stream ---
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null && heading.isFinite) {
        final snap = _navService.onHeadingUpdate(heading);
        _applySnapshot(snap);
      }
    });

    // --- Accelerometer + gyroscope: the software pedometer ---
    // No permission or async setup needed (raw motion sensors, unlike the
    // step counter, don't require ACTIVITY_RECOGNITION) — start immediately
    // so this is warm from segment 1, before native step events (if any)
    // ever arrive. This — not GPS — is what drives the route countdown
    // until/unless the native step sensor below proves itself; see
    // ArNavigationService's "Distance estimation" doc for the full picture.
    // gameInterval (~50Hz) rather than the coarser uiInterval: a real
    // peak-detection pedometer needs enough samples per stride to resolve
    // the step waveform, not just a coarse "is it moving" read.
    _userAccelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) {
        final snap = _navService.onAccelerometerSample(event.x, event.y, event.z);
        if (snap != null) _applySnapshot(snap);
      },
      onError: (dynamic _) {}, // sensor unavailable on this device — pedometer gate degrades gracefully (see _gateSatisfied)
      cancelOnError: true,
    );
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) => _navService.onGyroscopeSample(event.x, event.y, event.z),
      onError: (dynamic _) {}, // same graceful degradation as the accelerometer above
      cancelOnError: true,
    );

    // Ensure model is loaded
    RecognitionService.instance.loadModel();

    // Native step sensor — preferred once it proves itself, but the
    // software pedometer above is already driving progress from segment 1,
    // so there's no gap to fall back into if this permission is denied or
    // the platform sensor is missing (see enableStepMode's doc).
    unawaited(_startStepDetection());
  }

  // ── Step-based segment progress ─────────────────────────────────────────

  Future<void> _startStepDetection() async {
    var status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      status = await Permission.activityRecognition.request();
    }
    if (!status.isGranted) {
      debugPrint('[AR NAV] Activity recognition permission denied — '
          'staying on the software pedometer (accelerometer/gyroscope).');
      return;
    }
    if (!mounted) return;

    if (Platform.isAndroid) {
      // The pedometer package's own `pedestrianStatusStream` debounces
      // Android's raw per-step TYPE_STEP_DETECTOR events into a coarse
      // walking/stopped state (confirmed by reading its native source) —
      // exactly the granularity this app can't use for several segments
      // that are only a handful of steps long. Its native plugin already
      // registers an EventChannel('step_detection') wired directly to
      // TYPE_STEP_DETECTOR (one event per physical step); listening to it
      // directly here gets genuine per-step events without any new native
      // code. If a future pedometer version renames this internal channel,
      // this simply stops receiving events and the app stays on the
      // software pedometer — see the fallback note above.
      const rawStepChannel = EventChannel('step_detection');
      _stepDetectionSub = rawStepChannel.receiveBroadcastStream().listen(
        (_) => _onStepEvent(),
        onError: (dynamic _) {}, // sensor unavailable on this device — stay on the software pedometer
        cancelOnError: true,
      );
    } else {
      // iOS: CMPedometer's raw event stream reports pause/resume type
      // codes, not per-step events, so per-step counting isn't meaningful
      // there — drive progress from the documented cumulative stream
      // instead (still far better than nothing, just not per-step latency).
      int? lastCount;
      _stepCountSub = Pedometer.stepCountStream.listen(
        (event) {
          final prev = lastCount;
          lastCount = event.steps;
          if (prev == null) return; // first reading is just a baseline
          final delta = event.steps - prev;
          for (var i = 0; i < delta; i++) {
            _onStepEvent();
          }
        },
        onError: (dynamic _) {},
        cancelOnError: true,
      );
    }

    // Cumulative counter, on Android too — debug/reconciliation only, never
    // drives the countdown itself (see ArNavigationService.onStepCountUpdate).
    if (Platform.isAndroid) {
      _stepCountSub = Pedometer.stepCountStream.listen(
        (event) => _applySnapshot(_navService.onStepCountUpdate(event.steps)),
        onError: (dynamic _) {},
        cancelOnError: true,
      );
    }
  }

  bool _stepModeAnnounced = false;

  void _onStepEvent() {
    if (!mounted) return;
    if (!_stepModeAnnounced) {
      _stepModeAnnounced = true;
      _navService.enableStepMode();
    }
    _applySnapshot(_navService.onStepDetected());
  }

  // ── YOLO Frame Processing (nav mode, throttled) ────────────────────────────

  Future<void> _processNavFrame(CameraImage image) async {
    if (!_isSigiriya) return;
    if (_isProcessingFrame) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < _frameThrottleMs) return;

    final snap = _navSnapshot;
    if (snap == null || snap.routeComplete) return;

    // Before the Ticket Counter is confirmed only that one class is scanned
    // for; once the measured route is underway every known class is scanned
    // opportunistically so any landmark the camera sees can surface a
    // bounding box + info popup, matching camera_screen.dart's scan mode.
    final activeLabels = _navService.activeYoloLabels;
    if (activeLabels.isEmpty) return;

    _isProcessingFrame = true;
    _lastFrameMs = now;

    try {
      final results = await RecognitionService.instance.predictAll(
        image,
        sensorOrientation: _controller?.description.sensorOrientation ?? 0,
        threshold: 0.70,
        nmsIouThreshold: 0.45,
        allowedLabels: activeLabels,
      );

      if (!mounted) return;

      if (results.isEmpty) {
        // ── No detection ────────────────────────────────────────────────
        final staleMs = now - _lastNavDetectionMs;
        if (staleMs > _navBoxHoldMs) {
          // Box has been empty long enough – clear it so it doesn’t ghost.
          if (mounted && _liveDetections.isNotEmpty) {
            setState(() {
              _liveDetections = const [];
              _smoothedNavBox = null;
            });
          }
        }
        _arCandidateCount = 0;
        _arCandidateLabel = null;
        if (_arPopupDetection != null && now - _arLastConfirmedTime > _arPopupHoldMs) {
          _dismissArPopup();
        }
        final s = _navService.onDetectionUpdate(
          label: null,
          confidence: 0,
          bboxCenterX: null,
          bboxCenterY: null,
        );
        _applySnapshot(s);
      } else {
        // ── Live detection ─────────────────────────────────────────────
        _lastNavDetectionMs = now;
        final best =
            results.reduce((a, b) => a.confidence > b.confidence ? a : b);

        // Exponential smoothing on the box position to reduce jitter.
        final ref = best.boundingBox;
        _smoothedNavBox = _smoothedNavBox == null
            ? ref
            : Rect.fromLTRB(
                _smoothedNavBox!.left   * (1 - _navBoxAlpha) + ref.left   * _navBoxAlpha,
                _smoothedNavBox!.top    * (1 - _navBoxAlpha) + ref.top    * _navBoxAlpha,
                _smoothedNavBox!.right  * (1 - _navBoxAlpha) + ref.right  * _navBoxAlpha,
                _smoothedNavBox!.bottom * (1 - _navBoxAlpha) + ref.bottom * _navBoxAlpha,
              );

        final smoothedBest = DetectionResult(
          label: best.label,
          confidence: best.confidence,
          boundingBox: _smoothedNavBox!,
          classIndex: best.classIndex,
        );

        final cx = _smoothedNavBox!.left + _smoothedNavBox!.width / 2;
        final cy = _smoothedNavBox!.top + _smoothedNavBox!.height / 2;

        setState(() => _liveDetections = [smoothedBest]);
        _updateArPopup(smoothedBest, now);

        final s = _navService.onDetectionUpdate(
          label: best.label,
          confidence: best.confidence,
          bboxCenterX: cx,
          bboxCenterY: cy,
        );
        _applySnapshot(s);
      }
    } catch (_) {
      // ignore inference errors; keep navigating
    } finally {
      if (mounted) {
        _isProcessingFrame = false;
      }
    }
  }

  // ── Opportunistic landmark popup ────────────────────────────────────────

  /// Requires [_arRequiredFrames] consecutive frames above [_arCardThreshold]
  /// for the SAME class before it counts as stable — one noisy frame can
  /// show a bounding box, but never a popup card.
  bool _isArDetectionStable(DetectionResult best) {
    if (best.confidence < _arCardThreshold) {
      _arCandidateCount = 0;
      return false;
    }
    if (best.label == _arCandidateLabel) {
      _arCandidateCount++;
    } else {
      _arCandidateLabel = best.label;
      _arCandidateCount = 1;
    }
    return _arCandidateCount >= _arRequiredFrames;
  }

  void _updateArPopup(DetectionResult best, int now) {
    if (_isArDetectionStable(best)) {
      _arLastConfirmedTime = now;
      final isNew = _arPopupDetection == null || _arPopupDetection!.label != best.label;
      if (isNew) {
        setState(() => _arPopupDetection = best);
        HapticFeedback.mediumImpact();
      } else {
        _arPopupDetection = best; // refresh confidence/box without a full rebuild
      }
    } else if (_arPopupDetection != null &&
        now - _arLastConfirmedTime > _arPopupHoldMs) {
      _dismissArPopup();
    }
  }

  void _dismissArPopup() {
    if (_arPopupDetection == null) return;
    setState(() => _arPopupDetection = null);
    _arCandidateCount = 0;
    _arCandidateLabel = null;
  }

  /// e.g. 'sigiriya_lion_rock' → 'Lion Rock'
  String _classLabelToDisplayName(String label) {
    final normalized = label.trim().toLowerCase();
    const nameMap = {
      'sigiriya_lion_paws': 'Lion Paws',
      'sigiriya_lion_rock': 'Lion Rock',
      'sigiriya_mirror_wall': 'Mirror Wall',
      'sigiriya_throne': 'Throne',
      'sigiriya_ticket_counter': 'Ticket Counter',
    };
    if (nameMap.containsKey(normalized)) return nameMap[normalized]!;
    final parts = normalized.replaceFirst('sigiriya_', '').split('_');
    return parts
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  // ── Legacy sub-landmark helper ────────────────────────────────────────────

  Future<void> _loadSubLandmarks() async {
    final subs =
        await DatabaseHelper.instance.getSubLandmarks(widget.landmark.id ?? 1);
    if (mounted) setState(() => _subLandmarks = subs);
  }

  void _showOverlay() {
    if (!mounted) return;
    setState(() => _overlayVisible = true);
    _fadeAnim.forward();
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _pulseAnim.dispose();
    _fadeAnim.dispose();
    _controller?.dispose();
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _stepDetectionSub?.cancel();
    _stepCountSub?.cancel();
    _userAccelSub?.cancel();
    _gyroSub?.cancel();
    _arrowModelTimeoutTimer?.cancel();
    _flashBannerTimer?.cancel();
    super.dispose();
  }

  // ── Nav snapshot application (latches justArrivedFlash banners) ───────────

  void _applySnapshot(ArNavigationSnapshot snap) {
    if (snap.justArrivedFlash && snap.hasArrived) {
      _flashBannerTitle = snap.waypointTitle;
      _flashBannerTimer?.cancel();
      _flashBannerTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _flashBannerTitle = null);
      });
    }
    if (mounted) setState(() => _navSnapshot = snap);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isSigiriya) return _buildNavMode();
    return _buildLegacyMode();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AR NAVIGATION MODE (Sigiriya)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNavMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          _buildNavOverlay(),
          _buildNavTopBar(),
        ],
      ),
    );
  }

  Widget _buildNavOverlay() {
    if (_gpsFailure != ArGpsFailure.none) {
      return _buildGpsFailureOverlay();
    }

    final snap = _navSnapshot;

    // Waiting for GPS
    if (snap == null) {
      return _centeredMessage(
        icon: Icons.gps_not_fixed_rounded,
        color: Colors.blueGrey,
        title: 'Waiting for GPS fix',
        subtitle: 'Please move to an open area for a better signal.',
      );
    }

    // Route complete
    if (snap.routeComplete) {
      return _buildRouteCompleteOverlay();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Live detection overlay HUD
        if (_liveDetections.isNotEmpty)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DetectionOverlayPainter(
                  detections: _liveDetections,
                  previewSize: _controller?.value.previewSize,
                  sensorOrientation: _controller?.description.sensorOrientation ?? 0,
                ),
              ),
            ),
          ),
        // Main HUD — always shown, including while a turn banner is up, so
        // the arrow visibly agrees with "Turn Left" instead of vanishing
        // behind it for ~2s (which was the arrow feeling disconnected from
        // the instruction it's supposed to be illustrating).
        _buildArNavHud(snap),

        // Arrival / turn banner — a slim strip near the top (Google Maps'
        // turn-by-turn style), latched briefly so it's actually readable,
        // layered on top WITHOUT covering the arrow underneath it.
        if (_flashBannerTitle != null) _buildArrivedBanner(_flashBannerTitle!),

        // Opportunistic landmark info popup (bounding box already drawn above)
        _buildArDetectionPopup(),

        // GPS weak accuracy warning
        if (_gpsAccuracyM != null && _gpsAccuracyM! > 20 && snap.gpsStatus == ArGpsStatus.live)
          _buildGpsWarning(),

        // GPS disconnected warnings
        if (snap.gpsStatus == ArGpsStatus.stale)
          _buildGpsWarningBanner('GPS signal lost. Using last known location.', Colors.amber.shade800)
        else if (snap.gpsStatus == ArGpsStatus.degraded)
          _buildGpsWarningBanner('GPS accuracy reduced. Waiting for GPS signal.', Colors.deepOrange),
          
        // Manual Selection (Simulation) — only once a fix confirms the
        // visitor really is outside Sigiriya (never on a not-yet-acquired fix).
        if (snap.phase == ArNavPhase.seekingTicketCounter &&
            snap.sitePresence == ArSitePresence.outside)
          _buildManualSelectionBanner(),
      ],
    );
  }

  Widget _buildManualSelectionBanner() {
    return Positioned(
      top: 150,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: _showManualWaypointSelector,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.teal.shade700.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Far from the site? Tap to simulate the walking route.',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14)
            ],
          ),
        ),
      ),
    );
  }

  void _showManualWaypointSelector() {
    final segments = _navService.segments;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFF1A0A00),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Manual Navigation Simulation',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Jump directly to a measured segment to test turn instructions without physically walking.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: segments.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 18),
                      ),
                      title: const Text(
                        'Confirm Ticket Counter & start route',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Skip GPS search and begin at Segment 1',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(context);
                        _applySnapshot(_navService.simulateTicketCounterConfirmed());
                      },
                    );
                  }
                  final seg = segments[i - 1];
                  final label = seg.isReturn
                      ? 'Segment ${seg.number} · Return ${seg.distanceMeters.toStringAsFixed(2)} m'
                      : 'Segment ${seg.number} · ${seg.distanceMeters.toStringAsFixed(2)} m';
                  final subtitle = seg.landmarkLabel ??
                      (seg.turnAtEnd == TurnDirection.straight
                          ? 'Continue straight'
                          : 'Turn ${turnDirectionLabel(seg.turnAtEnd)}');
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade700,
                      child: Text('${seg.number}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    title: Text(label,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      _applySnapshot(_navService.simulateJumpToSegment(seg.number));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsFailureOverlay() {
    IconData icon;
    String title;
    String subtitle;
    String btnLabel;
    VoidCallback onBtn;

    switch (_gpsFailure) {
      case ArGpsFailure.serviceDisabled:
        icon = Icons.location_off_rounded;
        title = 'Location Services Disabled';
        subtitle = 'Turn on GPS to use AR navigation.';
        btnLabel = 'Open location settings';
        onBtn = () async {
          await Geolocator.openLocationSettings();
        };
        break;
      case ArGpsFailure.permissionDenied:
        icon = Icons.gps_off_rounded;
        title = 'Location Permission Denied';
        subtitle = 'Allow location access to place AR waypoints.';
        btnLabel = 'Try again';
        onBtn = _retryGps;
        break;
      case ArGpsFailure.permissionDeniedForever:
        icon = Icons.error_outline_rounded;
        title = 'Location Permission Denied';
        subtitle = 'Please enable location permissions in your device settings.';
        btnLabel = 'Open app settings';
        onBtn = () async {
          await Geolocator.openAppSettings();
        };
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.orange, size: 48),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              onBtn();
              if (_gpsFailure != ArGpsFailure.permissionDenied) {
                Future.delayed(const Duration(milliseconds: 1500), _retryGps);
              }
            },
            icon: const Icon(Icons.settings_rounded),
            label: Text(btnLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Opportunistic landmark popup card ───────────────────────────────────

  Widget _buildArDetectionPopup() {
    final det = _arPopupDetection;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 172,
      child: IgnorePointer(
        ignoring: det == null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: det == null
              ? const SizedBox.shrink(key: ValueKey('ar-popup-empty'))
              : _buildArDetectionPopupCard(det, key: ValueKey('ar-popup-${det.label}')),
        ),
      ),
    );
  }

  Widget _buildArDetectionPopupCard(DetectionResult det, {Key? key}) {
    final displayName = _classLabelToDisplayName(det.label);
    return Material(
      key: key,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.72), Colors.black.withOpacity(0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFB300).withOpacity(0.25),
                        const Color(0xFFFF8F00).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: Color(0xFFFFB300), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(det.confidence * 100).toStringAsFixed(0)}% match',
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _arPopupIconButton(
                  icon: Icons.smart_toy_rounded,
                  tooltip: 'Ask AI',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RagScreen(landmarkName: widget.landmark.name)),
                  ),
                ),
                const SizedBox(width: 6),
                _arPopupIconButton(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Details',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LandmarkDetailScreen(
                        landmark: widget.landmark,
                        highlightSubLandmarkLabel: det.label,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _dismissArPopup,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arPopupIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      ),
    );
  }

  Widget _buildArNavHud(ArNavigationSnapshot snap) {
    final size = MediaQuery.of(context).size;
    // The direction arrow is now always on screen (Google Maps never hides
    // its walking puck either) — it just sits neutral/straight before the
    // Ticket Counter is confirmed, with a small hint badge underneath
    // instead of swapping out for an unrelated icon.
    final isSeekingTicketCounter = snap.phase == ArNavPhase.seekingTicketCounter;
    return Stack(
      children: [
        // ── AR Virtual Breadcrumbs (Footsteps) ─────────────────────────────
        Positioned(
          top: size.height * 0.35,
          left: 0,
          right: 0,
          child: _buildFootstepsOverlay(snap),
        ),

        // ── Big directional arrow (3D model) ────────────────────────────────
        Positioned(
          top: size.height * 0.35, // Moved down to simulate ground projection
          left: 0,
          right: 0,
          child: Column(
            children: [
              _buildDirectionArrow(snap),
              const SizedBox(height: 24),
              if (isSeekingTicketCounter)
                _buildSeekHint(snap)
              else if (!snap.hasCompassFix)
                _buildCalibrationHint(),
            ],
          ),
        ),

        // ── Bottom HUD panel ───────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomHudPanel(snap),
        ),
      ],
    );
  }

  /// Seek-phase hint above the arrow. Keyed off `snap.sitePresence`:
  ///  * inside  → green "You're at Sigiriya" confirmation (or the pulsing
  ///    camera-search prompt once within `cameraSearchRadiusMeters`)
  ///  * locating→ neutral "Confirming you're at Sigiriya…" + Verify again
  ///  * outside → amber "You appear to be outside Sigiriya" + Verify again
  Widget _buildSeekHint(ArNavigationSnapshot snap) {
    if (snap.sitePresence == ArSitePresence.inside) {
      final bool cameraTier = snap.distanceMeters > 0 &&
          snap.distanceMeters <= ArNavigationService.cameraSearchRadiusMeters;
      if (cameraTier) return _buildTicketCounterSearchHint();
      return _seekChip(
        tint: Colors.greenAccent,
        icon: Icons.verified_rounded,
        text: "You're in the Sigiriya heritage site",
      );
    }

    final bool outside = snap.sitePresence == ArSitePresence.outside;
    return _seekChip(
      tint: outside ? Colors.orangeAccent : Colors.lightBlueAccent,
      icon: outside ? Icons.wrong_location_rounded : Icons.my_location_rounded,
      text: outside
          ? 'You appear to be outside Sigiriya'
          : 'Confirming you’re at Sigiriya…',
      showVerify: true,
    );
  }

  Widget _seekChip({
    required Color tint,
    required IconData icon,
    required String text,
    bool showVerify = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          if (showVerify) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _reverifying ? null : _reverify,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tint.withOpacity(0.6)),
                ),
                child: _reverifying
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Verify again',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketCounterSearchHint() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withOpacity(0.12 + _pulseAnim.value * 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.tealAccent.withOpacity(0.35 + _pulseAnim.value * 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_rounded, color: Colors.tealAccent, size: 14),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Point your camera at the Ticket Counter',
                style: TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFootstepsOverlay(ArNavigationSnapshot snap) {
    if (snap.footsteps.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 240, // Match the arrow's anchor box
      child: Stack(
        alignment: Alignment.center,
        children: snap.footsteps.map((step) {
          // Normalize distance: translating negatively in Y moves "forward" in the ground plane
          final double depthShift = -(step.distanceMeters * 12.0); // 1 meter = 12 virtual pixels

          // Direction comes from the measured route's TurnDirection, not the
          // compass — so it stays meaningful even before compass calibrates.
          final angle = step.relativeAngleDeg * math.pi / 180.0;

          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0025) // Ground perspective tilt
            ..rotateX(1.1)           // Lay flat
            ..rotateZ(angle)         // Swivel to target bearing
            ..translate(0.0, depthShift, 0.0); // Move "forward" away from player

          // Fade out based on distance so they vanish beautifully into the distance
          final double rawOpacity = 1.0 - (step.distanceMeters / 40.0);
          final double opacity = rawOpacity.clamp(0.0, 0.5); // Max 50% opacity
          
          if (opacity <= 0.0) return const SizedBox.shrink();

          return Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_arrow_up_rounded, // Chevron footprint
              size: 54,
              color: const Color(0xFFFFB300).withOpacity(opacity),
            ),
          );
        }).toList(),
      ),
    );
  }

  // The real .glb arrow model, offline-rendered via a local WebView. Its own
  // orientation/rotation attributes can't be updated live after load (a
  // limitation of model_viewer_plus), so the left/right/reverse turn is
  // applied the same way it always was for this widget: by rotating the
  // whole rendered arrow in Flutter's own transform layer (`rotateZ` below)
  // rather than asking the model itself to turn.
  //
  // IMPORTANT: this used to also get an outer fake-3D skew (rotateX +
  // perspective) left over from the old flat-icon design, plus a decorative
  // ring/tick overlay around it. On a real device that combination warped
  // the whole thing into an unrecognisable translucent oval — a circle
  // rotated ~63° on X with perspective projects as an ellipse, which is
  // exactly what showed up. The model already renders its own real 3D
  // perspective via `cameraOrbit` below; it must not get a second, unrelated
  // skew stacked on top, and nothing should visually compete with it.
  static const String _arrowModelSrc =
      'assets/models/Arrow by Max Level - 1TUCDmHZKQY.glb';
  // model-viewer's own well-tested default framing (works reasonably for
  // most objects) — a safer starting point than a custom-guessed angle that
  // was never actually previewed. If the arrowhead doesn't visually point
  // "forward/away from the viewer" once seen on a real device, rotate the
  // first (theta) value here in ~90deg steps until it does; everything else
  // (the turn animation) layers on top of whatever this default pose is.
  static const String _arrowModelCameraOrbit = '0deg 75deg 105%';

  /// The model-viewer web component fires its own DOM 'load'/'error'
  /// events — this JS hooks those and reports back over a JavascriptChannel
  /// so Dart actually knows whether the .glb rendered, instead of assuming
  /// silently (which is exactly how the arrow went missing before: the
  /// WebView failed with no visible signal anywhere in the Flutter layer).
  static const String _arrowModelStatusJs = '''
(function () {
  var mv = document.querySelector('model-viewer');
  if (!mv) { return; }
  mv.addEventListener('load', function () {
    ModelStatus.postMessage('load');
  });
  mv.addEventListener('error', function (e) {
    var detail = 'unknown';
    try { detail = JSON.stringify(e && e.detail); } catch (err) {}
    ModelStatus.postMessage('error:' + detail);
  });
})();
''';

  void _onArrowModelStatus(String message) {
    if (!mounted) return;
    if (message == 'load') {
      if (!_arrowModelReady) {
        setState(() => _arrowModelReady = true);
        debugPrint('[AR NAV] Arrow .glb loaded successfully.');
      }
    } else {
      debugPrint('[AR NAV] Arrow .glb reported an error: $message');
    }
  }

  Widget _buildArrowModel() {
    return SizedBox(
      width: 220,
      height: 220,
      child: ModelViewer(
        backgroundColor: Colors.transparent,
        src: _arrowModelSrc,
        alt: 'AR navigation direction arrow',
        autoRotate: false,
        cameraControls: false,
        disableZoom: true,
        disablePan: true,
        disableTap: true,
        touchAction: TouchAction.none,
        interactionPrompt: InteractionPrompt.none,
        cameraOrbit: _arrowModelCameraOrbit,
        javascriptChannels: {
          JavascriptChannel(
            'ModelStatus',
            onMessageReceived: (msg) => _onArrowModelStatus(msg.message),
          ),
        },
        relatedJs: _arrowModelStatusJs,
      ),
    );
  }

  Widget _buildDirectionArrow(ArNavigationSnapshot snap) {
    // relativeAngleDeg is compass-fused by ArNavigationService once each
    // segment's heading reference locks in (~1.5s after it starts) — so this
    // angle swings live as the phone physically rotates, on top of the base
    // turn instruction. 0=straight, ±90=left/right, 180=back, before lock.
    final angle = snap.relativeAngleDeg * math.pi / 180.0;

    final isConfirmed = snap.detectionConfirmed;
    final glowColor = isConfirmed ? const Color(0xFFFFB300) : Colors.greenAccent;

    // Built once and passed through as AnimatedBuilder's `child` so the
    // underlying WebView/3D model is never torn down and reloaded just
    // because the ambient glow is pulsing ~60 times a second.
    final arrowModel = _buildArrowModel();

    return AnimatedBuilder(
      animation: _pulseAnim,
      child: arrowModel,
      builder: (_, child) {
        return SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Solid contrast pedestal — keeps the arrow legible against
              // ANY camera background (busy screen, foliage, bright sky).
              // A shadow-only glow alone can be nearly invisible depending
              // on what's actually behind it.
              Container(
                width: 178,
                height: 178,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x6B000000), Color(0x00000000)],
                  ),
                ),
              ),
              // Soft ambient glow ring on top of the pedestal.
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.25 + _pulseAnim.value * 0.2),
                      blurRadius: 60,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
              // Instant fallback: a plain Material arrow visible the moment
              // navigation starts, so the visitor is never looking at a
              // blank spot while the 3D model's WebView loads — or on a
              // device where it never manages to (see _onArrowModelStatus).
              // Fades out once the real .glb confirms it actually rendered.
              AnimatedOpacity(
                opacity: _arrowModelReady ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 350),
                child: Transform.rotate(
                  angle: angle,
                  child: Icon(
                    Icons.navigation_rounded,
                    size: 108,
                    color: glowColor,
                    shadows: [
                      Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 14),
                    ],
                  ),
                ),
              ),
              // Only the model spins for the turn direction — a plain
              // screen-plane rotation, no perspective skew stacked on its
              // own already-3D render.
              AnimatedOpacity(
                opacity: _arrowModelReady ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: Transform.rotate(angle: angle, child: child),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalibrationHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Compass calibrating — turn instructions are still accurate',
              style: TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _turnIcon(TurnDirection d) {
    switch (d) {
      case TurnDirection.left:
        return Icons.turn_left_rounded;
      case TurnDirection.right:
        return Icons.turn_right_rounded;
      case TurnDirection.reverse:
        return Icons.u_turn_left_rounded;
      case TurnDirection.straight:
        return Icons.straight_rounded;
      case TurnDirection.none:
        return Icons.explore_rounded;
    }
  }

  Widget _buildBottomHudPanel(ArNavigationSnapshot snap) {
    final dist = snap.distanceMeters;
    final isKm = dist >= 1000;
    final distNumber = isKm ? (dist / 1000).toStringAsFixed(2) : dist.toStringAsFixed(0);
    final distUnit = isKm ? 'km' : 'm';

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.96), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                ),
                child: Text(
                  '${snap.waypointIndex + 1} / ${snap.totalWaypoints}',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (snap.waypointIndex + 1) / snap.totalWaypoints,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Google-Maps-style hero row: turn icon + huge distance ─────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.5)),
                ),
                child: Icon(_turnIcon(snap.turnDirection),
                    color: const Color(0xFFFFB300), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          distNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          distUnit,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snap.instruction,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Detection guidance chip
          if (snap.detectionGuidance != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: snap.detectionConfirmed
                    ? Colors.green.withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: snap.detectionConfirmed
                      ? Colors.greenAccent.withOpacity(0.6)
                      : Colors.white24,
                ),
              ),
              child: Text(
                snap.detectionGuidance!,
                style: TextStyle(
                  color: snap.detectionConfirmed
                      ? Colors.greenAccent
                      : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Contextual landmark note (opportunistic — never gates the route)
          if (snap.contextNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.landscape_rounded, color: Color(0xFFFFB300), size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      snap.contextNote!,
                      style: const TextStyle(
                        color: Color(0xFFFFB300),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArrivedBanner(String title) {
    // A slim strip near the top (Google Maps' turn-by-turn card style)
    // rather than a full block over the arrow's screen region — the arrow
    // stays visible and in sync with this instruction instead of vanishing
    // behind it, so "Turn Left" and the arrow pointing left are always seen
    // together.
    return Positioned(
      top: MediaQuery.of(context).padding.top + 78,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green.shade700.withOpacity(0.94),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCompleteOverlay() {
    // This is NOT a celebratory "tour complete" state — the physical survey
    // simply hasn't been extended past this point yet. Framing it as
    // finished would misrepresent how much of Sigiriya is actually covered.
    return Container(
      color: Colors.black.withOpacity(0.82),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom_rounded,
                color: Color(0xFFFFB300), size: 64),
            const SizedBox(height: 16),
            const Text(
              'End of Mapped Route',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'You have reached the end of the currently measured Sigiriya route. '
                'More segments will be added once surveyed.',
                style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsWarningBanner(String message, Color bgColor) {
    return Positioned(
      top: 115,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.gps_off_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsWarning() {
    return Positioned(
      top: 115,
      left: 16,
      right: 16,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.gps_not_fixed_rounded,
                color: Colors.white, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'GPS signal weak. Direction may be less accurate.',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 44, 16, 16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.landmark.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const Text(
                  'AR Navigation',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                ),
              ],
            ),
            const Spacer(),
            // GPS badge
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: (_navSnapshot?.hasGpsFix ?? false)
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_navSnapshot?.hasGpsFix ?? false)
                        ? Colors.greenAccent
                            .withOpacity(0.5 + _pulseAnim.value * 0.4)
                        : Colors.orange
                            .withOpacity(0.5 + _pulseAnim.value * 0.4),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_navSnapshot?.hasGpsFix ?? false)
                          ? Colors.greenAccent
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    (_navSnapshot?.hasGpsFix ?? false) ? 'GPS Active' : 'No GPS',
                    style: TextStyle(
                      color: (_navSnapshot?.hasGpsFix ?? false)
                          ? Colors.greenAccent
                          : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Manual route-segment picker — icon only, no visible label.
            // Always available so the measured route can be jumped into at
            // any point (testing turns, or resuming mid-walk) without waiting
            // on the GPS/YOLO Ticket Counter trigger.
            GestureDetector(
              onTap: _showManualWaypointSelector,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.alt_route_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY MODE (non-Sigiriya)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLegacyMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          if (_controller?.value.isInitialized == true && !_overlayVisible)
            _buildScanningOverlay(),
          if (_overlayVisible)
            FadeTransition(opacity: _fadeIn, child: _buildArOverlays()),
          _buildTopBar(),
          if (_overlayVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child:
                  FadeTransition(opacity: _fadeIn, child: _buildInfoPanel()),
            ),
          if (_selectedHotspot >= 0 && _selectedHotspot < _subLandmarks.length)
            _buildHotspotDetail(_subLandmarks[_selectedHotspot]),
        ],
      ),
    );
  }

  // ── Shared camera layer ───────────────────────────────────────────────────

  Widget _buildCameraLayer() {
    if (_error != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const _LoadingCamera();
    }
    return CameraPreview(_controller!);
  }

  Widget _centeredMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Positioned.fill(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Legacy: Top bar ────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 44, 16, 20),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.landmark.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia')),
                const Text('AR Camera View',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_overlayVisible ? Colors.green : Colors.orange)
                      .withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_overlayVisible ? Colors.green : Colors.orange)
                        .withOpacity(0.6 + _pulseAnim.value * 0.4),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_overlayVisible
                              ? Colors.greenAccent
                              : Colors.orangeAccent)
                          .withOpacity(0.6 + _pulseAnim.value * 0.4),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _overlayVisible ? 'Locked On' : 'Scanning',
                    style: TextStyle(
                      color: _overlayVisible
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Legacy: Scanning overlay ───────────────────────────────────────────────

  Widget _buildScanningOverlay() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (_, __) {
            final y = (size.height - 200) * _scanAnim.value + 80;
            return Positioned(
              top: y, left: 32, right: 32,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.greenAccent.withOpacity(0.9),
                    Colors.transparent,
                  ]),
                ),
              ),
            );
          },
        ),
        ..._cornerBrackets(context, Colors.greenAccent, scanning: true),
        Positioned(
          bottom: 130, left: 0, right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.black
                      .withOpacity(0.55 + _pulseAnim.value * 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.greenAccent
                          .withOpacity(0.35 + _pulseAnim.value * 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.view_in_ar_rounded,
                      color: Colors.greenAccent, size: 16),
                  SizedBox(width: 8),
                  Text('Scanning for landmark…',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Legacy: AR overlays ────────────────────────────────────────────────────

  Widget _buildArOverlays() {
    final size = MediaQuery.of(context).size;
    final positions = [
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.70, size.height * 0.18),
      Offset(size.width * 0.50, size.height * 0.38),
      Offset(size.width * 0.12, size.height * 0.52),
      Offset(size.width * 0.74, size.height * 0.46),
    ];
    final hotspots = _subLandmarks.take(positions.length).toList();
    return Stack(
      children: [
        ..._cornerBrackets(context, const Color(0xFFFFB300), scanning: false),
        Positioned(
          top: 145, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.62),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFFB300).withOpacity(0.65)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFFFFB300), size: 13),
                const SizedBox(width: 6),
                Text(widget.landmark.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia')),
              ]),
            ),
          ),
        ),
        ...hotspots.asMap().entries.map((entry) {
          final i = entry.key;
          final sub = entry.value;
          final pos = positions[i];
          return Positioned(
            left: pos.dx - 50,
            top: pos.dy - 12,
            child: GestureDetector(
              onTap: () => setState(
                  () => _selectedHotspot = _selectedHotspot == i ? -1 : i),
              child: _buildHotspotMarker(sub.name,
                  selected: _selectedHotspot == i),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHotspotMarker(String label, {bool selected = false}) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: selected ? 12 : 9,
          height: selected ? 12 : 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white : const Color(0xFFFFB300),
            border:
                selected ? Border.all(color: const Color(0xFFFFB300), width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300)
                    .withOpacity(0.3 + _pulseAnim.value * 0.5),
                blurRadius: 10 + _pulseAnim.value * 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFB300).withOpacity(0.9)
                : Colors.black.withOpacity(0.68),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? Colors.white : Colors.white24,
                width: selected ? 1.5 : 0.8),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              )),
        ),
      ]),
    );
  }

  Widget _buildHotspotDetail(SubLandmarkModel sub) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 24, right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.place_rounded,
                  color: Color(0xFFFFB300), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(sub.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedHotspot = -1),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white54, size: 18),
              ),
            ]),
            const SizedBox(height: 8),
            Text(sub.description,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.secondary.withOpacity(0.4)),
              ),
              child: Text(sub.type.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    final lm = widget.landmark;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.96), Colors.transparent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.view_in_ar_rounded,
                color: Color(0xFFFFB300), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(lm.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia')),
            ),
            GestureDetector(
              onTap: () =>
                  setState(() => _infoPanelExpanded = !_infoPanelExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_infoPanelExpanded ? 'Less' : 'More',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                  const SizedBox(width: 4),
                  Icon(
                    _infoPanelExpanded
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: Colors.white54,
                    size: 14,
                  ),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            _infoPanelExpanded
                ? lm.description
                : (lm.description.length > 100
                    ? '${lm.description.substring(0, 100)}…'
                    : lm.description),
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.45),
          ),
          if (_subLandmarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Points of Interest',
                style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _subLandmarks.take(6).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final sub = _subLandmarks[i];
                  final sel = i == _selectedHotspot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedHotspot = sel ? -1 : i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFFFB300).withOpacity(0.25)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel
                                ? const Color(0xFFFFB300)
                                : Colors.white24,
                            width: sel ? 1.5 : 0.8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_rounded,
                              color: sel
                                  ? const Color(0xFFFFB300)
                                  : Colors.white54,
                              size: 14),
                          const SizedBox(height: 3),
                          Text(
                            sub.name.length > 14
                                ? '${sub.name.substring(0, 12)}…'
                                : sub.name,
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.white70,
                              fontSize: 10,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<Widget> _cornerBrackets(BuildContext ctx, Color color,
    {required bool scanning}) {
  final size = MediaQuery.of(ctx).size;
  const margin = 36.0;
  const top = 88.0;
  final bottom = size.height * 0.55;
  const len = 28.0;
  const thick = 2.5;

  Widget bracket(double l, double t, _Corner c) => Positioned(
        left: l, top: t,
        child: CustomPaint(
          size: const Size(len, len),
          painter: _CornerPainter(corner: c, color: color, thickness: thick),
        ),
      );

  return [
    bracket(margin, top, _Corner.topLeft),
    bracket(size.width - margin - len, top, _Corner.topRight),
    bracket(margin, bottom, _Corner.bottomLeft),
    bracket(size.width - margin - len, bottom, _Corner.bottomRight),
    Positioned(
      left: margin + 6, top: top - 16,
      child: Text(
        scanning ? 'Searching…' : '▶ Landmark Detected',
        style: TextStyle(
          color: color.withOpacity(0.85),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
  ];
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerPainter extends CustomPainter {
  final _Corner corner;
  final Color color;
  final double thickness;

  const _CornerPainter(
      {required this.corner, required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    switch (corner) {
      case _Corner.topLeft:
        canvas.drawLine(Offset(0, h * 0.6), const Offset(0, 0), p);
        canvas.drawLine(const Offset(0, 0), Offset(w * 0.6, 0), p);
        break;
      case _Corner.topRight:
        canvas.drawLine(Offset(w * 0.4, 0), Offset(w, 0), p);
        canvas.drawLine(Offset(w, 0), Offset(w, h * 0.6), p);
        break;
      case _Corner.bottomLeft:
        canvas.drawLine(const Offset(0, 0), Offset(0, h * 0.6), p);
        canvas.drawLine(Offset(0, h), Offset(w * 0.6, h), p);
        break;
      case _Corner.bottomRight:
        canvas.drawLine(Offset(w, h * 0.4), Offset(w, h), p);
        canvas.drawLine(Offset(w, h), Offset(w * 0.4, h), p);
        break;
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.corner != corner || old.color != color;
}

class _LoadingCamera extends StatelessWidget {
  const _LoadingCamera();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: Colors.white38, strokeWidth: 2),
          const SizedBox(height: 16),
          const Text('Starting Camera…',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Preparing AR Overlay',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.2), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Detection overlay painter ───────────────────────────────────────────────

class _DetectionOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size? previewSize;
  final int sensorOrientation;

  const _DetectionOverlayPainter({
    required this.detections,
    required this.previewSize,
    required this.sensorOrientation,
  });

  @override
  void paint(Canvas canvas, Size widgetSize) {
    if (detections.isEmpty || previewSize == null) return;

    final bool isRotated90 = sensorOrientation == 90 || sensorOrientation == 270;
    final double pvW = isRotated90 ? previewSize!.height : previewSize!.width;
    final double pvH = isRotated90 ? previewSize!.width : previewSize!.height;

    final double scaleX = widgetSize.width / pvW;
    final double scaleY = widgetSize.height / pvH;
    final double scale = scaleX > scaleY ? scaleX : scaleY; // cover
    final double scaledW = pvW * scale;
    final double scaledH = pvH * scale;
    final double offsetX = (widgetSize.width - scaledW) / 2;
    final double offsetY = (widgetSize.height - scaledH) / 2;

    for (final det in detections) {
      final colour = const Color(0xFFFFB300);

      final x1 = offsetX + det.boundingBox.left * scaledW;
      final y1 = offsetY + det.boundingBox.top * scaledH;
      final x2 = offsetX + det.boundingBox.right * scaledW;
      final y2 = offsetY + det.boundingBox.bottom * scaledH;
      final box = Rect.fromLTRB(x1, y1, x2, y2);

      canvas.drawRect(
          box,
          Paint()
            ..color = colour.withOpacity(0.12)
            ..style = PaintingStyle.fill);

      canvas.drawRect(
          box,
          Paint()
            ..color = colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);

      _drawCorners(canvas, box, colour);

      final formattedLabel = det.label.split('_').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '').join(' ');
      final labelText = '$formattedLabel ${(det.confidence * 100).toStringAsFixed(0)}%';

      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: colour,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: widgetSize.width - 24);

      const padH = 10.0;
      const padV = 6.0;
      final chipW = tp.width + padH * 2;
      final chipH = tp.height + padV * 2;

      double chipX = x1;
      double chipY = y1 - chipH - 6;
      if (chipY < 0) chipY = y2 + 6;
      chipX = chipX.clamp(4.0, widgetSize.width - chipW - 4);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(chipX, chipY, chipW, chipH), const Radius.circular(10)),
        Paint()..color = Colors.black.withOpacity(0.75),
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(chipX, chipY, chipW, chipH), const Radius.circular(10)),
        Paint()
          ..color = colour.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      tp.paint(canvas, Offset(chipX + padH, chipY + padV));
    }
  }

  void _drawCorners(Canvas canvas, Rect box, Color colour) {
    const len = 14.0;
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(box.left, box.top), Offset(box.left + len, box.top), paint);
    canvas.drawLine(Offset(box.left, box.top), Offset(box.left, box.top + len), paint);
    canvas.drawLine(Offset(box.right, box.top), Offset(box.right - len, box.top), paint);
    canvas.drawLine(Offset(box.right, box.top), Offset(box.right, box.top + len), paint);
    canvas.drawLine(Offset(box.left, box.bottom), Offset(box.left + len, box.bottom), paint);
    canvas.drawLine(Offset(box.left, box.bottom), Offset(box.left, box.bottom - len), paint);
    canvas.drawLine(Offset(box.right, box.bottom), Offset(box.right - len, box.bottom), paint);
    canvas.drawLine(Offset(box.right, box.bottom), Offset(box.right, box.bottom - len), paint);
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter old) {
    if (old.detections.length != detections.length) return true;
    if (detections.isEmpty && old.detections.isEmpty) return false;
    for (int i = 0; i < detections.length; i++) {
      if (old.detections[i].label != detections[i].label ||
          old.detections[i].confidence != detections[i].confidence ||
          old.detections[i].boundingBox != detections[i].boundingBox) {
        return true;
      }
    }
    return false;
  }
}

