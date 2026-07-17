class LatLng {
  LatLng({
    this.id = 0,
    required this.lat,
    required this.lng,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory LatLng.fromMap(int id, Map<String, Object?> map) {
    return LatLng(
      id: id,
      lat: (map['lat']! as num).toDouble(),
      lng: (map['lng']! as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']! as int),
    );
  }

  final int id;
  final double lat;
  final double lng;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
