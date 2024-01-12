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
  Future<void> start({double? distanceFilter}) async {
    await _methodChannel.invokeMethod<bool>(
      'start_background_task',
      {'distanceFilter': distanceFilter},
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
