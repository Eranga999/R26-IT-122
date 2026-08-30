import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'geopackage/gpkg_geometry.dart';
import 'geopackage/sigiriya_map_loader.dart';

/// The map's own parchment background fill (also painted by
/// [_VectorMapPainter]). Reused for the [Scaffold] and the ground behind the
/// canvas so the letterbox bands around this wide-aspect map — a phone screen
/// is far taller and narrower than the bbox — read as blank map, not a gap.
const Color _kMapParchment = Color(0xFFEFE6D8);

// ── Heritage Map — separate full-screen route ───────────────────────────────
// Opened via Navigator.push from Home's Map nav button. Deliberately has no
// bottomNavigationBar / Camera-Explore-Map nav — just an AppBar with a back
// button that pops back to whichever screen (Home/Explore) launched it.
//
// Fully offline by design: instead of live map tiles (which needed
// `tile.openstreetmap.org` over HTTPS, breaking the app's offline
// requirement) this parses a bundled OpenStreetMap GeoPackage extract
// (assets/vectors/sigiriya_map.gpkg — real surveyed roads, buildings and
// points of interest for the Sigiriya/Pidurangala area) and draws it
// directly, entirely from local widgets/CustomPaint, so it never touches
// the network.
class HeritageMapScreen extends StatefulWidget {
  const HeritageMapScreen({super.key});

  @override
  State<HeritageMapScreen> createState() => _HeritageMapScreenState();
}

class _HeritageMapScreenState extends State<HeritageMapScreen> {
  late final Future<SigiriyaMapData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = SigiriyaMapLoader.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sigiriya Map'),
      ),
      backgroundColor: _kMapParchment,
      // No banner pushing the map down — it fills the whole body, edge to
      // edge, with a small floating chip (inside _VectorMap's Stack) for
      // the offline note instead. Maximizes actual map real estate.
      body: FutureBuilder<SigiriyaMapData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load the Sigiriya map data.\n${snapshot.error ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textBase),
                ),
              ),
            );
          }
          return _VectorMap(data: snapshot.data!);
        },
      ),
    );
  }
}

/// Landmark names that must always win the on-screen label contest, even
/// when a nearby lower-priority label would otherwise claim the space first
/// — the handful of stops a visitor actually orients by.
const Set<String> _pinnedLandmarks = {
  'Sigiriya',
  "Lion's Paws",
  'Sigiriya Museum',
  'Sigiriya Tank',
  'Pidurangala Rock',
  'Pidurangala Rock Viewpoint',
  'Pidurangala Vihara',
  'Sigiriya Entrance Bus Station',
  'Mapagala Rock',
  'Mapagala Archaeological Site',
  'Ramakale Stupa',
};

/// Per-name icon override for a [_pinnedLandmarks] entry whose generic
/// OSM-tag-derived icon (see [_pointMarkerStyle] / [_polygonMarkerStyle])
/// doesn't fit — e.g. Lion's Paws carries no historic/tourism tag in the
/// source data, so without this it would fall through to a plain pin.
const Map<String, IconData> _pinnedLandmarkIconOverride = {
  "Lion's Paws": Icons.pets_rounded,
};

/// Any marker at/above this priority is always drawn with its label — it
/// never loses out to another label wanting the same screen space. Used for
/// [_pinnedLandmarks] and [_curatedTrailStops]: the small set of landmarks a
/// visitor is actually here for, as opposed to the hundreds of incidental
/// roads/hotels/buildings that are fine to show as a plain dot when space is
/// tight.
const int kAlwaysShowPriority = 10;

class _CuratedStop {
  final String name;
  final double lon;
  final double lat;
  final IconData icon;
  final Color color;
  const _CuratedStop(this.name, this.lon, this.lat, this.icon, this.color);
}

/// The classic Sigiriya visitor-trail stops, in ascent order: Ticket Counter
/// → Water Gardens → Boulder Gardens → Terraced Gardens → Lion's Paws →
/// Mirror Wall/Fresco Gallery → Audience Hall & Throne → Summit Palace.
/// Sourced from the site layout described in published archaeological
/// literature (summarised on Wikipedia's Sigiriya article, itself citing
/// UNESCO/Bandaranayake surveys) — see docs/sigiriya_poi_dataset.md for the
/// full source citation. OpenStreetMap's crowdsourced extract doesn't tag
/// most of these under their popular visitor-guide names, so each anchor
/// below is taken from the nearest real surveyed OSM feature rather than an
/// invented coordinate:
///  - Ticket Counter      = "Sigiriya site ticket office" (real point)
///  - Water Gardens       = the unnamed leisure=park polygon on the entrance
///                          approach (real polygon, no OSM name to reuse)
///  - Boulder Gardens      = "Cobra Hood Cave" (real point) — sits in the
///                          boulder-garden stretch of the ascent
///  - Terraced Gardens     = no OSM anchor exists, so this is interpolated
///                          40% of the way from Cobra Hood Cave towards Lion's
///                          Paw Terrace, matching the described sequence
///                          (boulder gardens → terraces → lion staircase)
///  - Mirror Wall/Fresco   = no OSM anchor exists either (both are features
///                          on the rock's sheer face along the spiral
///                          staircase), interpolated 65% of the way along
///                          that same stretch
///  - Audience Hall/Throne = "Audience Hall" (real point) — a carved-boulder
///                          audience chamber at the rock's base, distinct
///                          from the summit palace despite the similar name
///  - Summit Palace        = "Upper Terrace" (real point/polygon, summit
///                          level, past Lion's Paws)
/// Lion's Paws itself already exists as an accurately-placed OSM point (see
/// [_pinnedLandmarks]) so it isn't duplicated here.
const List<_CuratedStop> _curatedTrailStops = [
  _CuratedStop('Ticket Counter', 80.75212635, 7.9577245,
      Icons.confirmation_num_rounded, AppTheme.primary),
  _CuratedStop('Water Gardens', 80.7561035, 7.9572137, Icons.water_rounded,
      Color(0xFF1565C0)),
  _CuratedStop('Boulder Gardens & Cobra Hood Cave', 80.7582684, 7.9562783,
      Icons.landscape_rounded, Color(0xFF2E7D32)),
  _CuratedStop('Terraced Gardens', 80.7590067, 7.9568577,
      Icons.layers_rounded, Color(0xFF2E7D32)),
  _CuratedStop('Mirror Wall & Fresco Gallery', 80.7594681, 7.9572197,
      Icons.auto_awesome_rounded, Color(0xFFD4A017)),
  _CuratedStop('Audience Hall & Throne', 80.7585222, 7.9560209,
      Icons.chair_rounded, Color(0xFFD4A017)),
  _CuratedStop('Summit Palace', 80.75979575, 7.9570616,
      Icons.castle_rounded, Color(0xFFD4A017)),
];

