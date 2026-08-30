import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/location/site_geofence.dart';
import '../../core/location/site_lock_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ar_availability.dart';
import '../../features/ar/ar_screen.dart';
import '../../features/database/database_helper.dart';
import '../../features/database/landmark_model.dart';
import '../../features/database/sub_landmark_model.dart';
import '../../widgets/landmark_info_card.dart';
import '../../widgets/site_selector_sheet.dart';
import '../camera/ar_translator_screen.dart'; // newly added translate screen
import '../camera/camera_screen.dart';
import '../chat/rag_chat_screen.dart';
import '../map/heritage_map_screen.dart';
import '../navigation/nav_screen.dart';
import '../sigiriya_guide/screens/home_screen.dart' as sigiriya_home;

/// The main landing screen of HeritageAR.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LandmarkModel> _landmarks = [];
  bool _loading = true;
  SiteLockResult? _siteLock;
  bool _siteLockLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLandmarks();
    // Only auto-check GPS if permission was already granted — never popup on launch.
    _checkSiteLockIfAlreadyPermitted();
  }

  Future<void> _checkSiteLockIfAlreadyPermitted() async {
    final permission = await Geolocator.checkPermission();
    final alreadyGranted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (alreadyGranted) {
      await _resolveGpsSiteLock(requestPermission: false, showFeedback: false);
    } else if (mounted) {
      setState(() => _siteLockLoading = false);
    }
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

  Future<void> _resolveGpsSiteLock({
    bool requestPermission = true,
    bool showFeedback = true,
  }) async {
    if (mounted) {
      setState(() => _siteLockLoading = true);
    }

    final result = await SiteLockService.instance.lockSiteByGps(
      requestPermission: requestPermission,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _siteLock = result;
      _siteLockLoading = false;
    });

    if (showFeedback) {
      _showSiteLockFeedback(result);
    }
  }

  void _showSiteLockFeedback(SiteLockResult result) {
    if (!mounted) return;

    final String text;
    final Color bg;
    final IconData icon;

    switch (result.status) {
      case SiteLockStatus.locked:
        text = 'Location verified — ${result.site?.landmarkName ?? 'Heritage site'}';
        bg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
      case SiteLockStatus.outOfRange:
        text = result.message ??
            'You are not near a supported heritage site. Use Choose Site for manual mode.';
        bg = const Color(0xFFE65100);
        icon = Icons.location_off_rounded;
      case SiteLockStatus.serviceDisabled:
        text = 'Turn on GPS/Location in your phone settings, then tap Verify Location again.';
        bg = const Color(0xFF1565C0);
        icon = Icons.gps_off_rounded;
      case SiteLockStatus.permissionDenied:
        text = result.message ??
            'Location permission denied. Allow location access for this app in Settings.';
        bg = const Color(0xFFC62828);
        icon = Icons.block_rounded;
      case SiteLockStatus.timeout:
        text = result.message ??
            'GPS signal weak. Move to an open area and try again.';
        bg = const Color(0xFFEF6C00);
        icon = Icons.signal_wifi_off_rounded;
      case SiteLockStatus.error:
        text = result.message ?? 'Could not verify location. Please try again.';
        bg = const Color(0xFFC62828);
        icon = Icons.error_outline_rounded;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          backgroundColor: bg,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: result.openSettings
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () async {
                    if (result.status == SiteLockStatus.serviceDisabled) {
                      await Geolocator.openLocationSettings();
                    } else {
                      await Geolocator.openAppSettings();
                    }
                  },
                )
              : null,
        ),
      );
  }

  Future<void> _launchCamera() async {
    if (!mounted) return;
    final lock = _siteLock;
    // A site already confirmed here (GPS or manual) is handed straight to
    // the camera screen so it doesn't re-run the GPS check on open.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          initialSiteLock: (lock != null && lock.isLocked) ? lock : null,
        ),
      ),
    );
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
      builder: (_) => SiteSelectorSheet(
        sites: sites,
        subtitle: 'Use manual selection when GPS is unavailable — this '
            'carries straight into the camera without rechecking GPS.',
        onSiteSelected: (site) {
          Navigator.pop(context);
          if (!mounted) return;
          setState(() {
            _siteLock = SiteLockResult.manual(site: site);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      drawer: _buildDrawer(), // Adding the drawer menu
      bottomNavigationBar: _buildBottomNav(),
      body: _buildExploreBody(),
      floatingActionButton: _buildScanFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ── Sidebar Drawer ────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3E1D0A), Color(0xFF8D4E1A)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('HeritageAR', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
                const Text('Offline Explorer Mode', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.g_translate_rounded, color: AppTheme.primary),
            title: const Text('Live AR Sign Translator', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textBase)),
            subtitle: const Text('Offline OCR & Translation', style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArTranslatorScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Bottom NAV ─────────────────────────────────────────────────────────────
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
    final active = index == 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const sigiriya_home.HomeScreen()),
          );
        } else {
          // Map opens as its own full-screen route — no bottom nav / Home chrome.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HeritageMapScreen()),
          );
        }
      },
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
      onPressed: _launchCamera,
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
      leading: Builder(
        builder: (context) => IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          splashRadius: 22,
          icon: const Icon(Icons.menu, color: Colors.white, size: 24),
          onPressed: () => Scaffold.of(context).openDrawer(), // Open the drawer
        ),
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
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
          child: _buildLocationCard(),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 18)),

      const SliverToBoxAdapter(child: SizedBox(height: 8)),

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

  Widget _buildLocationCard() {
    // ── Loading state ────────────────────────────────────────────────────────
    if (_siteLockLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.secondary)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Searching for your heritage site...',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textBase, height: 1.4),
            ),
          ),
        ]),
      );
    }

    final lock = _siteLock;
    final locked = lock?.isLocked ?? false;
    final outside = lock?.status == SiteLockStatus.outOfRange;

    // ── Locked state ─────────────────────────────────────────────────────────
    if (locked) {
      final siteName = lock!.site?.landmarkName ?? 'Heritage Site';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📍 Current Location',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text(
                  '$siteName  ●  You\'re at this site',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textBase,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: _siteLockLoading ? null : () => _resolveGpsSiteLock(requestPermission: true),
            child: const Text('Refresh'),
          ),
        ]),
      );
    }

    // ── Failed or Outside state ───────────────────────────────────────────────
    final statusDetail = lock?.message;
    final message = outside
        ? (statusDetail ??
            'You\'re not near a heritage site — Choose a site manually or verify again if you moved closer.')
        : (statusDetail ??
            'Location not verified — Enable GPS or choose a heritage site to begin exploration.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.location_off_rounded,
                color: AppTheme.secondary, size: 20),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('📍 Current Location',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4))),
          ]),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
                fontSize: 12.5, color: AppTheme.textBase, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _siteLockLoading ? null : () => _resolveGpsSiteLock(requestPermission: true),
                child: Text(outside ? 'Verify Again' : 'Verify Location'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _manualLockSitePicker,
                child: const Text('Choose Site'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

}

// â”€â”€ Featured horizontal card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FeaturedCard extends StatelessWidget {
  final LandmarkModel landmark;
  const _FeaturedCard({required this.landmark});

  static const _gradients = [
    [Color(0xFF8B5E3C), Color(0xFFBF8650)], // warm terracotta
    [Color(0xFF6D4C41), Color(0xFF8D6E63)], // espresso brown
    [Color(0xFFAF8C5B), Color(0xFFD4A017)], // antique gold
    [Color(0xFF5D4037), Color(0xFF795548)], // dark earth
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

/// One entry per camera-model class describing how it maps onto the
/// Points-of-Interest data — see [LandmarkDetailScreenState._detectionInfo].
class _DetectionInfo {
  final String? poiKeyword;
  final String? brief;
  const _DetectionInfo({required this.poiKeyword, required this.brief});
}

// â”€â”€ Landmark detail screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class LandmarkDetailScreen extends StatefulWidget {
  final LandmarkModel landmark;

  /// Raw camera-model class label (e.g. 'sigiriya_ticket_counter') when this
  /// screen was opened right after a live detection — used to auto-highlight
  /// the matching Point of Interest and offer a Brief/Detail summary of it.
  final String? highlightSubLandmarkLabel;

  const LandmarkDetailScreen({
    super.key,
    required this.landmark,
    this.highlightSubLandmarkLabel,
  });

  @override
  State<LandmarkDetailScreen> createState() => LandmarkDetailScreenState();
}

class LandmarkDetailScreenState extends State<LandmarkDetailScreen> {
  List<SubLandmarkModel> _subLandmarks = [];
  bool _subLoading = true;
  ArStatus? _arStatus;
  bool _showDetailView = false; // Brief (false) vs Detail (true)

  /// Explicit entry for every one of the 5 camera-model classes — deliberately
  /// complete, not a fallback/best-effort map, so each detected class gets an
  /// accurate Brief description regardless of how loosely its name matches
  /// the underlying Points-of-Interest record.
  ///
  /// [poiKeyword] locates the matching row in `SubLandmarkModel.name`
  /// (substring match — DB names don't equal the model's class names, e.g.
  /// "Lion Gate (Lion Paws)" vs 'sigiriya_lion_paws'). Null means there is no
  /// dedicated POI row for this class ('sigiriya_lion_rock' names the whole
  /// rock fortress — the parent landmark itself, not a specific stop).
  ///
  /// [brief] is written specifically for what the model detected, not a
  /// truncation of the matched POI's description — that matters most for
  /// 'sigiriya_throne', whose only matching POI ("Summit Palace") describes
  /// the whole palace ruin, not just the throne platform within it.
  static const Map<String, _DetectionInfo> _detectionInfo = {
    'sigiriya_lion_paws': _DetectionInfo(
      poiKeyword: 'lion paws',
      brief:
          "The colossal brick-and-plaster lion paws flanking Sigiriya's summit "
          'stairway — the only surviving remnant of the original lion gateway '
          'that gave the rock its name.',
    ),
    'sigiriya_lion_rock': _DetectionInfo(
      poiKeyword: null, // whole site — no dedicated POI row
      brief: null, // uses landmark.description instead, see _briefFor()
    ),
    'sigiriya_mirror_wall': _DetectionInfo(
      poiKeyword: 'mirror wall',
      brief:
          "A plaster wall on the rock's western face, once polished to a "
          'mirror finish — now etched with 685+ ancient Sinhala poems, the '
          'oldest such collection in the world.',
    ),
    'sigiriya_throne': _DetectionInfo(
      poiKeyword: 'summit palace',
      brief:
          "The throne platform within King Kassapa's summit palace ruins, "
          '200 metres above the plains — part of the royal residence that '
          'once crowned the rock.',
    ),
    'sigiriya_ticket_counter': _DetectionInfo(
      poiKeyword: 'ticket',
      brief:
          'The official Sigiriya entry point — ticketing, rest facilities, '
          'and an information centre with maps and audio guides for your visit.',
    ),
  };

  String? get _normalizedLabel =>
      widget.highlightSubLandmarkLabel?.trim().toLowerCase();

  _DetectionInfo? get _detectionForLabel =>
      _normalizedLabel == null ? null : _detectionInfo[_normalizedLabel];

  SubLandmarkModel? get _highlightedSub {
    final keyword = _detectionForLabel?.poiKeyword;
    if (keyword == null) return null;
    for (final s in _subLandmarks) {
      if (s.name.toLowerCase().contains(keyword)) return s;
    }
    return null;
  }

  /// Points of Interest with the detected one (if any) moved to the front,
  /// so it's immediately visible without scrolling past the others.
  List<SubLandmarkModel> get _orderedSubLandmarks {
    final highlighted = _highlightedSub;
    if (highlighted == null) return _subLandmarks;
    return [
      highlighted,
      ..._subLandmarks.where((s) => s.id != highlighted.id),
    ];
  }

  String _briefOf(String text) {
    final cut = text.indexOf('. ');
    if (cut != -1 && cut <= 160) return text.substring(0, cut + 1);
    if (text.length <= 160) return text;
    return '${text.substring(0, 157).trimRight()}...';
  }

  /// Brief text for the current detection — the curated [_DetectionInfo.brief]
  /// when one exists, the whole-site description for the Lion Rock case,
  /// falling back to a truncated POI description only for a label that isn't
  /// in [_detectionInfo] at all (defensive — shouldn't happen for the 5
  /// known classes, but keeps a future/unrecognised label from rendering
  /// blank instead of degrading gracefully).
  String get _briefText {
    final info = _detectionForLabel;
    if (info?.brief != null) return info!.brief!;
    if (_normalizedLabel == 'sigiriya_lion_rock') {
      return widget.landmark.description;
    }
    final sub = _highlightedSub;
    return sub != null ? _briefOf(sub.description) : widget.landmark.description;
  }

  String get _detailText {
    final sub = _highlightedSub;
    if (sub != null) return sub.description;
    return widget.landmark.history.isNotEmpty
        ? widget.landmark.history
        : widget.landmark.description;
  }

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
                      'Sri Lanka',
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
                  // ── Just-detected banner (opened straight from the camera) ──
                  if (widget.highlightSubLandmarkLabel != null && !_subLoading) ...[
                    _DetectedPoiBanner(
                      title: _highlightedSub?.name ?? widget.landmark.name,
                      briefText: _briefText,
                      detailText: _detailText,
                      showDetail: _showDetailView,
                      onToggle: (v) => setState(() => _showDetailView = v),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                      children: _orderedSubLandmarks
                          .map((sub) => _SubLandmarkTile(
                                sub: sub,
                                accentColor: Color(colors[0].value),
                                icon: _typeIcon(sub.type),
                                highlighted: sub.id == _highlightedSub?.id,
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
                                  landmarkName: widget.landmark.name,
                                  landmarkId: 'sigiriya',
                                ),
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
  final bool highlighted;
  const _SubLandmarkTile({
    required this.sub,
    required this.accentColor,
    required this.icon,
    this.highlighted = false,
  });

  @override
  State<_SubLandmarkTile> createState() => _SubLandmarkTileState();
}

class _SubLandmarkTileState extends State<_SubLandmarkTile> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-expand the tile matching what the camera just detected.
    _expanded = widget.highlighted;
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: widget.highlighted
              ? Border.all(color: AppTheme.secondary, width: 1.6)
              : null,
          boxShadow: [
            BoxShadow(
              color: widget.highlighted
                  ? AppTheme.secondary.withOpacity(0.25)
                  : Colors.black.withOpacity(0.05),
              blurRadius: widget.highlighted ? 14 : 8,
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
            initiallyExpanded: widget.highlighted,
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
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.sub.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF2D1B0E)),
                  ),
                ),
                if (widget.highlighted)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.center_focus_strong_rounded,
                            color: Colors.white, size: 10),
                        SizedBox(width: 3),
                        Text('DETECTED',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4)),
                      ],
                    ),
                  ),
              ],
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

// ── "Just scanned" banner — shown when this screen was opened straight from
// a camera detection, with a Brief/Detail toggle for what was found ────────
class _DetectedPoiBanner extends StatelessWidget {
  final String title;
  final String briefText;
  final String detailText;
  final bool showDetail;
  final ValueChanged<bool> onToggle;

  const _DetectedPoiBanner({
    required this.title,
    required this.briefText,
    required this.detailText,
    required this.showDetail,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppTheme.secondary.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.center_focus_strong_rounded,
                    color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('JUST SCANNED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A00))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ModeChip(
                  label: 'Brief',
                  icon: Icons.short_text_rounded,
                  selected: !showDetail,
                  onTap: () => onToggle(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeChip(
                  label: 'Detail',
                  icon: Icons.notes_rounded,
                  selected: showDetail,
                  onTap: () => onToggle(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              showDetail ? detailText : briefText,
              key: ValueKey(showDetail),
              style: const TextStyle(
                  color: Color(0xFF4E342E), fontSize: 13.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.secondary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? AppTheme.secondary
                  : AppTheme.secondary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15, color: selected ? Colors.white : AppTheme.secondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.primary)),
          ],
        ),
      ),
    );
  }
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

