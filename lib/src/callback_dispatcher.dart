import 'dart:ui';

import 'package:background_task/src/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  MethodChannel(ChannelName.methods.value)
    ..setMethodCallHandler((call) async {
      if (call.method == 'notify_callback_dispatcher') {
        // for 2 way handshake
        // debugPrint('notify_callback_dispatcher');
      } else if (call.method == 'background_handler') {
        final json = call.arguments as Map;
        final handle = json['callbackHandlerRawHandle'] as int?;
        if (handle != null) {
          final callback = PluginUtilities.getCallbackFromHandle(
            CallbackHandle.fromRawHandle(handle),
          );
          final data = (
            lat: json['lat'] as double?,
            lng: json['lng'] as double?,
          );
          callback?.call(data);
        }
      }
    })
    ..invokeMethod('callback_channel_initialized');
}
