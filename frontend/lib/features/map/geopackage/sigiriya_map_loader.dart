import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'gpkg_geometry.dart';

/// The clipped extent this map renders — matches the export's own bounding
/// box (planet_80.7281,7.9355_80.7919,7.9745), which covers Sigiriya +
/// Pidurangala with the widest east-west span of the extracts evaluated
/// (verified to still contain Pidurangala Rock/Vihara and every curated
/// trail anchor — see docs/sigiriya_poi_dataset.md). The GeoPackage's own
/// gpkg_contents extent is wider still (a metadata quirk of the export), so
/// features are clipped to this box rather than trusted at face value.
const double kMapMinLon = 80.7281;
const double kMapMinLat = 7.9355;
const double kMapMaxLon = 80.7919;
const double kMapMaxLat = 7.9745;

// Small padding so features straddling the edge (e.g. a road) aren't dropped
// just because one vertex falls a few metres outside the box.
const double _pad = 0.006;

bool _inBounds(GeoPoint p) =>
    p.lon >= kMapMinLon - _pad &&
    p.lon <= kMapMaxLon + _pad &&
    p.lat >= kMapMinLat - _pad &&
    p.lat <= kMapMaxLat + _pad;

bool _anyInBounds(List<GeoPoint> pts) => pts.any(_inBounds);

class MapPointFeature {
  final GeoPoint pos;
  final String? name;
  final String? category;
  final String? otherTags;
  const MapPointFeature({
    required this.pos,
    this.name,
    this.category,
    this.otherTags,
  });
}

class MapLineFeature {
  final List<GeoPoint> points;
  final String? name;
  final String? highway;
  final String? waterway;
  const MapLineFeature(
      {required this.points, this.name, this.highway, this.waterway});
}

class MapPolygonFeature {
  final List<List<GeoPoint>> rings;
  final String? name;
  final String? natural;
  final String? landuse;
  final String? building;
  final String? tourism;
  final String? historic;
  final String? amenity;
  final String? shop;
  const MapPolygonFeature({
    required this.rings,
    this.name,
    this.natural,
    this.landuse,
    this.building,
    this.tourism,
    this.historic,
    this.amenity,
    this.shop,
  });
}

class SigiriyaMapData {
  final List<MapPointFeature> points;
  final List<MapLineFeature> lines;
  final List<MapPolygonFeature> polygons;
  const SigiriyaMapData({
    required this.points,
    required this.lines,
    required this.polygons,
  });
}

/// Loads the bundled Sigiriya-area OpenStreetMap extract (an OGC GeoPackage
/// at assets/vectors/sigiriya_map.gpkg) and parses it into renderable
/// features. Fully offline — the file ships in the app bundle, nothing is
/// fetched over the network.
class SigiriyaMapLoader {
  SigiriyaMapLoader._();

  static const _assetPath = 'assets/vectors/sigiriya_map.gpkg';

  static Future<SigiriyaMapData> load() async {
    final dbPath = await _copyAssetToWritablePath();
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final points = await _loadPoints(db);
      final lines = await _loadLines(db);
      final polygons = await _loadPolygons(db);
      return SigiriyaMapData(points: points, lines: lines, polygons: polygons);
    } finally {
      await db.close();
    }
  }

  /// sqflite needs a real filesystem path, not an asset key, so the bundled
  /// GeoPackage is copied into app storage on every load — cheap at ~380KB
  /// and guarantees it's never stale after an app update.
  static Future<String> _copyAssetToWritablePath() async {
    final dir = await getTemporaryDirectory();
    final file = File(join(dir.path, 'sigiriya_map.gpkg'));
    final data = await rootBundle.load(_assetPath);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  static Future<List<MapPointFeature>> _loadPoints(Database db) async {
    final rows = await db.query('points',
        columns: ['geom', 'name', 'highway', 'place', 'man_made', 'other_tags']);
    final result = <MapPointFeature>[];
    for (final row in rows) {
      final blob = row['geom'] as Uint8List?;
      if (blob == null) continue;
      GeoPoint? pt;
      try {
        pt = readPointGeometry(blob);
      } catch (_) {
        continue;
      }
      if (pt == null || !_inBounds(pt)) continue;
      final otherTags = row['other_tags'] as String?;
      final tourism = _extractTag(otherTags, 'tourism');
      final category = (row['highway'] as String?) ??
          (row['place'] as String?) ??
          (row['man_made'] as String?) ??
          tourism;
      result.add(MapPointFeature(
        pos: pt,
        name: row['name'] as String?,
        category: category,
        otherTags: otherTags,
      ));
    }
    return result;
  }

  static Future<List<MapLineFeature>> _loadLines(Database db) async {
    final rows = await db
        .query('lines', columns: ['geom', 'name', 'highway', 'waterway']);
    final result = <MapLineFeature>[];
    for (final row in rows) {
      final blob = row['geom'] as Uint8List?;
      if (blob == null) continue;
      List<GeoPoint>? pts;
      try {
        pts = readLineGeometry(blob);
      } catch (_) {
        continue;
      }
      if (pts == null || pts.isEmpty || !_anyInBounds(pts)) continue;
      result.add(MapLineFeature(
        points: pts,
        name: row['name'] as String?,
        highway: row['highway'] as String?,
        waterway: row['waterway'] as String?,
      ));
    }
    return result;
  }

  static Future<List<MapPolygonFeature>> _loadPolygons(Database db) async {
    final rows = await db.query('multipolygons', columns: [
      'geom',
      'name',
      'natural',
      'landuse',
      'building',
      'tourism',
      'historic',
      'amenity',
      'shop',
    ]);
    final result = <MapPolygonFeature>[];
    for (final row in rows) {
      final blob = row['geom'] as Uint8List?;
      if (blob == null) continue;
      List<List<GeoPoint>>? rings;
      try {
        rings = readMultiPolygonExteriorRings(blob);
      } catch (_) {
        continue;
      }
      if (rings == null || rings.isEmpty) continue;
      if (!rings.any(_anyInBounds)) continue;
      result.add(MapPolygonFeature(
        rings: rings,
        name: row['name'] as String?,
        natural: row['natural'] as String?,
        landuse: row['landuse'] as String?,
        building: row['building'] as String?,
        tourism: row['tourism'] as String?,
        historic: row['historic'] as String?,
        amenity: row['amenity'] as String?,
        shop: row['shop'] as String?,
      ));
    }
    return result;
  }

  static String? _extractTag(String? otherTags, String key) {
    if (otherTags == null) return null;
    final match = RegExp('"$key"=>"([^"]*)"').firstMatch(otherTags);
    return match?.group(1);
  }
}
