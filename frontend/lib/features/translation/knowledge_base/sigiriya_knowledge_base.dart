import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/heritage_entry.dart';
import 'heritage_site_knowledge_base.dart';

class SigiriyaKnowledgeBase implements HeritageSiteKnowledgeBase {
  static const String datasetPath = 'assets/data/sigiriya_translation_dataset.json';

  @override
  String get siteId => 'sigiriya';

  @override
  String get siteName => 'Sigiriya Rock Fortress';

  final List<HeritageEntry> _entries = [];
  final Map<String, HeritageEntry> _idMap = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final jsonString = await rootBundle.loadString(datasetPath);
      final rawList = jsonDecode(jsonString) as List<dynamic>;

      _entries.clear();
      _idMap.clear();

      for (final raw in rawList) {
        if (raw is Map<String, dynamic>) {
          final entry = HeritageEntry.fromJson(raw);
          _entries.add(entry);
          _idMap[entry.id] = entry;
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[SigiriyaKnowledgeBase] Failed to load dataset from $datasetPath: $e');
      _isInitialized = false;
    }
  }

  /// Initialize with a custom raw list for testing or non-asset contexts.
  void initializeWithList(List<Map<String, dynamic>> rawList) {
    _entries.clear();
    _idMap.clear();

    for (final raw in rawList) {
      final entry = HeritageEntry.fromJson(raw);
      _entries.add(entry);
      _idMap[entry.id] = entry;
    }

    _isInitialized = true;
  }

  @override
  List<HeritageEntry> getAllEntries() => List.unmodifiable(_entries);

  @override
  HeritageEntry? findById(String id) => _idMap[id];
}
