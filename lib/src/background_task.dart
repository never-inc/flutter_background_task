import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'callback_dispatcher.dart';
import 'types.dart';

/// `BackgroundTask` is a class that manages background tasks.
class BackgroundTask {
  BackgroundTask(
    this._methodChannel,
    this._bgEventChannel,
    this._statusEventChannel,
  );

  /// Get instance
  static BackgroundTask get instance => _instance;

  static final BackgroundTask _instance = BackgroundTask(
    MethodChannel(ChannelName.methods.value),
    EventChannel(ChannelName.bgEvent.value),
    EventChannel(ChannelName.statusEvent.value),
  );

  final MethodChannel _methodChannel;
  final EventChannel _bgEventChannel;
  final EventChannel _statusEventChannel;

  /// `setBackgroundHandler` provides a function of location information.
  Future<void> setBackgroundHandler(BackgroundHandler handler) async {
    final callbackDispatcherHandle =
        PluginUtilities.getCallbackHandle(callbackDispatcher);
    final callbackHandler = PluginUtilities.getCallbackHandle(handler);
    if (callbackDispatcherHandle != null && callbackHandler != null) {
      await _methodChannel.invokeMethod<bool>(
        'set_background_handler',
        {
          'callbackDispatcherRawHandle': callbackDispatcherHandle.toRawHandle(),
          'callbackHandlerRawHandle': callbackHandler.toRawHandle(),
        },
      );
    }
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

  /// `start` starts the background task.
  /// `distanceFilter` - the minimum distance (in meters) a device must move
  /// horizontally before an update event is generated.
  /// `isEnabledEvenIfKilled` - if set to true, the location service will
  /// not stop even after the app is killed.
  /// `iOSDesiredAccuracy` - the desired accuracy of the location data.
  Future<void> start({
    double? distanceFilter,
    bool isEnabledEvenIfKilled = true,
    DesiredAccuracy iOSDesiredAccuracy = DesiredAccuracy.bestForNavigation,
  }) async {
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
