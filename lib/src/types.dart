/// `Location` is a type representing latitude and longitude.
typedef Location = ({double? lat, double? lng});

/// `StatusEvent` is a type representing a status event.
typedef StatusEvent = ({StatusEventType status, String? message});

/// `BackgroundHandler` is a type for a function that updates location.
typedef BackgroundHandler = void Function(Location);

/// `StatusEventType` is an enumeration representing the type of status event.
enum StatusEventType {
  start('start'),
  stop('stop'),
  updated('updated'),
  error('error'),
  permission('permission'),
  ;

  const StatusEventType(this.value);
  final String value;
}

/// `DesiredAccuracy` is an enumeration representing
/// the desired accuracy of location information.
enum DesiredAccuracy {
  // アプリが完全な精度の位置データを許可されていない場合に使用される精度
  reduced('reduced'),
  // ナビゲーションアプリのための高い精度
  bestForNavigation('bestForNavigation'),
  // 最高レベルの精度
  best('best'),
  // 10メートル以内の精度
  nearestTenMeters('nearestTenMeters'),
  // 100メートル以内の精度
  hundredMeters('hundredMeters'),
  // 1キロメートルでの精度
  kilometer('kilometer'),
  // 3キロメートルでの精度
  threeKilometers('threeKilometers'),
  ;

  const DesiredAccuracy(this.value);
  final String value;
}

enum ChannelName {
  methods('com.neverjp.background_task/methods'),
  bgEvent('com.neverjp.background_task/bgEvent'),
  statusEvent('com.neverjp.background_task/statusEvent'),
  ;

  const ChannelName(this.value);
  final String value;
}
