import 'dart:convert';
import 'package:http/http.dart' as http;

class HiveAuditService {
  // Update this to your deployed backend URL
  static const String baseUrl = 'https://your-backend-domain.com/api';
  // For local testing: 'http://10.0.2.2:3000/api' (Android emulator)
  // For iOS simulator: 'http://localhost:3000/api'
  
  static const Duration timeoutDuration = Duration(seconds: 10);

  static Future<Map<String, dynamic>> _makeRequest(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> logFileUpload({
    required String fileHash,
    required String userId,
    required String ipfsCid,
    required String fileType,
    required int recipientsCount,
  }) async {
    return await _makeRequest('log-upload', {
      'fileHash': fileHash,
      'userId': userId,
      'ipfsCid': ipfsCid,
      'fileType': fileType,
      'recipientsCount': recipientsCount,
    });
  }

  static Future<Map<String, dynamic>> logFileAccess({
    required String fileHash,
    required String userId,
    required String fileId,
  }) async {
    return await _makeRequest('log-access', {
      'fileHash': fileHash,
      'userId': userId,
      'fileId': fileId,
    });
  }

  static Future<Map<String, dynamic>> logAccessRevocation({
    required String fileHash,
    required String userId,
    required String fileId,
  }) async {
    return await _makeRequest('log-revocation', {
      'fileHash': fileHash,
      'userId': userId,
      'fileId': fileId,
    });
  }

  static Future<List<Map<String, dynamic>>> getAuditHistory(String fileHash) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/audit-history/$fileHash'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['logs']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting audit history: $e');
      return [];
    }
  }

  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/test'))
          .timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}