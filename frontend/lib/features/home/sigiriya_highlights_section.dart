import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../sigiriya_guide/data/sigiriya_knowledge_base.dart';
import '../sigiriya_guide/models/location_model.dart';
import '../sigiriya_guide/screens/gallery_screen.dart';
import '../sigiriya_guide/screens/location_detail_screen.dart';

class SigiriyaHighlightsSection extends StatelessWidget {
  const SigiriyaHighlightsSection({super.key});

  static const _gradients = [
    [Color(0xFFB71C1C), Color(0xFFE53935)],
    [Color(0xFFE65100), Color(0xFFFF8F00)],
    [Color(0xFF1A237E), Color(0xFF3949AB)],
    [Color(0xFF1B5E20), Color(0xFF43A047)],
    [Color(0xFF6D4C41), Color(0xFF8D6E63)],
    [Color(0xFF4A148C), Color(0xFF7E57C2)],
  ];

  @override
  Widget build(BuildContext context) {
    final locations = kSigiriyaLocations.take(6).toList();

    if (locations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppTheme.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Sigiriya Heritage Guide',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A00),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Theme(
                    data: AppTheme.dark,
                    child: const GalleryScreen(),
                  ),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Gallery'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return _SigiriyaCard(
                location: locations[index],
                gradient: _gradients[index % _gradients.length],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SigiriyaCard extends StatelessWidget {
  final SigiriyaLocation location;
  final List<Color> gradient;

  const _SigiriyaCard({required this.location, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Theme(
            data: AppTheme.dark,
            child: LocationDetailScreen(location: location),
          ),
        ),
      ),
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    location.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                location.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Georgia',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                location.briefSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              const Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: Colors.white70, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Sri Lanka',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
