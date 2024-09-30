import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_emoji/flutter_emoji.dart';
import '../env/env.dart';

class RemainingTimeScreen extends StatefulWidget {
  const RemainingTimeScreen({super.key});

  @override
  _RemainingTimeScreenState createState() => _RemainingTimeScreenState();
}

class _RemainingTimeScreenState extends State<RemainingTimeScreen> {
  static const platform = MethodChannel('com.example.toto_portal/device_info');

  // AUTH CONSTANTS
  final String username = Env.username;
  final String password = Env.password;
  String? authToken;
  Map<String, String>? cookies;

  // APP CONSTANTS
  String macAddress = "Unknown";
  int remainingSeconds = 0;
  bool isLoading = true;
  Timer? countdownTimer;

  // URLS AND IDS
  final String controllerId = Env.controllerId;
  final String siteId = Env.siteId;
  final String omadaUrl = Env.omadaUrl;

  @override
  void initState() {
    super.initState();
    retrieveMacAddress();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> retrieveMacAddress() async {
    try {
      final String result = await platform.invokeMethod('getMacAddress');
      setState(() {
        macAddress = result;
      });
      await loginAndFetchToken();
      await fetchRemainingTime(macAddress);
    } on PlatformException catch (e) {
      print("Failed to get MAC address: '${e.message}'.");
    }
  }

  Future<void> loginAndFetchToken() async {
    final String loginUrl = '$omadaUrl/$controllerId/api/v2/login';

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          authToken = data['result']['token'];
        });

        final cookieHeader = response.headers['set-cookie'];
        if (cookieHeader != null) {
          cookies = {'Cookie': cookieHeader}; // Store cookies
        }
      } else {
        print('Login failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during login: $e');
    }
  }

  Future<void> fetchRemainingTime(String mac) async {
    if (mac == "02:00:00:00:00:00") {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP() ?? "";
      final String clientUrl =
          '$omadaUrl/$controllerId/api/v2/sites/$siteId/clients?&token=$authToken&searchKey=$wifiIp&sorts.end=desc&filters.active=true&currentPage=1&currentPageSize=1';
      final response = await http.get(
        Uri.parse(clientUrl),
        headers: {
          'Content-Type': 'application/json',
          'Csrf-Token': authToken ?? '',
          if (cookies != null) ...cookies!,
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> parsedData = jsonDecode(response.body);
        mac = parsedData['result']['data'][0]['mac'];
      }
    }
    await fetchClientTime(mac);
  }

  Future<void> fetchClientTime(String mac) async {
    final String clientUrl =
        '$omadaUrl/$controllerId/api/v2/hotspot/sites/$siteId/clients?searchKey=$mac&sorts.end=desc&token=$authToken&currentPage=1&currentPageSize=1';

    try {
      final response = await http.get(
        Uri.parse(clientUrl),
        headers: {
          'Content-Type': 'application/json',
          'Csrf-Token': authToken ?? '',
          if (cookies != null) ...cookies!,
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> parsedData = jsonDecode(response.body);
        int endTimestamp = parsedData['result']['data'][0]['end'];
        int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

        int remainingTimeMillis = endTimestamp - currentTimestamp;

        if (remainingTimeMillis < 0) {
          print("Time's up!");
          setState(() {
            remainingSeconds = 0;
            isLoading = false;
          });
        } else {
          int seconds = remainingTimeMillis ~/ 1000;
          setState(() {
            remainingSeconds = seconds;
            isLoading = false;
          });
          startCountdown();
        }
      } else {
        print(
            'Failed to load remaining time, status code: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void startCountdown() {
    countdownTimer?.cancel();

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        print("Countdown finished.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var parser = EmojiParser();
    String constructionMessage = parser
        .emojify(':construction: This is under construction :construction:');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remaining Time'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Expanded widget to center the remaining time text
            Expanded(
              child: Center(
                child: isLoading
                    ? const Text(
                        'Loading...',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : Text(
                        remainingSeconds > 0
                            ? formatTime(remainingSeconds)
                            : "Time's up!",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            // Adding "Under Construction" message with bottom padding
            Padding(
              padding:
                  const EdgeInsets.only(bottom: 80.0), // Extra bottom padding
              child: Text(
                constructionMessage,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => fetchRemainingTime(macAddress),
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
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
}
