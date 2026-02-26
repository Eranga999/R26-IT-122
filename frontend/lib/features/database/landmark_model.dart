/// Represents a heritage landmark stored in the SQLite database.
class LandmarkModel {
  final int? id;
  final String name;

  /// Short one-paragraph overview shown in list cards.
  final String description;

  /// Longer historical narrative shown in the detail screen.
  final String history;

  /// Asset path to the site's representative image, e.g. assets/images/sigiriya.jpg
  /// Empty string when no image is available yet.
  final String imagePath;

  const LandmarkModel({
    this.id,
    required this.name,
    required this.description,
    this.history = '',
    this.imagePath = '',
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory LandmarkModel.fromMap(Map<String, dynamic> map) => LandmarkModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String,
        history: (map['history'] as String?) ?? '',
        imagePath: (map['image_path'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'history': history,
        'image_path': imagePath,
      };

  @override
  String toString() => 'LandmarkModel(id: $id, name: $name)';
}
