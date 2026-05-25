import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend base URL for the Flask API (`backend/app.py` on port 5000).
///
/// Override host (pick one):
/// - Physical phone on same Wi‑Fi: your PC LAN IP from `ipconfig` (e.g. 192.168.36.141)
/// - Android emulator: `10.0.2.2`
/// - Windows/macOS/Linux desktop: `127.0.0.1`
///
/// Run with: `flutter run --dart-define=API_HOST=192.168.36.141`
class ApiConfig {
  static const String _hostFromDefine = String.fromEnvironment('API_HOST');

  static String get host {
    if (_hostFromDefine.isNotEmpty) return _hostFromDefine;
    if (kIsWeb) return '127.0.0.1';
    if (Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  static const int port = 5000;

  static String get baseUrl => 'http://$host:$port';

  static String get predictUrl => '$baseUrl/api/predict';

  static String get finalPredictUrl => '$baseUrl/api/final-predict';
}
