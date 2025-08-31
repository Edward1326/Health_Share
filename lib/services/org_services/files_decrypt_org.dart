import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/crypto_utils.dart';

class OrgFilesDecryptService {
  static final _supabase = Supabase.instance.client;

  /// Decrypt a file shared between doctor and patient
  /// This handles both directions: patient->doctor and doctor->patient
  static Future<Uint8List?> decryptSharedFile({
    required String fileId,
    required String ipfsCid,
    required String sharedBy, // 'You' or doctor name
    required String doctorId, // Organization_User.id of the doctor
  }) async {
    try {
      print('=== ORG FILE DECRYPTION DEBUG ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');
      print('Shared by: $sharedBy');
      print('Doctor ID: $doctorId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      // STEP 1: Download encrypted file from IPFS
      print('\n--- Step 1: Downloading from IPFS ---');
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        throw Exception('Failed to download file from IPFS');
      }
      print('✓ Downloaded ${encryptedBytes.length} bytes from IPFS');

      // STEP 2: Get current user's RSA private key
      print('\n--- Step 2: Getting user RSA key ---');
      final userData =
          await _supabase
              .from('User')
              .select('id, rsa_private_key, email')
              .eq('id', currentUser.id)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String?;
      if (rsaPrivateKeyPem == null || rsaPrivateKeyPem.isEmpty) {
        throw Exception('User RSA private key is missing');
      }

      final rsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        rsaPrivateKeyPem,
      );
      print('✓ Retrieved RSA private key for user: ${userData['email']}');

      // STEP 3: Determine if we need to use patient or doctor decryption path
      print('\n--- Step 3: Determining decryption path ---');

      // Get the doctor's user_id from Organization_User
      final doctorOrgData =
          await _supabase
              .from('Organization_User')
              .select('user_id')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorOrgData == null) {
        throw Exception('Doctor not found with ID: $doctorId');
      }

      final doctorUserId = doctorOrgData['user_id'] as String;
      print('Doctor user_id: $doctorUserId');

      // Check if current user is the doctor or patient
      final isCurrentUserDoctor = currentUser.id == doctorUserId;
      print('Current user is doctor: $isCurrentUserDoctor');
      print('Shared by indicates user shared: ${sharedBy == "You"}');

      // STEP 4: Get the encrypted AES key based on role
      print('\n--- Step 4: Getting encrypted AES key ---');

      // Try to get the File_Keys record for the current user
      final fileKeyRecord =
          await _supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', currentUser.id)
              .maybeSingle();

      if (fileKeyRecord == null || fileKeyRecord['aes_key_encrypted'] == null) {
        // If not found directly, check if we have access through doctor relationship
        print('Direct key not found, checking alternative access...');

        // If current user is a patient, check if they have original ownership
        final originalFileKey =
            await _supabase
                .from('File_Keys')
                .select('aes_key_encrypted, nonce_hex')
                .eq('file_id', fileId)
                .eq('recipient_type', 'user')
                .eq('recipient_id', currentUser.id)
                .maybeSingle();

        if (originalFileKey == null) {
          throw Exception('No decryption key found for this file');
        }

        return _performDecryption(
          encryptedBytes,
          originalFileKey['aes_key_encrypted'] as String,
          originalFileKey['nonce_hex'] as String?,
          rsaPrivateKey,
        );
      }

      // STEP 5: Decrypt the file
      return _performDecryption(
        encryptedBytes,
        fileKeyRecord['aes_key_encrypted'] as String,
        fileKeyRecord['nonce_hex'] as String?,
        rsaPrivateKey,
      );
    } catch (e, stackTrace) {
      print('❌ Error in decryptSharedFile: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Alternative method that doesn't require knowing the sharing direction
  /// Useful when you just have the file info without the sharing context
  static Future<Uint8List?> decryptSharedFileSimple({
    required String fileId,
    required String ipfsCid,
  }) async {
    try {
      print('=== SIMPLE ORG FILE DECRYPTION ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No current user found');
      }

      // Download encrypted file
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        throw Exception('Failed to download file from IPFS');
      }

      // Get user's RSA private key
      final userData =
          await _supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', currentUser.id)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;
      final rsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        rsaPrivateKeyPem,
      );

      // Try to get the encrypted AES key for current user
      final fileKeyRecords = await _supabase
          .from('File_Keys')
          .select('aes_key_encrypted, nonce_hex')
          .eq('file_id', fileId)
          .eq('recipient_type', 'user')
          .eq('recipient_id', currentUser.id);

      if (fileKeyRecords.isEmpty) {
        throw Exception('No decryption key found for this file');
      }

      // Use the first valid key found
      final fileKeyRecord = fileKeyRecords.first;

      return _performDecryption(
        encryptedBytes,
        fileKeyRecord['aes_key_encrypted'] as String,
        fileKeyRecord['nonce_hex'] as String?,
        rsaPrivateKey,
      );
    } catch (e, stackTrace) {
      print('❌ Error in decryptSharedFileSimple: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Perform the actual decryption
  static Future<Uint8List> _performDecryption(
    Uint8List encryptedBytes,
    String encryptedKeyPackage,
    String? nonceHex,
    dynamic rsaPrivateKey,
  ) async {
    try {
      print('\n--- Performing decryption ---');

      // Decrypt the AES key package
      final decryptedJson = MyCryptoUtils.rsaDecrypt(
        encryptedKeyPackage,
        rsaPrivateKey,
      );

      final keyData = jsonDecode(decryptedJson);
      final aesKeyHex = keyData['key'] as String;
      final finalNonceHex = keyData['nonce'] as String? ?? nonceHex;

      if (finalNonceHex == null) {
        throw Exception('Nonce not found in key data or database');
      }

      print('✓ Successfully decrypted AES key and nonce');

      // Create AESHelper and decrypt file
      final aesHelper = AESHelper(aesKeyHex, finalNonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print(
        '✓ Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );
      return decryptedBytes;
    } catch (e) {
      print('Error in _performDecryption: $e');
      rethrow;
    }
  }

  /// Download file from IPFS
  static Future<Uint8List?> _downloadFromIPFS(String cid) async {
    try {
      print('Downloading from IPFS: https://gateway.pinata.cloud/ipfs/$cid');
      final response = await http.get(
        Uri.parse('https://gateway.pinata.cloud/ipfs/$cid'),
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
}
