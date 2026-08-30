import '../models/heritage_entry.dart';

abstract class HeritageSiteKnowledgeBase {
  String get siteId;
  String get siteName;

  Future<void> initialize();
  List<HeritageEntry> getAllEntries();
  HeritageEntry? findById(String id);
}