/// Real OSM features absorbed into a [_curatedTrailStops] anchor above — kept
/// out of the generic marker pass so the same physical spot doesn't get two
/// overlapping pins (one curated, one generic).
const Set<String> _absorbedIntoCuratedStops = {
  'Sigiriya site ticket office',
  'Cobra Hood Cave',
  'Audience Hall',
  'Upper Terrace',
};

/// The filter-chip categories shown above the map. [MapCategory.landmark]
/// is the default/opening view — everything else starts hidden and is
/// revealed by tapping its chip, so the map opens clean instead of
/// crowded with every hotel and restaurant at once.
enum MapCategory { landmark, hotel, food, facility, viewpoint, elephant, all }

class MapCategoryInfo {
  final MapCategory category;
  final String label;
  final IconData icon;
  final Color color;
  const MapCategoryInfo(this.category, this.label, this.icon, this.color);
}

/// Chip definitions in display order. Elephant warning zones are always
/// rendered regardless of filter (see [_VectorMapPainter.paint]) — its chip
/// just also empties the regular POI list so the map shows "that only", as
/// requested.
const List<MapCategoryInfo> kMapCategoryChips = [
  MapCategoryInfo(MapCategory.landmark, 'Landmarks', Icons.account_balance_rounded, Color(0xFFD4A017)),
  MapCategoryInfo(MapCategory.hotel, 'Hotels', Icons.hotel_rounded, Color(0xFF6A1B9A)),
  MapCategoryInfo(MapCategory.food, 'Food', Icons.restaurant_rounded, Color(0xFFE64A19)),
  MapCategoryInfo(MapCategory.facility, 'Facilities', Icons.local_parking_rounded, Color(0xFF455A64)),
  MapCategoryInfo(MapCategory.viewpoint, 'Viewpoints', Icons.landscape_rounded, Color(0xFF2E7D32)),
  MapCategoryInfo(MapCategory.elephant, 'Elephant Warning', Icons.warning_amber_rounded, Color(0xFFD84315)),
  MapCategoryInfo(MapCategory.all, 'All', Icons.layers_rounded, AppTheme.primary),
];

/// How a named feature (point or polygon) renders as a pin: icon, colour,
/// size, the priority it competes with for label space, and which filter
/// chip it belongs to.
class _MarkerStyle {
  final IconData icon;
  final Color color;
  final int priority;
  final double pinRadius;
  final MapCategory category;
  final String? categoryLabel;
  const _MarkerStyle({
    required this.icon,
    required this.color,
    required this.priority,
    required this.pinRadius,
    required this.category,
    this.categoryLabel,
  });
}

/// A named, tappable place rendered on the map — built once from both the
/// point and polygon feature tables so buildings/water/rock landmarks (which
/// only exist as polygons, e.g. Sigiriya Tank) get the same pin+label
/// treatment as point POIs (e.g. Lion's Paws).
class _MapMarker {
  final Offset screen;
  final String name;
  final IconData icon;
  final Color color;
  final int priority;
  final double pinRadius;
  final MapCategory category;
  final String? categoryLabel;
  const _MapMarker({
    required this.screen,
    required this.name,
    required this.icon,
    required this.color,
    required this.priority,
    required this.pinRadius,
    required this.category,
    this.categoryLabel,
  });
}

/// An [ElephantWarningZone] pre-projected to canvas coordinates, with its
/// approximate warning radius converted from metres to pixels.
class _ProjectedElephantZone {
  final ElephantWarningZone zone;
  final Offset screen;
  final double pixelRadius;
  const _ProjectedElephantZone({
    required this.zone,
    required this.screen,
    required this.pixelRadius,
  });
}

