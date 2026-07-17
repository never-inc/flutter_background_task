import 'package:background_task_example/model/sembast_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SembastRepository.configure();
  await initializeDateFormatting('ja_JP');
  runApp(const MyApp());
}
