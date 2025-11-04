import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart' hide Hash;
import 'package:pointycastle/export.dart' hide Mac;
import 'package:asn1lib/asn1lib.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:health_share/services/hive_service/verify_hive/hive_compare.dart';
import 'package:fast_rsa/fast_rsa.dart';

class OrgFilesDecryptService {
  static final _supabase = Supabase.instance.client;
  static final _aesGcm = AesGcm.with256bits();
  static final _sha256 = Sha256();

  /// Get the current authenticated user or throw an error
  static User get _currentUser {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }
    return user;
  }

  /// Decrypt a file shared between doctor and patient using PointyCastle RSA
  ///
  /// CORRECT SECURITY FLOW:
  /// 1. Download encrypted file from IPFS
  /// 2. Rehash the downloaded file (SHA-256)
  /// 3. Verify blockchain integrity (Hive_Logs ↔ Blockchain)
  /// 4. Verify file integrity (Downloaded file ↔ Blockchain)
  /// 5. Only decrypt if ALL verifications pass
  static Future<Uint8List?> decryptSharedFile({
    required String fileId,
    required String ipfsCid,
    required String sharedBy,
    required String doctorId,
    bool skipVerification = false,
  }) async {
    final startTime = DateTime.now();
    print('⏱️ Decryption started at: $startTime');

    try {
      print('=== ORG FILE DECRYPTION DEBUG ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');
      print('Shared by: $sharedBy');
      print('Doctor ID: $doctorId');

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
            await _supabase
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

      // Get current user's RSA private key
      final userData =
          await _supabase
              .from('User')
              .select('id, rsa_private_key, email')
              .eq('id', _currentUser.id)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String?;
      if (rsaPrivateKeyPem == null || rsaPrivateKeyPem.isEmpty) {
        throw Exception('User RSA private key is missing');
      }

      print('✓ Retrieved RSA private key for user: ${userData['email']}');

      // Get the encrypted AES key
      final fileKeyRecord =
          await _supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', _currentUser.id)
              .maybeSingle();

      if (fileKeyRecord == null || fileKeyRecord['aes_key_encrypted'] == null) {
        throw Exception('No decryption key found for this file');
      }

      // Decrypt the file with PointyCastle and Fast RSA fallback
      final decryptedBytes = await _performDecryptionWithFallback(
        encryptedBytes,
        fileKeyRecord['aes_key_encrypted'] as String,
        fileKeyRecord['nonce_hex'] as String?,
        rsaPrivateKeyPem,
      );

      if (decryptedBytes == null) {
        print('❌ Failed to decrypt file data');
        return null;
      }

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
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(startTime);
      print('❌ Error in decryptSharedFile: $e');
      print('⏱️ Failed after: ${errorDuration.inMilliseconds}ms');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Alternative method that doesn't require knowing the sharing direction
  ///
  /// CORRECT SECURITY FLOW:
  /// 1. Download encrypted file from IPFS
  /// 2. Rehash the downloaded file (SHA-256)
  /// 3. Verify blockchain integrity (Hive_Logs ↔ Blockchain)
  /// 4. Verify file integrity (Downloaded file ↔ Blockchain)
  /// 5. Only decrypt if ALL verifications pass
  static Future<Uint8List?> decryptSharedFileSimple({
    required String fileId,
    required String ipfsCid,
    bool skipVerification = false,
  }) async {
    final startTime = DateTime.now();
    print('⏱️ Simple decryption started at: $startTime');

    try {
      print('=== SIMPLE ORG FILE DECRYPTION ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');

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
            await _supabase
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

      // Get user's RSA private key
      final userData =
          await _supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', _currentUser.id)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;

      // Try to get the encrypted AES key for current user
      final fileKeyRecords = await _supabase
          .from('File_Keys')
          .select('aes_key_encrypted, nonce_hex')
          .eq('file_id', fileId)
          .eq('recipient_type', 'user')
          .eq('recipient_id', _currentUser.id);

      if (fileKeyRecords.isEmpty) {
        throw Exception('No decryption key found for this file');
      }

      // Use the first valid key found
      final fileKeyRecord = fileKeyRecords.first;

      final decryptedBytes = await _performDecryptionWithFallback(
        encryptedBytes,
        fileKeyRecord['aes_key_encrypted'] as String,
        fileKeyRecord['nonce_hex'] as String?,
        rsaPrivateKeyPem,
      );

      if (decryptedBytes == null) {
        print('❌ Failed to decrypt file data');
        return null;
      }

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
    } catch (e, stackTrace) {
      final errorDuration = DateTime.now().difference(startTime);
      print('❌ Error in decryptSharedFileSimple: $e');
      print('⏱️ Failed after: ${errorDuration.inMilliseconds}ms');
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

  /// Perform decryption with PointyCastle RSA first, then Fast RSA fallback
  static Future<Uint8List?> _performDecryptionWithFallback(
    Uint8List encryptedBytes,
    String encryptedKeyPackage,
    String? nonceHex,
    String rsaPrivateKeyPem,
  ) async {
    try {
      print(
        '\n--- Performing decryption with PointyCastle + Fast RSA fallback ---',
      );

      String? decryptedJson;
      bool usedFastRSA = false;
      final rsaDecryptStart = DateTime.now();

      // ATTEMPT 1: PointyCastle RSA-OAEP
      try {
        final rsaPrivateKey = _parseRSAPrivateKeyFromPem(rsaPrivateKeyPem);
        if (rsaPrivateKey != null) {
          decryptedJson = _decryptWithRSAOAEP(
            encryptedKeyPackage,
            rsaPrivateKey,
          );
          print('✓ Successfully decrypted using PointyCastle RSA-OAEP');
        }
      } catch (e) {
        print('PointyCastle RSA-OAEP failed: $e');
      }

      // ATTEMPT 2: PointyCastle PKCS1v15 (if OAEP failed)
      if (decryptedJson == null) {
        try {
          final rsaPrivateKey = _parseRSAPrivateKeyFromPem(rsaPrivateKeyPem);
          if (rsaPrivateKey != null) {
            decryptedJson = _decryptWithRSAPKCS1v15(
              encryptedKeyPackage,
              rsaPrivateKey,
            );
            print('✓ Successfully decrypted using PointyCastle PKCS1v15');
          }
        } catch (e) {
          print('PointyCastle PKCS1v15 failed: $e');
        }
      }

      // ATTEMPT 3: Fast RSA OAEP (fallback for user's own shared files)
      if (decryptedJson == null) {
        try {
          decryptedJson = await _decryptWithFastRSAOAEP(
            encryptedKeyPackage,
            rsaPrivateKeyPem,
          );
          print('✓ Successfully decrypted using Fast RSA OAEP');
          usedFastRSA = true;
        } catch (e) {
          print('Fast RSA OAEP failed: $e');
        }
      }

      // ATTEMPT 4: Fast RSA PKCS1v15 (ultimate fallback)
      if (decryptedJson == null) {
        try {
          decryptedJson = await _decryptWithFastRSAPKCS1v15(
            encryptedKeyPackage,
            rsaPrivateKeyPem,
          );
          print('✓ Successfully decrypted using Fast RSA PKCS1v15');
          usedFastRSA = true;
        } catch (e) {
          print('Fast RSA PKCS1v15 failed: $e');
        }
      }

      // If all methods failed
      if (decryptedJson == null) {
        print('❌ All RSA decryption methods failed');
        return null;
      }

      final rsaDecryptDuration = DateTime.now().difference(rsaDecryptStart);
      print(
        'Decryption method used: ${usedFastRSA ? "Fast RSA" : "PointyCastle"}',
      );
      print('⏱️ RSA decryption time: ${rsaDecryptDuration.inMilliseconds}ms');

      // Parse the decrypted JSON
      final keyData = jsonDecode(decryptedJson);
      final aesKeyBase64 = keyData['key'] as String;
      final nonceBase64 =
          keyData['nonce'] as String? ??
          (nonceHex != null
              ? base64Encode(
                List<int>.generate(
                  nonceHex.length ~/ 2,
                  (i) => int.parse(
                    nonceHex.substring(i * 2, i * 2 + 2),
                    radix: 16,
                  ),
                ),
              )
              : null);

      if (nonceBase64 == null) {
        throw Exception('Nonce not found in key data or database');
      }

      print('✓ Successfully extracted AES key and nonce');

      // Convert from base64 to bytes
      final aesKeyBytes = base64Decode(aesKeyBase64);
      final nonceBytes = base64Decode(nonceBase64);

      print('AES key length: ${aesKeyBytes.length} bytes');
      print('Nonce length: ${nonceBytes.length} bytes');

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
        '✓ Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );

      return decryptedBytes;
    } catch (e) {
      print('Error in _performDecryptionWithFallback: $e');
      return null;
    }
  }

  /// Decrypt using Fast RSA OAEP
  static Future<String> _decryptWithFastRSAOAEP(
    String encryptedBase64,
    String rsaPrivateKeyPem,
  ) async {
    print('Attempting Fast RSA OAEP decryption...');
    final decryptedString = await RSA.decryptOAEP(
      encryptedBase64,
      "", // label
      Hash.SHA256,
      rsaPrivateKeyPem,
    );
    return decryptedString;
  }

  /// Decrypt using Fast RSA PKCS1v15
  static Future<String> _decryptWithFastRSAPKCS1v15(
    String encryptedBase64,
    String rsaPrivateKeyPem,
  ) async {
    print('Attempting Fast RSA PKCS1v15 decryption...');
    final decryptedString = await RSA.decryptPKCS1v15(
      encryptedBase64,
      rsaPrivateKeyPem,
    );
    return decryptedString;
  }

  /// Parse RSA private key from PEM format using PointyCastle
  static RSAPrivateKey? _parseRSAPrivateKeyFromPem(String pem) {
    try {
      print('Parsing RSA private key from PEM using PointyCastle...');

      // Clean the PEM string
      final cleanPem = pem.trim();

      // Determine the format
      bool isPkcs1 = cleanPem.contains('-----BEGIN RSA PRIVATE KEY-----');
      bool isPkcs8 = cleanPem.contains('-----BEGIN PRIVATE KEY-----');

      if (!isPkcs1 && !isPkcs8) {
        throw FormatException('Invalid PEM format - missing proper headers');
      }

      String lines;
      if (isPkcs1) {
        print('Detected PKCS#1 format');
        lines =
            cleanPem
                .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
                .replaceAll('-----END RSA PRIVATE KEY-----', '')
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .replaceAll(' ', '')
                .trim();
      } else {
        print('Detected PKCS#8 format');
        lines =
            cleanPem
                .replaceAll('-----BEGIN PRIVATE KEY-----', '')
                .replaceAll('-----END PRIVATE KEY-----', '')
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .replaceAll(' ', '')
                .trim();
      }

      if (lines.isEmpty) {
        throw FormatException('Empty key data after cleaning');
      }

      final keyBytes = base64Decode(lines);

      if (isPkcs1) {
        // PKCS#1 format - direct RSA key structure
        return _parseRSAPrivateKeyFromPKCS1(keyBytes);
      } else {
        // PKCS#8 format - wrapped in algorithm identifier
        return _parseRSAPrivateKeyFromPKCS8(keyBytes);
      }
    } catch (e) {
      print('Error parsing RSA private key from PEM: $e');
      return null;
    }
  }

  /// Parse PKCS#1 RSA private key
  static RSAPrivateKey _parseRSAPrivateKeyFromPKCS1(Uint8List keyBytes) {
    final asn1Parser = ASN1Parser(keyBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    final modulus = (topLevelSeq.elements[1] as ASN1Integer).valueAsBigInteger!;
    final publicExponent =
        (topLevelSeq.elements[2] as ASN1Integer).valueAsBigInteger!;
    final privateExponent =
        (topLevelSeq.elements[3] as ASN1Integer).valueAsBigInteger!;
    final p = (topLevelSeq.elements[4] as ASN1Integer).valueAsBigInteger!;
    final q = (topLevelSeq.elements[5] as ASN1Integer).valueAsBigInteger!;

    print('PKCS#1 RSA private key parsed - Modulus bits: ${modulus.bitLength}');
    return RSAPrivateKey(modulus, privateExponent, p, q);
  }

  /// Parse PKCS#8 RSA private key
  static RSAPrivateKey _parseRSAPrivateKeyFromPKCS8(Uint8List keyBytes) {
    final asn1Parser = ASN1Parser(keyBytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Extract the private key octet string
    final privateKeyOctetString = topLevelSeq.elements[2] as ASN1OctetString;
    final privateKeyBytes = privateKeyOctetString.contentBytes();

    // Parse the inner PKCS#1 structure
    return _parseRSAPrivateKeyFromPKCS1(privateKeyBytes);
  }

  /// Decrypt data using RSA-OAEP with PointyCastle
  static String _decryptWithRSAOAEP(
    String encryptedBase64,
    RSAPrivateKey privateKey,
  ) {
    try {
      print('Decrypting with PointyCastle RSA-OAEP...');

      final encryptedBytes = base64Decode(encryptedBase64);

      // Create OAEP decryptor with SHA-256 (matching doctor's encryption)
      final decryptor = OAEPEncoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final decryptedBytes = decryptor.process(encryptedBytes);
      final decryptedString = utf8.decode(decryptedBytes);

      print('✓ RSA-OAEP decryption completed successfully');
      return decryptedString;
    } catch (e) {
      print('RSA-OAEP decryption error: $e');
      rethrow;
    }
  }

  /// Decrypt data using RSA PKCS1v15 with PointyCastle (fallback)
  static String _decryptWithRSAPKCS1v15(
    String encryptedBase64,
    RSAPrivateKey privateKey,
  ) {
    try {
      print('Decrypting with PointyCastle RSA PKCS1v15...');

      final encryptedBytes = base64Decode(encryptedBase64);

      // Create PKCS1v15 decryptor
      final decryptor = PKCS1Encoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final decryptedBytes = decryptor.process(encryptedBytes);
      final decryptedString = utf8.decode(decryptedBytes);

      print('✓ RSA PKCS1v15 decryption completed successfully');
      return decryptedString;
    } catch (e) {
      print('RSA PKCS1v15 decryption error: $e');
      rethrow;
    }
  }

  /// Decrypt file data using AES-GCM with cryptography package
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
        print(
          'Error: Combined data too short, must be at least 16 bytes for MAC',
        );
        return null;
      }

      // Separate ciphertext and MAC
      // Format from doctor's upload: [ciphertext][16-byte MAC]
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

  /// Download file from IPFS
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
        print('✓ Downloaded ${response.bodyBytes.length} bytes from IPFS');
        return response.bodyBytes;
      } else {
        print('Failed to fetch from IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading from IPFS: $e');
      return null;
    }
  }

  /// Verify if user has access to decrypt a file
  static Future<bool> canDecryptFile({
    required String fileId,
    required String userId,
  }) async {
    try {
      final keyCheck =
          await _supabase
              .from('File_Keys')
              .select('id')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      return keyCheck != null;
    } catch (e) {
      print('Error checking file access: $e');
      return false;
    }
  }

  /// Get file metadata including IPFS CID
  static Future<Map<String, dynamic>?> getFileMetadata(String fileId) async {
    try {
      final fileData =
          await _supabase
              .from('Files')
              .select(
                'id, filename, file_type, file_size, ipfs_cid, sha256_hash',
              )
              .eq('id', fileId)
              .maybeSingle();

      return fileData;
    } catch (e) {
      print('Error fetching file metadata: $e');
      return null;
    }
  }

  /// Batch decrypt multiple org files with three-way verification
  ///
  /// Efficiently verifies and decrypts multiple files in sequence
  /// Returns a map of fileId -> decrypted bytes (or null if failed)
  static Future<Map<String, Uint8List?>> decryptMultipleFiles({
    required List<Map<String, String>>
    files, // [{fileId, ipfsCid, sharedBy, doctorId}]
    bool skipVerification = false,
  }) async {
    final batchStartTime = DateTime.now();
    print('=== BATCH ORG FILE DECRYPTION START ===');
    print('⏱️ Batch started at: $batchStartTime');
    print('Files to decrypt: ${files.length}');

    final results = <String, Uint8List?>{};
    int totalBytes = 0;

    for (final file in files) {
      final fileId = file['fileId']!;
      final ipfsCid = file['ipfsCid']!;
      final sharedBy = file['sharedBy']!;
      final doctorId = file['doctorId']!;

      print('\nDecrypting file: $fileId');

      final decryptedBytes = await decryptSharedFile(
        fileId: fileId,
        ipfsCid: ipfsCid,
        sharedBy: sharedBy,
        doctorId: doctorId,
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

    print('\n=== BATCH ORG FILE DECRYPTION END ===');
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
}
