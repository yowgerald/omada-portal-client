import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(RemainingTimeApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class RemainingTimeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remaining Time App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RemainingTimeScreen(),
    );
  }
}

class RemainingTimeScreen extends StatefulWidget {
  @override
  _RemainingTimeScreenState createState() => _RemainingTimeScreenState();
}

class _RemainingTimeScreenState extends State<RemainingTimeScreen> {
  static const platform = MethodChannel('com.example.toto_portal/device_info');
  String macAddress = "Unknown";
  int remainingSeconds = 0;
  bool isLoading = true; // Flag to determine loading state
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    getMacAddress();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> getMacAddress() async {
    try {
      final String result = await platform.invokeMethod('getMacAddress');
      setState(() {
        macAddress = result;
      });
      await fetchRemainingTime(macAddress);
      startCountdown();
    } on PlatformException catch (e) {
      print("Failed to get MAC address: '${e.message}'.");
    }
  }

  Future<void> fetchRemainingTime(String macAddress) async {
    final url = 'https://192.168.0.107:3000/get_client?mac_id=$macAddress';

    try {
      final response = await http.get(Uri.parse(url));
      print(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          remainingSeconds = parseRemainingTime(
              data['remaining_time'] ?? "0 days 0 hours 0 minutes 0 seconds");
          isLoading = false; // Set loading to false after data is fetched
        });
      } else {
        print(
            'Failed to load remaining time, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false; // Set loading to false even if there is an error
      });
    }
  }

  int parseRemainingTime(String timeStr) {
    final regex = RegExp(r'(\d+) days (\d+) hours (\d+) minutes (\d+) seconds');
    final match = regex.firstMatch(timeStr);

    if (match != null) {
      final days = int.parse(match.group(1) ?? '0');
      final hours = int.parse(match.group(2) ?? '0');
      final minutes = int.parse(match.group(3) ?? '0');
      final seconds = int.parse(match.group(4) ?? '0');
      return days * 86400 + hours * 3600 + minutes * 60 + seconds;
    }
    return 0;
  }

  void startCountdown() {
    _timer?.cancel(); // Cancel any existing timer

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel(); // Stop the timer when countdown finishes
      }
    });
  }

  String formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final hours = (minutes / 60).floor();
    final days = (hours / 24).floor();

    final remainingHours = hours % 24;
    final remainingMinutes = minutes % 60;
    final remainingSeconds = seconds % 60;

    return '${days}d ${remainingHours}h ${remainingMinutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Remaining Time'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? Text(
                  'Loading...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                )
              : Text(
                  remainingSeconds > 0
                      ? formatTime(remainingSeconds)
                      : "Time's up!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => fetchRemainingTime(macAddress),
        tooltip: 'Refresh',
        child: Icon(Icons.refresh),
      ),
    );
  }
}
