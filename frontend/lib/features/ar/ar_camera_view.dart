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
  static const int _frameThrottleMs = 500;

  // GPS accuracy warning
  double? _gpsAccuracyM;

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

  Future<void> _startNavigation() async {
    // --- GPS stream ---
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _navSnapshot = _navSnapshot);
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      _gpsAccuracyM = pos.accuracy;
      final snap = _navService.onGpsUpdate(pos.latitude, pos.longitude);
      if (mounted) setState(() => _navSnapshot = snap);
    });

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
        allowedLabels: {wp.detectionLabel!},
      );

      if (!mounted) return;

      if (results.isEmpty) {
        final s = _navService.onDetectionUpdate(
          label: null,
          confidence: 0,
          bboxCenterX: null,
          bboxCenterY: null,
        );
        setState(() => _navSnapshot = s);
      } else {
        final best =
            results.reduce((a, b) => a.confidence > b.confidence ? a : b);
        final cx = best.boundingBox.left + best.boundingBox.width / 2;
        final cy = best.boundingBox.top + best.boundingBox.height / 2;
        final s = _navService.onDetectionUpdate(
          label: best.label,
          confidence: best.confidence,
          bboxCenterX: cx,
          bboxCenterY: cy,
        );
        setState(() => _navSnapshot = s);
      }
    } catch (_) {
      // ignore inference errors; keep navigating
    } finally {
      _isProcessingFrame = false;
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
      children: [
        // Arrived banner (brief)
        if (snap.hasArrived) _buildArrivedBanner(snap.waypointTitle),

        // Main HUD (always shown)
        if (!snap.hasArrived) _buildArNavHud(snap),

        // GPS weak warning
        if (_gpsAccuracyM != null && _gpsAccuracyM! > 20)
          _buildGpsWarning(),
      ],
    );
  }

  Widget _buildArNavHud(ArNavigationSnapshot snap) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // ── Big directional arrow ──────────────────────────────────────────
        Positioned(
          top: size.height * 0.22,
          left: 0,
          right: 0,
          child: Column(
            children: [
              _buildDirectionArrow(snap),
              const SizedBox(height: 10),
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

  Widget _buildDirectionArrow(ArNavigationSnapshot snap) {
    final angle = snap.hasCompassFix
        ? snap.relativeAngleDeg * math.pi / 180.0
        : 0.0;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.55),
            border: Border.all(
              color: Colors.greenAccent.withOpacity(0.55 + _pulseAnim.value * 0.35),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.2 + _pulseAnim.value * 0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.navigation_rounded,
            color: Colors.greenAccent,
            size: 60,
          ),
        ),
      ),
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