_MarkerStyle _polygonMarkerStyle(MapPolygonFeature poly) {
  if (poly.historic != null) {
    return const _MarkerStyle(
        icon: Icons.account_balance_rounded,
        color: Color(0xFFD4A017),
        priority: 4,
        pinRadius: 8,
        category: MapCategory.landmark,
        categoryLabel: 'HISTORIC SITE');
  }
  if (poly.tourism == 'museum') {
    return const _MarkerStyle(
        icon: Icons.museum_rounded,
        color: Color(0xFFD4A017),
        priority: 4,
        pinRadius: 8,
        category: MapCategory.landmark,
        categoryLabel: 'MUSEUM');
  }
  if (poly.tourism == 'attraction') {
    return const _MarkerStyle(
        icon: Icons.star_rounded,
        color: Color(0xFFD4A017),
        priority: 4,
        pinRadius: 8,
        category: MapCategory.landmark,
        categoryLabel: 'ATTRACTION');
  }
  if (poly.amenity == 'toilets') {
    return const _MarkerStyle(
        icon: Icons.wc_rounded,
        color: Color(0xFF00838F),
        priority: 3,
        pinRadius: 6,
        category: MapCategory.facility,
        categoryLabel: 'TOILETS');
  }
  if (poly.amenity == 'parking') {
    return const _MarkerStyle(
        icon: Icons.local_parking_rounded,
        color: Color(0xFF455A64),
        priority: 2,
        pinRadius: 6,
        category: MapCategory.facility,
        categoryLabel: 'PARKING');
  }
  if (poly.amenity == 'restaurant') {
    return const _MarkerStyle(
        icon: Icons.restaurant_rounded,
        color: Color(0xFFE64A19),
        priority: 1,
        pinRadius: 4,
        category: MapCategory.food,
        categoryLabel: 'RESTAURANT');
  }
  if (poly.amenity == 'fountain') {
    return const _MarkerStyle(
        icon: Icons.water_drop_rounded,
        color: Color(0xFF1565C0),
        priority: 2,
        pinRadius: 5,
        category: MapCategory.facility,
        categoryLabel: 'WATER FEATURE');
  }
  if (poly.amenity == 'place_of_worship') {
    return const _MarkerStyle(
        icon: Icons.temple_buddhist_rounded,
        color: Color(0xFFD4A017),
        priority: 3,
        pinRadius: 6,
        category: MapCategory.landmark,
        categoryLabel: 'TEMPLE');
  }
  if (poly.shop == 'ticket') {
    return const _MarkerStyle(
        icon: Icons.confirmation_num_rounded,
        color: AppTheme.primary,
        priority: 3,
        pinRadius: 6,
        category: MapCategory.facility,
        categoryLabel: 'TICKET COUNTER');
  }
  if (poly.natural == 'water') {
    return const _MarkerStyle(
        icon: Icons.water_drop_rounded,
        color: Color(0xFF1565C0),
        priority: 3,
        pinRadius: 6,
        category: MapCategory.landmark,
        categoryLabel: 'WATER');
  }
  if (poly.natural == 'bare_rock' || poly.natural == 'rock' || poly.natural == 'stone') {
    return const _MarkerStyle(
        icon: Icons.terrain_rounded,
        color: Color(0xFF6D4C41),
        priority: 4,
        pinRadius: 7,
        category: MapCategory.landmark,
        categoryLabel: 'ROCK OUTCROP');
  }
  if (poly.building != null) {
    return const _MarkerStyle(
        icon: Icons.apartment_rounded,
        color: Color(0xFF8D6E63),
        priority: 2,
        pinRadius: 5,
        category: MapCategory.facility,
        categoryLabel: 'BUILDING');
  }
  return const _MarkerStyle(
      icon: Icons.place_rounded,
      color: AppTheme.primary,
      priority: 1,
      pinRadius: 5,
      category: MapCategory.facility);
}

String? _tag(String? otherTags, String key) {
  if (otherTags == null) return null;
  final m = RegExp('"$key"=>"([^"]*)"').firstMatch(otherTags);
  return m?.group(1);
}

