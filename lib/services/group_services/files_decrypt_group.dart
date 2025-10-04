import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart' hide Hash;
import 'package:fast_rsa/fast_rsa.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:health_share/services/hive_service/verify_hive/hive_compare.dart';

class FilesDecryptGroup {
  // Cryptography instances
  static final _aesGcm = AesGcm.with256bits();

  /// Check if current user has access to a specific file in a group
  static Future<bool> hasGroupFileAccess(
    String fileId,
    String groupId,
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if user is a member of the group
      final memberCheck =
          await supabase
              .from('Group_Members')
              .select('id')
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (memberCheck == null) {
        print('User $userId is not a member of group $groupId');
        return false;
      }

      // Check if file is shared with the group
      final shareCheck =
          await supabase
              .from('File_Shares')
              .select('id')
              .eq('file_id', fileId)
              .eq('shared_with_group_id', groupId)
              .maybeSingle();

      return shareCheck != null;
    } catch (e) {
      print('Error checking group file access: $e');
      return false;
    }
  }

  /// Decrypt a shared file using group's RSA private key with RSA-OAEP
  static Future<Uint8List?> decryptGroupSharedFile({
    required String fileId,
    required String groupId,
    required String userId,
    required String ipfsCid,
    bool skipVerification = false, // Add this parameter
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== GROUP FILE DECRYPTION DEBUG ===');
      print('File ID: $fileId');
      print('Group ID: $groupId');
      print('User ID: $userId');
      print('IPFS CID: $ipfsCid');

      // 🔒 STEP 1: Verify blockchain integrity FIRST
      if (!skipVerification) {
        print('\n🔐 === BLOCKCHAIN VERIFICATION START ===');
        print('Verifying file integrity against Hive blockchain...');

        // Get Hive username from .env
        final hiveUsername = dotenv.env['HIVE_ACCOUNT_NAME'];
        if (hiveUsername == null || hiveUsername.isEmpty) {
          print('❌ HIVE_ACCOUNT_NAME not found in .env');
          return null;
        }

        final isVerified = await HiveCompareService.verifyBeforeDecryption(
          fileId: fileId,
          username: hiveUsername,
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

      // Verify user has access to this file
      final hasAccess = await hasGroupFileAccess(fileId, groupId, userId);
      if (!hasAccess) {
        print('❌ User does not have access to this file');
        return null;
      }
      print('✓ User has access to file');

      // Download encrypted file from IPFS
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        print('❌ Failed to download file from IPFS');
        return null;
      }
      print('✓ Downloaded ${encryptedBytes.length} bytes from IPFS');

      // Get group's RSA private key
      print('Fetching group RSA private key...');
      final groupData =
          await supabase
              .from('Group')
              .select('rsa_private_key')
              .eq('id', groupId)
              .single();

      final groupRsaPrivateKeyPem = groupData['rsa_private_key'] as String;
      print('✓ Retrieved group RSA private key');

      // Get encrypted AES key package for this group
      print('Fetching group file key package...');
      final groupFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted')
              .eq('file_id', fileId)
              .eq('recipient_type', 'group')
              .eq('recipient_id', groupId)
              .maybeSingle();

      if (groupFileKey == null || groupFileKey['aes_key_encrypted'] == null) {
        print('❌ AES key package not found for group access to file: $fileId');
        return null;
      }

      final encryptedKeyPackage = groupFileKey['aes_key_encrypted'] as String;
      print(
        '✓ Retrieved encrypted AES key package, length: ${encryptedKeyPackage.length}',
      );

      // Decrypt AES key package using group's RSA private key with fallback
      print('Decrypting AES key package...');
      String? decryptedKeyJson;
      try {
        // Try RSA-OAEP first (for new group shares)
        decryptedKeyJson = await RSA.decryptOAEP(
          encryptedKeyPackage,
          "",
          Hash.SHA256,
          groupRsaPrivateKeyPem,
        );
        print('✓ Successfully decrypted using RSA-OAEP');
      } catch (e) {
        print('RSA-OAEP decryption failed, trying PKCS1v15 fallback: $e');
        try {
          decryptedKeyJson = await RSA.decryptPKCS1v15(
            encryptedKeyPackage,
            groupRsaPrivateKeyPem,
          );
          print('✓ Successfully decrypted using PKCS1v15 fallback');
        } catch (fallbackError) {
          print('❌ Both RSA decryption methods failed: $fallbackError');
          return null;
        }
      }

      // Parse the JSON to get key and nonce
      final keyData = jsonDecode(decryptedKeyJson);
      final aesKeyBase64 = keyData['key'] as String;
      final nonceBase64 = keyData['nonce'] as String;

      // Convert from base64 to bytes
      final aesKeyBytes = base64Decode(aesKeyBase64);
      final nonceBytes = base64Decode(nonceBase64);

      print('✓ Successfully decrypted AES key package');
      print('AES key length: ${aesKeyBytes.length} bytes');
      print('Nonce length: ${nonceBytes.length} bytes');

      // Create SecretKey from bytes
      final aesKey = SecretKey(aesKeyBytes);

      // Decrypt file using AES-GCM with cryptography package
      print('Decrypting file data using AES-GCM...');
      final decryptedBytes = await _decryptFileData(
        encryptedBytes,
        nonceBytes,
        aesKey,
      );

      if (decryptedBytes == null) {
        print('❌ Failed to decrypt file data');
        return null;
      }

      print('✓ Successfully decrypted group shared file');
      print('Decrypted size: ${decryptedBytes.length} bytes');
      print('=== GROUP FILE DECRYPTION COMPLETED ===');

      return decryptedBytes;
    } catch (e, stackTrace) {
      print('❌ Error during group file decryption: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Decrypt file for group member using either user's own key or group key
  /// This method tries both approaches for maximum compatibility
  static Future<Uint8List?> decryptFileForGroupMember({
    required String fileId,
    required String userId,
    required String ipfsCid,
    String? groupId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== DECRYPTING FILE FOR GROUP MEMBER ===');
      print('File ID: $fileId');
      print('User ID: $userId');
      print('Group ID: $groupId');
      print('IPFS CID: $ipfsCid');

      // Download encrypted file from IPFS first
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        print('❌ Failed to download file from IPFS');
        return null;
      }
      print('✓ Downloaded ${encryptedBytes.length} bytes from IPFS');

      // Try user's own key first (if they uploaded the file)
      print('Attempting decryption with user key...');
      try {
        final userData =
            await supabase
                .from('User')
                .select('rsa_private_key')
                .eq('id', userId)
                .single();

        final userRsaPrivateKeyPem = userData['rsa_private_key'] as String;

        final userFileKey =
            await supabase
                .from('File_Keys')
                .select('aes_key_encrypted')
                .eq('file_id', fileId)
                .eq('recipient_type', 'user')
                .eq('recipient_id', userId)
                .maybeSingle();

        if (userFileKey != null) {
          final encryptedKeyPackage =
              userFileKey['aes_key_encrypted'] as String;

          // Try RSA-OAEP first, fallback to PKCS1v15
          String? decryptedKeyJson;
          try {
            decryptedKeyJson = await RSA.decryptOAEP(
              encryptedKeyPackage,
              "",
              Hash.SHA256,
              userRsaPrivateKeyPem,
            );
          } catch (e) {
            decryptedKeyJson = await RSA.decryptPKCS1v15(
              encryptedKeyPackage,
              userRsaPrivateKeyPem,
            );
          }

          final keyData = jsonDecode(decryptedKeyJson);
          final aesKeyBase64 = keyData['key'] as String;
          final nonceBase64 = keyData['nonce'] as String;

          final aesKeyBytes = base64Decode(aesKeyBase64);
          final nonceBytes = base64Decode(nonceBase64);
          final aesKey = SecretKey(aesKeyBytes);

          final decryptedBytes = await _decryptFileData(
            encryptedBytes,
            nonceBytes,
            aesKey,
          );

          if (decryptedBytes != null) {
            print('✓ Successfully decrypted using user key');
            return decryptedBytes;
          }
        }
      } catch (userKeyError) {
        print('User key decryption failed: $userKeyError');
      }

      // If user key didn't work and we have a group ID, try group key
      if (groupId != null) {
        print('Attempting decryption with group key...');
        return await decryptGroupSharedFile(
          fileId: fileId,
          groupId: groupId,
          userId: userId,
          ipfsCid: ipfsCid,
        );
      }

      // If no group ID provided, try to find which groups this file is shared with
      print('Finding groups this file is shared with...');
      final userGroups = await supabase
          .from('Group_Members')
          .select('group_id')
          .eq('user_id', userId);

      for (final membership in userGroups) {
        final testGroupId = membership['group_id'] as String;
        print('Trying group: $testGroupId');

        final result = await decryptGroupSharedFile(
          fileId: fileId,
          groupId: testGroupId,
          userId: userId,
          ipfsCid: ipfsCid,
        );

        if (result != null) {
          print('✓ Successfully decrypted using group key: $testGroupId');
          return result;
        }
      }

      print('❌ Could not decrypt file with any available keys');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error in decryptFileForGroupMember: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Decrypt file data using AES-GCM with cryptography package
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
          '✓ Successfully downloaded from IPFS. Size: ${response.bodyBytes.length} bytes',
        );
        return response.bodyBytes;
      } else {
        print(
          '❌ Failed to fetch from IPFS: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Error downloading from IPFS: $e');
      return null;
    }
  }

  /// Helper method to create SecretKey from base64 string
  static SecretKey createSecretKeyFromBase64(String base64Key) {
    final keyBytes = base64Decode(base64Key);
    return SecretKey(keyBytes);
  }
}
