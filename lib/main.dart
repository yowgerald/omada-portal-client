import 'dart:io';

import 'package:flutter/material.dart';
import 'services/http_overrides.dart';
import 'screens/remaining_time_screen.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const RemainingTimeApp());
}

class RemainingTimeApp extends StatelessWidget {
  const RemainingTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remaining Time App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RemainingTimeScreen(),
    );
  }
}
