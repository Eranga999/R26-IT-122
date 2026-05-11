import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CacheEntry {
  final String key;
  final String answer;
  final List<double> queryEmbedding;
  final DateTime createdAt;

  CacheEntry({
    required this.key,
    required this.answer,
    required this.queryEmbedding,
    required this.createdAt,
  });
}

class SemanticCache {
  static SemanticCache? _instance;
  Database? _db;

  // Mirrors Python: CACHE_SIM_THRESHOLD = 0.92
  static const double _simThreshold = 0.92;

  SemanticCache._();
  factory SemanticCache() => _instance ??= SemanticCache._();

  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'sigiriya_cache.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cache (
            key       TEXT PRIMARY KEY,
            answer    TEXT NOT NULL,
            embedding TEXT NOT NULL,
            created   TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Get cached answer — checks exact key first, then semantic similarity.
  /// Returns (answer, hitType) where hitType is 'exact', 'semantic', or null.
  Future<(String?, String?)> get(String place, String mode) async {
    final key = _makeKey(place, mode);

    // ── Exact match (fast) ────────────────────────────────────────
    final rows = await _db!.query(
      'cache',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isNotEmpty) {
      return (rows.first['answer'] as String, 'exact');
    }

    return (null, null);
  }

  /// Semantic similarity lookup — call with current query embedding.
  Future<(String?, String?)> getByEmbedding(
    List<double> queryEmbedding,
    String mode,
  ) async {
    // Load all entries for this mode
    final rows = await _db!.query('cache');

    String? bestAnswer;
    double  bestScore = _simThreshold;

    for (final row in rows) {
      final key = row['key'] as String;
      if (!key.endsWith('::$mode')) continue;

      final embStr = row['embedding'] as String;
      final emb    = embStr.split(',').map(double.parse).toList();
      final score  = _cosine(queryEmbedding, emb);

      if (score > bestScore) {
        bestScore  = score;
        bestAnswer = row['answer'] as String;
      }
    }

    if (bestAnswer != null) {
      return (bestAnswer, 'semantic');
    }
    return (null, null);
  }

  /// Save answer to cache.
  Future<void> set(
    String place,
    String mode,
    String answer,
    List<double> embedding,
  ) async {
    final key    = _makeKey(place, mode);
    final embStr = embedding.map((v) => v.toStringAsFixed(6)).join(',');

    await _db!.insert(
      'cache',
      {
        'key':      key,
        'answer':   answer,
        'embedding': embStr,
        'created':  DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> get size async {
    final result = await _db!.rawQuery('SELECT COUNT(*) as c FROM cache');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> clear() async {
    await _db!.delete('cache');
  }

  String _makeKey(String place, String mode) =>
      '${place.toLowerCase().trim()}::$mode';

  double _cosine(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    final len = min(a.length, b.length);
    for (int i = 0; i < len; i++) {
      dot += a[i] * b[i];
      na  += a[i] * a[i];
      nb  += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
    _instance = null;
  }
}
