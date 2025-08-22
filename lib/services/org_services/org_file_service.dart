import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';

class OrgFileService {
  /// Enhanced decryption with better error handling and data validation
  static Future<Uint8List?> _decryptWithKeysRobust({
    required Uint8List encryptedBytes,
    required String encryptedAesKeyBase64,
    required String rsaPrivateKeyPem,
    required String? nonceHex,
    required String debugContext,
  }) async {
    try {
      print('=== Attempting decryption: $debugContext ===');

      if (nonceHex == null || nonceHex.isEmpty) {
        print('ERROR: Nonce is null or empty');
        return null;
      }

      // Validate the encrypted file size
      if (encryptedBytes.length < 100) {
        print(
          'WARNING: Encrypted file is suspiciously small (${encryptedBytes.length} bytes)',
        );
        print('This might indicate an IPFS upload issue');
        // Don't return null here - let's try to decrypt anyway in case it's a test file
      }

      // Validate base64 format of encrypted AES key
      if (!_isValidBase64(encryptedAesKeyBase64)) {
        print('ERROR: Encrypted AES key is not valid base64 format');
        return null;
      }

      print('Encrypted AES key length: ${encryptedAesKeyBase64.length}');
      print('Nonce: $nonceHex');
      print('RSA private key length: ${rsaPrivateKeyPem.length}');

      // Try to decode the base64 first
      Uint8List rsaEncryptedBytes;
      try {
        rsaEncryptedBytes = base64Decode(encryptedAesKeyBase64);
        print(
          'Successfully decoded base64 AES key. Bytes length: ${rsaEncryptedBytes.length}',
        );
      } catch (e) {
        print('ERROR: Failed to decode base64 AES key: $e');
        return null;
      }

      // Convert bytes to text for RSA decryption
      String rsaEncryptedText;
      try {
        rsaEncryptedText = utf8.decode(rsaEncryptedBytes);
        print('Successfully converted bytes to UTF-8 text');
      } catch (e) {
        print('ERROR: Failed to convert bytes to UTF-8: $e');
        // Try alternative: treat the base64 string directly as the encrypted text
        print('Attempting direct base64 string as encrypted text...');
        rsaEncryptedText = encryptedAesKeyBase64;
      }

      // Parse RSA private key
      RSAPrivateKey rsaPrivateKey;
      try {
        rsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
        print('Successfully parsed RSA private key');
      } catch (e) {
        print('ERROR: Failed to parse RSA private key: $e');
        return null;
      }

      // Decrypt AES key with RSA
      String decryptedAesKeyBase64;
      try {
        decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
          rsaEncryptedText,
          rsaPrivateKey,
        );
        print('Successfully decrypted AES key with RSA');
      } catch (e) {
        print('ERROR: RSA decryption failed: $e');
        return null;
      }

      // Decode the decrypted AES key
      Uint8List decryptedAesKeyBytes;
      try {
        decryptedAesKeyBytes = base64Decode(decryptedAesKeyBase64);
        print(
          'Successfully decoded decrypted AES key. Length: ${decryptedAesKeyBytes.length}',
        );
      } catch (e) {
        print('ERROR: Failed to decode decrypted AES key: $e');
        return null;
      }

      // Convert AES key bytes to hex string
      final aesKeyHex =
          decryptedAesKeyBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();

      print('AES key hex length: ${aesKeyHex.length}');
      print('Expected AES key length: 64 characters (32 bytes)');

      if (aesKeyHex.length != 64) {
        print('WARNING: AES key length is not 32 bytes (256 bits)');
      }

      // Validate nonce hex format
      if (!_isValidHex(nonceHex)) {
        print('ERROR: Nonce is not valid hex format: $nonceHex');
        return null;
      }

      print('Creating AESHelper with key and nonce...');

      // Create AESHelper and decrypt file
      final aesHelper = AESHelper(aesKeyHex, nonceHex);

      print('Attempting AES decryption of ${encryptedBytes.length} bytes...');
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print('SUCCESS: Decrypted file. Size: ${decryptedBytes.length} bytes');

      // Validate decrypted file
      if (decryptedBytes.isEmpty) {
        print('WARNING: Decrypted file is empty');
        return null;
      }

      return decryptedBytes;
    } catch (e, stackTrace) {
      print('ERROR in _decryptWithKeysRobust ($debugContext): $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Validate if string is proper base64
  static bool _isValidBase64(String str) {
    try {
      if (str.isEmpty) return false;

      // Remove any whitespace
      str = str.replaceAll(RegExp(r'\s'), '');

      // Check if length is multiple of 4
      if (str.length % 4 != 0) return false;

      // Check if contains only valid base64 characters
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
      if (!base64Pattern.hasMatch(str)) return false;

      // Try to decode
      base64Decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate if string is proper hexadecimal
  static bool _isValidHex(String str) {
    try {
      if (str.isEmpty) return false;

      // Remove any whitespace
      str = str.replaceAll(RegExp(r'\s'), '');

      // Check if contains only hex characters
      final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
      return hexPattern.hasMatch(str);
    } catch (e) {
      return false;
    }
  }

  /// Enhanced user decryption with better error handling
  static Future<Uint8List?> _tryUserDecryptionRobust(
    String fileId,
    String userId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== Attempting User Decryption ===');
      print('File ID: $fileId');
      print('User ID: $userId');

      // Get user's File_Keys entry
      final userFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      if (userFileKey == null) {
        print('No user-specific File_Keys entry found');
        return null;
      }

      final encryptedAesKey = userFileKey['aes_key_encrypted'];
      final nonceHex = userFileKey['nonce_hex'];

      if (encryptedAesKey == null || encryptedAesKey.isEmpty) {
        print('ERROR: Encrypted AES key is null or empty');
        return null;
      }

      if (nonceHex == null || nonceHex.isEmpty) {
        print('ERROR: Nonce is null or empty');
        return null;
      }

      // Get user's RSA private key
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final userRsaPrivateKeyPem = userData['rsa_private_key'] as String?;

      if (userRsaPrivateKeyPem == null || userRsaPrivateKeyPem.isEmpty) {
        print('ERROR: User RSA private key is null or empty');
        return null;
      }

      return await _decryptWithKeysRobust(
        encryptedBytes: encryptedBytes,
        encryptedAesKeyBase64: encryptedAesKey,
        rsaPrivateKeyPem: userRsaPrivateKeyPem,
        nonceHex: nonceHex,
        debugContext: 'User Decryption',
      );
    } catch (e) {
      print('User decryption failed: $e');
      return null;
    }
  }

  /// Enhanced decryption method with comprehensive fallback strategies
  /// Enhanced decryption method with comprehensive diagnostics
  static Future<Uint8List?> decryptOrgSharedFileEnhanced({
    required String fileId,
    required String orgId,
    required String userId,
    required String ipfsCid,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== Starting Enhanced File Decryption ===');
      print('File ID: $fileId');
      print('Organization ID: $orgId');
      print('User ID: $userId');
      print('IPFS CID: $ipfsCid');

      // Step 1: Download and validate file from IPFS
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        print('FATAL: Failed to download file from IPFS');
        return null;
      }

      print('Downloaded file size: ${encryptedBytes.length} bytes');

      // Check if file is suspiciously small
      if (encryptedBytes.length < 100) {
        print('WARNING: File is very small (${encryptedBytes.length} bytes)');
        print('This might indicate an IPFS upload issue or test file');
      }

      // Step 2: Run diagnostics on available keys
      await _diagnoseFileKeys(fileId, orgId, userId);

      // Step 3: Try user-specific decryption with robust error handling
      print('\n--- Strategy 1: User Decryption ---');
      Uint8List? decryptedBytes = await _tryUserDecryptionRobust(
        fileId,
        userId,
        encryptedBytes,
      );
      if (decryptedBytes != null) {
        print('SUCCESS: User-specific decryption worked');
        return decryptedBytes;
      }

      // Step 4: Try organization decryption
      print('\n--- Strategy 2: Organization Decryption ---');
      decryptedBytes = await _tryOrganizationDecryptionRobust(
        fileId,
        orgId,
        encryptedBytes,
      );
      if (decryptedBytes != null) {
        print('SUCCESS: Organization decryption worked');
        return decryptedBytes;
      }

      // Step 5: Try doctor owner decryption (fallback)
      print('\n--- Strategy 3: Doctor Owner Decryption ---');
      decryptedBytes = await _tryDoctorOwnerDecryptionRobust(
        fileId,
        encryptedBytes,
      );
      if (decryptedBytes != null) {
        print('SUCCESS: Doctor owner decryption worked');
        return decryptedBytes;
      }

      print('\n--- All decryption strategies failed ---');
      return null;
    } catch (e, stackTrace) {
      print('ERROR in enhanced decryption: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Diagnostic method to analyze file key issues
  static Future<void> _diagnoseFileKeys(
    String fileId,
    String orgId,
    String userId,
  ) async {
    try {
      print('\n=== File Key Diagnostics ===');
      final supabase = Supabase.instance.client;

      // Get all File_Keys for this file
      final allKeys = await supabase
          .from('File_Keys')
          .select('recipient_type, recipient_id, aes_key_encrypted, nonce_hex')
          .eq('file_id', fileId);

      print('Total File_Keys entries: ${allKeys.length}');

      if (allKeys.isEmpty) {
        print('CRITICAL: No File_Keys entries found for this file');
        return;
      }

      for (int i = 0; i < allKeys.length; i++) {
        final key = allKeys[i];
        print('\nKey ${i + 1}:');
        print('  Type: ${key['recipient_type']}');
        print('  Recipient ID: ${key['recipient_id']}');
        print('  Has AES Key: ${key['aes_key_encrypted'] != null}');
        print('  AES Key Length: ${key['aes_key_encrypted']?.length ?? 0}');
        print('  Has Nonce: ${key['nonce_hex'] != null}');
        print('  Nonce Length: ${key['nonce_hex']?.length ?? 0}');

        // Validate key format
        if (key['aes_key_encrypted'] != null) {
          final isValidBase64 = _isValidBase64(key['aes_key_encrypted']);
          print('  AES Key Valid Base64: $isValidBase64');
        }

        if (key['nonce_hex'] != null) {
          final isValidHex = _isValidHex(key['nonce_hex']);
          print('  Nonce Valid Hex: $isValidHex');
        }

        // Check if this key is for current user or org
        if (key['recipient_type'] == 'user' && key['recipient_id'] == userId) {
          print('  >>> THIS IS THE PATIENT\'S KEY <<<');
        }
        if (key['recipient_type'] == 'organization' &&
            key['recipient_id'] == orgId) {
          print('  >>> THIS IS THE ORGANIZATION\'S KEY <<<');
        }
      }
    } catch (e) {
      print('Error in diagnostics: $e');
    }
  }

  /// Try organization decryption with robust error handling
  static Future<Uint8List?> _tryOrganizationDecryptionRobust(
    String fileId,
    String orgId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== Attempting Organization Decryption ===');

      // Get organization's File_Keys entry
      final orgFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'organization')
              .eq('recipient_id', orgId)
              .maybeSingle();

      if (orgFileKey == null) {
        print('No organization-specific File_Keys entry found');
        return null;
      }

      print(
        'Found organization File_Keys entry created at: ${orgFileKey['created_at']}',
      );

      final encryptedAesKey = orgFileKey['aes_key_encrypted'];
      final nonceHex = orgFileKey['nonce_hex'];

      if (encryptedAesKey == null || encryptedAesKey.isEmpty) {
        print('ERROR: Organization encrypted AES key is null or empty');
        return null;
      }

      // Get organization's RSA private key
      final orgData =
          await supabase
              .from('Organization')
              .select('rsa_private_key')
              .eq('id', orgId)
              .single();

      final orgRsaPrivateKeyPem = orgData['rsa_private_key'] as String?;

      if (orgRsaPrivateKeyPem == null || orgRsaPrivateKeyPem.isEmpty) {
        print('ERROR: Organization RSA private key is null or empty');
        return null;
      }

      return await _decryptWithKeysRobust(
        encryptedBytes: encryptedBytes,
        encryptedAesKeyBase64: encryptedAesKey,
        rsaPrivateKeyPem: orgRsaPrivateKeyPem,
        nonceHex: nonceHex,
        debugContext: 'Organization Decryption',
      );
    } catch (e) {
      print('Organization decryption failed: $e');
      return null;
    }
  }

  /// Try doctor owner decryption with robust error handling
  static Future<Uint8List?> _tryDoctorOwnerDecryptionRobust(
    String fileId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== Attempting Doctor Owner Decryption ===');

      // Get file owner (doctor) ID
      final fileData =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      final doctorUserId = fileData['uploaded_by'];
      print('Doctor/Owner User ID: $doctorUserId');

      // Get doctor's File_Keys entry
      final doctorFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', doctorUserId)
              .maybeSingle();

      if (doctorFileKey == null) {
        print('No doctor owner File_Keys entry found');
        return null;
      }

      print(
        'Found doctor File_Keys entry created at: ${doctorFileKey['created_at']}',
      );

      final encryptedAesKey = doctorFileKey['aes_key_encrypted'];
      final nonceHex = doctorFileKey['nonce_hex'];

      if (encryptedAesKey == null || encryptedAesKey.isEmpty) {
        print('ERROR: Doctor encrypted AES key is null or empty');
        return null;
      }

      // Get doctor's RSA private key
      final doctorData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', doctorUserId)
              .single();

      final doctorRsaPrivateKeyPem = doctorData['rsa_private_key'] as String?;

      if (doctorRsaPrivateKeyPem == null || doctorRsaPrivateKeyPem.isEmpty) {
        print('ERROR: Doctor RSA private key is null or empty');
        return null;
      }

      return await _decryptWithKeysRobust(
        encryptedBytes: encryptedBytes,
        encryptedAesKeyBase64: encryptedAesKey,
        rsaPrivateKeyPem: doctorRsaPrivateKeyPem,
        nonceHex: nonceHex,
        debugContext: 'Doctor Owner Decryption',
      );
    } catch (e) {
      print('Doctor owner decryption failed: $e');
      return null;
    }
  }

  /// Strategy 1: Try user-specific decryption
  static Future<Uint8List?> _tryUserDecryption(
    String fileId,
    String userId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get user's File_Keys entry
      final userFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      if (userFileKey == null || userFileKey['aes_key_encrypted'] == null) {
        print('No user-specific File_Keys entry found');
        return null;
      }

      // Get user's RSA private key
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final userRsaPrivateKeyPem = userData['rsa_private_key'] as String;

      return await _decryptWithKeys(
        encryptedBytes: encryptedBytes,
        encryptedAesKeyBase64: userFileKey['aes_key_encrypted'],
        rsaPrivateKeyPem: userRsaPrivateKeyPem,
        nonceHex: userFileKey['nonce_hex'],
      );
    } catch (e) {
      print('User decryption failed: $e');
      return null;
    }
  }

  /// Strategy 2: Try organization decryption
  static Future<Uint8List?> _tryOrganizationDecryption(
    String fileId,
    String orgId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get organization's File_Keys entry
      final orgFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'organization')
              .eq('recipient_id', orgId)
              .maybeSingle();

      if (orgFileKey == null || orgFileKey['aes_key_encrypted'] == null) {
        print('No organization-specific File_Keys entry found');
        return null;
      }

      // Get organization's RSA private key
      final orgData =
          await supabase
              .from('Organization')
              .select('rsa_private_key')
              .eq('id', orgId)
              .single();

      final orgRsaPrivateKeyPem = orgData['rsa_private_key'] as String;

      return await _decryptWithKeys(
        encryptedBytes: encryptedBytes,
        encryptedAesKeyBase64: orgFileKey['aes_key_encrypted'],
        rsaPrivateKeyPem: orgRsaPrivateKeyPem,
        nonceHex: orgFileKey['nonce_hex'],
      );
    } catch (e) {
      print('Organization decryption failed: $e');
      return null;
    }
  }

  /// Strategy 3: Try doctor owner decryption (fallback)
  static Future<Uint8List?> _tryDoctorOwnerDecryption(
    String fileId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get file owner (doctor) ID
      final fileData =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      final doctorUserId = fileData['uploaded_by'];
      print('Trying doctor owner decryption for user: $doctorUserId');

      // Get doctor's File_Keys entry
      final doctorFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', doctorUserId)
              .maybeSingle();

      if (doctorFileKey == null || doctorFileKey['aes_key_encrypted'] == null) {
        print('No doctor owner File_Keys entry found');
        return null;
      }

      // Get doctor's RSA private key
      final doctorData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', doctorUserId)
              .single();

      final doctorRsaPrivateKeyPem = doctorData['rsa_private_key'] as String;

      return await _decryptWithKeys(
        encryptedBytes: encryptedBytes,
        encryptedAesKeyBase64: doctorFileKey['aes_key_encrypted'],
        rsaPrivateKeyPem: doctorRsaPrivateKeyPem,
        nonceHex: doctorFileKey['nonce_hex'],
      );
    } catch (e) {
      print('Doctor owner decryption failed: $e');
      return null;
    }
  }

  /// Common decryption logic using RSA private key and AES
  static Future<Uint8List?> _decryptWithKeys({
    required Uint8List encryptedBytes,
    required String encryptedAesKeyBase64,
    required String rsaPrivateKeyPem,
    required String? nonceHex,
  }) async {
    try {
      if (nonceHex == null) {
        print('Nonce is null, cannot decrypt');
        return null;
      }

      // Decrypt AES key with RSA private key
      final rsaEncryptedBytes = base64Decode(encryptedAesKeyBase64);
      final rsaEncryptedText = utf8.decode(rsaEncryptedBytes);
      final rsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
      final decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
        rsaEncryptedText,
        rsaPrivateKey,
      );
      final decryptedAesKeyBytes = base64Decode(decryptedAesKeyBase64);

      // Convert AES key bytes to hex string
      final aesKeyHex =
          decryptedAesKeyBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();

      print('Successfully decrypted AES key with RSA private key');

      // Create AESHelper and decrypt file
      final aesHelper = AESHelper(aesKeyHex, nonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );
      return decryptedBytes;
    } catch (e) {
      print('Error in _decryptWithKeys: $e');
      return null;
    }
  }

  /// Strategy 4: Create missing patient keys
  static Future<bool> _createMissingPatientKeys(
    String fileId,
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      print('Attempting to create missing patient keys...');

      // Check if patient already has keys
      final existingKey =
          await supabase
              .from('File_Keys')
              .select('id')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', patientId)
              .maybeSingle();

      if (existingKey != null) {
        print('Patient already has keys for this file');
        return false;
      }

      // Get file owner (doctor) and their keys
      final fileData =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      final doctorUserId = fileData['uploaded_by'];

      // Get doctor's File_Keys entry to get the original AES key
      final doctorFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', doctorUserId)
              .maybeSingle();

      if (doctorFileKey == null) {
        print('No doctor keys found to derive patient keys from');
        return false;
      }

      // Get doctor's RSA private key to decrypt the AES key
      final doctorData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', doctorUserId)
              .single();

      // Get patient's RSA public key to encrypt for them
      final patientData =
          await supabase
              .from('User')
              .select('rsa_public_key')
              .eq('id', patientId)
              .single();

      // Decrypt AES key using doctor's private key
      final doctorRsaPrivateKeyPem = doctorData['rsa_private_key'] as String;
      final rsaEncryptedBytes = base64Decode(
        doctorFileKey['aes_key_encrypted'],
      );
      final rsaEncryptedText = utf8.decode(rsaEncryptedBytes);
      final doctorRsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(
        doctorRsaPrivateKeyPem,
      );
      final decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
        rsaEncryptedText,
        doctorRsaPrivateKey,
      );

      // Re-encrypt AES key with patient's public key
      final patientRsaPublicKeyPem = patientData['rsa_public_key'] as String;
      final patientRsaPublicKey = CryptoUtils.rsaPublicKeyFromPem(
        patientRsaPublicKeyPem,
      );
      final encryptedAesKeyForPatient = CryptoUtils.rsaEncrypt(
        decryptedAesKeyBase64,
        patientRsaPublicKey,
      );

      // Store new File_Keys entry for patient
      await supabase.from('File_Keys').insert({
        'file_id': fileId,
        'recipient_type': 'user',
        'recipient_id': patientId,
        'aes_key_encrypted': base64Encode(
          utf8.encode(encryptedAesKeyForPatient),
        ),
        'nonce_hex': doctorFileKey['nonce_hex'],
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Successfully created missing patient keys for file: $fileId');
      return true;
    } catch (e) {
      print('Error creating missing patient keys: $e');
      return false;
    }
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

  // Keep all existing methods from the original OrgFileService...

  /// Fetch all files shared with a specific organization
  static Future<List<Map<String, dynamic>>> fetchOrgSharedFiles(
    String orgId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final sharedFiles = await supabase
          .from('File_Shares')
          .select('''
            *,
            file:Files!inner(
              id,
              filename,
              file_type,
              file_size,
              uploaded_at,
              ipfs_cid,
              category
            ),
            shared_by:User!shared_by_user_id(email)
          ''')
          .eq('shared_with_org_id', orgId)
          .order('shared_at', ascending: false);

      print(
        'Fetched ${sharedFiles.length} shared files for organization $orgId',
      );
      return sharedFiles;
    } catch (e) {
      print('Error fetching organization shared files: $e');
      return [];
    }
  }

  /// Fetch files uploaded by doctors in a specific organization for a patient
  static Future<List<Map<String, dynamic>>> fetchDoctorFilesForPatient(
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get user's assigned doctors from this organization
      final assignmentsResponse = await supabase
          .from('Doctor_User_Assignment')
          .select('doctor_id')
          .eq('patient_id', patientId)
          .eq('status', 'active');

      if (assignmentsResponse.isEmpty) {
        print('No active doctor assignments found for patient $patientId');
        return [];
      }

      final doctorIds =
          assignmentsResponse
              .map((assignment) => assignment['doctor_id'])
              .toList();

      // Get doctor user IDs from Organization_User table
      final doctorsResponse = await supabase
          .from('Organization_User')
          .select('user_id')
          .inFilter('id', doctorIds)
          .eq('organization_id', orgId)
          .eq('position', 'Doctor');

      if (doctorsResponse.isEmpty) {
        print('No doctors found in organization $orgId');
        return [];
      }

      final doctorUserIds =
          doctorsResponse.map((doc) => doc['user_id']).toList();

      // Get files uploaded by these doctors with User and Person fields
      final filesResponse = await supabase
          .from('Files')
          .select('''
            id,
            filename,
            file_type,
            file_size,
            uploaded_at,
            ipfs_cid,
            category,
            uploaded_by,
            User!uploaded_by(
              id,
              email,
              rsa_public_key,
              rsa_private_key,
              Person!inner(first_name, middle_name, last_name)
            )
          ''')
          .inFilter('uploaded_by', doctorUserIds)
          .order('uploaded_at', ascending: false);

      print(
        'Fetched ${filesResponse.length} doctor files for patient from organization',
      );
      return filesResponse;
    } catch (e) {
      print('Error fetching doctor files for patient: $e');
      return [];
    }
  }

  /// Check if patient has access to doctor's file through doctor assignment
  static Future<bool> hasPatientDoctorFileAccess(
    String fileId,
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get file owner
      final fileData =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      final fileOwnerId = fileData['uploaded_by'];

      // Check if file owner is a doctor in the organization
      final doctorCheck =
          await supabase
              .from('Organization_User')
              .select('id')
              .eq('organization_id', orgId)
              .eq('user_id', fileOwnerId)
              .eq('position', 'Doctor')
              .maybeSingle();

      if (doctorCheck == null) {
        print('File owner is not a doctor in organization $orgId');
        return false;
      }

      // Check if patient is assigned to this doctor
      final assignmentCheck =
          await supabase
              .from('Doctor_User_Assignment')
              .select('id')
              .eq('doctor_id', doctorCheck['id'])
              .eq('patient_id', patientId)
              .eq('status', 'active')
              .maybeSingle();

      return assignmentCheck != null;
    } catch (e) {
      print('Error checking patient-doctor file access: $e');
      return false;
    }
  }

  /// Get assigned doctors for a patient in an organization
  static Future<List<Map<String, dynamic>>> getAssignedDoctors(
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get user's active doctor assignments
      final assignmentsResponse = await supabase
          .from('Doctor_User_Assignment')
          .select('doctor_id, assigned_at, status')
          .eq('patient_id', patientId)
          .eq('status', 'active');

      if (assignmentsResponse.isEmpty) {
        print('No active assignments found for patient $patientId');
        return [];
      }

      final doctorIds =
          assignmentsResponse
              .map((assignment) => assignment['doctor_id'])
              .toList();

      // Get doctor details from Organization_User table
      final doctorsResponse = await supabase
          .from('Organization_User')
          .select('''
            id,
            position,
            department,
            created_at,
            user_id,
            organization_id,
            User!inner(
              id, 
              email,
              Person!inner(first_name, middle_name, last_name)
            )
          ''')
          .inFilter('id', doctorIds)
          .eq('organization_id', orgId)
          .eq('position', 'Doctor')
          .order('created_at', ascending: false);

      // Add assignment date to each doctor
      final doctorsWithAssignment =
          doctorsResponse.map((doctor) {
            final assignment = assignmentsResponse.firstWhere(
              (a) => a['doctor_id'] == doctor['id'],
              orElse: () => {'assigned_at': null},
            );
            return {...doctor, 'assigned_at': assignment['assigned_at']};
          }).toList();

      print(
        'Fetched ${doctorsWithAssignment.length} assigned doctors for patient',
      );
      return doctorsWithAssignment;
    } catch (e) {
      print('Error fetching assigned doctors: $e');
      return [];
    }
  }
}
