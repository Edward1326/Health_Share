// lib/config/hive_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HiveConfig {
  static String get username => dotenv.env['HIVE_USERNAME'] ?? '';
  static String get postingKey => dotenv.env['HIVE_POSTING_KEY'] ?? '';
  static String get customJsonId => dotenv.env['HIVE_CUSTOM_JSON_ID'] ?? '';
  static const String apiUrl = 'https://api.hive.blog';

  // Validate that all required config is present
  static bool get isConfigured {
    return username.isNotEmpty &&
        postingKey.isNotEmpty &&
        customJsonId.isNotEmpty;
  }
}
