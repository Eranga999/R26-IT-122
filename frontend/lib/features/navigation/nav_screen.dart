import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../features/ar/ar_screen.dart';
import '../../features/database/database_helper.dart';
import '../../features/database/landmark_model.dart';

/// AR Navigation scaffold (Function 4).
///
/// Displays a route-planning UI with waypoints for the selected heritage site.
/// Full AR turn-by-turn navigation will be implemented using the AR plugin
/// once the on-site GPS coordinates are surveyed.
class NavScreen extends StatefulWidget {
  final String landmarkName;

  const NavScreen({super.key, required this.landmarkName});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  static const _waypointData = {
    'Sigiriya': [
      _Waypoint('Main Entrance Gate', 'Ticket counter and entrance plaza',
          Icons.door_front_door_rounded, Colors.green),
      _Waypoint('Water Gardens', 'Ancient hydraulic gardens and fountains',
          Icons.water_rounded, Colors.blue),
      _Waypoint('Boulder Gardens', 'Natural rock formations and caves',
          Icons.landscape_rounded, Colors.brown),
      _Waypoint('Mirror Wall', 'Polished plaster wall with ancient graffiti',
          Icons.auto_awesome_rounded, Colors.orange),
      _Waypoint('Fresco Gallery', '22 surviving ceiling paintings of Apsaras',
          Icons.palette_rounded, Colors.purple),
      _Waypoint('Lion Gate', 'Colossal lion paws entrance', Icons.pets_rounded,
          Colors.red),
      _Waypoint('Summit Palace', 'Royal palace ruins on the plateau',
          Icons.castle_rounded, Colors.indigo),
    ],
    'Dambulla Cave Temple': [
      _Waypoint('Temple Entrance', 'Golden temple entrance and steps',
          Icons.door_front_door_rounded, Colors.green),
      _Waypoint('Cave 1 – Devaraja Viharaya', '15-metre reclining Buddha',
          Icons.self_improvement_rounded, Colors.amber),
      _Waypoint('Cave 2 – Maharaja Viharaya', '150+ statues, 2100 sq ft murals',
          Icons.temple_hindu_rounded, Colors.orange),
      _Waypoint('Cave 3 – Maha Alut Viharaya', '50 gilt Buddha statues',
          Icons.temple_hindu_rounded, Colors.deepOrange),
      _Waypoint('Cave 4 – Pachima Viharaya', 'Sealed dagoba cave',
          Icons.temple_hindu_rounded, Colors.brown),
      _Waypoint('Cave 5 – Devana Alut Viharaya', 'Newest cave, Hindu-Buddhist',
          Icons.temple_hindu_rounded, Colors.teal),
      _Waypoint('Summit Dagoba', 'White stupa visible from the town below',
          Icons.architecture_rounded, Colors.blue),
    ],
    'Polonnaruwa': [
      _Waypoint('Museum Entrance', 'Start at the Polonnaruwa Museum',
          Icons.museum_rounded, Colors.green),
      _Waypoint('Royal Palace', 'Ruins of Parakramabahu\'s 5-storey palace',
          Icons.castle_rounded, Colors.brown),
      _Waypoint('Vatadage', 'Circular relic house with carved moonstone',
          Icons.circle_outlined, Colors.orange),
      _Waypoint('Rankot Vihara', '55-metre Golden Pinnacle stupa',
          Icons.architecture_rounded, Colors.amber),
      _Waypoint('Lankatilaka', '18-metre headless Buddha image house',
          Icons.account_balance_rounded, Colors.indigo),
      _Waypoint('Gal Vihara', 'Four colossal rock-cut Buddha figures',
          Icons.image_rounded, Colors.blue),
      _Waypoint('Parakrama Samudra', 'The vast 2,500-hectare ancient reservoir',
          Icons.water_rounded, Colors.cyan),
    ],
  };

  int _currentStep = 0;
  LandmarkModel? _landmark;

  @override
  void initState() {
    super.initState();
    _loadLandmark();
  }

  Future<void> _loadLandmark() async {
    // Attempt DB lookup by name; try both 'Dambulla' and 'Dambulla Cave Temple'
    final all = await DatabaseHelper.instance.getAllLandmarks();
    final name = widget.landmarkName;
    LandmarkModel? found;
    for (final lm in all) {
      if (lm.name == name ||
          (name == 'Dambulla' && lm.name == 'Dambulla Cave Temple') ||
          (name == 'Dambulla Cave Temple' && lm.name == 'Dambulla')) {
        found = lm;
        break;
      }
    }
    if (mounted) setState(() => _landmark = found);
  }

  // Normalize name so both 'Dambulla' and 'Dambulla Cave Temple' resolve correctly
  String get _normalizedName {
    if (widget.landmarkName == 'Dambulla') return 'Dambulla Cave Temple';
    return widget.landmarkName;
  }

  List<_Waypoint> get _waypoints =>
      _waypointData[_normalizedName] ?? _waypointData['Sigiriya']!;

  @override
  Widget build(BuildContext context) {
    final waypoints = _waypoints;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.landmarkName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Text(
              'AR Navigation Route',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Map view',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Map overlay coming in AR phase 2'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          _buildProgressBar(waypoints),

          // Current waypoint highlight
          _buildCurrentCard(waypoints),

          // Waypoint list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: waypoints.length,
              separatorBuilder: (_, i) => _buildConnector(i, waypoints),
              itemBuilder: (_, i) => _buildWaypointTile(i, waypoints[i]),
            ),
          ),

          // Footer
          _buildNavFooter(waypoints),
        ],
      ),
    );
  }

  Widget _buildProgressBar(List<_Waypoint> waypoints) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${_currentStep + 1} / ${waypoints.length} stops',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${((_currentStep + 1) / waypoints.length * 100).toInt()}%',
                  style: const TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / waypoints.length,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
              ),
            ),
          ],
        ),
      );

  Widget _buildCurrentCard(List<_Waypoint> waypoints) {
    final wp = waypoints[_currentStep];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(wp.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Stop',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  wp.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  wp.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // AR launch button
          IconButton(
            icon: const Icon(Icons.view_in_ar_rounded,
                color: Colors.white, size: 28),
            tooltip: 'View in AR',
            onPressed: () {
              final lm = _landmark;
              if (lm != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ArScreen(landmark: lm)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Landmark data not loaded yet'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointTile(int index, _Waypoint wp) {
    final isActive = index == _currentStep;
    final isDone = index < _currentStep;

    return GestureDetector(
      onTap: () => setState(() => _currentStep = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // Step number / check
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.green
                    : isActive
                        ? AppTheme.primary
                        : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : isActive
                        ? Icon(wp.icon, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey),
                          ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wp.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color:
                          isActive ? AppTheme.primary : const Color(0xFF2D1B0E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wp.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.my_location_rounded,
                  color: AppTheme.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector(int index, List<_Waypoint> waypoints) => Padding(
        padding: const EdgeInsets.only(left: 34),
        child: Container(
          height: 12,
          width: 2,
          color: index < _currentStep
              ? Colors.green.shade300
              : Colors.grey.shade200,
        ),
      );

  Widget _buildNavFooter(List<_Waypoint> waypoints) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Previous
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _currentStep > 0
                    ? () => setState(() => _currentStep--)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                label: const Text('Prev'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Next
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _currentStep < waypoints.length - 1
                    ? () => setState(() => _currentStep++)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                label: Text(_currentStep < waypoints.length - 1
                    ? 'Next Stop'
                    : 'Tour Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Data class ─────────────────────────────────────────────────────────────────
class _Waypoint {
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _Waypoint(this.name, this.description, this.icon, this.color);
}
