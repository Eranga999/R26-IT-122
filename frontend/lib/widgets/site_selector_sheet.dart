import 'package:flutter/material.dart';

import '../core/location/site_geofence.dart';
import '../core/theme/app_theme.dart';
import '../features/recognition/recognition_service.dart';

/// Bottom-sheet content for picking a heritage site manually.
///
/// Shared between the home screen (pick a site before opening the camera —
/// this skips the GPS check entirely once inside the camera screen) and the
/// camera screen's own GPS-fallback picker, so both look and behave the same.
class SiteSelectorSheet extends StatelessWidget {
  const SiteSelectorSheet({
    super.key,
    required this.sites,
    required this.onSiteSelected,
    this.subtitle = "Select the heritage site you're currently visiting.",
  });

  final List<SiteGeofence> sites;
  final String subtitle;
  final ValueChanged<SiteGeofence> onSiteSelected;

  // Same palette/icon-by-id pattern as the home screen's Featured Sites
  // cards, so a site looks the same wherever it appears in the app.
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A0A00),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4A017), Color(0xFFFF8F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.secondary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.place_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Your Heritage Site',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final site in sites)
            _SiteTile(
              site: site,
              gradient: _gradients[
                  (site.landmarkDbId - 1).abs() % _gradients.length],
              icon: _icons[(site.landmarkDbId - 1).abs() % _icons.length],
              onTap: () => onSiteSelected(site),
            ),
        ],
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final SiteGeofence site;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLiveDetection =
        RecognitionService.labelsForSite(site.landmarkName).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: AppTheme.secondary.withOpacity(0.15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color: gradient[0].withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.landmarkName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasLiveDetection
                              ? AppTheme.secondary.withOpacity(0.15)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasLiveDetection
                                ? AppTheme.secondary.withOpacity(0.4)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasLiveDetection
                                  ? Icons.auto_awesome_rounded
                                  : Icons.menu_book_rounded,
                              size: 11,
                              color: hasLiveDetection
                                  ? AppTheme.secondary
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasLiveDetection
                                  ? 'Live AI Detection'
                                  : 'Guide Only',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: hasLiveDetection
                                    ? AppTheme.secondary
                                    : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
