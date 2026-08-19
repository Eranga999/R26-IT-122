import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../database/landmark_model.dart';
import '../database/sub_landmark_model.dart';
import '../database/database_helper.dart';
import '../recognition/recognition_service.dart';
import '../../core/theme/app_theme.dart';
import 'ar_navigation_service.dart';

enum ArGpsFailure { none, serviceDisabled, permissionDenied, permissionDeniedForever }

/// Live-camera AR overlay view.
///
/// For Sigiriya: provides full camera-based AR waypoint navigation
/// using GPS + compass + YOLO landmark confirmation.
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
      _startNavigation();
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
        final snap = _navService.onGpsUpdate(pos.latitude, pos.longitude);
        if (mounted) setState(() => _navSnapshot = snap);
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
        if (mounted) setState(() => _navSnapshot = snap);
      }
    });

    // Ensure model is loaded
    RecognitionService.instance.loadModel();
  }

  // ── YOLO Frame Processing (nav mode, throttled) ────────────────────────────

  Future<void> _processNavFrame(CameraImage image) async {
    if (!_isSigiriya) return;
    if (_isProcessingFrame) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < _frameThrottleMs) return;

    final snap = _navSnapshot;
    if (snap == null || snap.routeComplete) return;

    final wp = _navService.current;
    if (!wp.requiresDetection) return; // skip YOLO for path-only waypoints

    _isProcessingFrame = true;
    _lastFrameMs = now;

    try {
      final results = await RecognitionService.instance.predictAll(
        image,
        sensorOrientation: _controller?.description.sensorOrientation ?? 0,
        threshold: 0.70,
        nmsIouThreshold: 0.45,
        allowedLabels: {
          'sigiriya_ticket_counter',
          'sigiriya_water_gardens', 
          'sigiriya_mirror_wall',
          'sigiriya_lion_paws',
          'sigiriya_lion_rock',
          'sigiriya_throne'
        },
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
        final s = _navService.onDetectionUpdate(
          label: null,
          confidence: 0,
          bboxCenterX: null,
          bboxCenterY: null,
        );
        if (mounted) setState(() => _navSnapshot = s);
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

        final s = _navService.onDetectionUpdate(
          label: best.label,
          confidence: best.confidence,
          bboxCenterX: cx,
          bboxCenterY: cy,
        );
        if (mounted) setState(() => _navSnapshot = s);
      }
    } catch (_) {
      // ignore inference errors; keep navigating
    } finally {
      if (mounted) {
        _isProcessingFrame = false;
      }
    }
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
    super.dispose();
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
        // Arrived banner (brief)
        if (snap.hasArrived && snap.justArrivedFlash) _buildArrivedBanner(snap.waypointTitle),

        // Main HUD (always shown)
        if (!snap.hasArrived) _buildArNavHud(snap),

        // GPS weak accuracy warning
        if (_gpsAccuracyM != null && _gpsAccuracyM! > 20 && snap.gpsStatus == ArGpsStatus.live)
          _buildGpsWarning(),

        // GPS disconnected warnings
        if (snap.gpsStatus == ArGpsStatus.stale)
          _buildGpsWarningBanner('GPS signal lost. Using last known location.', Colors.amber.shade800)
        else if (snap.gpsStatus == ArGpsStatus.degraded)
          _buildGpsWarningBanner('GPS accuracy reduced. Waiting for GPS signal.', Colors.deepOrange),
          
        // Manual Selection (Simulation) if user is far away
        if (snap.distanceMeters > 500 && snap.gpsStatus != ArGpsStatus.unavailable)
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
                  'Outside heritage site? Tap here to manually simulate navigating to waypoints.',
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
    final route = _navService.route;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
              'Select a waypoint to instantly simulate arriving near it.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: route.length,
                itemBuilder: (context, i) {
                  final wp = route[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade700,
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(wp.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(wp.description, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1),
                    onTap: () {
                      Navigator.pop(context);
                      // Simulate location just 10 meters away from the waypoint
                      _navService.simulateLocation(wp.latitude + 0.0001, wp.longitude + 0.0001);
                      if (mounted) setState(() {});
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

  Widget _buildArNavHud(ArNavigationSnapshot snap) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // ── AR Virtual Breadcrumbs (Footsteps) ─────────────────────────────
        Positioned(
          top: size.height * 0.35, 
          left: 0,
          right: 0,
          child: _buildFootstepsOverlay(snap),
        ),

        // ── Big directional arrow (3D Perspective Hologram) ────────────────
        Positioned(
          top: size.height * 0.35, // Moved down to simulate ground projection
          left: 0,
          right: 0,
          child: Column(
            children: [
              _buildDirectionArrow(snap),
              const SizedBox(height: 24),
              if (!snap.hasCompassFix)
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

  Widget _buildFootstepsOverlay(ArNavigationSnapshot snap) {
    if (snap.footsteps.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 220, // Match the arrow's anchor box
      child: Stack(
        alignment: Alignment.center,
        children: snap.footsteps.map((step) {
          // Normalize distance: translating negatively in Y moves "forward" in the ground plane
          final double depthShift = -(step.distanceMeters * 12.0); // 1 meter = 12 virtual pixels
          
          final angle = snap.hasCompassFix
              ? step.relativeAngleDeg * math.pi / 180.0
              : 0.0;

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

  Widget _buildDirectionArrow(ArNavigationSnapshot snap) {
    // 0 means straight ahead.
    final angle = snap.hasCompassFix
        ? snap.relativeAngleDeg * math.pi / 180.0
        : 0.0;

    final isConfirmed = snap.detectionConfirmed;
    final primaryColor = isConfirmed ? const Color(0xFFFFB300) : Colors.greenAccent;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        // Perspective 3D Tilt for realistic AR arrow floating on the ground
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0025) // depth perspective
          ..rotateX(1.1)           // Tilt backward into the screen
          ..rotateZ(angle);        // Swivel based on compass bearing

        return SizedBox(
          height: 220,
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.08),
                border: Border.all(
                  color: primaryColor.withOpacity(0.4 + _pulseAnim.value * 0.4),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.15 + _pulseAnim.value * 0.25),
                    blurRadius: 45,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer dashed glowing ring / compass ticks
                  for (int i = 0; i < 12; i++)
                    Transform.rotate(
                      angle: i * math.pi / 6,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: i % 3 == 0 ? 4 : 2,
                          height: i % 3 == 0 ? 16 : 8,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          margin: const EdgeInsets.only(top: 8),
                        ),
                      ),
                    ),
                  // Inner concentric radar circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withOpacity(0.2), width: 2),
                    ),
                  ),
                  // Inner target tick
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                    ),
                  ),
                  // The 3D navigational wedge / arrow
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Icon(
                        Icons.change_history_rounded, // Better futuristic arrow shape
                        color: primaryColor,
                        size: 90,
                        shadows: [
                          Shadow(
                            color: primaryColor,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              'Move slowly forward to calibrate direction',
              style: TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHudPanel(ArNavigationSnapshot snap) {
    final dist = snap.distanceMeters;
    final distLabel = dist < 1000
        ? '${dist.toStringAsFixed(0)} m'
        : '${(dist / 1000).toStringAsFixed(2)} km';

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
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

          const SizedBox(height: 14),

          // Waypoint name
          Text(
            snap.waypointTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),

          const SizedBox(height: 4),

          // Distance
          Row(
            children: [
              const Icon(Icons.straighten_rounded,
                  color: Color(0xFFFFB300), size: 16),
              const SizedBox(width: 6),
              Text(
                distLabel,
                style: const TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.info_outlined, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  snap.instruction,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

  Widget _buildArrivedBanner(String title) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.35,
      left: 30,
      right: 30,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 52),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCompleteOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.82),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFFFB300), size: 72),
            const SizedBox(height: 16),
            const Text(
              'Tour Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You have completed the Sigiriya\nAR Navigation route.',
              style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Finish'),
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

