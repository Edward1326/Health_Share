import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/crypto_utils.dart';

class OrgFileService {
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
      }

      // Validate base64 format of encrypted AES key
      if (!_isValidBase64(encryptedAesKeyBase64)) {
        print('ERROR: Encrypted AES key is not valid base64 format');
        return null;
      }

      print('Encrypted AES key length: ${encryptedAesKeyBase64.length}');
      print('Nonce: $nonceHex');
      print('RSA private key length: ${rsaPrivateKeyPem.length}');

      // Parse RSA private key
      RSAPrivateKey rsaPrivateKey;
      try {
        rsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
        print('Successfully parsed RSA private key');
      } catch (e) {
        print('ERROR: Failed to parse RSA private key: $e');
        return null;
      }

      // UPDATED APPROACH: Handle RSA decryption properly with your MyCryptoUtils
      String decryptedKeyJson;

      try {
        // Method 1: Direct decryption (your rsaDecrypt expects base64 string)
        print('Attempting Method 1: Direct rsaDecrypt with base64 string...');

        decryptedKeyJson = MyCryptoUtils.rsaDecrypt(
          encryptedAesKeyBase64,
          rsaPrivateKey,
        );
        print('Method 1 successful: Direct decryption worked');
      } catch (e1) {
        print('Method 1 failed: $e1');
        print(
          'This suggests the stored encrypted key format might be incompatible',
        );

        // Let's analyze the encrypted key format
        print('Encrypted key analysis:');
        print('  Length: ${encryptedAesKeyBase64.length}');
        print('  Is valid base64: ${_isValidBase64(encryptedAesKeyBase64)}');

        try {
          final decoded = base64Decode(encryptedAesKeyBase64);
          print('  Decoded byte length: ${decoded.length}');
          print(
            '  First 10 bytes: ${decoded.take(10).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
          );
        } catch (decodeError) {
          print('  Base64 decode failed: $decodeError');
        }

        // The error might be due to key format or encryption mismatch
        // Let's check if this is a padding or format issue
        print('ERROR: RSA decryption failed with your crypto implementation');
        print('This might indicate:');
        print(
          '1. The encrypted key was created with a different RSA implementation',
        );
        print('2. Key size mismatch between encryption and decryption');
        print('3. Different padding schemes used');
        print('4. The stored encrypted key is corrupted');

        return null;
      }

      print('Successfully decrypted key package');
      print('Decrypted content length: ${decryptedKeyJson.length}');
      print(
        'First 100 chars: ${decryptedKeyJson.length > 100 ? decryptedKeyJson.substring(0, 100) : decryptedKeyJson}',
      );

      // Try to parse as JSON (new format matching doctor's upload)
      String aesKeyHex;
      String actualNonceHex;

      try {
        final keyData = jsonDecode(decryptedKeyJson);

        if (keyData is Map<String, dynamic> &&
            keyData.containsKey('key') &&
            keyData.containsKey('nonce')) {
          aesKeyHex = keyData['key'] as String;
          actualNonceHex = keyData['nonce'] as String;

          print('Successfully parsed JSON key package (new format)');
          print('AES key length: ${aesKeyHex.length} chars');
          print('Nonce from package: $actualNonceHex');
        } else {
          throw FormatException(
            'JSON does not contain required key/nonce fields',
          );
        }
      } catch (jsonError) {
        print('Not new JSON format, trying old format: $jsonError');

        // Old format fallback: decrypted result is base64-encoded AES key
        try {
          final decryptedAesKeyBytes = base64Decode(decryptedKeyJson);
          aesKeyHex =
              decryptedAesKeyBytes
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join();
          actualNonceHex = nonceHex; // Use the provided nonce

          print('Successfully processed old format key');
          print('AES key hex length: ${aesKeyHex.length}');
        } catch (oldFormatError) {
          print(
            'ERROR: Failed to process decrypted key in any format: $oldFormatError',
          );
          print('Decrypted content: $decryptedKeyJson');
          return null;
        }
      }

      // Validate AES key length (should be 64 hex chars = 32 bytes = 256 bits)
      if (aesKeyHex.length != 64) {
        print(
          'WARNING: AES key length is not 32 bytes (256 bits): ${aesKeyHex.length} chars',
        );
        // Don't return null here, try to proceed anyway
      }

      // Validate nonce hex format (should be 24 hex chars = 12 bytes for GCM)
      if (!_isValidHex(actualNonceHex)) {
        print('ERROR: Nonce is not valid hex format: $actualNonceHex');
        return null;
      }

      if (actualNonceHex.length != 24) {
        print(
          'WARNING: Nonce length is not 12 bytes: ${actualNonceHex.length} chars',
        );
        // Don't return null here, try to proceed anyway
      }

      print('Final AES key (hex): $aesKeyHex');
      print('Final nonce (hex): $actualNonceHex');
      print('Creating AESHelper with validated key and nonce...');

      // Create AESHelper and decrypt file
      final aesHelper = AESHelper(aesKeyHex, actualNonceHex);

      print('Attempting AES decryption of ${encryptedBytes.length} bytes...');
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print('SUCCESS: Decrypted file. Size: ${decryptedBytes.length} bytes');

      // Validate decrypted file
      if (decryptedBytes.isEmpty) {
        print('WARNING: Decrypted file is empty');
        return null;
      }

      // Additional validation: check if file starts with known file signatures
      _validateFileFormat(decryptedBytes);

      return decryptedBytes;
    } catch (e, stackTrace) {
      print('ERROR in _decryptWithKeysRobust ($debugContext): $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Validate decrypted file format
  static void _validateFileFormat(Uint8List bytes) {
    if (bytes.length < 8) {
      print('File too small for format validation');
      return;
    }

    // Check common file signatures
    final header = bytes.take(8).toList();

    if (header[0] == 0x25 &&
        header[1] == 0x50 &&
        header[2] == 0x44 &&
        header[3] == 0x46) {
      print('✓ Detected PDF file format');
    } else if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
      print('✓ Detected JPEG file format');
    } else if (header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      print('✓ Detected PNG file format');
    } else if (header[0] == 0x50 && header[1] == 0x4B) {
      print('✓ Detected ZIP-based format (DOCX, etc.)');
    } else {
      print(
        '? Unknown file format, first 8 bytes: ${header.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
      );
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

      print('Found organization File_Keys entry');

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

      print('Found doctor File_Keys entry');

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

  /// Fetch ALL files available to patient in a specific organization (both doctor and patient uploaded)
  /// Fetch ALL files available to patient in a specific organization (both doctor and patient uploaded)
  static Future<List<Map<String, dynamic>>> fetchAllOrgFilesForPatient(
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== Fetching ALL Organization Files for Patient ===');
      print('Organization ID: $orgId');
      print('Patient ID: $patientId');

      // Get user's assigned doctors to validate doctor-patient relationships
      final assignmentsResponse = await supabase
          .from('Doctor_User_Assignment')
          .select('doctor_id')
          .eq('patient_id', patientId)
          .eq('status', 'active');

      final doctorIds =
          assignmentsResponse
              .map((assignment) => assignment['doctor_id'] as String)
              .toList();

      print('Patient assigned to ${doctorIds.length} doctors: $doctorIds');

      // Get all doctors in this organization
      final orgDoctorsResponse = await supabase
          .from('Organization_User')
          .select('id, user_id')
          .eq('organization_id', orgId)
          .eq('position', 'Doctor');

      final orgDoctorUserIds =
          orgDoctorsResponse.map((doc) => doc['user_id'] as String).toList();

      print(
        'Organization has ${orgDoctorUserIds.length} doctors: $orgDoctorUserIds',
      );

      Set<String> seenFileIds = {};
      List<Map<String, dynamic>> allFiles = [];

      // Method 1: Get files where patient has direct access through File_Keys (patient uploaded files)
      final patientAccessibleFiles = await supabase
          .from('File_Keys')
          .select('''
        file_id,
        Files!inner(
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
        )
      ''')
          .eq('recipient_type', 'user')
          .eq('recipient_id', patientId);

      print(
        'Found ${patientAccessibleFiles.length} files with patient access keys',
      );

      // Process patient accessible files
      for (final keyRecord in patientAccessibleFiles) {
        final file = keyRecord['Files'];
        final fileId = file['id'] as String;
        final uploaderId = file['uploaded_by'] as String;

        if (!seenFileIds.contains(fileId)) {
          // Check if this file is relevant to the organization
          bool isRelevantToOrg = false;
          String uploaderType = 'unknown';
          String uploaderRelation = 'unknown';

          if (uploaderId == patientId) {
            // Patient's own file - always relevant if patient is in org
            isRelevantToOrg = true;
            uploaderType = 'patient';
            uploaderRelation = 'self';
          } else if (orgDoctorUserIds.contains(uploaderId)) {
            // File uploaded by doctor in this organization
            isRelevantToOrg = true;
            uploaderType = 'doctor';
            uploaderRelation = 'assigned_doctor';
          } else {
            // File from someone else - check if it's shared through organization
            final orgShare =
                await supabase
                    .from('File_Keys')
                    .select('id')
                    .eq('file_id', fileId)
                    .eq('recipient_type', 'organization')
                    .eq('recipient_id', orgId)
                    .maybeSingle();

            if (orgShare != null) {
              isRelevantToOrg = true;
              uploaderType = 'external';
              uploaderRelation = 'shared_with_org';
            }
          }

          if (isRelevantToOrg) {
            seenFileIds.add(fileId);
            allFiles.add({
              'id': file['id'],
              'filename': file['filename'],
              'file_type': file['file_type'],
              'file_size': file['file_size'],
              'uploaded_at': file['uploaded_at'],
              'ipfs_cid': file['ipfs_cid'],
              'category': file['category'],
              'uploaded_by': file['uploaded_by'],
              'User': file['User'],
              'access_method': 'patient_key',
              'uploader_type': uploaderType,
              'uploader_relation': uploaderRelation,
            });
          }
        }
      }

      // Method 2: Get files from organization keys (typically doctor files shared with org)
      final orgAccessibleFiles = await supabase
          .from('File_Keys')
          .select('''
        file_id,
        Files!inner(
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
        )
      ''')
          .eq('recipient_type', 'organization')
          .eq('recipient_id', orgId);

      print(
        'Found ${orgAccessibleFiles.length} files with organization access keys',
      );

      // Process organization accessible files
      for (final keyRecord in orgAccessibleFiles) {
        final file = keyRecord['Files'];
        final fileId = file['id'] as String;
        final uploaderId = file['uploaded_by'] as String;

        if (!seenFileIds.contains(fileId)) {
          // For organization-shared files, check if patient should have access
          bool hasAccess = false;
          String uploaderType = 'unknown';
          String uploaderRelation = 'unknown';

          if (uploaderId == patientId) {
            // Patient's own file shared with org
            hasAccess = true;
            uploaderType = 'patient';
            uploaderRelation = 'self';
          } else if (orgDoctorUserIds.contains(uploaderId)) {
            // Check if this doctor is assigned to the patient
            final doctorOrgUser = orgDoctorsResponse.firstWhere(
              (doc) => doc['user_id'] == uploaderId,
            );

            if (doctorIds.contains(doctorOrgUser['id'])) {
              hasAccess = true;
              uploaderType = 'doctor';
              uploaderRelation = 'assigned_doctor';
            }
          } else {
            // File from external user shared with organization
            // Patient can access if it's explicitly shared
            final shareCheck =
                await supabase
                    .from('File_Shares')
                    .select('id')
                    .eq('file_id', fileId)
                    .isFilter('revoked_at', null)
                    .maybeSingle();

            if (shareCheck != null) {
              hasAccess = true;
              uploaderType = 'external';
              uploaderRelation = 'shared_with_org';
            }
          }

          if (hasAccess) {
            seenFileIds.add(fileId);
            allFiles.add({
              'id': file['id'],
              'filename': file['filename'],
              'file_type': file['file_type'],
              'file_size': file['file_size'],
              'uploaded_at': file['uploaded_at'],
              'ipfs_cid': file['ipfs_cid'],
              'category': file['category'],
              'uploaded_by': file['uploaded_by'],
              'User': file['User'],
              'access_method': 'organization_key',
              'uploader_type': uploaderType,
              'uploader_relation': uploaderRelation,
            });
          }
        }
      }

      // Method 3: ADDITIONAL - Get patient's own files that might be relevant to organization
      // This catches any patient files that might have been shared with doctors in this org
      final patientOwnFiles = await supabase
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
          .eq('uploaded_by', patientId);

      print('Found ${patientOwnFiles.length} files uploaded by patient');

      // Check which of patient's files have been shared with doctors in this org
      for (final file in patientOwnFiles) {
        final fileId = file['id'] as String;

        if (!seenFileIds.contains(fileId)) {
          // Check if this file has been shared with any doctor in this organization
          final doctorShares = await supabase
              .from('File_Shares')
              .select('shared_with_doctor')
              .eq('file_id', fileId)
              .eq('shared_by_user_id', patientId)
              .isFilter('revoked_at', null);

          // Check if any of these shares are with doctors from this organization
          bool hasOrgRelevantShare = false;
          for (final share in doctorShares) {
            final sharedWithDoctorId = share['shared_with_doctor'];
            if (doctorIds.contains(sharedWithDoctorId)) {
              hasOrgRelevantShare = true;
              break;
            }
          }

          // Also check if patient has File_Keys entry (indicating they can decrypt it)
          final patientKey =
              await supabase
                  .from('File_Keys')
                  .select('id')
                  .eq('file_id', fileId)
                  .eq('recipient_type', 'user')
                  .eq('recipient_id', patientId)
                  .maybeSingle();

          if (hasOrgRelevantShare && patientKey != null) {
            seenFileIds.add(fileId);
            allFiles.add({
              'id': file['id'],
              'filename': file['filename'],
              'file_type': file['file_type'],
              'file_size': file['file_size'],
              'uploaded_at': file['uploaded_at'],
              'ipfs_cid': file['ipfs_cid'],
              'category': file['category'],
              'uploaded_by': file['uploaded_by'],
              'User': file['User'],
              'access_method': 'patient_shared',
              'uploader_type': 'patient',
              'uploader_relation': 'self',
            });
          }
        }
      }

      // Sort by upload date (newest first)
      allFiles.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['uploaded_at'] ?? '') ?? DateTime(1970);
        final bDate =
            DateTime.tryParse(b['uploaded_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      print('Final result: ${allFiles.length} files available to patient');

      // Debug: Print file breakdown
      int doctorFiles =
          allFiles.where((f) => f['uploader_type'] == 'doctor').length;
      int patientFiles =
          allFiles.where((f) => f['uploader_type'] == 'patient').length;
      int externalFiles =
          allFiles.where((f) => f['uploader_type'] == 'external').length;

      print('File breakdown:');
      print('  - Doctor uploaded: $doctorFiles files');
      print('  - Patient uploaded: $patientFiles files');
      print('  - External shared: $externalFiles files');

      // Debug: Print each file with details
      for (final file in allFiles) {
        print(
          '  - ${file['filename']} (${file['uploader_type']} - ${file['access_method']})',
        );
      }

      return allFiles;
    } catch (e, stackTrace) {
      print('Error fetching all org files for patient: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Helper method to get uploader information (doctor or patient in org)
  static Future<Map<String, String>?> _getUploaderInfo(
    String uploaderId,
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if uploader is the patient themselves
      if (uploaderId == patientId) {
        return {'type': 'patient', 'relation': 'self'};
      }

      // Check if uploader is a doctor in the organization
      final doctorCheck =
          await supabase
              .from('Organization_User')
              .select('id, position')
              .eq('organization_id', orgId)
              .eq('user_id', uploaderId)
              .eq('position', 'Doctor')
              .maybeSingle();

      if (doctorCheck != null) {
        return {'type': 'doctor', 'relation': 'assigned_doctor'};
      }

      // Check if uploader is a patient in the organization (through assignments)
      final patientCheck =
          await supabase
              .from('Doctor_User_Assignment')
              .select('patient_id')
              .eq('patient_id', uploaderId)
              .eq('status', 'active')
              .maybeSingle();

      if (patientCheck != null) {
        return {
          'type': 'patient',
          'relation': uploaderId == patientId ? 'self' : 'other_patient',
        };
      }

      return null;
    } catch (e) {
      print('Error getting uploader info: $e');
      return null;
    }
  }

  /// Helper method to check if patient has access to organization-shared file
  static Future<bool> _hasPatientAccessToOrgFile(
    String fileId,
    String orgId,
    String patientId,
    List<String> assignedDoctorIds,
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

      // Case 1: Patient is the file owner
      if (fileOwnerId == patientId) {
        return true;
      }

      // Case 2: File owner is one of patient's assigned doctors
      final doctorCheck =
          await supabase
              .from('Organization_User')
              .select('id')
              .eq('organization_id', orgId)
              .eq('user_id', fileOwnerId)
              .eq('position', 'Doctor')
              .maybeSingle();

      if (doctorCheck != null &&
          assignedDoctorIds.contains(doctorCheck['id'])) {
        return true;
      }

      // Case 3: File was explicitly shared with patient
      final shareCheck =
          await supabase
              .from('File_Shares')
              .select('id')
              .eq('file_id', fileId)
              .eq('shared_by_user_id', fileOwnerId)
              .isFilter('revoked_at', null)
              .maybeSingle();

      return shareCheck != null;
    } catch (e) {
      print('Error checking patient access to org file: $e');
      return false;
    }
  }

  /// ORIGINAL METHODS - Keep for backward compatibility
  /// Fetch files uploaded by doctors in a specific organization for a patient
  /// Fetch files shared with patient by doctors in a specific organization
  static Future<List<Map<String, dynamic>>> fetchDoctorFilesForPatient(
    String orgId,
    String patientId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== Fetching Doctor Files for Patient ===');
      print('Organization ID: $orgId');
      print('Patient ID: $patientId');

      // Method 1: Get files shared with patient directly
      // Look for files where the patient has been given access through File_Keys
      final patientSharedFiles = await supabase
          .from('File_Keys')
          .select('''
          file_id,
          Files!inner(
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
          )
        ''')
          .eq('recipient_type', 'user')
          .eq('recipient_id', patientId);

      print(
        'Found ${patientSharedFiles.length} files with patient access keys',
      );

      // Method 2: Also check File_Shares table for explicit doctor shares
      final doctorShares = await supabase
          .from('File_Shares')
          .select('''
          file_id,
          shared_with_doctor,
          shared_by_user_id,
          shared_at,
          Files!inner(
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
          )
        ''')
          .not('shared_with_doctor', 'is', null)
          .isFilter('revoked_at', null);

      print('Found ${doctorShares.length} doctor share records');

      // Get user's assigned doctors to filter relevant shares
      final assignmentsResponse = await supabase
          .from('Doctor_User_Assignment')
          .select('doctor_id')
          .eq('patient_id', patientId)
          .eq('status', 'active');

      final doctorIds =
          assignmentsResponse
              .map((assignment) => assignment['doctor_id'])
              .toList();

      print('Patient assigned to ${doctorIds.length} doctors: $doctorIds');

      // Combine results and filter for doctor-uploaded files
      Set<String> seenFileIds = {};
      List<Map<String, dynamic>> allFiles = [];

      // Add files from patient keys (Method 1)
      for (final keyRecord in patientSharedFiles) {
        final file = keyRecord['Files'];
        final fileId = file['id'] as String;

        if (!seenFileIds.contains(fileId)) {
          seenFileIds.add(fileId);

          // Check if this file was uploaded by a doctor in the organization
          final isFromDoctorInOrg = await _isFileFromDoctorInOrganization(
            file['uploaded_by'],
            orgId,
          );

          if (isFromDoctorInOrg) {
            allFiles.add({
              'id': file['id'],
              'filename': file['filename'],
              'file_type': file['file_type'],
              'file_size': file['file_size'],
              'uploaded_at': file['uploaded_at'],
              'ipfs_cid': file['ipfs_cid'],
              'category': file['category'],
              'uploaded_by': file['uploaded_by'],
              'User': file['User'],
              'access_method': 'patient_key',
            });
          }
        }
      }

      // Add files from doctor shares (Method 2)
      for (final share in doctorShares) {
        final file = share['Files'];
        final fileId = file['id'] as String;
        final sharedWithDoctorId = share['shared_with_doctor'];

        // Check if this share is relevant to patient's assigned doctors
        if (doctorIds.contains(sharedWithDoctorId) &&
            !seenFileIds.contains(fileId)) {
          seenFileIds.add(fileId);

          allFiles.add({
            'id': file['id'],
            'filename': file['filename'],
            'file_type': file['file_type'],
            'file_size': file['file_size'],
            'uploaded_at': file['uploaded_at'],
            'ipfs_cid': file['ipfs_cid'],
            'category': file['category'],
            'uploaded_by': file['uploaded_by'],
            'User': file['User'],
            'shared_at': share['shared_at'],
            'shared_by_user_id': share['shared_by_user_id'],
            'access_method': 'doctor_share',
          });
        }
      }

      // Sort by upload date (newest first)
      allFiles.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['uploaded_at'] ?? '') ?? DateTime(1970);
        final bDate =
            DateTime.tryParse(b['uploaded_at'] ?? '') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      print('Final result: ${allFiles.length} files available to patient');

      // Debug: Print file details
      for (final file in allFiles) {
        print('  - ${file['filename']} (${file['access_method']})');
      }

      return allFiles;
    } catch (e, stackTrace) {
      print('Error fetching doctor files for patient: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Helper method to check if a file was uploaded by a doctor in the organization
  static Future<bool> _isFileFromDoctorInOrganization(
    String uploaderId,
    String orgId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final doctorCheck =
          await supabase
              .from('Organization_User')
              .select('id')
              .eq('organization_id', orgId)
              .eq('user_id', uploaderId)
              .eq('position', 'Doctor')
              .maybeSingle();

      return doctorCheck != null;
    } catch (e) {
      print('Error checking if uploader is doctor in org: $e');
      return false;
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
