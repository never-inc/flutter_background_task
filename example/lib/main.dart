import 'dart:async';

import 'package:background_task/background_task.dart';
import 'package:flutter/material.dart';

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
  late final StreamSubscription<String?> _disposer;

  @override
  void initState() {
    super.initState();
    _disposer = BackgroundTask.instance.stream.listen((event) {
      final message = '${event ?? ''}: ${DateTime.now()}';
      print(message);
      setState(() {
        _text = message;
      });
    });
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
          child: Text(_text),
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
