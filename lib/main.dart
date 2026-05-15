import 'package:flutter/material.dart';

import 'package:smf_app/app/main.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SleepRepository.instance.init();
  runApp(const SmfApp());
}
