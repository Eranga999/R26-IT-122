import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ar_availability.dart';
import '../../features/recognition/recognition_service.dart';
import '../../features/database/database_helper.dart';
import '../../features/database/landmark_model.dart';
import '../../features/database/sub_landmark_model.dart';
// recognition service already imported above
import '../ar/ar_screen.dart';
import '../ar/ar_navigation_screen.dart';
import '../rag/rag_screen.dart';
import '../navigation/nav_screen.dart';
import '../home/home_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    this.lockedLandmarkId,
    this.lockedLandmarkName,
  });

  final int? lockedLandmarkId;
  final String? lockedLandmarkName;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  String? _cameraError;
  bool _isProcessing = false;
  int _lastProcessTime = 0; // for throttling

  // ── Live detection state (shown while scanning) ────────────────────────────
  List<DetectionResult> _liveDetections = [];  // real-time boxes on camera

  // ── Info-panel state (opened when confident enough) ────────────────────────
  LandmarkModel? _detectedLandmark;
  DetectionResult? _activeDetection;
  String? _detectedClassLabel;
  List<SubLandmarkModel> _subLandmarks = [];
  double _confidence = 0;
  bool _panelVisible = false;

  late final AnimationController _pulseAnim;
  ArStatus? _arStatus;

  @override
  void initState() {
    super.initState();
    _pulseAnim =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    if (!_isDesktop) {
      _initCamera();
      RecognitionService.instance.loadModel();
      _checkArSupport();
    }
  }

  Future<void> _checkArSupport() async {
    final status = await ArAvailability.check();
    if (mounted) setState(() => _arStatus = status);
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
      _controller = CameraController(cameras.first, ResolutionPreset.medium,
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
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isProcessing || _panelVisible || (now - _lastProcessTime < 333)) return;
    _isProcessing = true;
    _lastProcessTime = now;
    try {
      final results = await RecognitionService.instance.predictAll(
        image,
        sensorOrientation: _controller?.description.sensorOrientation ?? 0,
        threshold: 0.30, // show boxes from 30% confidence
      );

      if (!mounted) return;

      if (kDebugMode) {
        debugPrint(
            '[Scan] ${results.length} detections | '
            'previewSize=${_controller?.value.previewSize} | '
            'sensor=${_controller?.description.sensorOrientation}°');
        for (final r in results) {
          debugPrint('  -> ${r.label} ${(r.confidence * 100).toStringAsFixed(1)}% box=${r.boundingBox}');
        }
      }

      // Always update the live overlay
      setState(() => _liveDetections = results);

      // Open the info panel only when confident enough
      final highConf = results
          .where((r) => r.confidence >= 0.50)
          .fold<DetectionResult?>(
              null,
              (best, r) =>
                  best == null || r.confidence > best.confidence ? r : best);

      if (highConf != null) {
        await _onLandmarkDetected(highConf);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Scan] frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onLandmarkDetected(DetectionResult detection) async {
    final id = _labelToId(detection.label);
    if (id == null) {
      if (kDebugMode) {
        debugPrint('Ignoring unsupported detection label: ${detection.label}');
      }
      return;
    }
    if (widget.lockedLandmarkId != null && id != widget.lockedLandmarkId) {
      return;
    }

    final lm = await DatabaseHelper.instance.getLandmarkById(id);
    if (lm == null || !mounted) return;
    final subs = await DatabaseHelper.instance.getSubLandmarks(id);
    if (!mounted) return;
    setState(() {
      _detectedLandmark = lm;
      _activeDetection = detection;
      _detectedClassLabel = detection.label;
      _subLandmarks = subs;
      _confidence = detection.confidence;
      _panelVisible = true;
    });
  }

  int? _labelToId(String label) {
    final normalized = label.trim().toLowerCase();
    const m = {
      'sigiriya_entrance': 1,
      'sigiriya_lion_rock': 1,
      'sigiriya_mirror_wall': 1,
      'sigiriya_lion_staircase': 1,
      'sigiriya_throne': 1,
      'sigiriya': 1,
      'dambulla': 2,
      'dambulla cave temple': 2,
      'polonnaruwa': 3,
    };
    return m[normalized];
  }

  void _dismissPanel() => setState(() {
        _panelVisible = false;
        _detectedLandmark = null;
        _activeDetection = null;
        _detectedClassLabel = null;
        _subLandmarks = [];
        _liveDetections = [];
      });

  Future<void> _showDemoPicker() async {
    final landmarks = await DatabaseHelper.instance.getAllLandmarks();
    final options = widget.lockedLandmarkId == null
        ? landmarks
        : landmarks.where((lm) => lm.id == widget.lockedLandmarkId).toList();

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
                widget.lockedLandmarkName == null
                    ? 'Select a landmark to preview the AR overlay'
                    : 'Site lock active: ${widget.lockedLandmarkName}',
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
                    final simulatedBox = Rect.fromLTWH(0.25, 0.25, 0.5, 0.5);
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
            child: IgnorePointer(
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

        // Debug Stats
        if (kDebugMode)
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('DEBUG SCANNER', style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text('Model Input: ${RecognitionService.instance.inputWidth}x${RecognitionService.instance.inputHeight}',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                   Text('Live Detections: ${_liveDetections.length}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                   if (_liveDetections.isNotEmpty)
                     Text('Top Conf: ${(_liveDetections.first.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                  if (RecognitionService.instance.loadError != null)
                    Text('ERROR: ${RecognitionService.instance.loadError}',
                         style: const TextStyle(color: Colors.redAccent, fontSize: 9)),
                ],
              ),
            ),
          ),

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
                if (widget.lockedLandmarkName != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      widget.lockedLandmarkName!,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
                const Spacer(),
                if (_panelVisible && _detectedLandmark != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                          '${_detectedClassLabel ?? _detectedLandmark!.name} • ${(_confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            )),

        if (_controller?.value.isInitialized == true && !_panelVisible)
          _buildScanFrame(),

        if (_panelVisible && _detectedLandmark != null) _buildArPanel(),

        if (_arStatus != null && !_panelVisible)
          Positioned(
              top: 110, left: 20, right: 20, child: _buildArStatusBanner()),

        if (widget.lockedLandmarkId != null &&
            widget.lockedLandmarkId != 1 &&
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
      floatingActionButton: (!_panelVisible &&
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

  Widget _buildArStatusBanner() {
    final status = _arStatus!;
    final ok = status.supported;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.withOpacity(0.85)
            : Colors.red.shade900.withOpacity(0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: ok ? Colors.green.shade200 : Colors.red.shade300,
            width: 0.8),
      ),
      child: Row(children: [
        Icon(
          ok ? Icons.view_in_ar_rounded : Icons.no_photography_outlined,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ok
                ? 'AR Supported – 3D overlays available'
                : status.reason ?? 'AR not supported on this device',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  Widget _buildUnsupportedSiteBanner() {
    final siteName = widget.lockedLandmarkName ?? 'this site';
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
            'Live recognition currently supports Sigiriya only. $siteName is available in the app, but this camera flow will not auto-detect it.',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  Widget _buildArPanel() {
    final lm = _detectedLandmark!;
    final idx = ((lm.id ?? 1) - 1);
    const gs = [
      [Color(0xFFB71C1C), Color(0xFFE53935)],
      [Color(0xFFE65100), Color(0xFFFF8F00)],
      [Color(0xFF1A237E), Color(0xFF3949AB)],
    ];
    final colors = gs[idx % gs.length];
    final histSnip = lm.history.isNotEmpty
        ? '${lm.history.split('. ').take(2).join('. ')}.'
        : lm.description;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.30,
        maxChildSize: 0.92,
        snap: true,
        snapSizes: const [0.30, 0.52, 0.92],
        builder: (context, sc) => Container(
          decoration: const BoxDecoration(
              color: Color(0xFFFFF8F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    blurRadius: 24,
                    color: Colors.black54,
                    offset: Offset(0, -4))
              ]),
          child: SingleChildScrollView(
              controller: sc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2)))),

                  // Header
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.account_balance_rounded,
                              color: Colors.white, size: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(lm.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Georgia',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on_rounded,
                                  color: Colors.white70, size: 13),
                              const SizedBox(width: 3),
                              const Text('Sri Lanka',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 10),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text('UNESCO',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600))),
                            ]),
                          ])),
                      IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70),
                          onPressed: _dismissPanel),
                    ]),
                  ),

                  // Quick facts
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _quickFacts(lm.id ?? 1)
                                .map((f) => _FactPill(
                                    label: f[0],
                                    value: f[1],
                                    color: Color(colors[0].value)))
                                .toList()),
                      )),

                  // History

                  if (_activeDetection != null)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF3E5AB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      Color(colors[0].value).withOpacity(0.2))),
                          child: Text(
                            'Detected class: ${_detectedClassLabel ?? _activeDetection!.label}\n'
                            'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%\n'
                            'BBox: ${_bboxText(_activeDetection!.boundingBox)}',
                            style: const TextStyle(
                                color: Color(0xFF4E342E),
                                fontSize: 12.5,
                                height: 1.6,
                                fontWeight: FontWeight.w600),
                          ),
                        )),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.history_edu_rounded,
                                  color: Color(colors[0].value), size: 18),
                              const SizedBox(width: 6),
                              const Text('History',
                                  style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A0A00))),
                            ]),
                            const SizedBox(height: 8),
                            Text(histSnip,
                                style: const TextStyle(
                                    color: Color(0xFF4E342E),
                                    fontSize: 13.5,
                                    height: 1.65)),
                          ])),

                  // Sub-landmarks
                  if (_subLandmarks.isNotEmpty) ...[
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Row(children: [
                          Icon(Icons.place_rounded,
                              color: Color(colors[0].value), size: 18),
                          const SizedBox(width: 6),
                          const Text('Points of Interest',
                              style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A0A00))),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color:
                                      Color(colors[0].value).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text('${_subLandmarks.length} stops',
                                  style: TextStyle(
                                      color: Color(colors[0].value),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600))),
                        ])),
                    const SizedBox(height: 10),
                    ..._subLandmarks.take(4).map((sub) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ]),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                        color: Color(colors[0].value)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Icon(_subTypeIcon(sub.type),
                                        color: Color(colors[0].value),
                                        size: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(sub.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF2D1B0E))),
                                      const SizedBox(height: 2),
                                      Text(sub.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xFF6D4C41),
                                              fontSize: 12,
                                              height: 1.5)),
                                    ])),
                              ]),
                        ))),
                  ],

                  // Action buttons
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          LandmarkDetailScreen(landmark: lm))),
                              icon: const Icon(Icons.open_in_full_rounded,
                                  size: 18),
                              label: const Text('View Full Details'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(colors[0].value),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700))))),

                  // View AR button – reflects device capability
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArNavigationScreen(
                              destination: _detectedLandmark!.name,
                              detectedLabel: _detectedClassLabel ??
                                  'sigiriya_lion_paws',
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('Navigate with AR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00695C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(children: [
                        Expanded(
                            child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            RagScreen(landmarkName: lm.name))),
                                icon: const Icon(Icons.smart_toy_rounded,
                                    size: 17),
                                label: const Text('Ask AI'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFB300),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            NavScreen(landmarkName: lm.name))),
                                icon:
                                    const Icon(Icons.explore_rounded, size: 17),
                                label: const Text('Navigate'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF37474F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))))),
                      ])),

                  const SizedBox(height: 24),
                ],
              )),
        ),
      ),
    );
  }

  List<List<String>> _quickFacts(int id) {
    const f1 = [
      ['Founded', '477 AD'],
      ['Type', 'Fortress'],
      ['UNESCO', '1982']
    ];
    const f2 = [
      ['Founded', '1st c BC'],
      ['Type', 'Cave Temple'],
      ['UNESCO', '1991']
    ];
    const f3 = [
      ['Founded', '1070 AD'],
      ['Type', 'Ancient City'],
      ['UNESCO', '1982']
    ];
    if (id == 1) return f1;
    if (id == 2) return f2;
    return f3;
  }

  IconData _subTypeIcon(String type) {
    switch (type) {
      case 'fresco':
        return Icons.palette_rounded;
      case 'gate':
        return Icons.door_front_door_rounded;
      case 'wall':
        return Icons.format_paint_rounded;
      case 'pool':
        return Icons.water_rounded;
      case 'palace':
        return Icons.castle_rounded;
      case 'cave':
        return Icons.terrain_rounded;
      case 'stupa':
        return Icons.architecture_rounded;
      case 'sculpture':
        return Icons.image_rounded;
      case 'temple':
        return Icons.temple_hindu_rounded;
      case 'reservoir':
        return Icons.waves_rounded;
      default:
        return Icons.place_rounded;
    }
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

  String _bboxText(Rect box) {
    return 'x:${(box.left * 100).toStringAsFixed(0)}% '
        'y:${(box.top * 100).toStringAsFixed(0)}% '
        'w:${((box.right - box.left) * 100).toStringAsFixed(0)}% '
        'h:${((box.bottom - box.top) * 100).toStringAsFixed(0)}%';
  }
}

