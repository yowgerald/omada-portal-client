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

  final String username = Env.username;
  final String password = Env.password;
  String? authToken;
  Map<String, String>? cookies;

  String macAddress = "Unknown";
  int remainingSeconds = 0;
  bool isLoading = true;
  Timer? countdownTimer;

  final String controllerId = Env.controllerId;
  final String siteId = Env.siteId;
  final String omadaUrl = Env.omadaUrl;

  DateTime? lastRequestTime;
  final int requestCooldown = 8000; // 8 seconds cooldown
  int cooldownRemainingSeconds = 0; // Track remaining cooldown time
  Timer? cooldownTimer;

  @override
  void initState() {
    super.initState();
    loadRemainingTime();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    cooldownTimer?.cancel();
    super.dispose();
  }

  bool canMakeRequest() {
    if (lastRequestTime == null) return true;
    final timeSinceLastRequest =
        DateTime.now().difference(lastRequestTime!).inMilliseconds;
    return timeSinceLastRequest > requestCooldown;
  }

  void startCooldownTimer() {
    setState(() {
      cooldownRemainingSeconds = requestCooldown ~/ 1000; // Convert to seconds
    });

    cooldownTimer?.cancel();
    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (cooldownRemainingSeconds > 0) {
        setState(() {
          cooldownRemainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> loadRemainingTime() async {
    if (!canMakeRequest()) {
      print('Request throttled to avoid server exhaustion.');
      return;
    }

    // Update the last request time and start cooldown timer
    lastRequestTime = DateTime.now();
    startCooldownTimer();

    // Reset states
    setState(() {
      remainingSeconds = 0;
      isLoading = true;
    });

    // Cancel any existing countdown timer
    countdownTimer?.cancel();

    try {
      final String result = await platform.invokeMethod('getMacAddress');
      setState(() {
        macAddress = result;
      });
      if (macAddress.isEmpty) {
        print('No Mac Address found.');
        return;
      }

      await loginAndFetchToken();
      if (authToken == null || cookies == null) {
        print('Cannot Login!');
        return;
      }

      await fetchClientData(macAddress);
      print('Loaded.');
    } on PlatformException catch (e) {
      print("Failed to get MAC address: '${e.message}'.");
      setState(() {
        isLoading = false;
      });
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

      if (response.statusCode != 200) {
        print('Login failed with status: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      setState(() {
        authToken = data['result']['token'];
      });

      final cookieHeader = response.headers['set-cookie'];
      if (cookieHeader != null) {
        cookies = {'Cookie': cookieHeader};
      }
    } catch (e) {
      print('Error during login: $e');
    }
  }

  Future<void> fetchClientData(String mac) async {
    if (mac == "02:00:00:00:00:00") {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP() ?? "";
      if (wifiIp.isEmpty) {
        print('No WiFi IP found.');
        return;
      }
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

      if (response.statusCode != 200) {
        return;
      }
      Map<String, dynamic> parsedData = jsonDecode(response.body);
      mac = parsedData['result']['data'][0]['mac'];
    }
    await fetchRemainingTime(mac);
  }

  Future<void> fetchRemainingTime(String mac) async {
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

      if (response.statusCode != 200) {
        print(
            'Failed to load remaining time, status code: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
        return;
      }

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
    String constructionMessage =
        parser.emojify(':construction: Under construction :construction:');
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
            // Show wait message during cooldown
            if (cooldownRemainingSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Please Wait $cooldownRemainingSeconds seconds to refresh again.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Adding "Under Construction" message
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
        onPressed: cooldownRemainingSeconds > 0 ? null : loadRemainingTime,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
        backgroundColor: cooldownRemainingSeconds > 0 ? Colors.grey : null,
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
