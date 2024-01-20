import 'package:background_task_example/model/lat_lng.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class IsarRepository {
  IsarRepository._();

  static Isar get isar => _isar!;

  static Isar? _isar;

  static Future<void> configure() async {
    if (_isar != null) {
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [LatLngSchema],
      directory: dir.path,
    );
  }
}
