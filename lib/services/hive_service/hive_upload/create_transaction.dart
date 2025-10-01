import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:convert/convert.dart';

class HiveTransactionService {
  // Hive API endpoint
  static const String _hiveApiUrl = 'https://api.hive.blog';

  /// Creates an unsigned Hive transaction with the given operations
  ///
  /// Parameters:
  /// - operations: List of operations to include in the transaction
  /// - expirationMinutes: Minutes from now when transaction expires (default: 30)
  ///
  /// Returns a Map representing the unsigned transaction
  static Future<Map<String, dynamic>> createUnsignedTransaction({
    required List<List<dynamic>> operations,
    int expirationMinutes = 30,
  }) async {
    try {
      // 1. Get dynamic global properties from Hive blockchain
      final globalProperties = await _getDynamicGlobalProperties();

      if (globalProperties == null) {
        throw Exception('Failed to fetch dynamic global properties');
      }

      // 2. Extract required values
      final headBlockNumber = globalProperties['head_block_number'] as int;
      final headBlockId = globalProperties['head_block_id'] as String;
      final chainTime = globalProperties['time'] as String;

      // 3. Compute ref_block_num (last 16 bits of head_block_number)
      final refBlockNum = headBlockNumber & 0xFFFF;

      // 4. Compute ref_block_prefix (first 4 bytes of head_block_id as little-endian uint32)
      final refBlockPrefix = _computeRefBlockPrefix(headBlockId);

      // 5. Compute expiration time
      final chainDateTime = DateTime.parse(chainTime + 'Z'); // Add Z for UTC
      final expirationTime = chainDateTime.add(
        Duration(minutes: expirationMinutes),
      );
      final expiration = expirationTime.toUtc().toIso8601String();

      // Remove the 'Z' suffix and milliseconds for Hive format
      final formattedExpiration = expiration.substring(0, 19);

      // 6. Create unsigned transaction
      final unsignedTransaction = {
        'ref_block_num': refBlockNum,
        'ref_block_prefix': refBlockPrefix,
        'expiration': formattedExpiration,
        'operations': operations,
        'extensions': <dynamic>[],
        'signatures': <String>[],
      };

      return unsignedTransaction;
    } catch (e) {
      throw Exception('Failed to create unsigned transaction: $e');
    }
  }

  /// Fetches dynamic global properties from Hive blockchain
  static Future<Map<String, dynamic>?> _getDynamicGlobalProperties() async {
    try {
      final response = await http.post(
        Uri.parse(_hiveApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'condenser_api.get_dynamic_global_properties',
          'params': [],
          'id': 1,
        }),
      );

      if (response.statusCode != 200) {
        print('HTTP error: ${response.statusCode}');
        return null;
      }

      final responseData = jsonDecode(response.body);

      if (responseData['error'] != null) {
        print('API error: ${responseData['error']}');
        return null;
      }

      return responseData['result'] as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching dynamic global properties: $e');
      return null;
    }
  }

  /// Computes ref_block_prefix from head_block_id
  /// Takes the first 8 hex characters and converts to uint32 little-endian
  static int _computeRefBlockPrefix(String headBlockId) {
    final bytes = Uint8List.fromList(hex.decode(headBlockId));
    // Extract bytes 4–7 (little endian uint32)
    return ByteData.sublistView(bytes).getUint32(4, Endian.little);
  }

  /// Creates an unsigned transaction specifically for custom_json operations
  ///
  /// Parameters:
  /// - customJsonOperation: The custom_json operation (already formatted)
  /// - expirationMinutes: Minutes from now when transaction expires (default: 30)
  ///
  /// Returns a Map representing the unsigned transaction
  static Future<Map<String, dynamic>> createCustomJsonTransaction({
    required List<dynamic> customJsonOperation,
    int expirationMinutes = 30,
  }) async {
    return await createUnsignedTransaction(
      operations: [customJsonOperation],
      expirationMinutes: expirationMinutes,
    );
  }

  /// Utility method to create a complete unsigned transaction from medical log data
  ///
  /// Parameters:
  /// - fileName: The name of the uploaded file
  /// - fileHash: The SHA-256 hash of the file
  /// - hiveAccountName: The Hive account name
  /// - timestamp: Optional timestamp (defaults to current time)
  /// - expirationMinutes: Minutes from now when transaction expires (default: 30)
  ///
  /// Returns a Map representing the unsigned transaction
  static Future<Map<String, dynamic>> createMedicalLogTransaction({
    required String fileName,
    required String fileHash,
    required String hiveAccountName,
    DateTime? timestamp,
    int expirationMinutes = 30,
  }) async {
    // Create the medical log payload
    final logTimestamp = timestamp ?? DateTime.now();
    final medicalLogData = {
      "action": "upload",
      "user_id": hiveAccountName,
      "file_name": fileName,
      "file_hash": fileHash,
      "timestamp": logTimestamp.toUtc().toIso8601String(),
    };

    // Create the custom_json operation
    final customJsonOperation = [
      "custom_json",
      {
        "id": "medical_logs",
        "json": jsonEncode(medicalLogData),
        "required_auths": <String>[],
        "required_posting_auths": [hiveAccountName],
      },
    ];

    return await createCustomJsonTransaction(
      customJsonOperation: customJsonOperation,
      expirationMinutes: expirationMinutes,
    );
  }

  /// Validates if a transaction structure is properly formatted
  static bool isValidTransactionStructure(Map<String, dynamic> transaction) {
    final requiredFields = [
      'ref_block_num',
      'ref_block_prefix',
      'expiration',
      'operations',
      'extensions',
      'signatures',
    ];

    for (final field in requiredFields) {
      if (!transaction.containsKey(field)) {
        return false;
      }
    }

    return transaction['operations'] is List &&
        transaction['extensions'] is List &&
        transaction['signatures'] is List;
  }

  /// Gets the current blockchain time (useful for debugging)
  static Future<String?> getCurrentBlockchainTime() async {
    final properties = await _getDynamicGlobalProperties();
    return properties?['time'] as String?;
  }

  /// Gets the current head block number (useful for debugging)
  static Future<int?> getCurrentHeadBlockNumber() async {
    final properties = await _getDynamicGlobalProperties();
    return properties?['head_block_number'] as int?;
  }
}
