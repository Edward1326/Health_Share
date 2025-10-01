import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HiveCustomJsonService {
  // Get Hive account name from environment
  static final String _hiveAccountName = dotenv.env['HIVE_ACCOUNT_NAME'] ?? '';

  /// Creates a custom JSON for Hive blockchain medical logs
  ///
  /// Parameters:
  /// - fileName: The name of the uploaded file
  /// - fileHash: The SHA-256 hash of the file
  /// - timestamp: Optional timestamp (defaults to current time)
  ///
  /// Returns a Map representing the custom_json operation
  static Map<String, dynamic> createMedicalLogCustomJson({
    required String fileName,
    required String fileHash,
    DateTime? timestamp,
  }) {
    if (_hiveAccountName.isEmpty) {
      throw Exception('HIVE_ACCOUNT_NAME not found in environment variables');
    }

    // Use provided timestamp or current time
    final logTimestamp = timestamp ?? DateTime.now();

    // Create the medical log payload
    final medicalLogData = {
      "action": "upload",
      "user_id": _hiveAccountName,
      "file_name": "$fileName",
      "file_hash": "$fileHash",
      "timestamp": logTimestamp.toUtc().toIso8601String(),
    };

    // Convert payload to JSON string
    final jsonPayload = jsonEncode(medicalLogData);

    // Create the custom_json operation
    final customJsonOperation = [
      "custom_json",
      {
        "id": "medical_logs",
        "json": jsonPayload,
        "required_auths": <String>[],
        "required_posting_auths": [_hiveAccountName],
      },
    ];

    return {
      "operation": customJsonOperation,
      "payload_data": medicalLogData, // For debugging/logging purposes
    };
  }

  /// Creates a custom JSON string ready for Hive blockchain submission
  ///
  /// Parameters:
  /// - fileName: The name of the uploaded file
  /// - fileHash: The SHA-256 hash of the file
  /// - timestamp: Optional timestamp (defaults to current time)
  ///
  /// Returns a JSON string of the custom_json operation
  static String createMedicalLogCustomJsonString({
    required String fileName,
    required String fileHash,
    DateTime? timestamp,
  }) {
    final customJson = createMedicalLogCustomJson(
      fileName: fileName,
      fileHash: fileHash,
      timestamp: timestamp,
    );

    return jsonEncode(customJson["operation"]);
  }

  /// Validates environment setup for Hive integration
  static bool isHiveConfigured() {
    return _hiveAccountName.isNotEmpty;
  }

  /// Gets the configured Hive account name
  static String getHiveAccountName() {
    return _hiveAccountName;
  }
}
