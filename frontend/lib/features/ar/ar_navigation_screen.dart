import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// AR Navigation Screen
/// Shows live camera feed with overlaid directional arrows
/// guiding the user from Sigiriya ticket counter to their destination.
class ArNavigationScreen extends StatefulWidget {
  final String destination;
  final String detectedLabel;

  const ArNavigationScreen({
    super.key,
    required this.destination,
    required this.detectedLabel,
  });

  @override
  State<ArNavigationScreen> createState() => _ArNavigationScreenState();
}

class _ArNavigationScreenState extends State<ArNavigationScreen>
    with TickerProviderStateMixin {

  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;

  // ── Route ─────────────────────────────────────────────────────────────────
  int _currentStep = 0;
  bool _arrived = false;
  late List<_RouteStep> _route;

  // ── Compass ───────────────────────────────────────────────────────────────
  double _compassHeading = 0.0;
  StreamSubscription? _compassSub;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _arrowPulse;
  late AnimationController _arrivalAnim;
  late Animation<double> _arrowScale;
  late Animation<double> _arrivalScale;

  // ── Simulated distance ────────────────────────────────────────────────────
  double _distanceRemaining = 0;
  Timer? _distanceTimer;

  @override
  void initState() {
    super.initState();
    _buildRoute();
    _initCamera();
    _initCompass();
    _initAnimations();
    _startDistanceSimulation();
  }

  void _buildRoute() {
    final dest = widget.detectedLabel;

    // Full route map from ticket counter to each destination
    final Map<String, List<_RouteStep>> allRoutes = {
      'sigiriya_lion_paws': [
        _RouteStep(
          instruction: 'Walk straight ahead',
          subInstruction: 'from the ticket counter',
          direction: _Direction.straight,
          distance: 180,
          landmark: 'Ticket Counter',
        ),
        _RouteStep(
          instruction: 'Turn right',
          subInstruction: 'at the water garden path',
          direction: _Direction.right,
          distance: 220,
          landmark: 'Water Gardens',
        ),
        _RouteStep(
          instruction: 'Continue straight',
          subInstruction: 'along the boulder garden path',
          direction: _Direction.straight,
          distance: 150,
          landmark: 'Boulder Gardens',
        ),
        _RouteStep(
          instruction: 'Turn left and climb',
          subInstruction: 'follow the staircase signs',
          direction: _Direction.left,
          distance: 120,
          landmark: 'Fresco Gallery',
        ),
        _RouteStep(
          instruction: 'You have arrived!',
          subInstruction: 'Lion Paws are ahead of you',
          direction: _Direction.arrive,
          distance: 0,
          landmark: 'Lion Paws',
        ),
      ],
      'sigiriya_mirror_wall': [
        _RouteStep(
          instruction: 'Walk straight ahead',
          subInstruction: 'from the ticket counter',
          direction: _Direction.straight,
          distance: 180,
          landmark: 'Ticket Counter',
        ),
        _RouteStep(
          instruction: 'Turn right',
          subInstruction: 'at the water garden path',
          direction: _Direction.right,
          distance: 220,
          landmark: 'Water Gardens',
        ),
        _RouteStep(
          instruction: 'Climb the staircase',
          subInstruction: 'follow signs to Mirror Wall',
          direction: _Direction.straight,
          distance: 130,
          landmark: 'Lower Staircase',
        ),
        _RouteStep(
          instruction: 'You have arrived!',
          subInstruction: 'Mirror Wall is on your left',
          direction: _Direction.arrive,
          distance: 0,
          landmark: 'Mirror Wall',
        ),
      ],
      'sigiriya_lion_rock': [
        _RouteStep(
          instruction: 'Walk straight ahead',
          subInstruction: 'from the ticket counter',
          direction: _Direction.straight,
          distance: 180,
          landmark: 'Ticket Counter',
        ),
        _RouteStep(
          instruction: 'Turn right',
          subInstruction: 'follow the main path',
          direction: _Direction.right,
          distance: 300,
          landmark: 'Water Gardens',
        ),
        _RouteStep(
          instruction: 'Continue climbing',
          subInstruction: 'up the main staircase',
          direction: _Direction.straight,
          distance: 250,
          landmark: 'Mid Staircase',
        ),
        _RouteStep(
          instruction: 'Turn left at the gate',
          subInstruction: 'through the lion paws',
          direction: _Direction.left,
          distance: 100,
          landmark: 'Lion Gate',
        ),
        _RouteStep(
          instruction: 'You have arrived!',
          subInstruction: 'Welcome to Lion Rock summit',
          direction: _Direction.arrive,
          distance: 0,
          landmark: 'Lion Rock Summit',
        ),
      ],
      'sigiriya_throne': [
        _RouteStep(
          instruction: 'Walk straight ahead',
          subInstruction: 'from the ticket counter',
          direction: _Direction.straight,
          distance: 180,
          landmark: 'Ticket Counter',
        ),
        _RouteStep(
          instruction: 'Turn left',
          subInstruction: 'toward the royal gardens',
          direction: _Direction.left,
          distance: 160,
          landmark: 'Royal Gardens',
        ),
        _RouteStep(
          instruction: 'You have arrived!',
          subInstruction: 'The throne is ahead of you',
          direction: _Direction.arrive,
          distance: 0,
          landmark: 'Royal Throne',
        ),
      ],
      'sigiriya_ticket_counter': [
        _RouteStep(
          instruction: 'You are at the start',
          subInstruction: 'Ticket counter is right here',
          direction: _Direction.arrive,
          distance: 0,
          landmark: 'Ticket Counter',
        ),
      ],
    };

    _route = allRoutes[dest] ??
        allRoutes['sigiriya_lion_paws']!;

    _distanceRemaining =
        _route[_currentStep].distance.toDouble();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found');
        return;
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _cameraError = e.toString());
    }
  }

  void _initCompass() {
    _compassSub = magnetometerEventStream().listen((event) {
      final heading = math.atan2(event.y, event.x) * (180 / math.pi);
      if (mounted) setState(() => _compassHeading = heading);
    });
  }

  void _initAnimations() {
    _arrowPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _arrowScale = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _arrowPulse, curve: Curves.easeInOut));

    _arrivalAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arrivalScale = CurvedAnimation(
        parent: _arrivalAnim, curve: Curves.elasticOut);
  }

  void _startDistanceSimulation() {
    _distanceTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _arrived) return;
      final step = _route[_currentStep];
      if (_distanceRemaining > 0) {
        setState(() {
          _distanceRemaining =
              (_distanceRemaining - 2).clamp(0, step.distance.toDouble());
        });
      }
    });
  }

  void _nextStep() {
    if (_currentStep >= _route.length - 1) {
      _triggerArrival();
      return;
    }
    setState(() {
      _currentStep++;
      _distanceRemaining = _route[_currentStep].distance.toDouble();
      if (_route[_currentStep].direction == _Direction.arrive) {
        _triggerArrival();
      }
    });
  }

  void _triggerArrival() {
    setState(() => _arrived = true);
    _arrivalAnim.forward();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _distanceTimer?.cancel();
    _cameraController?.dispose();
    _arrowPulse.dispose();
    _arrivalAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera background
          _buildCameraLayer(),

          // 2. Dark vignette overlay
          _buildVignette(),

          // 3. Top navigation bar
          _buildTopBar(),

          // 4. AR arrow in the middle
          if (!_arrived) _buildArArrow(),

          // 5. Route step card at the bottom
          if (!_arrived) _buildStepCard(),

          // 6. Arrival overlay
          if (_arrived) _buildArrivalOverlay(),

          // 7. Next step button
          if (!_arrived) _buildNextButton(),
        ],
      ),
    );
  }

  // ── Camera layer ──────────────────────────────────────────────────────────
  Widget _buildCameraLayer() {
    if (_cameraError != null) {
      return Container(
        color: const Color(0xFF0A1628),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              const Text('Camera unavailable',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Text(
                'AR overlay still works',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_cameraReady || _cameraController == null) {
      return Container(
        color: const Color(0xFF0A1628),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFB300)),
              SizedBox(height: 16),
              Text('Starting camera...',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return CameraPreview(_cameraController!);
  }

  // ── Vignette ──────────────────────────────────────────────────────────────
  Widget _buildVignette() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.55),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final step = _route[_currentStep];
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
        padding: const EdgeInsets.fromLTRB(8, 48, 16, 24),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigating to ${_destinationDisplay()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of ${_route.length}  •  '
                    '${step.distance}m total',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Compass indicator
            _buildCompassIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassIndicator() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Transform.rotate(
        angle: _compassHeading * (math.pi / 180),
        child: const Icon(Icons.navigation_rounded,
            color: Color(0xFFFFB300), size: 22),
      ),
    );
  }

  // ── AR Arrow ──────────────────────────────────────────────────────────────
  Widget _buildArArrow() {
    final step = _route[_currentStep];

    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Distance pill above arrow
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                _distanceRemaining > 0
                    ? '${_distanceRemaining.toInt()} m ahead'
                    : 'Turn now',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // The main AR arrow
            ScaleTransition(
              scale: _arrowScale,
              child: _ArrowWidget(
                direction: step.direction,
                color: _arrowColor(step.direction),
              ),
            ),

            const SizedBox(height: 20),

            // Landmark label below arrow
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _arrowColor(step.direction).withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                step.landmark,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _arrowColor(_Direction dir) {
    switch (dir) {
      case _Direction.left:
        return const Color(0xFF1565C0);
      case _Direction.right:
        return const Color(0xFF2E7D32);
      case _Direction.straight:
        return const Color(0xFFFFB300);
      case _Direction.arrive:
        return const Color(0xFF00897B);
    }
  }

  // ── Step card at the bottom ───────────────────────────────────────────────
  Widget _buildStepCard() {
    final step = _route[_currentStep];
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _arrowColor(step.direction).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _arrowColor(step.direction), width: 1.5),
              ),
              child: Icon(
                _directionIcon(step.direction),
                color: _arrowColor(step.direction),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.subInstruction,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Progress dots
            Column(
              children: List.generate(_route.length, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  width: 8,
                  height: i == _currentStep ? 16 : 8,
                  decoration: BoxDecoration(
                    color: i <= _currentStep
                        ? const Color(0xFFFFB300)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Next button ───────────────────────────────────────────────────────────
  Widget _buildNextButton() {
    final isLast = _currentStep == _route.length - 1;
    return Positioned(
      bottom: 28,
      left: 24,
      right: 24,
      child: ElevatedButton.icon(
        onPressed: _nextStep,
        icon: Icon(isLast
            ? Icons.flag_rounded
            : Icons.arrow_forward_rounded),
        label: Text(
          isLast ? 'I have arrived!' : 'Next step →',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLast
              ? const Color(0xFF00897B)
              : const Color(0xFFFFB300),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: const Color(0xFFFFB300).withOpacity(0.5),
        ),
      ),
    );
  }

  // ── Arrival overlay ───────────────────────────────────────────────────────
  Widget _buildArrivalOverlay() {
    final dest = _destinationDisplay();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: ScaleTransition(
            scale: _arrivalScale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(28),
                border:
                    Border.all(color: const Color(0xFF00897B), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00897B).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF00897B), width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF00897B), size: 44),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'You have arrived!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dest,
                    style: const TextStyle(
                      color: Color(0xFF00897B),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You have successfully navigated\nfrom the ticket counter.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Back to app'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _destinationDisplay() {
    const names = {
      'sigiriya_lion_paws': 'Lion Paws',
      'sigiriya_mirror_wall': 'Mirror Wall',
      'sigiriya_lion_rock': 'Lion Rock Summit',
      'sigiriya_throne': 'Royal Throne',
      'sigiriya_ticket_counter': 'Ticket Counter',
    };
    return names[widget.detectedLabel] ?? widget.destination;
  }

  IconData _directionIcon(_Direction dir) {
    switch (dir) {
      case _Direction.left:
        return Icons.turn_left_rounded;
      case _Direction.right:
        return Icons.turn_right_rounded;
      case _Direction.straight:
        return Icons.straight_rounded;
      case _Direction.arrive:
        return Icons.flag_rounded;
    }
  }
}

// ── AR Arrow Widget ───────────────────────────────────────────────────────────
class _ArrowWidget extends StatelessWidget {
  final _Direction direction;
  final Color color;

  const _ArrowWidget({required this.direction, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Icon(
        _icon(),
        color: color,
        size: 80,
      ),
    );
  }

  IconData _icon() {
    switch (direction) {
      case _Direction.left:
        return Icons.turn_left_rounded;
      case _Direction.right:
        return Icons.turn_right_rounded;
      case _Direction.straight:
        return Icons.arrow_upward_rounded;
      case _Direction.arrive:
        return Icons.flag_rounded;
    }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────
enum _Direction { straight, left, right, arrive }

class _RouteStep {
  final String instruction;
  final String subInstruction;
  final _Direction direction;
  final int distance;
  final String landmark;

  const _RouteStep({
    required this.instruction,
    required this.subInstruction,
    required this.direction,
    required this.distance,
    required this.landmark,
  });
}