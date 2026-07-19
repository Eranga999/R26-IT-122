import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../core/location/site_geofence.dart';
import '../../core/location/site_lock_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/recognition/recognition_service.dart';
import '../../features/database/database_helper.dart';
import '../../features/database/landmark_model.dart';
import '../../features/database/sub_landmark_model.dart';
// recognition service already imported above
import '../ar/ar_screen.dart';
import '../rag/rag_screen.dart';
import '../navigation/nav_screen.dart';
import '../home/home_screen.dart';

/// Verification state of the GPS geofence check.
enum _VerifyStatus { verifying, locked, outside, failed, manual }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  String? _cameraError;
  bool _isProcessing = false;
  int _lastProcessTime = 0; // for throttling
  int _lastPanelUpdateTime = 0;
  String? _lastPanelLabel;
  final Map<int, LandmarkModel> _landmarkCache = {};
  final Map<int, List<SubLandmarkModel>> _subCache = {};

  // ── GPS / site verification state ─────────────────────────────────────────
  _VerifyStatus _verifyStatus = _VerifyStatus.verifying;
  SiteLockResult? _siteLock;
  List<String> _allowedLabels = const [];

  bool get _canRunDetector =>
      (_verifyStatus == _VerifyStatus.locked ||
          _verifyStatus == _VerifyStatus.manual) &&
      _allowedLabels.isNotEmpty;

  // ── Live detection state (shown while scanning) ────────────────────────────
  List<DetectionResult> _liveDetections = []; // real-time boxes on camera

  // ── Bounding-box smoothing ────────────────────────────────────────────────
  Rect? _smoothedBoxRect; // exponentially smoothed box
  static const double _boxAlpha = 0.85; // Faster visual tracking

  // ── False positive protection (Stable detection tracking) ──────────────────
  String? _candidateLabel;
  int _candidateCount = 0;
  int _lastConfirmedTime = 0;
  static const int _panelHoldMs = 4000; // Increased hold time

  bool get _isGpsLocked => _verifyStatus == _VerifyStatus.locked;
  double get _modelThreshold => _isGpsLocked ? 0.65 : 0.70;
  double get _cardThreshold => _isGpsLocked ? 0.75 : 0.80;
  int get _requiredFrames => _isGpsLocked ? 1 : 2; // Needs less frames to trigger

  bool _isStableDetection(DetectionResult bestDetection) {
    if (bestDetection.confidence < _cardThreshold) {
      _candidateCount = 0;
      return false;
    }

    if (bestDetection.label == _candidateLabel) {
      _candidateCount++;
    } else {
      _candidateLabel = bestDetection.label;
      _candidateCount = 1;
    }

    return _candidateCount >= _requiredFrames;
  }

  // ── Info-panel state (opened when confident enough) ────────────────────────
  LandmarkModel? _detectedLandmark;
  DetectionResult? _activeDetection;
  String? _detectedClassLabel;
  List<SubLandmarkModel> _subLandmarks = [];
  double _confidence = 0;
  bool _panelVisible = false;

  late final AnimationController _pulseAnim;
  late final AnimationController _cardAnim;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _pulseAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _cardAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _cardFade = CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut));
    // Always open camera immediately — do not wait for GPS.
    if (!_isDesktop) {
      _initCamera();
    }
    // GPS verification runs concurrently in the background.
    _verifyGpsInBackground();
  }

  /// Runs GPS geofencing in the background after the camera is already open.
  Future<void> _verifyGpsInBackground() async {
    final result = await SiteLockService.instance.lockSiteByGps();
    if (!mounted) return;
    final labels = RecognitionService.labelsForSite(result.site?.landmarkName);
    setState(() {
      _siteLock = result;
      _allowedLabels = labels;
      switch (result.status) {
        case SiteLockStatus.locked:
          _verifyStatus = _VerifyStatus.locked;
        case SiteLockStatus.outOfRange:
          _verifyStatus = _VerifyStatus.outside;
        default:
          // permissionDenied, serviceDisabled, timeout, error
          _verifyStatus = _VerifyStatus.failed;
      }
    });
    if (_canRunDetector) {
      RecognitionService.instance.loadModel();
      // Pre-warm DB cache once the site is confirmed.
      Future.microtask(() async {
        final all = await DatabaseHelper.instance.getAllLandmarks();
        for (final lm in all) {
          if (lm.id == null || !mounted) continue;
          _landmarkCache[lm.id!] = lm;
          _subCache[lm.id!] =
              await DatabaseHelper.instance.getSubLandmarks(lm.id!);
        }
      });
    }
  }

  /// Shows the manual site-selection bottom sheet from within the camera screen.
  Future<void> _selectManualSite() async {
    final sites = await SiteLockService.instance.loadSites();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A0A00),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2)))),
          const Text('Select Your Current Site',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
              'GPS is unavailable — choose your heritage site manually.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          ...sites.map((site) => ListTile(
                leading: const Icon(Icons.place_rounded,
                    color: Color(0xFFFFB300)),
                title: Text(site.landmarkName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(site.landmarkId,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  final labels =
                      RecognitionService.labelsForSite(site.landmarkName);
                  setState(() {
                    _siteLock = SiteLockResult.manual(site: site);
                    _allowedLabels = labels;
                    _verifyStatus = _VerifyStatus.manual;
                  });
                  RecognitionService.instance.loadModel();
                  final all = await DatabaseHelper.instance.getAllLandmarks();
                  for (final lm in all) {
                    if (lm.id == null || !mounted) continue;
                    _landmarkCache[lm.id!] = lm;
                    _subCache[lm.id!] =
                        await DatabaseHelper.instance.getSubLandmarks(lm.id!);
                  }
                },
              )),
        ]),
      ),
    );
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera found.');
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.low,
          enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
      _controller!.startImageStream(_processFrame);
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Camera unavailable: ${e.toString()}');
      }
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (!_canRunDetector) return;
    if (!mounted) return;
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      // 1. Get results from service
      final results = await RecognitionService.instance.predictAll(
        image,
        sensorOrientation: _controller?.description.sensorOrientation ?? 0,
        threshold: _modelThreshold,
        allowedLabels: _allowedLabels.toSet(),
      );
      _isProcessing = false;
      if (!mounted) return;

      // Filter out very small boxes (likely noise)
      const minArea = 0.01; // normalised area (1% of frame)
      final filtered = results
          .where((r) => (r.boundingBox.width * r.boundingBox.height) >= minArea)
          .toList();

      // ── Bounding-box smoothing ────────────────────────────────────────────
      if (filtered.isNotEmpty) {
        // Find the most confident current box
        final originalBestBox = filtered.reduce((a, b) => a.confidence > b.confidence ? a : b);
        final bestBoxRef = originalBestBox.boundingBox;
        
        // Immediate exponential smoothing
        final old = _smoothedBoxRect;
        if (old == null) {
          _smoothedBoxRect = bestBoxRef;
        } else {
          _smoothedBoxRect = Rect.fromLTRB(
            old.left * (1 - _boxAlpha) + bestBoxRef.left * _boxAlpha,
            old.top  * (1 - _boxAlpha) + bestBoxRef.top  * _boxAlpha,
            old.right  * (1 - _boxAlpha) + bestBoxRef.right  * _boxAlpha,
            old.bottom * (1 - _boxAlpha) + bestBoxRef.bottom * _boxAlpha,
          );
        }
        
        final smoothedBestBox = DetectionResult(
           label: originalBestBox.label,
           confidence: originalBestBox.confidence,
           boundingBox: _smoothedBoxRect!,
           classIndex: originalBestBox.classIndex,
        );
        
        final bestBoxIdx = filtered.indexOf(originalBestBox);
        if (bestBoxIdx != -1) {
           filtered[bestBoxIdx] = smoothedBestBox;
        }
      } else {
        _smoothedBoxRect = null;
      }

      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (filtered.isNotEmpty) {
        final bestBox = filtered.reduce((a, b) => a.confidence > b.confidence ? a : b);
        
        if (_isStableDetection(bestBox)) {
          _lastConfirmedTime = now;
          if (!_panelVisible || _activeDetection?.label != bestBox.label) {
             Future.microtask(() => _onLandmarkDetected(bestBox));
          } else {
             // Just implicitly update the UI state inside the active panel
             setState(() {
                _activeDetection = bestBox;
                _confidence = bestBox.confidence;
                _liveDetections = filtered;
             });
          }
        } else if (_panelVisible) {
           if (now - _lastConfirmedTime > _panelHoldMs) {
             _dismissPanel();
           } else {
             setState(() => _liveDetections = filtered);
           }
        } else {
           setState(() => _liveDetections = filtered);
        }
      } else {
        if (_panelVisible && (now - _lastConfirmedTime > _panelHoldMs)) {
           _dismissPanel();
        } else {
           setState(() => _liveDetections = []);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Scan] frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onLandmarkDetected(DetectionResult detection) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = _labelToId(detection.label);
    if (id == null) return;

    // Use current site lock if available to filter relevant detections
    if (_siteLock?.site?.landmarkDbId != null &&
        id != _siteLock!.site!.landmarkDbId) {
      return;
    }

    // Ignore repeat calls if we're already rendering this panel
    if (_panelVisible && _detectedLandmark?.id == id) {
       return;
    }

    LandmarkModel? lm;
    List<SubLandmarkModel> subs;
    if (_landmarkCache.containsKey(id)) {
      lm = _landmarkCache[id];
      subs = _subCache[id] ?? [];
    } else {
      lm = await DatabaseHelper.instance.getLandmarkById(id);
      if (lm == null || !mounted) return;
      subs = await DatabaseHelper.instance.getSubLandmarks(id);
      if (!mounted) return;
      _landmarkCache[id] = lm;
      _subCache[id] = subs;
    }
    if (!mounted) return;
    setState(() {
      _detectedLandmark = lm;
      _activeDetection = detection;
      _detectedClassLabel = detection.label;
      _subLandmarks = subs;
      _confidence = detection.confidence;
      _panelVisible = true;
    });
    // Animate the floating card in
    _cardAnim.forward(from: 0);
    HapticFeedback.mediumImpact();
    _lastPanelLabel = detection.label;
    _lastPanelUpdateTime = now;
  }

  int? _labelToId(String label) {
    final normalized = label.trim().toLowerCase();
    // Broad matching: any class starting with 'sigiriya' belongs to ID 1
    if (normalized.contains('sigiriya')) return 1;
    if (normalized.contains('dambulla')) return 2;
    if (normalized.contains('polonnaruwa')) return 3;
    
    // Fallback directly to the indices if labels are just numbers or generic
    return null;
  }

  void _dismissPanel() {
    _cardAnim.reverse();
    setState(() {
      _panelVisible = false;
      _detectedLandmark = null;
      _activeDetection = null;
      _detectedClassLabel = null;
      _subLandmarks = [];
      _candidateCount = 0;
      _candidateLabel = null;
    });
  }

  Future<void> _showDemoPicker() async {
    final landmarks = await DatabaseHelper.instance.getAllLandmarks();
    final options = _siteLock?.site?.landmarkDbId == null
        ? landmarks
        : landmarks
            .where((lm) => lm.id == _siteLock?.site?.landmarkDbId)
            .toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A0A00),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2)))),
            const Text('Simulate Detection',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                _siteLock?.site?.landmarkName == null
                    ? 'Select a landmark to preview the AR overlay'
                    : 'Site lock active: ${_siteLock?.site?.landmarkName}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            ...options.map((lm) => ListTile(
                  leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_rounded,
                          color: Color(0xFFFFB300), size: 20)),
                  title: Text(lm.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tap to simulate',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    // Simulate a detection result centered on screen
                    const simulatedBox = Rect.fromLTWH(0.25, 0.25, 0.5, 0.5);
                    final detection = DetectionResult(
                        label: lm.name.toLowerCase(),
                        confidence: 0.94,
                        boundingBox: simulatedBox,
                        classIndex: 0);
                    _onLandmarkDetected(detection);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    _cardAnim.dispose();
    _controller?.dispose();
    RecognitionService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) return _buildDesktopUnsupported();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (_cameraError != null)
          _buildCameraError()
        else if (_controller == null || !_controller!.value.isInitialized)
          _buildLoadingState()
        else
          CameraPreview(_controller!),

        // Live bounding-box overlay – shown while scanning AND after panel opens
        if (_liveDetections.isNotEmpty || _activeDetection != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DetectionOverlayPainter(
                  detections: _panelVisible && _activeDetection != null
                      ? [_activeDetection!]
                      : _liveDetections,
                  previewSize: _controller?.value.previewSize,
                  sensorOrientation:
                      _controller?.description.sensorOrientation ?? 0,
                ),
              ),
            ),
          ),

        // GPS / site verification status overlay (banners, spinner, manual pick)
        if (!_panelVisible)
          _buildGpsStatusOverlay(),

        // Top bar
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent])),
              padding: const EdgeInsets.only(
                  top: 48, bottom: 20, left: 8, right: 16),
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
                const Text('Scan Landmark',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia')),
                if (_siteLock?.site?.landmarkName != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        _siteLock!.site!.landmarkName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                const Spacer(),
              ]),
            )),

        if (_controller?.value.isInitialized == true && !_panelVisible)
          _buildScanFrame(),

        if (_panelVisible && _detectedLandmark != null) _buildFloatingDetectionCard(),

        if (_canRunDetector &&
            _siteLock?.site?.landmarkDbId != null &&
            _siteLock?.site?.landmarkDbId != 1 &&
            !_panelVisible)
          Positioned(
              top: 162,
              left: 20,
              right: 20,
              child: _buildUnsupportedSiteBanner()),

        if (!_panelVisible)
          Positioned(
              bottom: 32, left: 24, right: 24, child: _buildBottomLabel()),
      ]),
      floatingActionButton: (_canRunDetector &&
              !_panelVisible &&
              _cameraError == null &&
              _controller?.value.isInitialized == true)
          ? FloatingActionButton.extended(
              onPressed: _showDemoPicker,
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.science_rounded),
              label: const Text('Demo',
                  style: TextStyle(fontWeight: FontWeight.w600)))
          : null,
    );
  }

  Widget _buildUnsupportedSiteBanner() {
    final siteName = _siteLock?.site?.landmarkName ?? 'this site';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200, width: 0.8),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Live recognition is limited to the locked site profile. $siteName is available in the app, but no detector is running for unsupported labels.',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  // ── GPS status overlay ──────────────────────────────────────────────────────────────

  /// Returns the correct top-of-screen overlay for the current GPS state.
  /// Returns an empty [SizedBox] when no overlay is needed (e.g. locked state).
  Widget _buildGpsStatusOverlay() {
    switch (_verifyStatus) {
      case _VerifyStatus.verifying:
        return _statusBanner(
          icon: Icons.gps_not_fixed_rounded,
          color: Colors.blueGrey.shade700,
          message: 'Verifying your heritage site...',
          showSpinner: true,
        );
      case _VerifyStatus.failed:
        return _statusBanner(
          icon: Icons.gps_off_rounded,
          color: Colors.orange.shade800,
          message:
              'Enable GPS or verify your site to start landmark detection.',
          actionLabel: 'Select your current site',
          onAction: _selectManualSite,
        );
      case _VerifyStatus.outside:
        return _statusBanner(
          icon: Icons.location_off_rounded,
          color: Colors.red.shade700,
          message: 'You are outside a supported heritage site.',
          actionLabel: 'Select your current site',
          onAction: _selectManualSite,
        );
      case _VerifyStatus.manual:
        return _statusBanner(
          icon: Icons.touch_app_rounded,
          color: Colors.teal.shade700,
          message:
              'Manual Site Mode: ${_siteLock?.site?.landmarkName ?? ''}',
        );
      case _VerifyStatus.locked:
        return const SizedBox.shrink(); // no banner in GPS-locked state
    }
  }

  Widget _statusBanner({
    required IconData icon,
    required Color color,
    required String message,
    bool showSpinner = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Positioned(
      top: 86,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.92),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showSpinner)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                else
                  Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(message,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500))),
              ]),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(actionLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }



  /// Compact glassmorphism floating card — slides up from bottom on detection.
  Widget _buildFloatingDetectionCard() {
    final lm = _detectedLandmark!;
    return Positioned(
      bottom: 28,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _cardFade,
        child: SlideTransition(
          position: _cardSlide,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.black.withOpacity(0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.18), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 32,
                        offset: const Offset(0, 12)),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                value: _confidence,
                                strokeWidth: 4.0,
                                backgroundColor: Colors.white.withOpacity(0.06),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
                              ),
                            ),
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFFB300).withOpacity(0.2),
                                    const Color(0xFFFF8F00).withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_rounded,
                                  color: Color(0xFFFFB300), size: 24),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lm.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Georgia', // Elegant heritage font
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFB300), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_confidence * 100).toStringAsFixed(0)}% AI Match',
                                      style: const TextStyle(
                                        color: Color(0xFFFFB300),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismissPanel,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ]),
                    const SizedBox(height: 18),
                    // Action buttons
                    Row(children: [
                      Expanded(
                        child: _glassButton(
                          label: 'Details',
                          icon: Icons.open_in_full_rounded,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      LandmarkDetailScreen(landmark: lm))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _glassButton(
                          label: 'Navigate',
                          icon: Icons.explore_rounded,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      NavScreen(landmarkName: lm.name))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _glassButton(
                          label: 'Ask AI',
                          icon: Icons.smart_toy_rounded,
                          color: AppTheme.secondary,
                          isHighlight: true,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RagScreen(landmarkName: lm.name))),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isHighlight = false,
  }) {
    final fg = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isHighlight
              ? const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighlight
                ? Colors.transparent
                : Colors.white.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: isHighlight
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isHighlight ? const Color(0xFF1A1A1A) : fg, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: isHighlight ? const Color(0xFF1A1A1A) : fg,
                    fontSize: 12,
                    fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }



  Widget _buildDesktopUnsupported() => Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
              const Text('Scan Landmark',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia')),
            ])),
        const Spacer(),
        Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.secondary.withOpacity(0.4))),
            child: const Icon(Icons.smartphone_rounded,
                size: 52, color: Color(0xFFFFB300))),
        const SizedBox(height: 28),
        const Text('Mobile Device Required',
            style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
                'The landmark scanning feature uses your device camera and '
                'AI model. It is only supported on Android and iOS devices.\n\n'
                'Run this app on a physical mobile device to use this feature.',
                style:
                    TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
                textAlign: TextAlign.center)),
        const Spacer(),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)))))),
      ])));

  Widget _buildLoadingState() => Container(
      color: Colors.black,
      child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: Color(0xFFFFB300)),
        SizedBox(height: 16),
        Text('Starting camera...',
            style: TextStyle(color: Colors.white60, fontSize: 14)),
      ])));

  Widget _buildCameraError() => Container(
      color: const Color(0xFF1A0A00),
      child: Center(
          child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.secondary.withOpacity(0.4))),
                    child: const Icon(Icons.no_photography_outlined,
                        size: 44, color: Color(0xFFFFB300))),
                const SizedBox(height: 24),
                const Text('Camera Not Available',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Georgia')),
                const SizedBox(height: 10),
                Text(_cameraError ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13, height: 1.5)),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _cameraError = null);
                      _initCamera();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)))),
              ]))));

  Widget _buildScanFrame() => Center(
      child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) {
            final g = _pulseAnim.value;
            return Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Color.lerp(AppTheme.secondary,
                            AppTheme.secondary.withOpacity(0.3), g)!,
                        width: 2.5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.secondary.withOpacity(0.2 * (1 - g)),
                          blurRadius: 20,
                          spreadRadius: 4)
                    ]),
                child: Stack(children: [
                  _corner(Alignment.topLeft),
                  _corner(Alignment.topRight),
                  _corner(Alignment.bottomLeft),
                  _corner(Alignment.bottomRight),
                ]));
          }));

  Widget _corner(Alignment a) => Align(
      alignment: a,
      child: SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(painter: _CornerPainter(alignment: a, thick: 3))));

  Widget _buildBottomLabel() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_rounded, color: Color(0xFFFFB300), size: 18),
        SizedBox(width: 8),
        Flexible(
            child: Text('Point camera at a heritage landmark...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center)),
      ]));

}

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  final double thick;
  const _CornerPainter({required this.alignment, required this.thick});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.secondary
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final h =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final v = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    const len = 16.0;
    final x = h ? 0.0 : size.width;
    final y = v ? 0.0 : size.height;
    canvas.drawLine(Offset(x, y), Offset(x + (h ? len : -len), y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + (v ? len : -len)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Detection overlay painter ───────────────────────────────────────────────

class _DetectionOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size? previewSize; // CameraValue.previewSize (always landscape)
  final int sensorOrientation; // degrees (0, 90, 180, 270)

  const _DetectionOverlayPainter({
    required this.detections,
    required this.previewSize,
    required this.sensorOrientation,
  });

  @override
  void paint(Canvas canvas, Size widgetSize) {
    if (detections.isEmpty || previewSize == null) return;

    // CameraValue.previewSize is always in landscape (width > height).
    // When the sensor is rotated 90° or 270° (portrait device), the logical
    // preview shown by CameraPreview is actually portrait, so we must swap
    // width ↔ height to get the correct aspect ratio for the displayed frame.
    final bool isRotated90 =
        sensorOrientation == 90 || sensorOrientation == 270;
    final double pvW = isRotated90 ? previewSize!.height : previewSize!.width;
    final double pvH = isRotated90 ? previewSize!.width : previewSize!.height;

    // Compute how CameraPreview scales the frame inside the widget
    // (it uses BoxFit.cover – the preview fills the widget, cropping if needed).
    final double scaleX = widgetSize.width / pvW;
    final double scaleY = widgetSize.height / pvH;
    final double scale = scaleX > scaleY ? scaleX : scaleY; // cover
    final double scaledW = pvW * scale;
    final double scaledH = pvH * scale;
    final double offsetX = (widgetSize.width - scaledW) / 2;
    final double offsetY = (widgetSize.height - scaledH) / 2;

    for (final det in detections) {
      final colour = const Color(0xFFFFB300); // Standardized AR Yellow

      // Map normalised [0..1] box to widget pixels
      final x1 = offsetX + det.boundingBox.left * scaledW;
      final y1 = offsetY + det.boundingBox.top * scaledH;
      final x2 = offsetX + det.boundingBox.right * scaledW;
      final y2 = offsetY + det.boundingBox.bottom * scaledH;
      final box = Rect.fromLTRB(x1, y1, x2, y2);

      // Semi-transparent fill
      canvas.drawRect(
          box,
          Paint()
            ..color = colour.withOpacity(0.12)
            ..style = PaintingStyle.fill);

      // Border
      canvas.drawRect(
          box,
          Paint()
            ..color = colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);

      // Corner accents
      _drawCorners(canvas, box, colour);

      // Label chip: "<name>  <conf>%"
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

      // Position chip above the box; flip below if out of bounds
      double chipX = x1;
      double chipY = y1 - chipH - 6;
      if (chipY < 0) chipY = y2 + 6;
      chipX = chipX.clamp(4.0, widgetSize.width - chipW - 4);

      // Chip background (Dark Frosted Glass)
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(chipX, chipY, chipW, chipH),
            const Radius.circular(10)),
        Paint()..color = Colors.black.withOpacity(0.75),
      );
      
      // Chip subtle border
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(chipX, chipY, chipW, chipH),
            const Radius.circular(10)),
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

    // Top-left
    canvas.drawLine(
        Offset(box.left, box.top), Offset(box.left + len, box.top), paint);
    canvas.drawLine(
        Offset(box.left, box.top), Offset(box.left, box.top + len), paint);
    // Top-right
    canvas.drawLine(
        Offset(box.right, box.top), Offset(box.right - len, box.top), paint);
    canvas.drawLine(
        Offset(box.right, box.top), Offset(box.right, box.top + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(box.left, box.bottom),
        Offset(box.left + len, box.bottom), paint);
    canvas.drawLine(Offset(box.left, box.bottom),
        Offset(box.left, box.bottom - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(box.right, box.bottom),
        Offset(box.right - len, box.bottom), paint);
    canvas.drawLine(Offset(box.right, box.bottom),
        Offset(box.right, box.bottom - len), paint);
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter old) {
    if (old.detections.length != detections.length) return true;
    if (detections.isEmpty) return false;
    return old.detections.first.label != detections.first.label ||
        old.detections.first.boundingBox != detections.first.boundingBox;
  }
}
