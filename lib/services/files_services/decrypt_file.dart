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
  static final _sha256 = Sha256();

  /// Decrypts a file from IPFS with THREE-WAY verification
  ///
  /// CORRECT SECURITY FLOW:
  /// 1. Download encrypted file from IPFS
  /// 2. Rehash the downloaded file (SHA-256)
  /// 3. Verify blockchain integrity (Hive_Logs ↔ Blockchain)
  /// 4. Verify file integrity (Downloaded file ↔ Blockchain)
  /// 5. Only decrypt if ALL verifications pass
  ///
  /// Parameters:
  /// - cid: IPFS content identifier
  /// - fileId: File ID from Supabase
  /// - userId: User ID requesting decryption
  /// - username: Hive username for blockchain verification
  /// - skipVerification: Set to true to bypass verification (NOT RECOMMENDED)
  ///
  /// Returns decrypted file bytes or null if verification/decryption fails
  static Future<Uint8List?> decryptFileFromIpfs({
    required String cid,
    required String fileId,
    required String userId,
    required String username,
    bool skipVerification = false,
  }) async {
    // Start timing the entire decryption process
    final startTime = DateTime.now();
    print('⏱️ Decryption started at: $startTime');

    try {
      final supabase = Supabase.instance.client;

      print('Starting decryption for CID: $cid, File ID: $fileId');

      // ═══════════════════════════════════════════════════════════
      // STEP 1: DOWNLOAD ENCRYPTED FILE FROM IPFS
      // ═══════════════════════════════════════════════════════════
      print('\n📥 === STEP 1: DOWNLOAD FROM IPFS ===');
      final downloadStart = DateTime.now();
      final encryptedBytes = await _downloadFromIPFS(cid);

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

        final blockchainVerification =
            await HiveCompareService.verifyBeforeDecryption(
              fileId: fileId,
              username: username,
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

      // Get current user's RSA private key from Supabase
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;
      print('Retrieved RSA private key from user data');

      // Get encrypted AES key+nonce JSON from Supabase
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
          '❌ AES key not found in File_Keys for file_id: $fileId and user_id: $userId',
        );
        return null;
      }

      final encryptedKeyPackage = fileKeyRecord['aes_key_encrypted'] as String;
      print('Retrieved encrypted AES key package from database');

      // Decrypt AES key package using RSA-OAEP
      final rsaDecryptStart = DateTime.now();
      String? decryptedJson;

      try {
        decryptedJson = await RSA.decryptOAEP(
          encryptedKeyPackage,
          "",
          Hash.SHA256,
          rsaPrivateKeyPem,
        );
        final rsaDecryptDuration = DateTime.now().difference(rsaDecryptStart);
        print('✅ Successfully decrypted AES key package');
        print('⏱️ RSA decryption time: ${rsaDecryptDuration.inMilliseconds}ms');
      } catch (e) {
        print('⚠️ RSA-OAEP decryption failed: $e');
        print('Attempting fallback to PKCS1v15 for backward compatibility...');

        try {
          decryptedJson = await RSA.decryptPKCS1v15(
            encryptedKeyPackage,
            rsaPrivateKeyPem,
          );
          final rsaDecryptDuration = DateTime.now().difference(rsaDecryptStart);
          print('✅ Successfully decrypted using PKCS1v15 fallback');
          print(
            '⏱️ RSA decryption time (fallback): ${rsaDecryptDuration.inMilliseconds}ms',
          );
        } catch (fallbackError) {
          print('❌ PKCS1v15 fallback also failed: $fallbackError');
          return null;
        }
      }

      final keyData = jsonDecode(decryptedJson);
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
      print('\n✅ === DECRYPTION COMPLETE ===');
      print(
        '⏱️ Total decryption time: ${totalDuration.inMilliseconds}ms (${(totalDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)',
      );
      print(
        '📊 Decryption speed: ${(encryptedBytes.length / 1024 / (totalDuration.inMilliseconds / 1000)).toStringAsFixed(2)} KB/s',
      );

      return decryptedBytes;
    } catch (e, st) {
      final errorDuration = DateTime.now().difference(startTime);
      print('❌ Error during decryption flow: $e');
      print('⏱️ Failed after: ${errorDuration.inMilliseconds}ms');
      print('Stack trace: $st');
      return null;
    }
  }

  /// Batch decrypt multiple files with three-way verification
  ///
  /// Efficiently verifies and decrypts multiple files in sequence
  /// Returns a map of fileId -> decrypted bytes (or null if failed)
  static Future<Map<String, Uint8List?>> decryptMultipleFiles({
    required List<Map<String, String>> files, // [{fileId, cid, username}]
    required String userId,
    bool skipVerification = false,
  }) async {
    final batchStartTime = DateTime.now();
    print('=== BATCH DECRYPTION START ===');
    print('⏱️ Batch started at: $batchStartTime');
    print('Files to decrypt: ${files.length}');

    final results = <String, Uint8List?>{};
    int totalBytes = 0;

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
      if (decryptedBytes != null) {
        totalBytes += decryptedBytes.length;
      }
    }

    final successCount = results.values.where((v) => v != null).length;
    final failCount = files.length - successCount;
    final batchDuration = DateTime.now().difference(batchStartTime);

    print('\n=== BATCH DECRYPTION END ===');
    print('Success: $successCount / ${files.length}');
    print('Failed: $failCount / ${files.length}');
    print(
      '📦 Total data decrypted: ${totalBytes} bytes (${(totalBytes / 1024).toStringAsFixed(2)} KB)',
    );
    print(
      '⏱️ Total batch time: ${batchDuration.inMilliseconds}ms (${(batchDuration.inMilliseconds / 1000).toStringAsFixed(2)}s)',
    );
    if (successCount > 0) {
      print(
        '📊 Average time per file: ${(batchDuration.inMilliseconds / successCount).toStringAsFixed(2)}ms',
      );
    }

    return results;
  }

  /// Calculate SHA-256 hash of file data
  static Future<String> _calculateSHA256(Uint8List data) async {
    final hash = await _sha256.hash(data);
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Decrypt file data using AES-GCM
  /// Properly separates MAC from combined encrypted data
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
}
