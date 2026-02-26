import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ar_availability.dart';
import '../../features/recognition/recognition_service.dart';
import '../../features/database/database_helper.dart';
import '../../features/database/landmark_model.dart';
import '../../features/database/sub_landmark_model.dart';
import '../ar/ar_screen.dart';
import '../rag/rag_screen.dart';
import '../navigation/nav_screen.dart';
import '../home/home_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  String? _cameraError;
  bool _isProcessing = false;
  LandmarkModel? _detectedLandmark;
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
    if (_isProcessing || _panelVisible) return;
    _isProcessing = true;
    try {
      final result =
          await RecognitionService.instance.predict(image.planes.first.bytes);
      if (result != null && mounted && result.confidence >= 0.70) {
        await _onLandmarkDetected(result.label, result.confidence);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _onLandmarkDetected(String label, double conf) async {
    final id = _labelToId(label);
    final lm = await DatabaseHelper.instance.getLandmarkById(id);
    if (lm == null || !mounted) return;
    final subs = await DatabaseHelper.instance.getSubLandmarks(id);
    if (!mounted) return;
    setState(() {
      _detectedLandmark = lm;
      _subLandmarks = subs;
      _confidence = conf;
      _panelVisible = true;
    });
  }

  int _labelToId(String label) {
    const m = {
      'Sigiriya': 1,
      'Dambulla': 2,
      'Dambulla Cave Temple': 2,
      'Polonnaruwa': 3
    };
    return m[label] ?? 1;
  }

  void _dismissPanel() => setState(() {
        _panelVisible = false;
        _detectedLandmark = null;
        _subLandmarks = [];
      });

  Future<void> _showDemoPicker() async {
    final landmarks = await DatabaseHelper.instance.getAllLandmarks();
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
            const Text('Select a landmark to preview the AR overlay',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            ...landmarks.map((lm) => ListTile(
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
                    _onLandmarkDetected(lm.name, 0.94);
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
                      Text('${(_confidence * 100).toStringAsFixed(0)}% match',
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
                                      builder: (_) => ArScreen(landmark: lm))),
                              icon: const Icon(Icons.view_in_ar_rounded,
                                  size: 18),
                              label: Text(
                                _arStatus?.supported == true
                                    ? 'Launch AR'
                                    : 'View AR Details',
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _arStatus?.supported == true
                                      ? const Color(0xFF00695C)
                                      : const Color(0xFF455A64),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700))))),

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
