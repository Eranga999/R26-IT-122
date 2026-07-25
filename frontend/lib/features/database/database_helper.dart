import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';
import 'landmark_model.dart';
import 'sub_landmark_model.dart';

/// Singleton SQLite helper for HeritageAR.
///
/// Schema version 2 adds [history] and [image_path] to the [landmarks]
/// table and introduces a new [sub_landmarks] table.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedLandmarks(db);
    await _seedSubLandmarks(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS ${AppConstants.subLandmarksTable}');
    await db.execute('DROP TABLE IF EXISTS ${AppConstants.landmarksTable}');
    await _createTables(db);
    await _seedLandmarks(db);
    await _seedSubLandmarks(db);
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.landmarksTable} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        description TEXT NOT NULL,
        history     TEXT NOT NULL DEFAULT '',
        image_path  TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.subLandmarksTable} (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        landmark_id INTEGER NOT NULL,
        name        TEXT NOT NULL,
        description TEXT NOT NULL,
        type        TEXT NOT NULL DEFAULT 'site',
        FOREIGN KEY (landmark_id) REFERENCES ${AppConstants.landmarksTable}(id)
      )
    ''');
  }

  Future<void> _seedLandmarks(Database db) async {
    final batch = db.batch();

    batch.insert(AppConstants.landmarksTable, {
      'name': 'Sigiriya',
      'description':
          'Sigiriya, or Lion Rock, is a 5th-century rock fortress rising '
          '200 metres above the central plains of Sri Lanka. King Kassapa I '
          'built his palace atop this sheer granite column between 477–495 AD, '
          'surrounded by elaborate gardens, water features, and vivid frescoes.',
      'history':
          'Sigiriya was constructed by King Kassapa I (477–495 AD) after '
          'he seized the throne by entombing his father King Dhatusena. Fearing '
          'retaliation from his brother Moggallana, Kassapa chose the impregnable '
          'rock as his new capital and palace. He transformed the entire summit '
          'into a royal citadel with a lion-shaped gateway, mirror-polished walls '
          'adorned with poetry, and beautiful frescoes of celestial maidens. After '
          'Kassapa\'s death in battle against Moggallana in 495 AD, the site '
          'became a Buddhist monastery for over a thousand years. Today, Sigiriya '
          'is Sri Lanka\'s most visited cultural monument and a UNESCO World '
          'Heritage Site since 1982, recognised as one of the best-preserved '
          'examples of ancient urban planning in South Asia.',
      'image_path': 'assets/images/sigiriya.jpg',
    });

    batch.insert(AppConstants.landmarksTable, {
      'name': 'Dambulla Cave Temple',
      'description':
          'The Dambulla Cave Temple is Sri Lanka\'s largest and best-preserved '
          'cave temple complex, featuring five cavernous sanctuaries containing '
          '157 statues of the Buddha and murals covering over 2,100 square metres.',
      'history':
          'The Dambulla Cave Temple has been a sacred Buddhist site for over '
          '2,000 years. King Valagamba took refuge here in the 1st century BC '
          'after being driven from Anuradhapura by South Indian invaders. Upon '
          'reclaiming his throne, he converted the natural caves into magnificent '
          'rock temples. Over successive centuries, kings including Nissanka Malla '
          '(12th century) and Kirti Sri Rajasimha (18th century) enriched the caves '
          'with new statues and repainted the murals. The temple ceilings and walls '
          'are covered entirely in paintings depicting the life of the Buddha and '
          'the Jataka stories. Designated a UNESCO World Heritage Site in 1991, '
          'it remains an active place of worship visited by pilgrims annually.',
      'image_path': 'assets/images/dambulla.jpg',
    });

    batch.insert(AppConstants.landmarksTable, {
      'name': 'Polonnaruwa',
      'description':
          'Polonnaruwa was Sri Lanka\'s capital during the 11th and 12th centuries '
          'and is now one of the best-preserved ancient cities in Asia, showcasing '
          'the architectural and irrigation genius of the medieval Sinhalese kingdom.',
      'history':
          'Polonnaruwa rose to prominence when King Vijayabahu I defeated the Chola '
          'invaders in 1070 AD and established it as the new capital of Sri Lanka. '
          'The city reached its golden age under Parakramabahu I (1153–1186 AD), '
          'who constructed the Parakrama Samudra reservoir, palaces, temples, and '
          'the iconic Gal Vihara rock sculptures. His reign is remembered for the '
          'decree that "not a single drop of rain should be allowed to fall into the '
          'sea without being useful to man." After his death, successive invasions '
          'led to the gradual abandonment of the city. Rediscovered in the 19th '
          'century, Polonnaruwa was inscribed as a UNESCO World Heritage Site in '
          '1982 as part of the Cultural Triangle of Sri Lanka.',
      'image_path': 'assets/images/polonnaruwa.jpg',
    });

    await batch.commit(noResult: true);
  }

  Future<void> _seedSubLandmarks(Database db) async {
    final batch = db.batch();

    // Sigiriya sub-landmarks (landmark_id = 1) — 7 UNESCO-quality entries
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Ticket & Visitor Centre',
      'description':
          'The official entry point to the Sigiriya World Heritage Site. '
          'Admission: LKR 5,000 for adults / USD 30 for foreign nationals. '
          'Open daily 7:00 am – 5:30 pm. Facilities include a shaded rest area, '
          'drinking water, souvenir stalls, and an information centre with maps '
          'and audio guides for the full site circuit.',
      'type': 'site',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Lion Gate (Lion Paws)',
      'description':
          'The dramatic entrance to Sigiriya\'s summit stairway is flanked by '
          'two colossal brick-and-plaster lion\'s paws — the only surviving remnants '
          'of a full lion sculpture that once formed the gateway. Visitors pass '
          'between the ancient claws to begin the steep final ascent to the palace '
          'plateau. The lion symbolised King Kassapa\'s power and divine authority.',
      'type': 'gate',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Mirror Wall',
      'description':
          'Running along the western face of the rock, this plaster wall was '
          'once polished so finely that King Kassapa could see his reflection. '
          'Over seven centuries of visitors inscribed 685+ graffiti poems on its '
          'surface — the oldest surviving collection of Sinhala poetry in the world, '
          'dating from the 6th to 14th centuries AD.',
      'type': 'wall',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Water Gardens',
      'description':
          'Considered the oldest landscaped garden in Asia, the Water Gardens '
          'feature three distinct zones of symmetrical pools, serpentine moats, '
          'underground hydraulic pipes, and seasonal fountains that still operate '
          'naturally during the rainy season — a 1,500-year-old masterpiece '
          'of hydraulic engineering.',
      'type': 'pool',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Boulder Gardens',
      'description':
          'Between the Water Gardens and the Lion Gate lie the Boulder Gardens — '
          'massive natural granite boulders forming terraces, cisterns, and caves. '
          'These outworks served as defensive positions and were later occupied '
          'by Buddhist monks; ancient cave inscriptions and drip-ledges (used to '
          'divert rain) are still visible on many boulders.',
      'type': 'cave',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Fresco Gallery',
      'description':
          'Sheltered in a natural rock pocket half-way up the cliff, 22 vivid '
          'apsara (celestial maiden) paintings have survived from an original 500. '
          'Applied on lime plaster using natural pigments, the murals depict '
          'heavenly figures emerging from clouds, still luminous after 1,500 years. '
          'A spiral iron staircase provides access to the gallery alcove.',
      'type': 'fresco',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 1,
      'name': 'Summit Palace',
      'description':
          'Crowning the 200-metre granite plateau, the ruins of King Kassapa\'s '
          'royal residence include brick foundations, a royal bathing pool cut '
          'into the bedrock, cisterns, throne platforms, and audience halls. '
          'The summit commands a 360-degree panorama of jungle, plains, and distant '
          'water bodies — unchanged since the 5th century AD.',
      'type': 'palace',
    });

    // Dambulla sub-landmarks (landmark_id = 2)
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 2,
      'name': 'Cave 1 – Devaraja Viharaya',
      'description':
          'The Cave of the Divine King contains a 15-metre reclining Buddha '
          'carved from natural rock. A wooden structure around the feet depicts '
          'the Parinirvana scene. Smaller images of seated Buddhas, Vishnu, and '
          'Saman also reside within this intimate cave.',
      'type': 'cave',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 2,
      'name': 'Cave 2 – Maharaja Viharaya',
      'description':
          'The largest and most impressive cave of Dambulla contains over 150 '
          'Buddha statues and murals covering approximately 2,100 square feet. '
          'Statues of kings Nissanka Malla and Valagamba stand alongside Buddhist '
          'imagery in this grand rock sanctuary.',
      'type': 'cave',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 2,
      'name': 'Cave 3 – Maha Alut Viharaya',
      'description':
          'Built under King Kirti Sri Rajasimha in the 18th century, this cave '
          'contains 50 gilt Buddha statues and a large reclining Buddha. Windows '
          'cut into the front wall allow natural light to illuminate the golden '
          'statues and intricate ceiling murals.',
      'type': 'cave',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 2,
      'name': 'Cave 4 – Pachima Viharaya',
      'description':
          'The smallest of the working caves houses around 10 sealed Buddha '
          'statues and a central dagoba said to contain a jewel belonging to '
          'Queen Somawathie. The cave was broken into by thieves in the early '
          '20th century but remains an active daily shrine.',
      'type': 'cave',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 2,
      'name': 'Cave 5 – Devana Alut Viharaya',
      'description':
          'The newest addition to Dambulla, added in the 18th century, '
          'contains a reclining Buddha alongside statues of Hindu deities '
          'including Vishnu and Kataragama, reflecting the coexistence of '
          'Buddhism and Hinduism in Sri Lankan worship.',
      'type': 'cave',
    });

    // Polonnaruwa sub-landmarks (landmark_id = 3)
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 3,
      'name': 'Gal Vihara',
      'description':
          'Carved under King Parakramabahu I, Gal Vihara features four colossal '
          'figures from a single granite face: a seated meditating Buddha, a '
          'standing 7-metre Buddha, a 14-metre reclining Parinirvana Buddha, and '
          'a smaller seated figure in a chamber. It is the pinnacle of Sri Lankan '
          'stone-carving artistry.',
      'type': 'sculpture',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 3,
      'name': 'Vatadage',
      'description':
          'A circular relic house built on a two-tiered terrace, the Vatadage '
          'enshrines a small dagoba surrounded by four seated Buddha statues. '
          'It is celebrated for its exquisitely carved moonstone — one of the '
          'finest examples in Sri Lanka — and elaborate guard-stone reliefs.',
      'type': 'stupa',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 3,
      'name': 'Rankot Vihara',
      'description':
          'The largest stupa in Polonnaruwa, standing 55 metres high, was built '
          'by King Nissanka Malla (1187–1196 AD) in the tradition of the great '
          'stupas of Anuradhapura. Its name means "Golden Pinnacle Vihara" and '
          'its base is surrounded by four entrance gopuras (gateways).',
      'type': 'stupa',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 3,
      'name': 'Lankatilaka',
      'description':
          'A towering image house built by Parakramabahu I, Lankatilaka\'s walls '
          'soar over 17 metres high and enclose a colossal 18-metre headless brick '
          'Buddha whose head collapsed in an earthquake. The exterior walls are '
          'decorated with fine bas-reliefs of gods and celestial beings.',
      'type': 'temple',
    });
    batch.insert(AppConstants.subLandmarksTable, {
      'landmark_id': 3,
      'name': 'Parakrama Samudra',
      'description':
          'The vast "Sea of Parakrama" reservoir was constructed by Parakramabahu I '
          'to ensure no raindrop was wasted. Covering 2,500 hectares with an '
          '84-km bund, it is still the largest ancient irrigation reservoir in '
          'Sri Lanka and a monument to medieval hydraulic engineering.',
      'type': 'reservoir',
    });

    await batch.commit(noResult: true);
  }

  // CRUD: Landmarks

  Future<List<LandmarkModel>> getAllLandmarks() async {
    final db = await database;
    final maps = await db.query(AppConstants.landmarksTable);
    return maps.map(LandmarkModel.fromMap).toList();
  }

  Future<LandmarkModel?> getLandmarkById(int id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.landmarksTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LandmarkModel.fromMap(maps.first);
  }

  Future<LandmarkModel?> getLandmarkByName(String name) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.landmarksTable,
      where: 'LOWER(name) LIKE LOWER(?)',
      whereArgs: ['%$name%'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LandmarkModel.fromMap(maps.first);
  }

  Future<int> insertLandmark(LandmarkModel landmark) async {
    final db = await database;
    return db.insert(AppConstants.landmarksTable, landmark.toMap());
  }

  Future<int> updateLandmark(LandmarkModel landmark) async {
    final db = await database;
    return db.update(
      AppConstants.landmarksTable,
      landmark.toMap(),
      where: 'id = ?',
      whereArgs: [landmark.id],
    );
  }

  Future<int> deleteLandmark(int id) async {
    final db = await database;
    return db.delete(
      AppConstants.landmarksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD: Sub-Landmarks

  Future<List<SubLandmarkModel>> getSubLandmarks(int landmarkId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.subLandmarksTable,
      where: 'landmark_id = ?',
      whereArgs: [landmarkId],
    );
    return maps.map(SubLandmarkModel.fromMap).toList();
  }

  Future<int> insertSubLandmark(SubLandmarkModel sub) async {
    final db = await database;
    return db.insert(AppConstants.subLandmarksTable, sub.toMap());
  }

  Future<int> deleteSubLandmark(int id) async {
    final db = await database;
    return db.delete(
      AppConstants.subLandmarksTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
