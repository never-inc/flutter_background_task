import 'dart:io';

import 'package:flutter/services.dart';

typedef EventType = ({double? lat, double? lng});

class BackgroundTask {
  BackgroundTask(this._methodChannel, this._eventChannel);

  static final BackgroundTask _instance = BackgroundTask(
    const MethodChannel('com.neverjp.background_task/methods'),
    const EventChannel('com.neverjp.background_task/events'),
  );

  static BackgroundTask get instance => _instance;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Future<void> start({double? distanceFilter}) async {
    await _methodChannel.invokeMethod<bool>(
      'start_background_task',
      {'distanceFilter': distanceFilter},
    );
  }

  Future<void> stop() async {
    await _methodChannel.invokeMethod<bool>('stop_background_task');
  }

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

  Stream<EventType?> get stream =>
      _eventChannel.receiveBroadcastStream().map((event) {
        final json = event as Map;
        final lat = json['lat'] as double?;
        final lng = json['lng'] as double?;
        return (lat: lat, lng: lng);
      }).asBroadcastStream();
}
