/// Represents a notable sub-feature inside a main heritage landmark.
class SubLandmarkModel {
  final int? id;
  final int landmarkId;
  final String name;
  final String description;

  /// Category: e.g. "fresco", "gate", "pool", "sculpture", "cave", "stupa"
  final String type;

  const SubLandmarkModel({
    this.id,
    required this.landmarkId,
    required this.name,
    required this.description,
    required this.type,
  });

  factory SubLandmarkModel.fromMap(Map<String, dynamic> m) => SubLandmarkModel(
        id: m['id'] as int?,
        landmarkId: m['landmark_id'] as int,
        name: m['name'] as String,
        description: m['description'] as String,
        type: m['type'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'landmark_id': landmarkId,
        'name': name,
        'description': description,
        'type': type,
      };

  @override
  String toString() =>
      'SubLandmarkModel(id: $id, landmarkId: $landmarkId, name: $name, type: $type)';
}
