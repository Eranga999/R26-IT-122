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

/// The handful of names a visitor calls the whole site by. Ranked above the
/// other must-see landmarks so that when a dense knot of them folds into a
/// single pin (see [_VectorMapState._buildClusters]) this is the name that
/// pin carries — the tangle of trail stops on the rock folds under
/// "Sigiriya", not under "Terraced Gardens" — and so their own labels win
/// the space contest first.
const Set<String> _headlinerLandmarks = {
  'Sigiriya',
  'Pidurangala Rock',
  'Sigiriya Museum',
  'Sigiriya Entrance Bus Station',
};

/// Priority for [_headlinerLandmarks] — above [kAlwaysShowPriority].
const int kHeadlinerPriority = 12;

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

/// One on-screen pin after the zoom-aware declutter: a representative marker
/// ([lead] — the strongest POI at that spot) plus every lower-priority marker
/// close enough that a second pin would just overlap it ([members], which
/// always holds [lead] first). [members] length > 1 ⇒ the pin is drawn with a
/// "stacked" hint and a tap opens the list of everything it stands for,
/// instead of the single-place sheet. The fold distance is a screen-pixel
/// value divided by the live zoom, so pinching in dissolves the stacks.
class _PinCluster {
  final _MapMarker lead;
  final List<_MapMarker> members;
  const _PinCluster(this.lead, this.members);
  bool get isStack => members.length > 1;
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

  /// Markers in the selected category (drawn + tappable) — the filter the
  /// chip row controls. Cached with a stable list identity, recomputed only
  /// on [_selectCategory], so the painter's `shouldRepaint` stays false while
  /// the map is merely panned (the label layer otherwise rebuilds on every
  /// transform tick now that it re-runs on zoom). [MapCategory.all] bypasses
  /// the filter; [MapCategory.elephant] matches nothing (elephant zones are a
  /// separate always-on layer), so it empties the list and the map shows
  /// "that only", as requested.
  late List<_MapMarker> _visibleMarkers;

  void _recomputeVisibleMarkers() {
    _visibleMarkers = _selectedCategory == MapCategory.all
        ? _markers
        : _markers.where((m) => m.category == _selectedCategory).toList();
  }

  void _selectCategory(MapCategory c) {
    if (c == _selectedCategory) return;
    setState(() {
      _selectedCategory = c;
      _recomputeVisibleMarkers();
      _clusterKey = double.nan; // force a re-fold for the new marker set
    });
  }

  // ── Zoom-aware pin declutter ─────────────────────────────────────────────
  // Overlapping *pins* are the other half of the clutter problem (labels are
  // handled inside the painter). Instead of a numbered "23" cluster badge —
  // which the user rejected — nearby weaker pins are folded into the strongest
  // pin at that spot; that pin is drawn with a small stacked-disc hint and, on
  // tap, lists everything it covers. The fold radius is screen px ÷ zoom, so
  // zooming in separates the pins again. Result is memoised on the quantised
  // scale so a pan (scale unchanged) neither re-folds nor repaints.
  double _clusterKey = double.nan;
  List<_PinCluster> _clusters = const [];

  static double _quantiseScale(double raw) =>
      raw <= 0 ? 1.0 : (raw * 100).roundToDouble() / 100;

  List<_PinCluster> _clustersFor(double quantisedScale) {
    if (quantisedScale != _clusterKey) {
      _clusterKey = quantisedScale;
      _clusters = _buildClusters(_visibleMarkers, quantisedScale);
    }
    return _clusters;
  }

  /// Greedy, priority-ordered fold: walk markers strongest-first and either
  /// start a new pin or, for a weaker marker within the fold radius of one
  /// already placed, tuck it underneath. A must-see landmark never folds into
  /// a weaker pin, but a headliner ([_headlinerLandmarks], sorted first) does
  /// absorb the ordinary must-see landmarks around it — so the whole knot of
  /// trail stops on the rock collapses to one "Sigiriya" pin at the site
  /// overview and fans back out as you zoom in.
  static List<_PinCluster> _buildClusters(
      List<_MapMarker> markers, double scale) {
    final invS = 1.0 / scale;
    final foldPx = 38.0 * invS;
    final foldPxFeatured = 44.0 * invS;

    final leads = <_MapMarker>[];
    final memberLists = <List<_MapMarker>>[];

    for (final m in markers) {
      final mFeatured = m.priority >= kAlwaysShowPriority;
      var hostIdx = -1;
      var hostDist = double.infinity;
      for (var i = 0; i < leads.length; i++) {
        final leadFeatured = leads[i].priority >= kAlwaysShowPriority;
        if (mFeatured && !leadFeatured) continue;
        final fold = (mFeatured && leadFeatured) ? foldPxFeatured : foldPx;
        final d = (leads[i].screen - m.screen).distance;
        if (d < fold && d < hostDist) {
          hostDist = d;
          hostIdx = i;
        }
      }
      if (hostIdx == -1) {
        leads.add(m);
        memberLists.add(<_MapMarker>[m]);
      } else {
        memberLists[hostIdx].add(m);
      }
    }

    return [
      for (var i = 0; i < leads.length; i++)
        _PinCluster(leads[i], memberLists[i]),
    ];
  }

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
    _recomputeVisibleMarkers();
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
    // OSM often carries the same anchor name on more than one feature (a
    // polygon *and* a node for "Sigiriya", say). Keep only the first so the
    // site doesn't sprout two identical pins/labels.
    final seenAnchors = <String>{};

