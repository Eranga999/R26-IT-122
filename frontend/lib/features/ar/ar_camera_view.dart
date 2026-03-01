import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../database/landmark_model.dart';
import '../database/sub_landmark_model.dart';
import '../database/database_helper.dart';
import '../../core/theme/app_theme.dart';

/// Live-camera AR overlay view for Function 2.
///
/// Uses the [camera] package to show the device camera feed, then layers
/// animated AR-style overlays (scanning frame → landmark name badge →
/// hotspot markers → info panel) on top.
///
/// Full ARCore 3-D anchor rendering will replace the overlay layer in
/// Phase 2 once the ar_flutter_plugin NDK compatibility issue is resolved.
class ArCameraView extends StatefulWidget {
  final LandmarkModel landmark;

  const ArCameraView({super.key, required this.landmark});

  @override
  State<ArCameraView> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCameraView>
    with TickerProviderStateMixin {
  // ── Camera ──────────────────────────────────────────────────────────────
  CameraController? _controller;
  String? _error;

  // ── Data ─────────────────────────────────────────────────────────────────
  List<SubLandmarkModel> _subLandmarks = [];
  bool _overlayVisible = false;
  bool _infoPanelExpanded = false;

  // ── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _scanAnim;
  late final AnimationController _pulseAnim;
  late final AnimationController _fadeAnim;
  late final Animation<double> _fadeIn;

  // ── Hotspot tap states ────────────────────────────────────────────────────
  int _selectedHotspot = -1;

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
    _loadSubLandmarks();
  }

  // ── Init helpers ──────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.high,
          enableAudio: false);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      // Simulate landmark "lock-on" after 2 s
      Future.delayed(const Duration(seconds: 2), _showOverlay);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: ${e.toString()}');
    }
  }

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
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera feed
          _buildCameraLayer(),

          // 2. Scan animation (shown while "tracking")
          if (_controller?.value.isInitialized == true && !_overlayVisible)
            _buildScanningOverlay(),

          // 3. AR overlays (shown after lock-on)
          if (_overlayVisible)
            FadeTransition(opacity: _fadeIn, child: _buildArOverlays()),

          // 4. Top bar (always visible)
          _buildTopBar(),

          // 5. Bottom info panel
          if (_overlayVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeTransition(opacity: _fadeIn, child: _buildInfoPanel()),
            ),

          // 6. Hotspot detail popup
          if (_selectedHotspot >= 0 && _selectedHotspot < _subLandmarks.length)
            _buildHotspotDetail(_subLandmarks[_selectedHotspot]),
        ],
      ),
    );
  }

  // ── Camera layer ─────────────────────────────────────────────────────────

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

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
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
                Text(
                  widget.landmark.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const Text('AR Camera View',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const Spacer(),
            // Live badge
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

  // ── Scanning overlay ──────────────────────────────────────────────────────

  Widget _buildScanningOverlay() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Horizontal scan line
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (_, __) {
            final y = (size.height - 200) * _scanAnim.value + 80;
            return Positioned(
              top: y,
              left: 32,
              right: 32,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.greenAccent.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Corner brackets
        ..._cornerBrackets(context, Colors.greenAccent, scanning: true),
        // Status chip
        Positioned(
          bottom: 130,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color:
                      Colors.black.withOpacity(0.55 + _pulseAnim.value * 0.15),
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

  // ── AR overlays ───────────────────────────────────────────────────────────

  Widget _buildArOverlays() {
    final size = MediaQuery.of(context).size;

    // Five hotspot positions spread across the viewfinder
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
        // Corner brackets – golden when locked
        ..._cornerBrackets(context, const Color(0xFFFFB300), scanning: false),

        // Landmark name label
        Positioned(
          top: 145,
          left: 0,
          right: 0,
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
                Text(
                  widget.landmark.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
              ]),
            ),
          ),
        ),

        // Hotspot markers
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
            border: selected
                ? Border.all(color: const Color(0xFFFFB300), width: 2)
                : null,
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
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Hotspot detail popup ──────────────────────────────────────────────────

  Widget _buildHotspotDetail(SubLandmarkModel sub) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 24,
      right: 24,
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            Text(
              sub.description,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.5),
            ),
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

  // ── Bottom info panel ─────────────────────────────────────────────────────

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
          stops: const [0.0, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10)),
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

          // Description (truncated or full)
          Text(
            _infoPanelExpanded
                ? lm.description
                : (lm.description.length > 100
                    ? '${lm.description.substring(0, 100)}…'
                    : lm.description),
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, height: 1.45),
          ),

          // Sub-landmark chips
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
                    onTap: () =>
                        setState(() => _selectedHotspot = sel ? -1 : i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFFFB300).withOpacity(0.25)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                sel ? const Color(0xFFFFB300) : Colors.white24,
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
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
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

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Corner bracket decorations for the viewfinder frame.
List<Widget> _cornerBrackets(BuildContext ctx, Color color,
    {required bool scanning}) {
  final size = MediaQuery.of(ctx).size;
  const margin = 36.0;
  final top = 88.0;
  final bottom = size.height * 0.55;
  const len = 28.0;
  const thick = 2.5;

  Widget bracket(double l, double t, _Corner c) => Positioned(
        left: l,
        top: t,
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
    // distance indicator
    Positioned(
      left: margin + 6,
      top: top - 16,
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

/// Loading widget shown while camera initialises.
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
