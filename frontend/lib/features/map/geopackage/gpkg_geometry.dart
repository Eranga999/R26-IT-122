import 'dart:typed_data';

/// A geographic coordinate stored as (longitude, latitude) — matches WKB's
/// x=lon, y=lat axis order for EPSG:4326 data.
class GeoPoint {
  final double lon;
  final double lat;
  const GeoPoint(this.lon, this.lat);
}

/// Cursor over a [ByteData] buffer with auto-advancing reads — needed
/// because MultiPolygon/GeometryCollection bodies embed full sub-geometries
/// (each with their own byte-order + type header) whose length isn't known
/// up front.
class _Cursor {
  final ByteData data;
  int pos;
  _Cursor(this.data, this.pos);

  int _u8() {
    final v = data.getUint8(pos);
    pos += 1;
    return v;
  }

  int _u32(Endian e) {
    final v = data.getUint32(pos, e);
    pos += 4;
    return v;
  }

  double _f64(Endian e) {
    final v = data.getFloat64(pos, e);
    pos += 8;
    return v;
  }
}

GeoPoint _readPointBody(_Cursor c, Endian e) => GeoPoint(c._f64(e), c._f64(e));

List<GeoPoint> _readLineStringBody(_Cursor c, Endian e) {
  final n = c._u32(e);
  return List.generate(n, (_) => _readPointBody(c, e));
}

/// Rings of a single Polygon body — ring 0 is the exterior, any further
/// rings are holes (holes are ignored by callers; this map is informational,
/// not a precise cadastral rendering).
List<List<GeoPoint>> _readPolygonBody(_Cursor c, Endian e) {
  final numRings = c._u32(e);
  return List.generate(numRings, (_) => _readLineStringBody(c, e));
}

/// Reads one full WKB geometry (its own byte-order + type header included),
/// dispatching on type. Handles the base 2D types plus their Multi/Collection
/// wrappers, which is everything ogr2ogr's OSM->GeoPackage export produces.
dynamic _readWkbGeometry(_Cursor c) {
  final byteOrder = c._u8();
  final e = byteOrder == 1 ? Endian.little : Endian.big;
  // ISO WKB adds 1000/2000/3000 for Z/M/ZM variants; this export is 2D-only
  // but mask defensively so an unexpected Z/M flag doesn't misroute us.
  final type = c._u32(e) % 1000;
  switch (type) {
    case 1:
      return _readPointBody(c, e);
    case 2:
      return _readLineStringBody(c, e);
    case 3:
      return _readPolygonBody(c, e);
    case 4:
      final n = c._u32(e);
      return List.generate(n, (_) => _readWkbGeometry(c) as GeoPoint);
    case 5:
      final n = c._u32(e);
      return List.generate(n, (_) => _readWkbGeometry(c) as List<GeoPoint>);
    case 6:
      final n = c._u32(e);
      return List.generate(
          n, (_) => _readWkbGeometry(c) as List<List<GeoPoint>>);
    case 7:
      final n = c._u32(e);
      return List.generate(n, (_) => _readWkbGeometry(c));
    default:
      throw FormatException('Unsupported WKB geometry type $type');
  }
}

/// Envelope size in bytes for each GeoPackage "envelope contents indicator"
/// code (GeoPackage spec §2.1.3) — only the byte count matters since callers
/// never need the envelope values, just to skip past them.
const Map<int, int> _envelopeBytes = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64};

/// Parses a GeoPackage geometry BLOB (GP header + standard WKB body) into
/// GeoPoint / List&lt;GeoPoint&gt; / List&lt;List&lt;GeoPoint&gt;&gt; depending on the
/// underlying WKB type. Returns null for an empty geometry.
dynamic parseGeoPackageGeometry(Uint8List blob) {
  if (blob.length < 8 || blob[0] != 0x47 || blob[1] != 0x50) {
    throw const FormatException('Not a GeoPackage geometry blob');
  }
  final flags = blob[3];
  final isEmpty = (flags & 0x10) != 0;
  if (isEmpty) return null;
  final envelopeCode = (flags >> 1) & 0x07;
  final envSize = _envelopeBytes[envelopeCode] ?? 0;
  final wkbOffset = 8 + envSize;
  final data = ByteData.sublistView(blob);
  return _readWkbGeometry(_Cursor(data, wkbOffset));
}

GeoPoint? readPointGeometry(Uint8List blob) =>
    parseGeoPackageGeometry(blob) as GeoPoint?;

List<GeoPoint>? readLineGeometry(Uint8List blob) =>
    parseGeoPackageGeometry(blob) as List<GeoPoint>?;

/// Exterior ring of every polygon part in a MultiPolygon geometry — holes are
/// dropped (see [_readPolygonBody]).
List<List<GeoPoint>>? readMultiPolygonExteriorRings(Uint8List blob) {
  final parsed = parseGeoPackageGeometry(blob);
  if (parsed == null) return null;
  final polygons = parsed as List<List<List<GeoPoint>>>;
  return [
    for (final rings in polygons)
      if (rings.isNotEmpty) rings.first,
  ];
}
