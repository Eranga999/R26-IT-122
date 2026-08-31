import 'package:flutter/material.dart';

import '../explore_theme.dart';
import '../services/rag_service.dart';
import 'explore_screen.dart';
import 'gamified_explore_screen.dart';

class ExploreHubScreen extends StatelessWidget {
  final RagService? rag;

  const ExploreHubScreen({super.key, this.rag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExploreTheme.bg,
      appBar: AppBar(
        backgroundColor: ExploreTheme.bar,
        foregroundColor: Colors.white,
        title: const Text('Explore Experiences'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _HeroBanner(),
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
                      accent: ExploreTheme.accent,
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
                      accent: ExploreTheme.info,
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
                    color: ExploreTheme.textSoft,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: ExploreTheme.accent.withOpacity(0.10),
        border: Border.all(color: ExploreTheme.accent.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your experience',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ExploreTheme.accentText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore Sigiriya in the classic way, or switch to a gamified heritage journey with challenges and rewards.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ExploreTheme.body,
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
      color: ExploreTheme.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ExploreTheme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.30)),
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
                      color: ExploreTheme.text,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ExploreTheme.body,
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
                        side: BorderSide(color: accent.withOpacity(0.35)),
                        backgroundColor: accent.withOpacity(0.10),
                        labelStyle: TextStyle(
                          color: ExploreTheme.text.withOpacity(0.75),
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
