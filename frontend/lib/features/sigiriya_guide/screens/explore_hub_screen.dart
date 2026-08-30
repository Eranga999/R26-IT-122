import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../services/rag_service.dart';
import 'explore_screen.dart';
import 'gamified_explore_screen.dart';

class ExploreHubScreen extends StatelessWidget {
  final RagService? rag;

  const ExploreHubScreen({super.key, this.rag});

  @override
  Widget build(BuildContext context) {
    // Same Explore-flow colour rule as the selection screen: heritage-gold
    // accent on the app-wide light parchment/terracotta theme.
    const gold = AppTheme.secondary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Explore Experiences'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surface.withOpacity(0.92),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroBanner(
                gold: gold,
                onSurface: onSurface,
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isWide ? 2 : 1,
                    childAspectRatio: isWide ? 1.95 : 1.55,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      _HubCard(
                        icon: Icons.explore_rounded,
                        title: 'Explore Sigiriya',
                        description:
                            'Browse the heritage locations, read details, and open each site interface.',
                        accent: gold,
                        chips: const [
                          'Location list',
                          'Site details',
                          'Guided reading'
                        ],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExploreScreen(rag: rag),
                            ),
                          );
                        },
                      ),
                      _HubCard(
                        icon: Icons.emoji_events_rounded,
                        title: 'Gamified Exploration Layer',
                        description:
                            'Treasure hunts, quizzes, and achievement badges for active heritage learning.',
                        accent: const Color(0xFF7BD389),
                        chips: const ['Treasure hunt', 'Quiz mode', 'Badges'],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GamifiedExploreScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Pick the path you want to take. The first option keeps the current Sigiriya browsing flow, while the second adds the learning game layer.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textBase.withOpacity(0.65),
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final Color gold;
  final Color onSurface;

  const _HeroBanner({required this.gold, required this.onSurface});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            gold.withOpacity(0.18),
            Theme.of(context).colorScheme.surface.withOpacity(0.96),
          ],
        ),
        border: Border.all(color: gold.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your experience',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore Sigiriya in the classic way, or switch to a gamified heritage journey with challenges and rewards.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: onSurface.withOpacity(0.75),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final List<String> chips;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.28)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.14),
                Theme.of(context).colorScheme.surface.withOpacity(0.92),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.16),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textBase,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textBase.withOpacity(0.7),
                      height: 1.45,
                    ),
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips
                    .map(
                      (chip) => Chip(
                        label: Text(chip),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: accent.withOpacity(0.3)),
                        backgroundColor: accent.withOpacity(0.08),
                        labelStyle: TextStyle(
                          color: accent.withOpacity(0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