    _MapMarker? anchorMarker(String name, Offset screen, _MarkerStyle style) {
      final headliner = _headlinerLandmarks.contains(name);
      final pinned = _pinnedLandmarks.contains(name);
      if ((headliner || pinned) && !seenAnchors.add(name)) return null;
      return _MapMarker(
        screen: screen,
        name: name,
        icon: _pinnedLandmarkIconOverride[name] ?? style.icon,
        color: style.color,
        priority: headliner
            ? kHeadlinerPriority
            : (pinned ? kAlwaysShowPriority : style.priority),
        pinRadius: (headliner || pinned)
            ? max(style.pinRadius, headliner ? 10 : 9)
            : style.pinRadius,
        // A named anchor is always a "Landmarks" chip result, regardless of
        // what OSM tag happened to classify it under.
        category: (headliner || pinned) ? MapCategory.landmark : style.category,
        categoryLabel: style.categoryLabel,
      );
    }

    for (final poly in data.polygons) {
      final name = poly.name;
      if (name == null || poly.rings.isEmpty) continue;
      if (_absorbedIntoCuratedStops.contains(name)) continue;
      final m = anchorMarker(
        name,
        _project(_ringCentroid(poly.rings.first), canvasSize),
        _polygonMarkerStyle(poly),
      );
      if (m != null) markers.add(m);
    }

