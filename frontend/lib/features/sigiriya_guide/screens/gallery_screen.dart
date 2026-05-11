// lib/screens/gallery_screen.dart
import 'package:flutter/material.dart';
import '../data/sigiriya_knowledge_base.dart';
import '../models/location_model.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  SigiriyaLocation? _selectedLocation;
  late final AnimationController _filterAnimCtrl;

  static const _gold = Color(0xFFE8B84B);

  @override
  void initState() {
    super.initState();
    _filterAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _filterAnimCtrl.dispose();
    super.dispose();
  }

  List<SigiriyaLocation> get _locationsWithImages =>
      kSigiriyaLocations.where((l) => l.imageAssets.isNotEmpty).toList();

  List<String> get _currentImages {
    if (_selectedLocation != null) return _selectedLocation!.imageAssets;
    return _locationsWithImages.expand((l) => l.imageAssets).toList();
  }

  SigiriyaLocation? _findOwner(String path) {
    for (final loc in kSigiriyaLocations) {
      if (loc.imageAssets.contains(path)) return loc;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final crossAxisCount = size.width > 900 ? 4 : (isTablet ? 3 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0800),
      appBar: _buildAppBar(isTablet),
      body: Column(
        children: [
          // Filter chips row
          _buildFilterRow(),

          // Location header (if filtered)
          if (_selectedLocation != null) _buildLocationHeader(isTablet),

          // Grid
          Expanded(
            child: _currentImages.isEmpty
                ? _buildEmptyState()
                : _buildGrid(crossAxisCount, isTablet),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isTablet) {
    return AppBar(
      backgroundColor: const Color(0xFF100900),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          const Text('🖼️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            'Gallery',
            style: TextStyle(
              color: _gold,
              fontWeight: FontWeight.w700,
              fontSize: isTablet ? 18 : 16,
            ),
          ),
          const SizedBox(width: 8),
          if (_currentImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_currentImages.length}',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF100900),
        border: Border(bottom: BorderSide(color: _gold.withOpacity(0.1))),
      ),
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          children: [
            _FilterPill(
              label: 'All',
              emoji: '✨',
              selected: _selectedLocation == null,
              onTap: () => setState(() => _selectedLocation = null),
            ),
            ...kSigiriyaLocations.map(
              (loc) => _FilterPill(
                label: loc.name.split(' ').first,
                emoji: loc.emoji,
                selected: _selectedLocation?.id == loc.id,
                onTap: () => setState(() => _selectedLocation = loc),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHeader(bool isTablet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Text(_selectedLocation!.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedLocation!.name,
                  style: TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w700,
                    fontSize: isTablet ? 17 : 15,
                  ),
                ),
                Text(
                  '${_currentImages.length} image${_currentImages.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(int crossAxisCount, bool isTablet) {
    return GridView.builder(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 12 : 8,
        mainAxisSpacing: isTablet ? 12 : 8,
        childAspectRatio: 1.0,
      ),
      itemCount: _currentImages.length,
      itemBuilder: (context, index) {
        final path = _currentImages[index];
        final ownerLoc = _findOwner(path);
        return _GalleryTile(assetPath: path, location: ownerLoc, index: index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withOpacity(0.06),
              border: Border.all(color: _gold.withOpacity(0.15)),
            ),
            child: Icon(
              Icons.image_outlined,
              size: 36,
              color: _gold.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Images Yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add images to assets/images/locations/\nto see them here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Pill ───────────────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  static const _gold = Color(0xFFE8B84B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _gold : _gold.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _gold : _gold.withOpacity(0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF1A0E00) : Colors.white60,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gallery Tile ──────────────────────────────────────────────────────
class _GalleryTile extends StatefulWidget {
  final String assetPath;
  final SigiriyaLocation? location;
  final int index;

  const _GalleryTile({
    required this.assetPath,
    this.location,
    required this.index,
  });

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _gold = Color(0xFFE8B84B);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) => _ctrl.reverse(),
        onTapCancel: () => _ctrl.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              if (widget.location != null) _buildOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Image.asset(
      widget.assetPath,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          _AssetPlaceholder(location: widget.location),
    );
  }

  Widget _buildOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            Text(widget.location!.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                widget.location!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Asset Placeholder ─────────────────────────────────────────────────
class _AssetPlaceholder extends StatelessWidget {
  final SigiriyaLocation? location;
  const _AssetPlaceholder({this.location});

  static const _gold = Color(0xFFE8B84B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1200), Color(0xFF2C1A0A)],
        ),
        border: Border.all(color: _gold.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (location != null)
            Text(location!.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Icon(Icons.image_outlined, color: _gold.withOpacity(0.25), size: 24),
          const SizedBox(height: 6),
          if (location != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                location!.name,
                style: TextStyle(color: _gold.withOpacity(0.4), fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
