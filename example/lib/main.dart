import 'dart:async';
import 'dart:io';

import 'package:background_task/background_task.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> backgroundHandler(Location location) async {
  final value = 'bg: $location, ${DateTime.now()}';
  debugPrint(value);
}

void main() {
  BackgroundTask.instance.setBackgroundHandler(backgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _bgText = 'no start';
  String _statusText = 'status';
  bool _isEnabledEvenIfKilled = true;

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

    Future(() async {
      final result = await Permission.notification.request();
      debugPrint('notification: $result');
      if (Platform.isAndroid) {
        if (result.isGranted) {
          await BackgroundTask.instance.setAndroidNotification(
            title: 'バックグラウンド処理',
            message: 'バックグラウンド処理を実行中',
          );
        }
      }
    });

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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bgText,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
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
                  Flexible(
                    flex: 2,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Monitor even if killed',
                          ),
                          WidgetSpan(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: CupertinoSwitch(
                                value: _isEnabledEvenIfKilled,
                                onChanged: (value) {
                                  setState(() {
                                    _isEnabledEvenIfKilled = value;
                                  });
                                },
                              ),
                            ),
                            alignment: PlaceholderAlignment.middle,
                          )
                        ],
                      ),
                    ),
                  ),
                  Flexible(
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
                        await BackgroundTask.instance.start(
                          isEnabledEvenIfKilled: _isEnabledEvenIfKilled,
                        );
                        setState(() {
                          _bgText = 'start';
                        });
                      },
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
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
                  Flexible(
                    child: Builder(
                      builder: (context) {
                        return FilledButton(
                          onPressed: () async {
                            final isRunning =
                                await BackgroundTask.instance.isRunning;
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('isRunning: $isRunning'),
                                  action: SnackBarAction(
                                    label: 'close',
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('isRunning'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
