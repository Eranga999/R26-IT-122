// lib/screens/explore_screen.dart
import 'package:flutter/material.dart';
import '../data/sigiriya_knowledge_base.dart';
import '../models/location_model.dart';
import 'location_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _search = '';

  List<SigiriyaLocation> get _filtered {
    if (_search.isEmpty) return kSigiriyaLocations;
    final q = _search.toLowerCase();
    return kSigiriyaLocations.where((loc) {
      return loc.name.toLowerCase().contains(q) ||
          loc.tags.any((t) => t.contains(q)) ||
          loc.briefSummary.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Sigiriya'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search locations, tags…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: gold.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No locations found for "$_search"',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final loc = _filtered[i];
                return _LocationCard(
                  location: loc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationDetailScreen(location: loc),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final SigiriyaLocation location;
  final VoidCallback onTap;

  const _LocationCard({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(location.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      location.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: gold.withOpacity(0.6)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                location.briefSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: location.tags.take(4).map((tag) {
                  return Chip(
                    label: Text(tag),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: TextStyle(fontSize: 11, color: gold.withOpacity(0.9)),
                    backgroundColor: gold.withOpacity(0.1),
                    side: BorderSide(color: gold.withOpacity(0.3)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