    for (final pt in data.points) {
      final name = pt.name;
      if (name == null) continue;
      if (_absorbedIntoCuratedStops.contains(name)) continue;
      final m = anchorMarker(name, _project(pt.pos, canvasSize), _pointMarkerStyle(pt));
      if (m != null) markers.add(m);
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

    // Highest priority first so it wins the greedy fold + label passes; a
    // name tiebreak keeps the fold representative deterministic across runs.
    markers.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : a.name.compareTo(b.name);
    });
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

    // Tap target is a constant ~20 screen px: divide by the live zoom so a
    // zoomed-out map (tiny pins) is still comfortably tappable.
    final rawScale = _transformController.value.getMaxScaleOnAxis();
    final scale = rawScale <= 0 ? 1.0 : rawScale;
    final hitRadius = (20.0 / scale).clamp(6.0, 60.0);

    // Hit-test the folded pins actually on screen, not every raw marker, so a
    // tap in a dense spot lands on the stack that's drawn there.
    _PinCluster? nearest;
    var nearestDist = double.infinity;
    for (final c in _clustersFor(_quantiseScale(rawScale))) {
      final d = (c.lead.screen - details.localPosition).distance;
      if (d < hitRadius && d < nearestDist) {
        nearest = c;
        nearestDist = d;
      }
    }
    if (nearest == null) return;
    if (nearest.isStack) {
      _showClusterSheet(nearest);
    } else {
      _showPoiSheet(nearest.lead);
    }
  }

  /// Tapped a pin that stands in for several overlapping places — list them so
  /// nothing folded away is unreachable. Ordered strongest-first (as on the
  /// map); each row opens that place's own sheet.
  void _showClusterSheet(_PinCluster cluster) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                '${cluster.members.length} places here',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textBase,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'Too close together to show separately — zoom in on the map to '
                'spread them out.',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: cluster.members.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final m = cluster.members[i];
                  return ListTile(
                    leading: Icon(m.icon, color: m.color),
                    title: Text(
                      m.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppTheme.textBase),
                    ),
                    subtitle: m.categoryLabel == null
                        ? null
                        : Text(
                            m.categoryLabel!,
                            style: const TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 0.5,
                                color: AppTheme.secondary),
                          ),
                    onTap: () {
                      Navigator.pop(context);
                      _showPoiSheet(m);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
          onSelect: _selectCategory,
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
                          // Rebuilds as the map is zoomed (not panned — the
                          // scale is quantised so a pan, which leaves it
                          // unchanged, repaints nothing) so the label pass can
                          // size itself in screen pixels and reveal more names
                          // as you zoom into a cluster.
                          child: AnimatedBuilder(
                            animation: _transformController,
                            builder: (context, _) {
                              final scale = _quantiseScale(_transformController
                                  .value
                                  .getMaxScaleOnAxis());
                              return CustomPaint(
                                size: _canvasSize,
                                painter: _VectorMapPainter(
                                  data: widget.data,
                                  canvasSize: _canvasSize,
                                  clusters: _clustersFor(scale),
                                  elephantZones: _elephantZones,
                                  viewScale: scale,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
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

  /// Pins to draw — already folded (see [_VectorMapState._buildClusters]) so
  /// there is exactly one entry per on-screen pin, not one per raw POI.
  final List<_PinCluster> clusters;
  final List<_ProjectedElephantZone> elephantZones;

  /// Current pinch-zoom scale of the enclosing [InteractiveViewer]. Pin and
  /// label sizes are divided by this so they stay a constant on-screen size
  /// instead of ballooning, and the "another label is too close" test tightens
  /// as you zoom in — revealing more names in a dense cluster.
  final double viewScale;

  const _VectorMapPainter({
    required this.data,
    required this.canvasSize,
    required this.clusters,
    required this.elephantZones,
    this.viewScale = 1.0,
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
    // full pins (with icon + label) in the marker pass below. Skip a context
    // dot that a real pin is already sitting on — it only adds speckle around
    // a cluster.
    final dotClear = 9.0 / (viewScale <= 0 ? 1.0 : viewScale);
    for (final pt in data.points) {
      if (pt.name != null) continue;
      final o = _project(pt.pos);
      if (clusters.any((c) => (c.lead.screen - o).distance < dotClear)) continue;
      _paintUnnamedDot(canvas, pt);
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

  /// Draws one pin per folded cluster (see [_VectorMapState._buildClusters]),
  /// then a second, priority-ordered pass that labels as many as read cleanly:
  ///
  ///  * Pin and label sizes are screen-pixel values divided by [viewScale], so
  ///    they stay a constant on-screen size at any zoom instead of ballooning,
  ///    and the whole pass re-runs (via `shouldRepaint`) each zoom change.
  ///  * A name is skipped when another already-labelled pin sits within a
  ///    minimum screen-pixel gap of it. Because that gap is in *screen*
  ///    pixels, zooming into a cluster spreads its pins apart and the
  ///    suppressed names appear one by one — real-map behaviour.
  ///  * Ordinary (non must-see) names also share a budget that grows with
  ///    zoom, so Food / All don't try to print forty labels at once.
  ///
  /// Anything that doesn't get a label is still a pin you can tap. No leader
  /// lines — every drawn label sits directly against its own pin.
  void _paintMarkersWithLabels(Canvas canvas) {
    final s = viewScale <= 0 ? 1.0 : viewScale;
    final invS = 1.0 / s;
    // Keep pins near a constant on-screen size, but don't let them shrink to
    // nothing when deeply zoomed in or bloat when zoomed right out.
    final pinScale = invS.clamp(0.65, 1.7);

    final pinRects = <Rect>[];
    for (final c in clusters) {
      _drawPin(canvas, c.lead, stacked: c.isStack, pinScale: pinScale);
      pinRects.add(Rect.fromCircle(
        center: c.lead.screen,
        radius: c.lead.pinRadius * pinScale + 2,
      ));
    }

    // Minimum clear space between two *labelled* pins, in screen px → canvas
    // units. Landmark names run long ("Boulder Gardens & Cobra Hood Cave"), so
    // this is generous — better to show four landmark labels cleanly and let
    // the rest come in on zoom than cram ten on top of each other.
    final minGap = 52.0 * invS;
    final minGapFeatured = 46.0 * invS;

    final placedLabelRects = <Rect>[];
    final labelledPoints = <Offset>[];
    var budget = (16 * s).round();
    if (budget < 16) budget = 16;
    if (budget > 70) budget = 70;

    for (final c in clusters) {
      final m = c.lead;
      final featured = m.priority >= kAlwaysShowPriority;
      final gate = featured ? minGapFeatured : minGap;

      if (labelledPoints.any((p) => (p - m.screen).distance < gate)) continue;
      if (!featured && budget <= 0) continue;

      if (_tryDrawLabel(canvas, m, pinRects, placedLabelRects, invS, pinScale)) {
        labelledPoints.add(m.screen);
        if (!featured) budget--;
      }
    }
  }

  void _drawPin(Canvas canvas, _MapMarker m,
      {bool stacked = false, double pinScale = 1.0}) {
    final featured = m.priority >= kAlwaysShowPriority;
    final r = m.pinRadius * pinScale;

    // "More than one place here" hint: a ghost pin peeking out behind, so a
    // folded group reads as a stack of cards — no number badge.
    if (stacked) {
      final backCenter = m.screen + Offset(r * 0.62, r * 0.62);
      canvas.drawCircle(backCenter, r, Paint()..color = Colors.white);
      canvas.drawCircle(
        backCenter,
        r,
        Paint()
          ..color = m.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * pinScale,
      );
      canvas.drawCircle(backCenter, r * 0.5, Paint()..color = m.color.withOpacity(0.55));
    }

    if (featured) {
      // Soft white halo so the must-see Sigiriya landmarks read as clearly
      // more important than the surrounding category-coloured dots/pins.
      canvas.drawCircle(m.screen, r + 3.5 * pinScale,
          Paint()..color = Colors.white.withOpacity(0.9));
    }
    canvas.drawCircle(m.screen, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      m.screen,
      r,
      Paint()
        ..color = m.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (featured ? 2.4 : 1.7) * pinScale,
    );
    canvas.drawCircle(m.screen, r * 0.68, Paint()..color = m.color);
    if (r >= 6) {
      _drawIconGlyph(canvas, m.screen, m.icon, r * 1.15, Colors.white);
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

  /// Tries to place [m]'s name in one of a few slots hugging its own pin,
  /// each sized in screen pixels (`* invS` → canvas units). Paints and
  /// returns true on the first slot clear of every pin and every label
  /// already placed; returns false (caller leaves it pin-only) if none fits.
  bool _tryDrawLabel(
    Canvas canvas,
    _MapMarker m,
    List<Rect> pinRects,
    List<Rect> placedLabelRects,
    double invS,
    double pinScale,
  ) {
    final featured = m.priority >= kAlwaysShowPriority;
    final bold = m.priority >= 4;
    final tp = TextPainter(
      text: TextSpan(
        text: m.name,
        style: TextStyle(
          fontSize: (featured ? 12.5 : (bold ? 12.0 : 10.5)) * invS,
          fontWeight: featured
              ? FontWeight.w800
              : (bold ? FontWeight.w700 : FontWeight.w600),
          color: AppTheme.textBase,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: (featured ? 168.0 : 128.0) * invS);

    final hPad = 6.0 * invS, vPad = 3.0 * invS, gap = 6.0 * invS;
    final labelW = tp.width + hPad * 2;
    final labelH = tp.height + vPad * 2;
    final cx = m.screen.dx, cy = m.screen.dy, r = m.pinRadius * pinScale;
    final maxRight = canvasSize.width - 2;
    final maxBottom = canvasSize.height - 2;

    // Slots that touch the pin, best first: right, left, above, below — plus
    // the four diagonals for must-see landmarks so they try harder before
    // giving up. Never far enough to need a leader line.
    final candidates = <Offset>[
      Offset(cx + r + gap, cy - labelH / 2),
      Offset(cx - r - gap - labelW, cy - labelH / 2),
      Offset(cx - labelW / 2, cy - r - gap - labelH),
      Offset(cx - labelW / 2, cy + r + gap),
      if (featured) ...[
        Offset(cx + r + gap, cy - r - gap - labelH),
        Offset(cx + r + gap, cy + r + gap),
        Offset(cx - r - gap - labelW, cy - r - gap - labelH),
        Offset(cx - r - gap - labelW, cy + r + gap),
      ],
    ];

    for (final o in candidates) {
      final rect = Rect.fromLTWH(o.dx, o.dy, labelW, labelH);
      if (rect.left < 2 ||
          rect.top < 2 ||
          rect.right > maxRight ||
          rect.bottom > maxBottom) {
        continue;
      }
      if (pinRects.any((p) => p.overlaps(rect))) continue;
      if (placedLabelRects.any((p) => p.overlaps(rect))) continue;

      placedLabelRects.add(rect);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(5 * invS));
      canvas.drawRRect(
        rrect,
        Paint()..color = Colors.white.withOpacity(featured ? 0.94 : 0.82),
      );
      if (featured) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = m.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * invS,
        );
      }
      tp.paint(canvas, Offset(rect.left + hPad, rect.top + vPad));
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) =>
      !identical(oldDelegate.clusters, clusters) ||
      oldDelegate.viewScale != viewScale;
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

