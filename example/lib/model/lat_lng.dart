import 'package:isar/isar.dart';

part 'lat_lng.g.dart';

@collection
@Name('LatLng')
class LatLng {
  Id id = Isar.autoIncrement;
  double lat = 0;
  double lng = 0;
  @Index()
  DateTime createdAt = DateTime.now();
}
