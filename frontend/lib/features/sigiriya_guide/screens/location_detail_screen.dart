// lib/screens/location_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/location_model.dart';

class LocationDetailScreen extends StatefulWidget {
  final SigiriyaLocation location;
  const LocationDetailScreen({super.key, required this.location});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final loc = widget.location;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                loc.name,
                style: TextStyle(
                  color: gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero image or gradient placeholder
                  _HeroImage(location: loc),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 16,
                    child: Text(
                      loc.emoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: gold,
              labelColor: gold,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Details'),
                Tab(text: 'Gallery'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _SummaryTab(location: loc),
            _DetailsTab(location: loc),
            _GalleryTab(location: loc),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Tab ─────────────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final SigiriyaLocation location;
  const _SummaryTab({required this.location});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Quick Summary', Icons.summarize_outlined),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: gold.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold.withOpacity(0.25)),
            ),
            child: Text(
              location.briefSummary,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Tags', Icons.label_outline),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: location.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withOpacity(0.3)),
                ),
                child: Text(
                  '# $tag',
                  style: TextStyle(
                    color: gold.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Details Tab ─────────────────────────────────────────────────────────────
class _DetailsTab extends StatelessWidget {
  final SigiriyaLocation location;
  const _DetailsTab({required this.location});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _MarkdownRenderer(text: location.detailedInfo),
    );
  }
}

// ─── Gallery Tab ─────────────────────────────────────────────────────────────
class _GalleryTab extends StatelessWidget {
  final SigiriyaLocation location;
  const _GalleryTab({required this.location});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    if (location.imageAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(location.emoji, style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              'No images yet.\n\nAdd images to:\nassets/images/locations/',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, height: 1.6),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: location.imageAssets.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showFullImage(context, location.imageAssets[index]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              location.imageAssets[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: gold.withOpacity(0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(location.emoji, style: const TextStyle(fontSize: 36)),
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: gold.withOpacity(0.3),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullImageViewer(assetPath: assetPath),
        fullscreenDialog: true,
      ),
    );
  }
}

class _FullImageViewer extends StatelessWidget {
  final String assetPath;
  const _FullImageViewer({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Text(
                'Image not found',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, color: gold, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: gold,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  final SigiriyaLocation location;
  const _HeroImage({required this.location});

  @override
  Widget build(BuildContext context) {
    if (location.imageAssets.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C1A0E), Color(0xFF5C3D1E)],
          ),
        ),
      );
    }
    return Image.asset(
      location.imageAssets.first,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C1A0E), Color(0xFF5C3D1E)],
          ),
        ),
      ),
    );
  }
}

/// Simple markdown-like renderer (no external package needed)
class _MarkdownRenderer extends StatelessWidget {
  final String text;
  const _MarkdownRenderer({required this.text});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: Text(
              line.substring(3),
              style: TextStyle(
                color: gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              line.substring(4),
              style: TextStyle(
                color: gold.withOpacity(0.85),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else if (line.startsWith('**') &&
          line.endsWith('**') &&
          line.length > 4) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              line.replaceAll('**', ''),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: gold, fontSize: 14)),
                Expanded(child: _InlineText(line.substring(2))),
              ],
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _InlineText(line),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _InlineText extends StatelessWidget {
  final String text;
  const _InlineText(this.text);

  @override
  Widget build(BuildContext context) {
    // Simple bold rendering: split on **
    final parts = text.split('**');
    if (parts.length == 1) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.6,
        ),
      );
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
            color: i.isOdd ? Colors.white : Colors.white70,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, height: 1.6),
        children: spans,
      ),
    );
  }
}