_MarkerStyle _pointMarkerStyle(MapPointFeature pt) {
  final tags = pt.otherTags;
  if ((tags ?? '').contains('"historic"')) {
    return const _MarkerStyle(
        icon: Icons.account_balance_rounded,
        color: Color(0xFFD4A017),
        priority: 4,
        pinRadius: 7,
        category: MapCategory.landmark,
        categoryLabel: 'HISTORIC');
  }

  switch (_tag(tags, 'amenity')) {
    case 'toilets':
      return const _MarkerStyle(
          icon: Icons.wc_rounded, color: Color(0xFF00838F), priority: 3, pinRadius: 6, category: MapCategory.facility, categoryLabel: 'TOILETS');
    case 'drinking_water':
      return const _MarkerStyle(
          icon: Icons.water_drop_rounded, color: Color(0xFF00838F), priority: 3, pinRadius: 6, category: MapCategory.facility, categoryLabel: 'DRINKING WATER');
    case 'parking':
      return const _MarkerStyle(
          icon: Icons.local_parking_rounded, color: Color(0xFF455A64), priority: 2, pinRadius: 6, category: MapCategory.facility, categoryLabel: 'PARKING');
    case 'restaurant':
      return const _MarkerStyle(
          icon: Icons.restaurant_rounded, color: Color(0xFFE64A19), priority: 1, pinRadius: 4, category: MapCategory.food, categoryLabel: 'RESTAURANT');
    case 'cafe':
      return const _MarkerStyle(
          icon: Icons.local_cafe_rounded, color: Color(0xFFE64A19), priority: 1, pinRadius: 4, category: MapCategory.food, categoryLabel: 'CAFE');
    case 'pub':
      return const _MarkerStyle(
          icon: Icons.restaurant_rounded, color: Color(0xFFE64A19), priority: 1, pinRadius: 4, category: MapCategory.food, categoryLabel: 'RESTAURANT');
    case 'police':
      return const _MarkerStyle(
          icon: Icons.local_police_rounded, color: Color(0xFFC62828), priority: 3, pinRadius: 6, category: MapCategory.facility, categoryLabel: 'POLICE');
    case 'first_aid':
    case 'doctors':
      return const _MarkerStyle(
          icon: Icons.medical_services_rounded, color: Color(0xFFC62828), priority: 3, pinRadius: 6, category: MapCategory.facility, categoryLabel: 'FIRST AID');
    case 'bicycle_rental':
      return const _MarkerStyle(
          icon: Icons.pedal_bike_rounded, color: Color(0xFF6D4C41), priority: 1, pinRadius: 4, category: MapCategory.facility, categoryLabel: 'BICYCLE RENTAL');
    case 'bench':
      return const _MarkerStyle(
          icon: Icons.chair_rounded, color: Color(0xFF8D6E63), priority: 1, pinRadius: 3, category: MapCategory.facility, categoryLabel: 'REST AREA');
    case 'atm':
      return const _MarkerStyle(
          icon: Icons.local_atm_rounded, color: Color(0xFF455A64), priority: 1, pinRadius: 4, category: MapCategory.facility, categoryLabel: 'ATM');
    case 'place_of_worship':
      return const _MarkerStyle(
          icon: Icons.temple_buddhist_rounded, color: Color(0xFFD4A017), priority: 3, pinRadius: 6, category: MapCategory.landmark, categoryLabel: 'TEMPLE');
  }

  switch (_tag(tags, 'shop')) {
    case 'ticket':
      return const _MarkerStyle(
          icon: Icons.confirmation_num_rounded, color: AppTheme.primary, priority: 3, pinRadius: 6, category: MapCategory.facility, categoryLabel: 'TICKET COUNTER');
    case 'gift':
    case 'craft':
      return const _MarkerStyle(
          icon: Icons.card_giftcard_rounded, color: Color(0xFF6A1B9A), priority: 1, pinRadius: 4, category: MapCategory.facility, categoryLabel: 'SOUVENIR SHOP');
    case 'convenience':
      return const _MarkerStyle(
          icon: Icons.local_convenience_store_rounded, color: Color(0xFF455A64), priority: 1, pinRadius: 4, category: MapCategory.facility, categoryLabel: 'SHOP');
  }

  switch (pt.category) {
    case 'information':
      return const _MarkerStyle(
          icon: Icons.info_rounded, color: Color(0xFF1565C0), priority: 2, pinRadius: 5, category: MapCategory.facility, categoryLabel: 'TOURIST INFORMATION');
    case 'gallery':
    case 'artwork':
      return const _MarkerStyle(
          icon: Icons.palette_rounded, color: Color(0xFF6A1B9A), priority: 1, pinRadius: 4, category: MapCategory.landmark, categoryLabel: 'GALLERY');
    case 'viewpoint':
      return const _MarkerStyle(
          icon: Icons.landscape_rounded,
          color: Color(0xFF2E7D32),
          priority: 4,
          pinRadius: 7,
          category: MapCategory.viewpoint,
          categoryLabel: 'VIEWPOINT');
    case 'bus_stop':
      return const _MarkerStyle(
          icon: Icons.directions_bus_rounded,
          color: Color(0xFF1565C0),
          priority: 3,
          pinRadius: 6,
          category: MapCategory.facility,
          categoryLabel: 'BUS STOP');
    case 'guest_house':
      return const _MarkerStyle(
          icon: Icons.hotel_rounded,
          color: Color(0xFF6A1B9A),
          priority: 2,
          pinRadius: 5,
          category: MapCategory.hotel,
          categoryLabel: 'GUEST HOUSE');
    case 'hotel':
      return const _MarkerStyle(
          icon: Icons.hotel_rounded,
          color: Color(0xFF6A1B9A),
          priority: 2,
          pinRadius: 5,
          category: MapCategory.hotel,
          categoryLabel: 'HOTEL');
    case 'village':
    case 'town':
      return const _MarkerStyle(
          icon: Icons.location_city_rounded,
          color: Color(0xFF8B5E3C),
          priority: 4,
          pinRadius: 7,
          category: MapCategory.landmark,
          categoryLabel: 'VILLAGE');
    default:
      return const _MarkerStyle(
          icon: Icons.place_rounded,
          color: AppTheme.primary,
          priority: 1,
          pinRadius: 4,
          category: MapCategory.facility);
  }
}

/// A wildlife/elephant warning reference point — NOT a live elephant
/// location. Represents an area where elephant activity has been observed
/// or reported; the visitor should read this as "activity may occur here",
/// never as "an elephant is currently here".
///
/// Coordinates are user-provided GPS points (source of truth: field
/// observation), not derived from OSM or invented. No verified ecological
/// habitat boundary exists for these areas, so [warningRadiusMeters] is an
/// approximate visual warning radius only — see
/// docs/sigiriya_poi_dataset.md ("geometry_status: approximate_warning_
/// visualization") for the full methodology note.
class ElephantWarningZone {
  final String id;
  final String name;
  final double lon;
  final double lat;
  final double warningRadiusMeters;
  const ElephantWarningZone({
    required this.id,
    required this.name,
    required this.lon,
    required this.lat,
    this.warningRadiusMeters = 90,
  });
}

const List<ElephantWarningZone> kElephantWarningZones = [
  ElephantWarningZone(
    id: 'sigiriya_wildlife_001',
    name: 'Elephant Warning Area 1',
    lat: 7.9544126754,
    lon: 80.7563181363,
  ),
  ElephantWarningZone(
    id: 'sigiriya_wildlife_002',
    name: 'Elephant Warning Area 2',
    lat: 7.9534636278,
    lon: 80.7552407025,
  ),
  ElephantWarningZone(
    id: 'sigiriya_wildlife_003',
    name: 'Elephant Warning Area 3',
    lat: 7.9525135509,
    lon: 80.7494084020,
  ),
];

/// Bounding-box centre of a polygon ring — cheap and, for the compact
/// building/tank/rock shapes in this dataset, a good enough label anchor
/// (a true area-weighted centroid isn't worth the extra complexity here).
GeoPoint _ringCentroid(List<GeoPoint> ring) {
  double minLon = ring.first.lon, maxLon = ring.first.lon;
  double minLat = ring.first.lat, maxLat = ring.first.lat;
  for (final p in ring) {
    if (p.lon < minLon) minLon = p.lon;
    if (p.lon > maxLon) maxLon = p.lon;
    if (p.lat < minLat) minLat = p.lat;
    if (p.lat > maxLat) maxLat = p.lat;
  }
  return GeoPoint((minLon + maxLon) / 2, (minLat + maxLat) / 2);
}

