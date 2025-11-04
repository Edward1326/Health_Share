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
  static final _sha256 = Sha256();

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
    bool skipVerification = false,
  }) async {
    final startTime = DateTime.now();
    print('⏱️ Group decryption started at: $startTime');

    try {
      final supabase = Supabase.instance.client;

      print('=== GROUP FILE DECRYPTION START ===');
      print('File ID: $fileId');
      print('Group ID: $groupId');
      print('User ID: $userId');
      print('IPFS CID: $ipfsCid');

      // Verify user has access to this file
      final hasAccess = await hasGroupFileAccess(fileId, groupId, userId);
      if (!hasAccess) {
        print('❌ User does not have access to this file');
        return null;
      }
      print('✅ User has access to file');

      // ═══════════════════════════════════════════════════════════
      // STEP 1: DOWNLOAD ENCRYPTED FILE FROM IPFS
      // ═══════════════════════════════════════════════════════════
      print('\n📥 === STEP 1: DOWNLOAD FROM IPFS ===');
      final downloadStart = DateTime.now();
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);

      if (encryptedBytes == null) {
        print('❌ Failed to download file from IPFS');
        return null;
      }

      final downloadDuration = DateTime.now().difference(downloadStart);
      print(
        '✅ Downloaded file size: ${encryptedBytes.length} bytes (${(encryptedBytes.length / 1024).toStringAsFixed(2)} KB)',
      );
      print('⏱️ Download time: ${downloadDuration.inMilliseconds}ms');

      // ═══════════════════════════════════════════════════════════
      // STEP 2: REHASH THE DOWNLOADED FILE
      // ═══════════════════════════════════════════════════════════
      if (!skipVerification) {
        print('\n🔐 === STEP 2: REHASH DOWNLOADED FILE ===');
        final hashStart = DateTime.now();

        final downloadedFileHash = await _calculateSHA256(encryptedBytes);

        final hashDuration = DateTime.now().difference(hashStart);
        print('✅ Rehashed downloaded file: $downloadedFileHash');
        print('⏱️ Hashing time: ${hashDuration.inMilliseconds}ms');

        // ═══════════════════════════════════════════════════════════
        // STEP 3: VERIFY BLOCKCHAIN INTEGRITY (Hive_Logs ↔ Blockchain)
        // ═══════════════════════════════════════════════════════════
        print('\n🔐 === STEP 3: BLOCKCHAIN INTEGRITY VERIFICATION ===');
        print('Verifying Hive_Logs against Blockchain...');

        // Get Hive username from .env
        final hiveUsername = dotenv.env['HIVE_ACCOUNT_NAME'];
        if (hiveUsername == null || hiveUsername.isEmpty) {
          print('❌ HIVE_ACCOUNT_NAME not found in .env');
          return null;
        }

        final blockchainVerification =
            await HiveCompareService.verifyBeforeDecryption(
              fileId: fileId,
              username: hiveUsername,
            );

        if (!blockchainVerification) {
          print('❌ BLOCKCHAIN INTEGRITY VERIFICATION FAILED');
          print('Hive_Logs hash does not match blockchain record');
          print('DECRYPTION ABORTED FOR SECURITY');
          return null;
        }

        print('✅ BLOCKCHAIN INTEGRITY VERIFIED');
        print('Hive_Logs ↔ Blockchain match confirmed');

        // ═══════════════════════════════════════════════════════════
        // STEP 4: VERIFY FILE INTEGRITY (Downloaded File ↔ Blockchain)
        // ═══════════════════════════════════════════════════════════
        print('\n🔐 === STEP 4: FILE INTEGRITY VERIFICATION ===');
        print('Comparing downloaded file hash with blockchain record...');

        // Get the confirmed hash from Hive_Logs (which we just verified matches blockchain)
        final hiveLogRecord =
            await supabase
                .from('Hive_Logs')
                .select('file_hash')
                .eq('file_id', fileId)
                .maybeSingle();

        if (hiveLogRecord == null) {
          print('❌ No Hive_Logs record found');
          return null;
        }

        final blockchainConfirmedHash = hiveLogRecord['file_hash'] as String;

        print('Downloaded file hash: $downloadedFileHash');
        print('Blockchain hash:       $blockchainConfirmedHash');

        if (downloadedFileHash != blockchainConfirmedHash) {
          print('❌ FILE INTEGRITY VERIFICATION FAILED');
          print('Downloaded file hash DOES NOT match blockchain record');
          print('The file may have been tampered with or corrupted on IPFS');
          print('DECRYPTION ABORTED FOR SECURITY');
          return null;
        }

        print('✅ FILE INTEGRITY VERIFIED');
        print('Downloaded file matches blockchain record');
        print('✅ ALL SECURITY CHECKS PASSED - Proceeding with decryption');
      } else {
        print('⚠️ WARNING: All verification steps skipped');
      }

      // ═══════════════════════════════════════════════════════════
      // STEP 5: DECRYPT THE FILE (Only if all checks passed)
      // ═══════════════════════════════════════════════════════════
      print('\n🔓 === STEP 5: DECRYPTION ===');

      // Get group's RSA private key
      print('Fetching group RSA private key...');
      final groupData =
          await supabase
              .from('Group')
              .select('rsa_private_key')
              .eq('id', groupId)
              .single();

      final groupRsaPrivateKeyPem = groupData['rsa_private_key'] as String;
      print('✅ Retrieved group RSA private key');

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
      print('✅ Retrieved encrypted AES key package');

      // Decrypt AES key package using group's RSA private key with fallback
      print('Decrypting AES key package...');
      final rsaDecryptStart = DateTime.now();
      String? decryptedKeyJson;

      try {
        // Try RSA-OAEP first (for new group shares)
        decryptedKeyJson = await RSA.decryptOAEP(
          encryptedKeyPackage,
          "",
          Hash.SHA256,
          groupRsaPrivateKeyPem,
        );
        final rsaDecryptDuration = DateTime.now().difference(rsaDecryptStart);
        print('✅ Successfully decrypted using RSA-OAEP');
        print('⏱️ RSA decryption time: ${rsaDecryptDuration.inMilliseconds}ms');
      } catch (e) {
        print('⚠️ RSA-OAEP decryption failed: $e');
        print('Attempting fallback to PKCS1v15 for backward compatibility...');
        try {
          decryptedKeyJson = await RSA.decryptPKCS1v15(
            encryptedKeyPackage,
            groupRsaPrivateKeyPem,
          );
          final rsaDecryptDuration = DateTime.now().difference(rsaDecryptStart);
          print('✅ Successfully decrypted using PKCS1v15 fallback');
          print(
            '⏱️ RSA decryption time (fallback): ${rsaDecryptDuration.inMilliseconds}ms',
          );
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

      print('✅ Successfully extracted AES key and nonce');

      // Create SecretKey from bytes
      final aesKey = SecretKey(aesKeyBytes);

      // Decrypt file using AES-GCM
      final aesDecryptStart = DateTime.now();
      final decryptedBytes = await _decryptFileData(
        encryptedBytes,
        nonceBytes,
        aesKey,
      );

      if (decryptedBytes == null) {
        print('❌ Failed to decrypt file data');
        return null;
      }

      final aesDecryptDuration = DateTime.now().difference(aesDecryptStart);
      print(
        '⏱️ AES-GCM decryption time: ${aesDecryptDuration.inMilliseconds}ms',
      );
      print(
        '📄 Decrypted file size: ${decryptedBytes.length} bytes (${(decryptedBytes.length / 1024).toStringAsFixed(2)} KB)',
      );

      // Calculate total time
      final totalDuration = DateTime.now().difference(startTime);
      print('\n✅ === GROUP DECRYPTION COMPLETE ===');
      print(
        '⏱️ Total decryption time: ${totalDuration.inMilliseconds}ms (${(totalDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)',
      );
      print(
        '📊 Decryption speed: ${(encryptedBytes.length / 1024 / (totalDuration.inMilliseconds / 1000)).toStringAsFixed(2)} KB/s',
      );

      return decryptedBytes;
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(startTime);
      print('❌ Error during group file decryption: $e');
      print('⏱️ Failed after: ${errorDuration.inMilliseconds}ms');
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
    bool skipVerification = false,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== DECRYPTING FILE FOR GROUP MEMBER ===');
      print('File ID: $fileId');
      print('User ID: $userId');
      print('Group ID: $groupId');
      print('IPFS CID: $ipfsCid');

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
          // Download once for user key attempt
          final encryptedBytes = await _downloadFromIPFS(ipfsCid);
          if (encryptedBytes == null) {
            print('❌ Failed to download file from IPFS');
            return null;
          }

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
            print('✅ Successfully decrypted using user key');
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
          skipVerification: skipVerification,
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
          skipVerification: skipVerification,
        );

        if (result != null) {
          print('✅ Successfully decrypted using group key: $testGroupId');
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

  /// Calculate SHA-256 hash of file data
  static Future<String> _calculateSHA256(Uint8List data) async {
    final hash = await _sha256.hash(data);
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
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
        print('❌ Combined data too short, must be at least 16 bytes for MAC');
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
      print('❌ AES-GCM decryption failed: $e');
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
      print(
        'Downloading from IPFS: https://apricot-delicate-vole-342.mypinata.cloud/ipfs/$cid',
      );
      final response = await http.get(
        Uri.parse('https://apricot-delicate-vole-342.mypinata.cloud/ipfs/$cid'),
        headers: {'Accept': '*/*'},
      );

      if (response.statusCode == 200) {
        print(
          '✅ Successfully downloaded from IPFS. Size: ${response.bodyBytes.length} bytes',
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
