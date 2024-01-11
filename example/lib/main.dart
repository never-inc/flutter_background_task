import 'dart:async';
import 'dart:io';

import 'package:background_task/background_task.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _text = 'no start';
  late final StreamSubscription<EventType?> _disposer;

  @override
  void initState() {
    super.initState();
    _disposer = BackgroundTask.instance.stream.listen((event) {
      final message = '${event?.lat}, ${event?.lng}\n${DateTime.now()}';
      debugPrint(message);
      setState(() {
        _text = message;
      });
    });
    if (Platform.isAndroid) {
      Future(() async {
        final result = await Permission.notification.request();
        debugPrint('notification: $result');
        if (result.isGranted) {
          await BackgroundTask.instance.setAndroidNotification(
            title: 'バックグラウンド処理',
            message: 'バックグラウンド処理を実行中',
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _disposer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text(
            _text,
            textAlign: TextAlign.center,
          ),
        ),
        persistentFooterAlignment: AlignmentDirectional.center,
        persistentFooterButtons: [
          FilledButton(
            onPressed: () async {
              await BackgroundTask.instance.stop();
              setState(() {
                _text = 'stop';
              });
            },
            child: const Text('Stop'),
          ),
          FilledButton(
            onPressed: () async {
              await BackgroundTask.instance.start();
              setState(() {
                _text = 'start';
              });
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
