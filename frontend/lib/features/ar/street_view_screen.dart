import 'package:flutter/material.dart';

class StreetViewScreen extends StatefulWidget {
  final String landmarkName;
  const StreetViewScreen({super.key, required this.landmarkName});

  @override
  State<StreetViewScreen> createState() => _StreetViewScreenState();
}

class _StreetViewScreenState extends State<StreetViewScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<_TourStop> _stops = [
    _TourStop(
      name: 'Main Entrance Gate',
      description:
          'Start your journey at the Sigiriya main entrance. '
          'Buy your tickets and prepare for the climb ahead.',
      direction: 'Walk straight through the gate →',
      imageUrl:
          'https://sigiriyafortress.com/wp-content/uploads/2022/11/Tickets-to-sigiriya-lion-rock-Sigiriya-museum-jpg.webp',
      icon: Icons.door_front_door_rounded,
      color: Color(0xFF6D4C41),
    ),
    _TourStop(
      name: 'Water Gardens',
      description:
          'The ancient water gardens are 1,500 years old. '
          'Symmetrical pools and fountains still work naturally during rain.',
      direction: 'Continue forward, turn right →',
      imageUrl:
          'https://overatours.com/wp-content/uploads/2021/09/59-1024x679-1-1024x540.jpg',
      icon: Icons.water_rounded,
      color: Color(0xFF1565C0),
    ),
    _TourStop(
      name: 'Mirror Wall',
      description:
          'The Mirror Wall was once so polished that the king could '
          'see his reflection. Ancient poetry is carved into its surface.',
      direction: 'Climb the staircase, follow left path →',
      imageUrl:
          'https://thumbs.dreamstime.com/b/mirror-wall-sigiriya-sri-lanka-view-inner-side-graffiti-inscriptions-leading-to-upper-level-lion-rock-palace-king-422291364.jpg',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF6A1B9A),
    ),
    _TourStop(
      name: 'Lion Gate (Lion Paws)',
      description:
          'The famous lion paws mark the entrance to the final climb. '
          'Originally a full lion\'s head rose above — only the paws survive.',
      direction: 'Climb through the lion paws →',
      imageUrl:
          'https://preview.redd.it/giant-lions-paws-at-the-entrance-of-sigiriya-fortress-the-v0-s4vp239qk6h51.jpg?width=1080&crop=smart&auto=webp&s=82451b8d60e72c273e6b36e91cb8d1e99e18ced1',
      icon: Icons.pets_rounded,
      color: Color(0xFFB71C1C),
    ),
    _TourStop(
      name: 'Summit Palace',
      description:
          'You have reached the top! The ruins of King Kassapa\'s '
          'palace sit 200 metres above the plains with a stunning 360° view.',
      direction: 'You have arrived at the summit ✓',
      imageUrl:
          'https://www.yogawinetravel.com/wp-content/uploads/2016/05/Sigiriya-Lion-Rock-drone-photo-in-Sri-Lanka.jpg',
      icon: Icons.castle_rounded,
      color: Color(0xFF2E7D32),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _stops.length) return;
    _animController.reset();
    setState(() => _currentIndex = index);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stop = _stops[_currentIndex];
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == _stops.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background photo ──────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: Image.network(
              stop.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: const Color(0xFFFFB300),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading location...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A0A00),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stop.icon, color: stop.color, size: 80),
                      const SizedBox(height: 16),
                      Text(
                        stop.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Dark gradient top ─────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Dark gradient bottom ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Top bar ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.landmarkName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const Text(
                        'Route Tour',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Step counter badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_stops.length}',
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
          ),

          // ── Progress dots ─────────────────────────────────────────────
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_stops.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentIndex ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentIndex
                        ? const Color(0xFFFFB300)
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // ── Location name + description ───────────────────────────────
          Positioned(
            bottom: 160,
            left: 20,
            right: 20,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: stop.color.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stop.icon, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          stop.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stop.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Direction hint
                  Row(
                    children: [
                      const Icon(Icons.navigation_rounded,
                          color: Color(0xFFFFB300), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        stop.direction,
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Navigation arrows ─────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back arrow
                  _NavButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    enabled: !isFirst,
                    onTap: () => _goTo(_currentIndex - 1),
                  ),

                  // Center: current stop icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: stop.color.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: stop.color.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(stop.icon, color: Colors.white, size: 30),
                  ),

                  // Forward arrow
                  _NavButton(
                    icon: isLast
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                    label: isLast ? 'Done' : 'Next',
                    enabled: true,
                    onTap: isLast
                        ? () => Navigator.pop(context)
                        : () => _goTo(_currentIndex + 1),
                    highlight: true,
                  ),
                ],
              ),
            ),
          ),

          // ── Swipe gesture detector ────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -300) {
                  // Swipe left = go forward
                  _goTo(_currentIndex + 1);
                } else if (details.primaryVelocity! > 300) {
                  // Swipe right = go back
                  _goTo(_currentIndex - 1);
                }
              },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation button widget ──────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool highlight;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFFFFB300)
                : Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: highlight ? Colors.white : Colors.white38,
              width: highlight ? 2 : 1,
            ),
            boxShadow: highlight
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!highlight) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: highlight ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (highlight) ...[
                const SizedBox(width: 6),
                Icon(icon,
                    color: highlight ? Colors.black : Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _TourStop {
  final String name;
  final String description;
  final String direction;
  final String imageUrl;
  final IconData icon;
  final Color color;

  const _TourStop({
    required this.name,
    required this.description,
    required this.direction,
    required this.imageUrl,
    required this.icon,
    required this.color,
  });
}