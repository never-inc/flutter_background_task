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
  String _bgText = 'no start';
  String _statusText = '';

  late final StreamSubscription<Location> _bgDisposer;
  late final StreamSubscription<StatusEvent> _statusDisposer;
  @override
  void initState() {
    super.initState();
    _bgDisposer = BackgroundTask.instance.stream.listen((event) {
      final message = '${event.lat}, ${event.lng}\n${DateTime.now()}';
      debugPrint(message);
      setState(() {
        _bgText = message;
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
    _statusDisposer = BackgroundTask.instance.status.listen((event) {
      final message =
          'status: ${event.status.value}, message: ${event.message}';
      debugPrint(message);
      setState(() {
        _statusText = message;
      });
    });
  }

  @override
  void dispose() {
    _bgDisposer.cancel();
    _statusDisposer.cancel();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _bgText,
                  textAlign: TextAlign.center,
                ),
              ),
              Flexible(
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        persistentFooterAlignment: AlignmentDirectional.center,
        persistentFooterButtons: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await BackgroundTask.instance.stop();
                        setState(() {
                          _bgText = 'stop';
                        });
                      },
                      child: const Text('Stop'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final status = Platform.isIOS
                            ? await Permission.locationAlways.request()
                            : await Permission.location.request();
                        if (!status.isGranted) {
                          setState(() {
                            _bgText = 'Permission is not isGranted.';
                          });
                          return;
                        }
                        await BackgroundTask.instance.start();
                        setState(() {
                          _bgText = 'start';
                        });
                      },
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  return FilledButton(
                    onPressed: () async {
                      final isRunning = await BackgroundTask.instance.isRunning;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('isRunning: $isRunning'),
                          ),
                        );
                      }
                    },
                    child: const Text('isRunning'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
