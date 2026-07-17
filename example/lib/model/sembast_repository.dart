import 'package:background_task_example/model/lat_lng.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

class SembastRepository {
  SembastRepository._();

  static final StoreRef<int, Map<String, Object?>> _store =
      intMapStoreFactory.store('latLngs');

  static Database? _database;
  static Future<Database>? _openingDatabase;

  static Future<void> configure() async {
    await _getDatabase();
  }

  static Future<int> add(LatLng latLng) async {
    final database = await _getDatabase();
    return _store.add(database, latLng.toMap());
  }

  static Future<List<LatLng>> find({
    int offset = 0,
    required int limit,
  }) async {
    final database = await _getDatabase();
    final records = await _store.find(
      database,
      finder: Finder(
        offset: offset,
        limit: limit,
        sortOrders: [SortOrder('createdAt', false)],
      ),
    );
    return records
        .map((record) => LatLng.fromMap(record.key, record.value))
        .toList();
  }

  static Future<void> clear() async {
    final database = await _getDatabase();
    await _store.delete(database);
  }

  static Future<Database> _getDatabase() async {
    final database = _database;
    if (database != null) {
      return database;
    }

    final openingDatabase = _openingDatabase;
    if (openingDatabase != null) {
      return openingDatabase;
    }

    final newOpeningDatabase = _openDatabase();
    _openingDatabase = newOpeningDatabase;
    try {
      return _database = await newOpeningDatabase;
    } finally {
      _openingDatabase = null;
    }
  }

  static Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    final databasePath = p.join(directory.path, 'background_task.db');
    return databaseFactoryIo.openDatabase(databasePath);
  }
}
