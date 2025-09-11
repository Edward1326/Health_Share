// lib/services/hive_service.dart
import 'dart:convert';
import 'package:health_share/config/hive_config.dart';
import 'package:http/http.dart' as http;

class HiveService {
  // Test connection to Hive API
  static Future<bool> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(HiveConfig.apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'condenser_api.get_dynamic_global_properties',
          'params': [],
          'id': 1,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Hive connection test failed: $e');
      return false;
    }
  }

  // Simple broadcast method (we'll enhance this later)
  static Future<bool> broadcastCustomJson(Map<String, dynamic> jsonData) async {
    try {
      // For now, just test the data structure
      print('Would broadcast to Hive: $jsonData');

      // We'll implement actual broadcasting in the next step
      return true;
    } catch (e) {
      print('Broadcast failed: $e');
      return false;
    }
  }
}
