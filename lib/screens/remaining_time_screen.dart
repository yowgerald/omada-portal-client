import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../env/env.dart';

class RemainingTimeScreen extends StatefulWidget {
  const RemainingTimeScreen({super.key});

  @override
  _RemainingTimeScreenState createState() => _RemainingTimeScreenState();
}

class _RemainingTimeScreenState extends State<RemainingTimeScreen> {
  static const platform = MethodChannel('com.example.toto_portal/device_info');

  // AUTH CONSTANTS
  final _username = Env.username;
  final _password = Env.password;
  String? _token;
  Map<String, String>? _cookies;

  // APP CONSTANTS
  String _macAddress = "Unknown";
  int _remainingSeconds = 0;
  bool _isLoading = true;
  Timer? _timer;

  // URLS AND IDS
  final String _controllerId = Env.controllerId;
  final String _siteId = Env.siteId;
  final String _omadaUrl = Env.omadaUrl;

  @override
  void initState() {
    super.initState();
    _getMacAddress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getMacAddress() async {
    try {
      final String result = await platform.invokeMethod('getMacAddress');
      setState(() {
        _macAddress = result;
      });
      await _loginAndFetchToken();
      await _fetchRemainingTime(_macAddress);
      _startCountdown();
    } on PlatformException catch (e) {
      print("Failed to get MAC address: '${e.message}'.");
    }
  }

  Future<void> _loginAndFetchToken() async {
    final String loginUrl = '$_omadaUrl/$_controllerId/api/v2/login';

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username,
          'password': _password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _token = data['result']['token'];
        });

        final cookieHeader = response.headers['set-cookie'];
        if (cookieHeader != null) {
          _cookies = {'Cookie': cookieHeader}; // Store cookies
        }
      } else {
        print('Login failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during login: $e');
    }
  }

  Future<void> _fetchRemainingTime(String macAddress) async {
    final String clientUrl =
        '$_omadaUrl/$_controllerId/api/v2/hotspot/sites/$_siteId/clients?searchKey=$macAddress&sorts.end=desc&token=$_token&currentPage=1&currentPageSize=1';

    try {
      final response = await http.get(
        Uri.parse(clientUrl),
        headers: {
          'Content-Type': 'application/json',
          'Csrf-Token': _token ?? '',
          if (_cookies != null) ..._cookies!,
        },
      );
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _remainingSeconds = _parseRemainingTime(
              data['remaining_time'] ?? "0 days 0 hours 0 minutes 0 seconds");
          _isLoading = false;
        });
      } else {
        print(
            'Failed to load remaining time, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remaining Time'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Text(
                  'Loading...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                )
              : Text(
                  _remainingSeconds > 0
                      ? _formatTime(_remainingSeconds)
                      : "Time's up!",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _fetchRemainingTime(_macAddress),
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

int _parseRemainingTime(String timeStr) {
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

String _formatTime(int seconds) {
  final minutes = (seconds / 60).floor();
  final hours = (minutes / 60).floor();
  final days = (hours / 24).floor();

  final remainingHours = hours % 24;
  final remainingMinutes = minutes % 60;
  final remainingSeconds = seconds % 60;

  return '${days}d ${remainingHours}h ${remainingMinutes}m ${remainingSeconds}s';
}
