import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart' hide Hash;
import 'package:fast_rsa/fast_rsa.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/hive_service/verify_hive/hive_compare.dart';

class DecryptFileService {
  // Cryptography instances
  static final _aesGcm = AesGcm.with256bits();

  /// Decrypts a file from IPFS with blockchain verification
  ///
  /// This method now includes a critical security step:
  /// 1. VERIFY blockchain integrity BEFORE decryption
  /// 2. Only proceed with decryption if verification passes
  ///
  /// Parameters:
  /// - cid: IPFS content identifier
  /// - fileId: File ID from Supabase
  /// - userId: User ID requesting decryption
  /// - username: Hive username for blockchain verification
  /// - skipVerification: Set to true to bypass blockchain check (NOT RECOMMENDED)
  ///
  /// Returns decrypted file bytes or null if verification/decryption fails
  static Future<Uint8List?> decryptFileFromIpfs({
    required String cid,
    required String fileId,
    required String userId,
    required String username,
    bool skipVerification = false,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('Starting decryption for CID: $cid, File ID: $fileId');

      // 🔒 CRITICAL SECURITY STEP: Verify blockchain integrity FIRST
      if (!skipVerification) {
        print('\n🔐 === BLOCKCHAIN VERIFICATION START ===');
        print('Verifying file integrity against Hive blockchain...');

        final isVerified = await HiveCompareService.verifyBeforeDecryption(
          fileId: fileId,
          username: username,
        );

        if (!isVerified) {
          print('❌ BLOCKCHAIN VERIFICATION FAILED');
          print('File hash does not match blockchain record');
          print('DECRYPTION ABORTED FOR SECURITY');
          print('=== BLOCKCHAIN VERIFICATION END ===\n');
          return null;
        }

        print('✅ BLOCKCHAIN VERIFICATION PASSED');
        print('File integrity confirmed - proceeding with decryption');
        print('=== BLOCKCHAIN VERIFICATION END ===\n');
      } else {
        print('⚠️ WARNING: Blockchain verification skipped');
      }

      // 1. Download encrypted file from IPFS
      final encryptedBytes = await _downloadFromIPFS(cid);
      if (encryptedBytes == null) {
        print('Failed to download file from IPFS');
        return null;
      }
      print('Downloaded ${encryptedBytes.length} bytes from IPFS');

      // 2. Get current user's RSA private key from Supabase
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;
      print('Retrieved RSA private key from user data');

      // 3. Get encrypted AES key+nonce JSON from Supabase
      final fileKeyRecord =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      if (fileKeyRecord == null || fileKeyRecord['aes_key_encrypted'] == null) {
        print(
          'AES key not found in File_Keys for file_id: $fileId and user_id: $userId',
        );
        return null;
      }

      final encryptedKeyPackage = fileKeyRecord['aes_key_encrypted'] as String;
      print('Retrieved encrypted AES key package from database');

      // 4. Decrypt AES key package using RSA-OAEP
      String? decryptedJson;
      try {
        decryptedJson = await RSA.decryptOAEP(
          encryptedKeyPackage,
          "",
          Hash.SHA256,
          rsaPrivateKeyPem,
        );
        print('Successfully decrypted AES key package');
      } catch (e) {
        print('RSA-OAEP decryption failed: $e');

        // Fallback to PKCS1v15 for backward compatibility
        print('Attempting fallback to PKCS1v15 for backward compatibility...');
        try {
          decryptedJson = await RSA.decryptPKCS1v15(
            encryptedKeyPackage,
            rsaPrivateKeyPem,
          );
          print('Successfully decrypted using PKCS1v15 fallback');
        } catch (fallbackError) {
          print('PKCS1v15 fallback also failed: $fallbackError');
          return null;
        }
      }

      final keyData = jsonDecode(decryptedJson);
      final aesKeyBase64 = keyData['key'] as String;
      final nonceBase64 = keyData['nonce'] as String;

      // Convert from base64 to bytes
      final aesKeyBytes = base64Decode(aesKeyBase64);
      final nonceBytes = base64Decode(nonceBase64);

      print('Successfully extracted AES key and nonce');

      // 5. Create SecretKey from bytes
      final aesKey = SecretKey(aesKeyBytes);

      // 6. Decrypt file using AES-GCM
      final decryptedBytes = await _decryptFileData(
        encryptedBytes,
        nonceBytes,
        aesKey,
      );

      if (decryptedBytes == null) {
        print('Failed to decrypt file data');
        return null;
      }

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );

      return decryptedBytes;
    } catch (e, st) {
      print('Error during decryption flow: $e');
      print('Stack trace: $st');
      return null;
    }
  }

  /// Batch decrypt multiple files with blockchain verification
  ///
  /// Efficiently verifies and decrypts multiple files in sequence
  /// Returns a map of fileId -> decrypted bytes (or null if failed)
  static Future<Map<String, Uint8List?>> decryptMultipleFiles({
    required List<Map<String, String>> files, // [{fileId, cid, username}]
    required String userId,
    bool skipVerification = false,
  }) async {
    print('=== BATCH DECRYPTION START ===');
    print('Files to decrypt: ${files.length}');

    final results = <String, Uint8List?>{};

    for (final file in files) {
      final fileId = file['fileId']!;
      final cid = file['cid']!;
      final username = file['username']!;

      print('\nDecrypting file: $fileId');

      final decryptedBytes = await decryptFileFromIpfs(
        cid: cid,
        fileId: fileId,
        userId: userId,
        username: username,
        skipVerification: skipVerification,
      );

      results[fileId] = decryptedBytes;
    }

    final successCount = results.values.where((v) => v != null).length;
    final failCount = files.length - successCount;

    print('\n=== BATCH DECRYPTION END ===');
    print('Success: $successCount / ${files.length}');
    print('Failed: $failCount / ${files.length}');

    return results;
  }

  /// Decrypt file data using AES-GCM
  /// FIXED: Properly separates MAC from combined encrypted data
  static Future<Uint8List?> _decryptFileData(
    Uint8List combinedData, // Contains both ciphertext and MAC
    List<int> nonce,
    SecretKey aesKey,
  ) async {
    try {
      print(
        'Attempting to decrypt ${combinedData.length} bytes of combined data',
      );

      // Check if we have enough data (at least 16 bytes for MAC)
      if (combinedData.length < 16) {
        print(
          'Error: Combined data too short, must be at least 16 bytes for MAC',
        );
        return null;
      }

      // Separate ciphertext and MAC
      // Format: [ciphertext][16-byte MAC]
      final cipherText = combinedData.sublist(0, combinedData.length - 16);
      final macBytes = combinedData.sublist(combinedData.length - 16);

      print(
        'Separated ciphertext: ${cipherText.length} bytes, MAC: ${macBytes.length} bytes',
      );

      // Create SecretBox with proper MAC
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      final decryptedData = await _aesGcm.decrypt(secretBox, secretKey: aesKey);

      return Uint8List.fromList(decryptedData);
    } catch (e) {
      print('AES-GCM decryption failed: $e');
      print('This might be due to incorrect MAC separation or corrupted data');

      // Try alternative approaches for backward compatibility
      return await _tryAlternativeDecryption(combinedData, nonce, aesKey);
    }
  }

  /// Try alternative decryption methods for backward compatibility
  static Future<Uint8List?> _tryAlternativeDecryption(
    Uint8List encryptedData,
    List<int> nonce,
    SecretKey aesKey,
  ) async {
    print('Trying alternative decryption methods...');

    // Method 1: Try with Mac.empty (for old data without proper MAC storage)
    try {
      print('Attempting decryption with Mac.empty');
      final secretBox = SecretBox(encryptedData, nonce: nonce, mac: Mac.empty);

      final decryptedData = await _aesGcm.decrypt(secretBox, secretKey: aesKey);
      print('✅ Success with Mac.empty method');
      return Uint8List.fromList(decryptedData);
    } catch (e) {
      print('Mac.empty method failed: $e');
    }

    // Method 2: Try assuming MAC is at the beginning (alternative format)
    try {
      if (encryptedData.length > 16) {
        print('Attempting decryption with MAC at beginning');
        final macBytes = encryptedData.sublist(0, 16);
        final cipherText = encryptedData.sublist(16);

        final secretBox = SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        );

        final decryptedData = await _aesGcm.decrypt(
          secretBox,
          secretKey: aesKey,
        );
        print('✅ Success with MAC-at-beginning method');
        return Uint8List.fromList(decryptedData);
      }
    } catch (e) {
      print('MAC-at-beginning method failed: $e');
    }

    print('❌ All decryption methods failed');
    return null;
  }

  /// Downloads file from IPFS using CID
  static Future<Uint8List?> _downloadFromIPFS(String cid) async {
    try {
      print('Downloading from IPFS: https://gateway.pinata.cloud/ipfs/$cid');
      final response = await http.get(
        Uri.parse('https://gateway.pinata.cloud/ipfs/$cid'),
        headers: {'Accept': '*/*'},
      );

      if (response.statusCode == 200) {
        print(
          'Successfully downloaded from IPFS. Size: ${response.bodyBytes.length} bytes',
        );
        return response.bodyBytes;
      } else {
        print(
          'Failed to fetch from IPFS: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error downloading from IPFS: $e');
      return null;
    }
  }

  /// Fetches all files for the current user from Supabase
  static Future<List<Map<String, dynamic>>> fetchUserFiles(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final files = await supabase
          .from('Files')
          .select(
            'id, filename, file_type, file_size, uploaded_at, ipfs_cid, category, sha256_hash',
          )
          .eq('uploaded_by', userId)
          .order('uploaded_at', ascending: false);

      print('Fetched ${files.length} files from database');
      return files;
    } catch (e) {
      print('Error fetching files: $e');
      return [];
    }
  }

  /// Helper method to create SecretKey from base64 string
  static SecretKey createSecretKeyFromBase64(String base64Key) {
    final keyBytes = base64Decode(base64Key);
    return SecretKey(keyBytes);
  }

  /// Get decryption key for a specific file (useful for sharing files)
  static Future<Map<String, dynamic>?> getFileDecryptionKey({
    required String fileId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Get user's RSA private key
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;

      // Get encrypted AES key package
      final fileKeyRecord =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      if (fileKeyRecord == null || fileKeyRecord['aes_key_encrypted'] == null) {
        return null;
      }

      final encryptedKeyPackage = fileKeyRecord['aes_key_encrypted'] as String;

      // Try to decrypt with RSA-OAEP first, fallback to PKCS1v15
      String? decryptedJson;
      try {
        decryptedJson = await RSA.decryptOAEP(
          encryptedKeyPackage,
          "",
          Hash.SHA256,
          rsaPrivateKeyPem,
        );
      } catch (e) {
        print('RSA-OAEP decryption failed, trying PKCS1v15 fallback: $e');
        decryptedJson = await RSA.decryptPKCS1v15(
          encryptedKeyPackage,
          rsaPrivateKeyPem,
        );
      }

      final keyData = jsonDecode(decryptedJson);

      return {'aesKey': keyData['key'], 'nonce': keyData['nonce']};
    } catch (e) {
      print('Error getting decryption key: $e');
      return null;
    }
  }

  /// Check if a file can be decrypted (verifies blockchain integrity)
  /// Useful for pre-flight checks before attempting decryption
  static Future<bool> canDecryptFile({
    required String fileId,
    required String username,
  }) async {
    try {
      print('Checking if file can be decrypted: $fileId');

      final isVerified = await HiveCompareService.verifyBeforeDecryption(
        fileId: fileId,
        username: username,
      );

      if (isVerified) {
        print('✅ File can be decrypted - blockchain verification passed');
      } else {
        print('❌ File cannot be decrypted - blockchain verification failed');
      }

      return isVerified;
    } catch (e) {
      print('Error checking decryption eligibility: $e');
      return false;
    }
  }
}
