import 'dart:io';

import 'package:flutter/services.dart';

typedef Location = ({double? lat, double? lng});
typedef StatusEvent = ({StatusEventType status, String? message});

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

enum DesiredAccuracy {
  // アプリが完全な精度の位置データを許可されていない場合に使用される精度のレベル
  reduced('reduced'),
  // ナビゲーションアプリのための高い精度と追加のセンサーも使用する
  bestForNavigation('bestForNavigation'),
  // 最高レベルの精度
  best('best'),
  // 10メートル以内の精度
  nearestTenMeters('nearestTenMeters'),
  // 100メートル以内の精度
  hundredMeters('hundredMeters'),
  // 1キロメートルでの精度
  kilometer('kilometer'),
  // キロメートルでの精度
  threeKilometers('threeKilometers'),
  ;

  const DesiredAccuracy(this.value);
  final String value;
}

class BackgroundTask {
  BackgroundTask(
    this._methodChannel,
    this._bgEventChannel,
    this._statusEventChannel,
  );

  /// Get instance
  static BackgroundTask get instance => _instance;

  static final BackgroundTask _instance = BackgroundTask(
    const MethodChannel('com.neverjp.background_task/methods'),
    const EventChannel('com.neverjp.background_task/bgEvent'),
    const EventChannel('com.neverjp.background_task/statusEvent'),
  );

  final MethodChannel _methodChannel;
  final EventChannel _bgEventChannel;
  final EventChannel _statusEventChannel;

  /// Start
  Future<void> start({
    double? distanceFilter,
    DesiredAccuracy iOSDesiredAccuracy = DesiredAccuracy.bestForNavigation,
  }) async {
    await _methodChannel.invokeMethod<bool>(
      'start_background_task',
      {
        'distanceFilter': distanceFilter,
        'iOSDesiredAccuracy': iOSDesiredAccuracy.value,
      },
    );
  }

  /// Stop
  Future<void> stop() async {
    await _methodChannel.invokeMethod<bool>('stop_background_task');
  }

  /// isRunning
  Future<bool> isRunning() async {
    final result =
        await _methodChannel.invokeMethod<bool>('is_running_background_task');
    return result ?? false;
  }

  /// Set android notification
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

  /// Stream bg event
  Stream<Location> get stream =>
      _bgEventChannel.receiveBroadcastStream().map((event) {
        final json = event as Map;
        final lat = json['lat'] as double?;
        final lng = json['lng'] as double?;
        return (lat: lat, lng: lng);
      }).asBroadcastStream();

  /// Stream status event
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
