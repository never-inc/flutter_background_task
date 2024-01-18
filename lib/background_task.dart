import 'dart:io';

import 'package:flutter/services.dart';

/// `Location` is a type representing latitude and longitude.
typedef Location = ({double? lat, double? lng});

/// `StatusEvent` is a type representing a status event.
typedef StatusEvent = ({StatusEventType status, String? message});

/// `BackgroundHandler` is a type for a function that updates location.
typedef BackgroundHandler = Future<void> Function(Location);

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

/// `BackgroundTask` is a class that manages background tasks.
class BackgroundTask {
  BackgroundTask(
    this._methodChannel,
    this._bgEventChannel,
    this._statusEventChannel,
  );

  /// Get instance
  static BackgroundTask get instance => _instance;

  static BackgroundHandler? _backgroundHandler;

  static final BackgroundTask _instance = BackgroundTask(
    const MethodChannel('com.neverjp.background_task/methods'),
    const EventChannel('com.neverjp.background_task/bgEvent'),
    const EventChannel('com.neverjp.background_task/statusEvent'),
  );

  final MethodChannel _methodChannel;
  final EventChannel _bgEventChannel;
  final EventChannel _statusEventChannel;

  /// `setBackgroundHandler` provides a function of location information.
  Future<void> setBackgroundHandler(BackgroundHandler handler) async {
    _backgroundHandler = handler;
  }

  /// `start` starts the background task.
  /// `distanceFilter` - the minimum distance (in meters) a device must move
  /// horizontally before an update event is generated.
  /// `isEnabledEvenIfKilled` - if set to true, the location service will
  /// not stop even after the app is killed.
  /// `iOSDesiredAccuracy` - the desired accuracy of the location data.
  Future<void> start({
    double? distanceFilter,
    bool isEnabledEvenIfKilled = false,
    DesiredAccuracy iOSDesiredAccuracy = DesiredAccuracy.bestForNavigation,
  }) async {
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'backgroundHandler') {
        final json = call.arguments as Map;
        final lat = json['lat'] as double?;
        final lng = json['lng'] as double?;
        await _backgroundHandler?.call((lat: lat, lng: lng));
      }
      return 'OK';
    });

    await _methodChannel.invokeMethod<bool>(
      'start_background_task',
      {
        'distanceFilter': distanceFilter,
        'isEnabledEvenIfKilled': isEnabledEvenIfKilled,
        'iOSDesiredAccuracy': iOSDesiredAccuracy.value,
      },
    );
  }

  /// `stop` stops the background task.
  Future<void> stop() async {
    await _methodChannel.invokeMethod<bool>('stop_background_task');
  }

  /// `isRunning` returns whether the background task is running or not.
  Future<bool> get isRunning async {
    final result =
        await _methodChannel.invokeMethod<bool>('is_running_background_task');
    return result ?? false;
  }

  /// `setAndroidNotification` sets the Android notification.
  Future<void> setAndroidNotification({
    String? title,
    String? message,
    String? icon,
  }) async {
    if (Platform.isAndroid) {
      await _methodChannel.invokeMethod<bool>(
        'set_android_notification',
        {
          'title': title,
          'message': message,
          'icon': icon,
        },
      );
    }
  }

  /// `stream` provides a stream of location information.
  Stream<Location> get stream =>
      _bgEventChannel.receiveBroadcastStream().map((event) {
        final json = event as Map;
        final lat = json['lat'] as double?;
        final lng = json['lng'] as double?;
        return (lat: lat, lng: lng);
      }).asBroadcastStream();

  /// `status` provides a stream of status events.
  Stream<StatusEvent> get status =>
      _statusEventChannel.receiveBroadcastStream().map((event) {
        final value = (event as String).split(',');
        return (
          status: StatusEventType.values
              .firstWhere((element) => element.value == value[0]),
          message: value.length > 1 ? value[1] : null,
        );
      }).asBroadcastStream();
}