class _FactPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FactPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]);
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
  final Size?  previewSize;      // CameraValue.previewSize (always landscape)
  final int    sensorOrientation; // degrees (0, 90, 180, 270)

  const _DetectionOverlayPainter({
    required this.detections,
    required this.previewSize,
    required this.sensorOrientation,
  });

  // Distinct colours per class index
  static const _boxColours = [
    Color(0xFF00E676), // green
    Color(0xFF40C4FF), // light blue
    Color(0xFFFF6D00), // orange
    Color(0xFFE040FB), // purple
    Color(0xFFFFD740), // amber
  ];

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
    final double pvH = isRotated90 ? previewSize!.width  : previewSize!.height;

    // Compute how CameraPreview scales the frame inside the widget
    // (it uses BoxFit.cover – the preview fills the widget, cropping if needed).
    final double scaleX = widgetSize.width  / pvW;
    final double scaleY = widgetSize.height / pvH;
    final double scale  = scaleX > scaleY ? scaleX : scaleY; // cover
    final double scaledW = pvW * scale;
    final double scaledH = pvH * scale;
    final double offsetX = (widgetSize.width  - scaledW) / 2;
    final double offsetY = (widgetSize.height - scaledH) / 2;

    for (final det in detections) {
      final colour = _boxColours[det.classIndex % _boxColours.length];

      // Map normalised [0..1] box to widget pixels
      final x1 = offsetX + det.boundingBox.left   * scaledW;
      final y1 = offsetY + det.boundingBox.top    * scaledH;
      final x2 = offsetX + det.boundingBox.right  * scaledW;
      final y2 = offsetY + det.boundingBox.bottom * scaledH;
      final box = Rect.fromLTRB(x1, y1, x2, y2);

      // Semi-transparent fill
      canvas.drawRect(
          box,
          Paint()
            ..color = colour.withOpacity(0.15)
            ..style = PaintingStyle.fill);

      // Border
      canvas.drawRect(
          box,
          Paint()
            ..color = colour
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);

      // Corner accents
      _drawCorners(canvas, box, colour);

      // Label chip: "<name>  <conf>%"
      final labelText =
          '${det.label.replaceAll('_', ' ')}  '
          '${(det.confidence * 100).toStringAsFixed(0)}%';

      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: widgetSize.width - 24);

      const padH = 6.0;
      const padV = 4.0;
      final chipW = tp.width  + padH * 2;
      final chipH = tp.height + padV * 2;

      // Position chip above the box; flip below if out of bounds
      double chipX = x1;
      double chipY = y1 - chipH - 4;
      if (chipY < 0) chipY = y2 + 4;
      chipX = chipX.clamp(4.0, widgetSize.width - chipW - 4);

      // Chip background
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(chipX, chipY, chipW, chipH),
            const Radius.circular(6)),
        Paint()..color = colour.withOpacity(0.88),
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
    canvas.drawLine(Offset(box.left, box.top), Offset(box.left + len, box.top), paint);
    canvas.drawLine(Offset(box.left, box.top), Offset(box.left, box.top + len), paint);
    // Top-right
    canvas.drawLine(Offset(box.right, box.top), Offset(box.right - len, box.top), paint);
    canvas.drawLine(Offset(box.right, box.top), Offset(box.right, box.top + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(box.left, box.bottom), Offset(box.left + len, box.bottom), paint);
    canvas.drawLine(Offset(box.left, box.bottom), Offset(box.left, box.bottom - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(box.right, box.bottom), Offset(box.right - len, box.bottom), paint);
    canvas.drawLine(Offset(box.right, box.bottom), Offset(box.right, box.bottom - len), paint);
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter old) =>
      old.detections != detections;
}

