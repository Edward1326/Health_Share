import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' hide Hash;
import 'package:fast_rsa/fast_rsa.dart';
import 'package:health_share/services/hive_service/create_custom_json.dart';
import 'package:health_share/services/hive_service/create_transaction.dart';
import 'package:health_share/services/hive_service/sign_transaction.dart';
import 'package:health_share/services/hive_service/broadcast_transaction.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/services/files_services/file_picker_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UploadFileService {
  // Pinata JWT token (store securely in .env)
  static final String _pinataJWT = dotenv.env['PINATA_JWT'] ?? '';

  // Cryptography instances
  static final _aesGcm = AesGcm.with256bits();
  static final _sha256 = Sha256();

  /// Uploads a file with encryption, stores metadata in Supabase, AND logs to Hive blockchain
  /// This is the main integration point that connects all services
  /// Returns true if successful, false otherwise
  static Future<bool> uploadFile(BuildContext context) async {
    try {
      // 1. Pick a file
      final file = await FilePickerService.pickFile();
      if (file == null) return false;

      final fileBytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final fileType = fileName.split('.').last.toUpperCase();

      // 2. Calculate SHA-256 hash of original file
      final fileHash = await _calculateSHA256(fileBytes);
      print('File SHA-256 hash: $fileHash');

      // 3. Generate AES key and encrypt file
      final aesKey = await _aesGcm.newSecretKey();
      final encryptionResult = await _encryptFileData(fileBytes, aesKey);
      final encryptedBytes = encryptionResult['encryptedData'] as Uint8List;
      final nonce = encryptionResult['nonce'] as List<int>;

      // 4. Get current user
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User not logged in!')));
        }
        return false;
      }

      // 5. Fetch user RSA public key
      final userData =
          await supabase
              .from('User')
              .select('rsa_public_key, id')
              .eq('id', user.id)
              .single();

      final rsaPublicKeyPem = userData['rsa_public_key'] as String;

      // 6. Prepare AES key data for RSA encryption
      final aesKeyBytes = await aesKey.extractBytes();
      final keyData = {
        'key': base64Encode(aesKeyBytes),
        'nonce': base64Encode(nonce),
      };
      final keyDataJson = jsonEncode(keyData);

      // 7. Encrypt AES key package with RSA-OAEP
      final encryptedKeyPackage = await RSA.encryptOAEP(
        keyDataJson,
        "",
        Hash.SHA256,
        rsaPublicKeyPem,
      );

      // 8. Upload encrypted file to Pinata
      final ipfsCid = await _uploadToPinata(encryptedBytes, fileName);
      if (ipfsCid == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload to IPFS')),
          );
        }
        return false;
      }
      print('Upload successful. CID: $ipfsCid');

      // 9. Insert file metadata into Supabase with SHA-256 hash
      final uploadTimestamp = DateTime.now();
      final fileInsert =
          await supabase
              .from('Files')
              .insert({
                'filename': fileName,
                'category': 'General',
                'file_type': fileType,
                'uploaded_at': uploadTimestamp.toIso8601String(),
                'file_size': fileBytes.length,
                'ipfs_cid': ipfsCid,
                'uploaded_by': user.id,
                'sha256_hash': fileHash,
              })
              .select()
              .single();

      final String fileId = fileInsert['id'].toString();
      print('File inserted with ID: $fileId');

      // 10. Store encrypted key package in File_Keys
      final keyStoreSuccess = await _storeFileKey(
        fileId: fileId,
        encryptedKeyPackage: encryptedKeyPackage,
        userId: user.id,
      );

      if (!keyStoreSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File uploaded but key storage failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      // 🔗 11. HIVE BLOCKCHAIN INTEGRATION - The key connection point!
      final hiveSuccess = await _logToHiveBlockchain(
        fileName: fileName,
        fileHash: fileHash,
        timestamp: uploadTimestamp,
        context: context,
      );

      // 12. Show final success message
      if (context.mounted) {
        final message =
            hiveSuccess
                ? 'File uploaded, encrypted, and logged to Hive blockchain successfully!'
                : 'File uploaded and encrypted successfully! (Hive logging failed - check logs)';

        final backgroundColor = hiveSuccess ? Colors.green : Colors.orange;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: backgroundColor),
        );
      }

      return true; // Still return true even if Hive fails, since file upload succeeded
    } catch (e, stackTrace) {
      print('Error uploading file: $e');
      print('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
      }
      return false;
    }
  }

  /// 🔗 MAIN INTEGRATION METHOD - Connects all 5 Hive services
  /// This method orchestrates the entire Hive workflow:
  /// HiveCustomJsonService → HiveTransactionService → HiveTransactionSigner → HiveTransactionBroadcaster
  static Future<bool> _logToHiveBlockchain({
    required String fileName,
    required String fileHash,
    required DateTime timestamp,
    required BuildContext context,
  }) async {
    try {
      // Check if Hive is configured
      if (!HiveCustomJsonService.isHiveConfigured()) {
        print('Warning: Hive not configured (HIVE_ACCOUNT_NAME missing)');
        return false;
      }

      print('Starting Hive blockchain logging...');

      // 🔗 STEP 1: Create custom JSON using HiveCustomJsonService
      final customJsonResult = HiveCustomJsonService.createMedicalLogCustomJson(
        fileName: fileName,
        fileHash: fileHash,
        timestamp: timestamp,
      );
      final customJsonOperation =
          customJsonResult['operation'] as List<dynamic>;
      print('✓ Custom JSON created');

      // 🔗 STEP 2: Create unsigned transaction using HiveTransactionService
      final unsignedTransaction =
          await HiveTransactionService.createCustomJsonTransaction(
            customJsonOperation: customJsonOperation,
            expirationMinutes: 30,
          );
      print('✓ Unsigned transaction created');

      // 🔗 STEP 3: Sign transaction using HiveTransactionSigner
      final signedTransaction = await HiveTransactionSigner.signTransaction(
        unsignedTransaction,
      );
      print('✓ Transaction signed');

      // 🔗 STEP 4: Broadcast transaction using HiveTransactionBroadcaster
      final broadcastResult =
          await HiveTransactionBroadcaster.broadcastTransaction(
            signedTransaction,
          );

      if (broadcastResult.success) {
        print('✓ Transaction broadcasted successfully!');
        print('  Transaction ID: ${broadcastResult.getTxId()}');
        print('  Block Number: ${broadcastResult.getBlockNum()}');
        return true;
      } else {
        print(
          '✗ Failed to broadcast transaction: ${broadcastResult.getError()}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      print('Error logging to Hive blockchain: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Test the complete Hive workflow without uploading a file
  /// Useful for debugging and testing the integration
  static Future<bool> testHiveWorkflow({
    String testFileName = 'test_file.pdf',
    String testFileHash = 'abc123def456...',
  }) async {
    try {
      return await _logToHiveBlockchain(
        fileName: testFileName,
        fileHash: testFileHash,
        timestamp: DateTime.now(),
        context: NavigatorService.navigatorKey.currentContext!,
      );
    } catch (e) {
      print('Hive workflow test failed: $e');
      return false;
    }
  }

  /// Get status of all services for debugging
  static Future<Map<String, dynamic>> getServicesStatus() async {
    final status = <String, dynamic>{};

    // Check HiveCustomJsonService
    status['hive_configured'] = HiveCustomJsonService.isHiveConfigured();
    status['hive_account'] = HiveCustomJsonService.getHiveAccountName();

    // Check HiveTransactionService connectivity
    try {
      final blockchainTime =
          await HiveTransactionService.getCurrentBlockchainTime();
      status['blockchain_connectivity'] = blockchainTime != null;
      status['blockchain_time'] = blockchainTime;
    } catch (e) {
      status['blockchain_connectivity'] = false;
      status['blockchain_error'] = e.toString();
    }

    // Check HiveTransactionSigner WIF
    final wif = HiveTransactionSigner.getPostingWif();
    status['wif_configured'] = wif.isNotEmpty;
    status['wif_valid'] =
        wif.isNotEmpty ? HiveTransactionSigner.isValidWif(wif) : false;

    // Check HiveTransactionBroadcaster connectivity
    try {
      final nodeConnectivity =
          await HiveTransactionBroadcaster.testConnection();
      status['node_connectivity'] = nodeConnectivity;
      status['node_url'] = HiveTransactionBroadcaster.getHiveNodeUrl();

      if (nodeConnectivity) {
        final nodeInfo = await HiveTransactionBroadcaster.getNodeInfo();
        status['node_info'] = nodeInfo;
      }
    } catch (e) {
      status['node_connectivity'] = false;
      status['node_error'] = e.toString();
    }

    // Check Pinata
    status['pinata_configured'] = _pinataJWT.isNotEmpty;

    return status;
  }

  // ... (keep all existing helper methods unchanged)

  /// Calculate SHA-256 hash of file data
  static Future<String> _calculateSHA256(Uint8List data) async {
    final hash = await _sha256.hash(data);
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Encrypt file data using AES-GCM
  /// FIXED: Now combines ciphertext and MAC into single data structure
  static Future<Map<String, dynamic>> _encryptFileData(
    Uint8List fileData,
    SecretKey aesKey,
  ) async {
    try {
      // Generate random nonce for AES-GCM
      final nonce = _aesGcm.newNonce();

      // Encrypt the file data
      final secretBox = await _aesGcm.encrypt(
        fileData,
        secretKey: aesKey,
        nonce: nonce,
      );

      // Combine ciphertext and MAC into single byte array
      // Format: [ciphertext][16-byte MAC]
      final combinedData = Uint8List(secretBox.cipherText.length + 16);
      combinedData.setRange(
        0,
        secretBox.cipherText.length,
        secretBox.cipherText,
      );
      combinedData.setRange(
        secretBox.cipherText.length,
        combinedData.length,
        secretBox.mac.bytes,
      );

      return {
        'encryptedData': combinedData, // Now includes both ciphertext and MAC
        'nonce': nonce,
      };
    } catch (e) {
      throw Exception('Failed to encrypt file data: $e');
    }
  }

  /// Decrypt file data using AES-GCM (for future use)
  /// FIXED: Now properly separates MAC from combined data
  static Future<Uint8List> decryptFileData(
    Uint8List combinedData, // Contains both ciphertext and MAC
    List<int> nonce,
    SecretKey aesKey,
  ) async {
    try {
      // Separate ciphertext and MAC
      final cipherText = combinedData.sublist(0, combinedData.length - 16);
      final macBytes = combinedData.sublist(combinedData.length - 16);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
      final decryptedData = await _aesGcm.decrypt(secretBox, secretKey: aesKey);

      return Uint8List.fromList(decryptedData);
    } catch (e) {
      throw Exception('Failed to decrypt file data: $e');
    }
  }

  /// Create AES key from base64 string (for decryption)
  static Future<SecretKey> createAESKeyFromBase64(String base64Key) async {
    final keyBytes = base64Decode(base64Key);
    return SecretKey(keyBytes);
  }

  /// Uploads encrypted file to Pinata with original filename
  static Future<String?> _uploadToPinata(
    Uint8List encryptedBytes, // Now contains both ciphertext and MAC
    String fileName,
  ) async {
    try {
      final url = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');

      final request =
          http.MultipartRequest('POST', url)
            ..headers['Authorization'] = 'Bearer $_pinataJWT'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                encryptedBytes,
                filename: fileName,
              ),
            );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        print('Failed to upload to Pinata: ${response.body}');
        return null;
      }

      final ipfsJson = jsonDecode(response.body);
      return ipfsJson['IpfsHash'] as String;
    } catch (e) {
      print('Error uploading to Pinata: $e');
      return null;
    }
  }

  /// Stores RSA-encrypted AES package in File_Keys
  static Future<bool> _storeFileKey({
    required String fileId,
    required String encryptedKeyPackage,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final insertData = {
        'file_id': fileId,
        'recipient_type': 'user',
        'recipient_id': userId,
        'aes_key_encrypted': encryptedKeyPackage,
      };

      final result =
          await supabase.from('File_Keys').insert(insertData).select();
      print('File key inserted successfully: $result');
      return true;
    } catch (fileKeyError, stackTrace) {
      print('Error inserting file key: $fileKeyError');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}

// Helper class for navigation context (if not already existing)
class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
