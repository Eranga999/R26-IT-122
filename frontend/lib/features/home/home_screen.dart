import 'package:flutter/material.dart';
import '../../core/location/site_geofence.dart';
import '../../core/location/site_lock_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ar_availability.dart';
import '../../features/ar/ar_screen.dart';
import '../../features/database/database_helper.dart';
import '../../features/database/landmark_model.dart';
import '../../features/database/sub_landmark_model.dart';
import '../../widgets/landmark_info_card.dart';
import '../camera/camera_screen.dart';
import '../rag/rag_screen.dart';
import '../chat/rag_chat_screen.dart';
import '../navigation/nav_screen.dart';

/// The main landing screen of HeritageAR.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LandmarkModel> _landmarks = [];
  bool _loading = true;
  int _navIndex = 0;
  SiteLockResult? _siteLock;
  bool _siteLockLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLandmarks();
    _resolveGpsSiteLock();
  }

  Future<void> _loadLandmarks() async {
    final data = await DatabaseHelper.instance.getAllLandmarks();
    if (mounted) {
      setState(() {
        _landmarks = data;
        _loading = false;
      });
    }
  }

  Future<void> _resolveGpsSiteLock() async {
    if (mounted) {
      setState(() => _siteLockLoading = true);
    }

    final result = await SiteLockService.instance.lockSiteByGps();
    if (!mounted) {
      return;
    }

    setState(() {
      _siteLock = result;
      _siteLockLoading = false;
    });
  }

  Future<void> _manualLockSitePicker() async {
    if (_landmarks.isEmpty) {
      return;
    }

    final sites = await SiteLockService.instance.loadSites();
    if (!mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A0A00),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Current Site',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use manual lock when GPS is unavailable.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ...sites.map((site) => ListTile(
                    leading: const Icon(Icons.place_rounded,
                        color: Color(0xFFFFB300)),
                    title: Text(site.landmarkName,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(site.landmarkId,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _siteLock = SiteLockResult.manual(site: site);
                      });
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          _navIndex == 0 ? _buildExploreBody() : _buildMapPlaceholder(),

        ],
      ),
      floatingActionButton: _buildScanFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // â”€â”€ Bottom NAV â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.explore_rounded, 'Explore'),
            const SizedBox(width: 72), // FAB gap
            _navItem(1, Icons.map_rounded, 'Map'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _navIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _navIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: active ? AppTheme.primary : Colors.grey, size: 22),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                color: active ? AppTheme.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanFab() {
    return FloatingActionButton(
      backgroundColor: AppTheme.secondary,
      elevation: 6,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CameraScreen(
            lockedLandmarkId: _siteLock?.site?.landmarkDbId,
            lockedLandmarkName: _siteLock?.site?.landmarkName,
          ),
        ),
      ),
      child:
          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
    );
  }

  // â”€â”€ Main explore body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildExploreBody() {
    return CustomScrollView(
      slivers: [
        _buildHeroHeader(),
        if (_loading)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else
          ..._buildContent(),
      ],
    );
  }

  // â”€â”€ Hero gradient header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  SliverAppBar _buildHeroHeader() {
    return SliverAppBar(
      expandedHeight: 290,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.primary,
      leadingWidth: 56,
      leading: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        splashRadius: 22,
        icon: const Icon(Icons.menu, color: Colors.white, size: 24),
        onPressed: () {},
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3E1D0A),
                Color(0xFF8D4E1A),
                Color(0xFFD4891A),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(72, 12, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'HeritageAR',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Discover Sri Lanka\'s',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ancient Heritage',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.05,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppTheme.secondary.withOpacity(0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'UNESCO World Heritage Sites',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
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

  // â”€â”€ Content slivers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Widget> _buildContent() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _buildSiteLockBanner(),
        ),
      ),

      // section label
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
              SizedBox(width: 6),
              Text(
                'Featured Sites',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A00),
                ),
              ),
            ],
          ),
        ),
      ),

      // horizontal featured cards
      SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _landmarks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _FeaturedCard(landmark: _landmarks[i]),
          ),
        ),
      ),

      // all landmarks section
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: Color(0xFF6D4C41), size: 20),
              SizedBox(width: 6),
              Text(
                'All Landmarks',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A00),
                ),
              ),
            ],
          ),
        ),
      ),

      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: LandmarkInfoCard(landmark: _landmarks[i]),
          ),
          childCount: _landmarks.length,
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];
  }

  Widget _buildSiteLockBanner() {
    if (_siteLockLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Detecting your current heritage site by GPS...',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final lock = _siteLock;
    final locked = lock?.isLocked ?? false;
    final siteName = lock?.site?.landmarkName ?? 'Site not locked';
    final subtitle = locked
        ? 'Locked by ${lock!.source.toUpperCase()}  |  ${lock.distanceMeters?.toStringAsFixed(0) ?? '-'} m from center'
        : (lock?.message ?? 'Unable to lock site from GPS.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: locked ? const Color(0xFF81C784) : const Color(0xFFFFB74D),
        ),
      ),
      child: Row(
        children: [
          Icon(
            locked ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            color: locked ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  siteName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: locked ? _resolveGpsSiteLock : _manualLockSitePicker,
            child: Text(locked ? 'Refresh' : 'Manual'),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Map placeholder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMapPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 80, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'Interactive Map',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia'),
            ),
            SizedBox(height: 8),
            Text(
              'Coming soon â€“ offline maps\nfor heritage sites',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Featured horizontal card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FeaturedCard extends StatelessWidget {
  final LandmarkModel landmark;
  const _FeaturedCard({required this.landmark});

  static const _gradients = [
    [Color(0xFFB71C1C), Color(0xFFE53935)],
    [Color(0xFFE65100), Color(0xFFFF8F00)],
    [Color(0xFF1A237E), Color(0xFF3949AB)],
    [Color(0xFF1B5E20), Color(0xFF43A047)],
  ];

  static const _icons = [
    Icons.castle_rounded,
    Icons.temple_hindu_rounded,
    Icons.account_balance_rounded,
    Icons.landscape_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final idx = (landmark.id ?? 1) - 1;
    final colors = _gradients[idx % _gradients.length];
    final icon = _icons[idx % _icons.length];

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Text(
                landmark.name,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white70, size: 12),
                  SizedBox(width: 3),
                  Text('Sri Lanka',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LandmarkDetailScreen(landmark: landmark)),
    );
  }
}

// â”€â”€ Landmark detail screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class LandmarkDetailScreen extends StatefulWidget {
  final LandmarkModel landmark;
  const LandmarkDetailScreen({super.key, required this.landmark});

  @override
  State<LandmarkDetailScreen> createState() => LandmarkDetailScreenState();
}

class LandmarkDetailScreenState extends State<LandmarkDetailScreen> {
  List<SubLandmarkModel> _subLandmarks = [];
  bool _subLoading = true;
  ArStatus? _arStatus;

  static const _gradients = [
    [Color(0xFFB71C1C), Color(0xFFE53935)],
    [Color(0xFFE65100), Color(0xFFFF8F00)],
    [Color(0xFF1A237E), Color(0xFF3949AB)],
  ];

  static const _icons = [
    Icons.castle_rounded,
    Icons.temple_hindu_rounded,
    Icons.account_balance_rounded,
  ];

  static const _facts = [
    ['Founded', '477 AD'],
    ['Type', 'Rock Fortress'],
    ['UNESCO', '1982'],
    ['Country', 'Sri Lanka'],
  ];
  static const _facts2 = [
    ['Founded', '1st c. BC'],
    ['Type', 'Cave Temple'],
    ['UNESCO', '1991'],
    ['Country', 'Sri Lanka'],
  ];
  static const _facts3 = [
    ['Founded', '1070 AD'],
    ['Type', 'Ancient City'],
    ['UNESCO', '1982'],
    ['Country', 'Sri Lanka'],
  ];

  List<List<String>> get _siteFacts {
    final id = widget.landmark.id ?? 1;
    if (id == 1) return _facts;
    if (id == 2) return _facts2;
    return _facts3;
  }

  @override
  void initState() {
    super.initState();
    _loadSubLandmarks();
    _checkAr();
  }

  Future<void> _checkAr() async {
    final status = await ArAvailability.check();
    if (mounted) setState(() => _arStatus = status);
  }

  Future<void> _loadSubLandmarks() async {
    final id = widget.landmark.id;
    if (id == null) {
      setState(() => _subLoading = false);
      return;
    }
    final subs = await DatabaseHelper.instance.getSubLandmarks(id);
    if (mounted) {
      setState(() {
        _subLandmarks = subs;
        _subLoading = false;
      });
    }
  }

  IconData _typeIcon(String type) {
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

  @override
  Widget build(BuildContext context) {
    final idx = ((widget.landmark.id ?? 1) - 1) % _gradients.length;
    final colors = _gradients[idx];
    final icon = _icons[idx];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Color(colors[0].value),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(icon, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.landmark.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ðŸ‡±ðŸ‡°  Sri Lanka',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // â”€â”€ Quick facts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _siteFacts
                          .map((f) => _FactCell(label: f[0], value: f[1]))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // â”€â”€ About â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const Text('About',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A0A00),
                      )),
                  const SizedBox(height: 10),
                  Text(
                    widget.landmark.description,
                    style: const TextStyle(
                      color: Color(0xFF4E342E),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),

                  // â”€â”€ History â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (widget.landmark.history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('History',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A0A00),
                        )),
                    const SizedBox(height: 10),
                    Text(
                      widget.landmark.history,
                      style: const TextStyle(
                        color: Color(0xFF4E342E),
                        fontSize: 15,
                        height: 1.7,
                      ),
                    ),
                  ],

                  // â”€â”€ Points of Interest â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Text('Points of Interest',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A0A00),
                          )),
                      const Spacer(),
                      if (!_subLoading && _subLandmarks.isNotEmpty)
                        Text('${_subLandmarks.length} stops',
                            style: TextStyle(
                                color: Color(colors[0].value),
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_subLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_subLandmarks.isEmpty)
                    const Text('No sub-landmarks found.',
                        style: TextStyle(color: Colors.grey, fontSize: 14))
                  else
                    Column(
                      children: _subLandmarks
                          .map((sub) => _SubLandmarkTile(
                                sub: sub,
                                accentColor: Color(colors[0].value),
                                icon: _typeIcon(sub.type),
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 32),

                  // â”€â”€ Action buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArScreen(landmark: widget.landmark),
                        ),
                      ),
                      icon: const Icon(Icons.view_in_ar_rounded),
                      label: Text(
                        _arStatus?.supported == true
                            ? 'Launch AR Experience'
                            : 'View AR Details',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _arStatus?.supported == true
                            ? const Color(0xFF00695C)
                            : Color(colors[0].value),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Ask AI
                      // Ask AI Guide (Only for Sigiriya)
                      if (widget.landmark.id == 1) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RagChatScreen(
                                    landmarkName: widget.landmark.name),
                              ),
                            ),
                            icon: const Icon(Icons.smart_toy_rounded, size: 18),
                            label: const Text('Ask AI Guide'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB300),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      // Navigate
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NavScreen(landmarkName: widget.landmark.name),
                            ),
                          ),
                          icon: const Icon(Icons.explore_rounded, size: 18),
                          label: const Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF37474F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Sub-landmark expandable tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _SubLandmarkTile extends StatefulWidget {
  final SubLandmarkModel sub;
  final Color accentColor;
  final IconData icon;
  const _SubLandmarkTile(
      {required this.sub, required this.accentColor, required this.icon});

  @override
  State<_SubLandmarkTile> createState() => _SubLandmarkTileState();
}

class _SubLandmarkTileState extends State<_SubLandmarkTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
          ),
          child: ExpansionTile(
            onExpansionChanged: (v) => setState(() => _expanded = v),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.accentColor, size: 22),
            ),
            title: Text(
              widget.sub.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF2D1B0E)),
            ),
            subtitle: Text(
              widget.sub.type.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: widget.accentColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8),
            ),
            trailing: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.grey,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  widget.sub.description,
                  style: const TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FactCell extends StatelessWidget {
  final String label, value;
  const _FactCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF1A0A00))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