class _VectorMap extends StatefulWidget {
  final SigiriyaMapData data;
  const _VectorMap({required this.data});

  @override
  State<_VectorMap> createState() => _VectorMapState();
}

class _VectorMapState extends State<_VectorMap> {
  // Logical canvas resolution — height derived from the real-world aspect
  // ratio of the clipped bounding box so the map isn't stretched.
  static const double _canvasWidth = 900;
  late final Size _canvasSize;
  late final List<_MapMarker> _markers;
  late final List<_ProjectedElephantZone> _elephantZones;
  late final Rect _importantBounds;
  final TransformationController _transformController = TransformationController();
  bool _initialViewSet = false;
  MapCategory _selectedCategory = MapCategory.landmark;

  /// Only markers in the selected category are drawn/tappable — this is
  /// the filter the chip row controls. [MapCategory.all] bypasses the
  /// filter entirely; [MapCategory.elephant] intentionally has no matching
  /// markers (elephant zones are a separate always-on layer), so selecting
  /// it empties this list and the map shows "that only", as requested.
  List<_MapMarker> get _visibleMarkers => _selectedCategory == MapCategory.all
      ? _markers
      : _markers.where((m) => m.category == _selectedCategory).toList();

  @override
  void initState() {
    super.initState();
    final midLat = (kMapMinLat + kMapMaxLat) / 2;
    final lonSpanKm =
        (kMapMaxLon - kMapMinLon) * 111.32 * cos(midLat * pi / 180);
    final latSpanKm = (kMapMaxLat - kMapMinLat) * 110.57;
    final aspect = lonSpanKm / latSpanKm;
    _canvasSize = Size(_canvasWidth, _canvasWidth / aspect);

    _markers = _buildMarkers(widget.data, _canvasSize);
    _importantBounds = _boundsOf(
      _markers.where((m) => m.priority >= kAlwaysShowPriority).map((m) => m.screen),
      _canvasSize,
    );

    final pixelsPerMeter = _canvasSize.width / (lonSpanKm * 1000);
    _elephantZones = [
      for (final z in kElephantWarningZones)
        _ProjectedElephantZone(
          zone: z,
          screen: _project(GeoPoint(z.lon, z.lat), _canvasSize),
          pixelRadius: z.warningRadiusMeters * pixelsPerMeter,
        ),
    ];
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  static Offset _project(GeoPoint p, Size canvasSize) {
    final dx = (p.lon - kMapMinLon) / (kMapMaxLon - kMapMinLon);
    final dy = 1 - (p.lat - kMapMinLat) / (kMapMaxLat - kMapMinLat);
    return Offset(dx * canvasSize.width, dy * canvasSize.height);
  }

  /// Bounding box (with padding) of a set of canvas points, falling back to
  /// the whole canvas if the set is empty.
  static Rect _boundsOf(Iterable<Offset> points, Size canvasSize) {
    if (points.isEmpty) return Offset.zero & canvasSize;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    const pad = 70.0;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  /// Every named feature (facilities/landmarks *and* hotels/restaurants/
  /// shops alike) goes through the same pin-with-priority-ordered-label
  /// pass — see [_tryDrawLabel]. There's no separate "cluster into a
  /// number" step: a real name wherever there's room beats an anonymous
  /// count badge, and the priority tiers (see [_pointMarkerStyle] /
  /// [_polygonMarkerStyle]) already make sure landmarks/facilities win the
  /// label contest over an ordinary guest house.
  static List<_MapMarker> _buildMarkers(SigiriyaMapData data, Size canvasSize) {
    final markers = <_MapMarker>[];

    for (final poly in data.polygons) {
      final name = poly.name;
      if (name == null || poly.rings.isEmpty) continue;
      if (_absorbedIntoCuratedStops.contains(name)) continue;
      final style = _polygonMarkerStyle(poly);
      final pinned = _pinnedLandmarks.contains(name);
      markers.add(_MapMarker(
        screen: _project(_ringCentroid(poly.rings.first), canvasSize),
        name: name,
        icon: _pinnedLandmarkIconOverride[name] ?? style.icon,
        color: style.color,
        priority: pinned ? kAlwaysShowPriority : style.priority,
        pinRadius: pinned ? max(style.pinRadius, 9) : style.pinRadius,
        // A pinned base-map landmark is always a "Landmarks" chip result,
        // regardless of what OSM tag happened to classify it under.
        category: pinned ? MapCategory.landmark : style.category,
        categoryLabel: style.categoryLabel,
      ));
    }

    for (final pt in data.points) {
      final name = pt.name;
      if (name == null) continue;
      if (_absorbedIntoCuratedStops.contains(name)) continue;
      final style = _pointMarkerStyle(pt);
      final pinned = _pinnedLandmarks.contains(name);
      markers.add(_MapMarker(
        screen: _project(pt.pos, canvasSize),
        name: name,
        icon: _pinnedLandmarkIconOverride[name] ?? style.icon,
        color: style.color,
        priority: pinned ? kAlwaysShowPriority : style.priority,
        pinRadius: pinned ? max(style.pinRadius, 9) : style.pinRadius,
        category: pinned ? MapCategory.landmark : style.category,
        categoryLabel: style.categoryLabel,
      ));
    }

    for (final stop in _curatedTrailStops) {
      markers.add(_MapMarker(
        screen: _project(GeoPoint(stop.lon, stop.lat), canvasSize),
        name: stop.name,
        icon: stop.icon,
        color: stop.color,
        priority: kAlwaysShowPriority,
        pinRadius: 10,
        category: MapCategory.landmark,
        categoryLabel: 'SIGIRIYA LANDMARK',
      ));
    }

    // Highest priority first so it wins the greedy label-collision pass.
    markers.sort((a, b) => b.priority.compareTo(a.priority));
    return markers;
  }

  void _onTapUp(TapUpDetails details) {
    // Elephant warning zones take tap priority within their radius — safety
    // information should never be shadowed by an ordinary POI pin.
    for (final z in _elephantZones) {
      if ((z.screen - details.localPosition).distance <= z.pixelRadius) {
        _showElephantWarningSheet(z.zone);
        return;
      }
    }

    const hitRadius = 18.0;
    _MapMarker? nearest;
    double nearestDist = double.infinity;
    for (final m in _visibleMarkers) {
      final d = (m.screen - details.localPosition).distance;
      if (d < hitRadius && d < nearestDist) {
        nearest = m;
        nearestDist = d;
      }
    }
    if (nearest != null) {
      _showPoiSheet(nearest);
    }
  }

  void _showElephantWarningSheet(ElephantWarningZone zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text('WILDLIFE WARNING',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '🐘 ${zone.name}',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textBase,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Wild elephants may be present in this area. This marks a '
              'location where elephant activity has been observed or '
              'reported — it does not show a current elephant location. '
              'Follow local safety instructions and posted warning signs, '
              'and do not walk alone outside populated areas.',
              style: TextStyle(color: Color(0xFF4E342E), fontSize: 13.5, height: 1.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Source: User-provided GPS coordinates. Warning area shown is '
              'an approximate visualisation, not a confirmed habitat boundary.',
              style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showPoiSheet(_MapMarker m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(m.icon, color: m.color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.name,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textBase,
                    ),
                  ),
                ),
              ],
            ),
            if (m.categoryLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                m.categoryLabel!,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Frames [_importantBounds] — the curated trail stops plus every
  /// always-shown base-map landmark (Sigiriya, Pidurangala, the Museum,
  /// Tank, bus station, ...) — so the whole site is on screen the moment
  /// the map opens, rather than a hand-picked focus point (previously cut
  /// off Pidurangala) or the whole bundled extent (pins/text too small).
  ///
  /// This *contains* the important-bounds rect: `fitScale` is the largest
  /// zoom at which the rect still fits the viewport on both axes. On a
  /// phone the width is the limiting axis, so the full east–west spread of
  /// the site — ticket counter through the summit, plus Pidurangala — is
  /// visible at once instead of the east side being pushed off the right
  /// edge. Leftover vertical space becomes a parchment band top/bottom
  /// (same colour as the map, see [_kMapParchment]), which reads as blank
  /// map. `wholeCanvasScale` is a floor so opening the map never shows
  /// dead space *beyond* the canvas on the limiting axis; 4x is the ceiling.
  ///
  /// A `coverScale` floor (scale needed for the whole canvas to fill the
  /// viewport on both axes) was tried here and removed: this map's bbox is
  /// wide-and-short and a phone is tall-and-narrow, so "cover" forces the
  /// canvas to overflow sideways and there is no opening zoom at which the
  /// east–west span all fits — exactly the bug this replaces.
  void _setInitialView(Size viewportSize) {
    if (_initialViewSet || viewportSize.shortestSide == 0) return;
    _initialViewSet = true;
    final rect = _importantBounds;
    final fitScale = min(
      viewportSize.width / rect.width,
      viewportSize.height / rect.height,
    );
    final wholeCanvasScale = min(
      viewportSize.width / _canvasSize.width,
      viewportSize.height / _canvasSize.height,
    );
    var scale = fitScale;
    if (scale > 4.0) scale = 4.0;
    if (scale < wholeCanvasScale) scale = wholeCanvasScale;
    final dx = viewportSize.width / 2 - rect.center.dx * scale;
    final dy = viewportSize.height / 2 - rect.center.dy * scale;
    _transformController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryChipBar(
          selected: _selectedCategory,
          onSelect: (c) => setState(() => _selectedCategory = c),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _setInitialView(constraints.biggest));
              return Stack(
                children: [
                  // Parchment ground so the letterbox bands around the
                  // wide-aspect canvas read as blank map, not a gap.
                  const Positioned.fill(
                    child: ColoredBox(color: _kMapParchment),
                  ),
                  InteractiveViewer(
                    transformationController: _transformController,
                    // The child is the full logical map canvas — far wider
                    // than a phone screen and a different aspect ratio — so
                    // it must NOT be squeezed to the viewport. Left at its
                    // `true` default the canvas collapsed to the viewport
                    // box: the eastern half of the site (the rock itself,
                    // Pidurangala) was clipped away before pan/zoom, and a
                    // dead parchment band was left below the map.
                    constrained: false,
                    // Low enough to pinch right out to the whole canvas
                    // (~0.4 is "whole canvas" on a phone) with room to spare.
                    minScale: 0.25,
                    maxScale: 8.0,
                    // Generous, so the contained opening view (which
                    // letterboxes on the short axis) isn't fought by the
                    // boundary, but finite so the map can't be flung away
                    // and lost.
                    boundaryMargin: const EdgeInsets.all(400),
                    child: SizedBox(
                      width: _canvasSize.width,
                      height: _canvasSize.height,
                      child: GestureDetector(
                        onTapUp: _onTapUp,
                        child: ClipRect(
                          child: CustomPaint(
                            size: _canvasSize,
                            painter: _VectorMapPainter(
                              data: widget.data,
                              canvasSize: _canvasSize,
                              markers: _visibleMarkers,
                              elephantZones: _elephantZones,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: _OfflineInfoChip(),
                  ),
                  if (_elephantZones.isNotEmpty)
                    const Positioned(bottom: 12, left: 12, child: _ElephantLegendChip()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal, always-visible category filter row ("map upper choose icon
/// tab"). Selecting a chip filters the map's POI pins to that category only
/// (see [_VectorMapState._visibleMarkers]) — e.g. selecting "Elephant
/// Warning" hides every ordinary pin so only the warning zones remain,
/// selecting "Food" reveals every restaurant/cafe at once instead of most
/// of them losing the label-collision contest to landmarks. The map opens
/// on "Landmarks" so it starts clean rather than crowded.
class _CategoryChipBar extends StatelessWidget {
  final MapCategory selected;
  final ValueChanged<MapCategory> onSelect;
  const _CategoryChipBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: kMapCategoryChips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final info = kMapCategoryChips[i];
            return _CategoryChip(
              info: info,
              selected: info.category == selected,
              onTap: () => onSelect(info.category),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final MapCategoryInfo info;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? info.color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? info.color : Colors.grey.shade300, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 16, color: selected ? Colors.white : info.color),
            const SizedBox(width: 6),
            Text(
              info.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textBase,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed (non-pannable) offline-source note — was previously a full-width
/// banner pushing the whole map down; moved into the map's own overlay so
/// the map fills the screen instead of losing a chunk of height to a
/// permanent bar.
class _OfflineInfoChip extends StatelessWidget {
  const _OfflineInfoChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.offline_pin_rounded, size: 14, color: Color(0xFF8D6E63)),
            const SizedBox(width: 5),
            Text('Offline map — OpenStreetMap extract',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }
}

/// Fixed (non-pannable) legend explaining the red warning pins — added so
/// the per-pin floating label could be removed (it collided/overlapped when
/// zones sat close together) without losing the explanation.
class _ElephantLegendChip extends StatelessWidget {
  const _ElephantLegendChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD84315).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD84315), size: 15),
          const SizedBox(width: 6),
          Text('Elephant warning area — tap for details',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey[800])),
        ],
      ),
    );
  }
}

class _VectorMapPainter extends CustomPainter {
  final SigiriyaMapData data;
  final Size canvasSize;
  final List<_MapMarker> markers;
  final List<_ProjectedElephantZone> elephantZones;
  const _VectorMapPainter({
    required this.data,
    required this.canvasSize,
    required this.markers,
    required this.elephantZones,
  });

  Offset _project(GeoPoint p) {
    final dx = (p.lon - kMapMinLon) / (kMapMaxLon - kMapMinLon);
    final dy = 1 - (p.lat - kMapMinLat) / (kMapMaxLat - kMapMinLat);
    return Offset(dx * canvasSize.width, dy * canvasSize.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _kMapParchment);

    for (final poly in data.polygons) {
      _paintPolygon(canvas, poly);
    }
    for (final line in data.lines) {
      _paintLine(canvas, line);
    }
    // Unnamed points get a plain context dot; named ones are drawn as
    // full pins (with icon + label) in the marker pass below.
    for (final pt in data.points) {
      if (pt.name == null) _paintUnnamedDot(canvas, pt);
    }

    // Every named place — landmark, facility, or hotel alike — is drawn as
    // a pin, then labelled via the same priority-ordered collision pass
    // (see _paintMarkersWithLabels). Wildlife warnings are painted last so
    // they're always the topmost, most visible layer.
    _paintMarkersWithLabels(canvas);

    for (final z in elephantZones) {
      _paintElephantZone(canvas, z);
    }
  }

  /// Deliberately no floating name label here — with 3 zones as close as
  /// ~150m apart in real distance, always-on labels collided/overlapped
  /// each other and cluttered the map (see map screen doc comment). The pin
  /// itself (red, haloed, warning-icon) is already unmistakable; the name
  /// and full safety copy are one tap away. A fixed legend chip (outside
  /// the pannable canvas — see [_ElephantLegendChip]) explains what these
  /// pins mean.
  void _paintElephantZone(Canvas canvas, _ProjectedElephantZone z) {
    const warnColor = Color(0xFFD84315);
    canvas.drawCircle(z.screen, z.pixelRadius, Paint()..color = warnColor.withOpacity(0.10));
    _drawDashedCircle(canvas, z.screen, z.pixelRadius, warnColor);

    // Halo + pin, matching the "featured landmark" visual language but in
    // warning colours so it reads as categorically different at a glance.
    canvas.drawCircle(z.screen, 13, Paint()..color = Colors.white.withOpacity(0.95));
    canvas.drawCircle(z.screen, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      z.screen,
      10,
      Paint()
        ..color = warnColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );
    canvas.drawCircle(z.screen, 6.8, Paint()..color = warnColor);
    _drawIconGlyph(canvas, z.screen, Icons.warning_amber_rounded, 11.5, Colors.white);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    const dashDegrees = 10.0;
    const gapDegrees = 6.0;
    double deg = 0;
    while (deg < 360) {
      final start = deg * pi / 180;
      final sweep = dashDegrees * pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      deg += dashDegrees + gapDegrees;
    }
  }

  void _paintPolygon(Canvas canvas, MapPolygonFeature poly) {
    final style = _polygonFillStyle(poly);
    if (style == null) return;
    for (final ring in poly.rings) {
      if (ring.length < 3) continue;
      final path = Path()..moveTo(_project(ring.first).dx, _project(ring.first).dy);
      for (final p in ring.skip(1)) {
        final o = _project(p);
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = style.fill..style = PaintingStyle.fill);
      if (style.stroke != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = style.stroke!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  _PolyFillStyle? _polygonFillStyle(MapPolygonFeature poly) {
    if (poly.historic != null || poly.tourism == 'attraction' || poly.tourism == 'museum') {
      return const _PolyFillStyle(Color(0x33D4A017), Color(0xFFD4A017));
    }
    if (poly.natural == 'water') {
      return const _PolyFillStyle(Color(0xFFA9CCE3), null);
    }
    if (poly.natural == 'bare_rock' || poly.natural == 'rock' || poly.natural == 'stone') {
      return const _PolyFillStyle(Color(0xFFB0785A), null);
    }
    if (poly.natural == 'wood' || poly.natural == 'heath') {
      return const _PolyFillStyle(Color(0xFFA8C08A), null);
    }
    if (poly.landuse == 'farmland') {
      return const _PolyFillStyle(Color(0xFFD9DFA0), null);
    }
    if (poly.landuse == 'residential' || poly.landuse == 'commercial') {
      return const _PolyFillStyle(Color(0xFFE8DFCB), null);
    }
    if (poly.building != null) {
      return const _PolyFillStyle(Color(0xFFCBB994), Color(0xFFAA9670));
    }
    return null;
  }

  void _paintLine(Canvas canvas, MapLineFeature line) {
    if (line.points.length < 2) return;
    final path = Path()..moveTo(_project(line.points.first).dx, _project(line.points.first).dy);
    for (final p in line.points.skip(1)) {
      final o = _project(p);
      path.lineTo(o.dx, o.dy);
    }

    final style = _lineStyle(line);
    canvas.drawPath(
      path,
      Paint()
        ..color = style.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  _LineStyle _lineStyle(MapLineFeature line) {
    if (line.waterway != null) {
      return const _LineStyle(Color(0xFF5B9BD5), 2);
    }
    switch (line.highway) {
      case 'primary':
      case 'secondary':
        return const _LineStyle(Color(0xFF6D4C41), 3);
      case 'tertiary':
        return const _LineStyle(Color(0xFF8D6E63), 2.2);
      case 'residential':
      case 'unclassified':
      case 'living_street':
      case 'service':
        return const _LineStyle(Color(0xFFA1887F), 1.4);
      case 'footway':
      case 'path':
      case 'track':
      case 'steps':
        return const _LineStyle(Color(0xFF556B2F), 1.2);
      default:
        return const _LineStyle(Color(0xFFBCAAA4), 1.0);
    }
  }

  void _paintUnnamedDot(Canvas canvas, MapPointFeature pt) {
    final o = _project(pt.pos);
    canvas.drawCircle(o, 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(
      o,
      2.2,
      Paint()
        ..color = AppTheme.primary.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  /// Draws every named place as a pin (always visible), then makes a second,
  /// priority-ordered pass to lay text labels next to them — skipping any
  /// label that would overlap a pin or a label already placed. This keeps
  /// the busiest clusters legible (Google Maps-style declutter) while still
  /// showing a name for every place that has room.
  void _paintMarkersWithLabels(Canvas canvas) {
    final placedRects = <Rect>[];

    for (final m in markers) {
      _drawPin(canvas, m);
      placedRects.add(Rect.fromCircle(center: m.screen, radius: m.pinRadius + 2));
    }
    for (final m in markers) {
      _tryDrawLabel(canvas, m, placedRects);
    }
  }

  void _drawPin(Canvas canvas, _MapMarker m) {
    final featured = m.priority >= kAlwaysShowPriority;
    if (featured) {
      // Soft white halo so the must-see Sigiriya landmarks read as clearly
      // more important than the surrounding category-coloured dots/pins.
      canvas.drawCircle(m.screen, m.pinRadius + 4, Paint()..color = Colors.white.withOpacity(0.9));
    }
    canvas.drawCircle(m.screen, m.pinRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      m.screen,
      m.pinRadius,
      Paint()
        ..color = m.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = featured ? 2.6 : 1.8,
    );
    canvas.drawCircle(m.screen, m.pinRadius * 0.68, Paint()..color = m.color);
    if (m.pinRadius >= 6) {
      _drawIconGlyph(canvas, m.screen, m.icon, m.pinRadius * 1.15, Colors.white);
    }
  }

  void _drawIconGlyph(Canvas canvas, Offset center, IconData icon, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _tryDrawLabel(Canvas canvas, _MapMarker m, List<Rect> placedRects) {
    // The must-see Sigiriya trail landmarks always get their name shown —
    // they never lose out to a lower-priority label wanting the same space.
    final featured = m.priority >= kAlwaysShowPriority;
    final bold = m.priority >= 4;
    final tp = TextPainter(
      text: TextSpan(
        text: m.name,
        style: TextStyle(
          fontSize: featured ? 13.5 : (bold ? 12.5 : 10.5),
          fontWeight: featured ? FontWeight.w900 : (bold ? FontWeight.w800 : FontWeight.w600),
          color: AppTheme.textBase,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const hPad = 6.0, vPad = 3.0;
    final labelW = tp.width + hPad * 2;
    final labelH = tp.height + vPad * 2;

    // Anchor to the right of the pin by default, but flip to the left when
    // there isn't room before the canvas edge — otherwise labels near the
    // right/bottom of the map get silently clipped by the surrounding
    // ClipRect instead of just... not being placed on the wrong side.
    final fitsRight = m.screen.dx + m.pinRadius + 6 + labelW <= canvasSize.width - 4;
    final left = fitsRight
        ? m.screen.dx + m.pinRadius + 6
        : m.screen.dx - m.pinRadius - 6 - labelW;
    var top = m.screen.dy - labelH / 2;
    top = top.clamp(4.0, canvasSize.height - labelH - 4);

    final rect = Rect.fromLTWH(left, top, labelW, labelH);

    if (!featured && placedRects.any((r) => r.overlaps(rect))) return;
    placedRects.add(rect);

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withOpacity(featured ? 0.96 : 0.88),
    );
    if (featured) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = m.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    tp.paint(canvas, Offset(left + hPad, top + vPad));
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) =>
      !identical(oldDelegate.markers, markers);
}

class _PolyFillStyle {
  final Color fill;
  final Color? stroke;
  const _PolyFillStyle(this.fill, this.stroke);
}

class _LineStyle {
  final Color color;
  final double width;
  const _LineStyle(this.color, this.width);
}
