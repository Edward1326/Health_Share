import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/crypto_utils.dart';
import 'package:health_share/services/files_services/file_preview.dart';
import 'package:flutter/material.dart';

class FilesDecryptOrgService {
  /// Decrypts and previews a file from the organization/doctor sharing context
  /// This is specifically for files shown in OrgDoctorsFilesScreen
  static Future<void> decryptAndPreviewOrgFile({
    required BuildContext context,
    required String fileId,
    required String fileName,
    required String ipfsCid,
    required String currentUserId,
  }) async {
    try {
      print('=== DECRYPT ORG FILE DEBUG ===');
      print('File ID: $fileId');
      print('File Name: $fileName');
      print('IPFS CID: $ipfsCid');
      print('Current User ID: $currentUserId');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Decrypting $fileName...'),
                ],
              ),
            ),
      );

      final decryptedBytes = await _decryptFileFromIpfs(
        cid: ipfsCid,
        fileId: fileId,
        userId: currentUserId,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (decryptedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decrypt file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );

      // Verify decrypted data is not empty
      if (decryptedBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Decrypted file is empty'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Use enhanced preview service
      await EnhancedFilePreviewService.previewFile(
        context,
        fileName,
        decryptedBytes,
      );
    } catch (e, stackTrace) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      print('Error in decryptAndPreviewOrgFile: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Core decryption logic for organization shared files
  static Future<Uint8List?> _decryptFileFromIpfs({
    required String cid,
    required String fileId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('Starting decryption for CID: $cid, File ID: $fileId');

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
      final rsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        rsaPrivateKeyPem,
      );
      print('Retrieved RSA private key from user data');

      // 3. Get encrypted AES key+nonce JSON from Supabase
      // For organization context, we need to check for the user's File_Keys entry
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
          'AES key not found in File_Keys for file_id: $fileId, user_id: $userId',
        );
        return null;
      }

      final encryptedKeyPackage = fileKeyRecord['aes_key_encrypted'] as String;
      print('Retrieved encrypted AES key package from database');

      // 4. Decrypt AES key package (Base64 → JSON string)
      final decryptedJson = MyCryptoUtils.rsaDecrypt(
        encryptedKeyPackage,
        rsaPrivateKey,
      );
      final keyData = jsonDecode(decryptedJson);

      final aesKeyHex = keyData['key'] as String;
      final nonceHex = keyData['nonce'] as String;

      print('Successfully decrypted AES key and nonce');

      // 5. Create AESHelper with GCM mode and decrypt file
      final aesHelper = AESHelper(aesKeyHex, nonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );

      return decryptedBytes;
    } catch (e, st) {
      print('Error during decryption flow: $e');
      print(st);
      return null;
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

  /// Fetches shared files between a specific user and doctor
  /// This is used specifically for the OrgDoctorsFilesScreen
  static Future<List<Map<String, dynamic>>> fetchSharedFilesWithDoctor({
    required String userId,
    required String doctorId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== FETCH SHARED FILES WITH DOCTOR ===');
      print('User ID: $userId');
      print('Doctor ID: $doctorId');

      // Get doctor's user ID from Organization_User
      final doctorOrgResponse =
          await supabase
              .from('Organization_User')
              .select('user_id, position, department')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorOrgResponse == null) {
        throw Exception('Doctor not found: $doctorId');
      }

      final doctorUserId = doctorOrgResponse['user_id'] as String;
      print('Doctor user ID: $doctorUserId');

      final Map<String, Map<String, dynamic>> allUniqueFiles = {};

      // Approach 1: Direct doctor shares (shared_with_doctor field)
      print('Fetching direct doctor shares...');
      final directDoctorShares = await supabase
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            revoked_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id,
              filename,
              file_type,
              file_size,
              category,
              uploaded_at,
              sha256_hash,
              ipfs_cid
            )
          ''')
          .eq('shared_with_doctor', doctorUserId)
          .isFilter('revoked_at', null);

      print('Found ${directDoctorShares.length} direct doctor shares');
      _processShares(directDoctorShares, allUniqueFiles, userId, doctorUserId);

      // Approach 2: User-to-user shares (patient to doctor)
      print('Fetching patient to doctor shares...');
      final patientToDoctorShares = await supabase
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            revoked_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id,
              filename,
              file_type,
              file_size,
              category,
              uploaded_at,
              sha256_hash,
              ipfs_cid
            )
          ''')
          .eq('shared_by_user_id', userId)
          .eq('shared_with_user_id', doctorUserId)
          .isFilter('revoked_at', null);

      print('Found ${patientToDoctorShares.length} patient-to-doctor shares');
      _processShares(
        patientToDoctorShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // Approach 3: Doctor-to-patient shares
      print('Fetching doctor to patient shares...');
      final doctorToPatientShares = await supabase
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            revoked_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id,
              filename,
              file_type,
              file_size,
              category,
              uploaded_at,
              sha256_hash,
              ipfs_cid
            )
          ''')
          .eq('shared_by_user_id', doctorUserId)
          .eq('shared_with_user_id', userId)
          .isFilter('revoked_at', null);

      print('Found ${doctorToPatientShares.length} doctor-to-patient shares');
      _processShares(
        doctorToPatientShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // Convert to list and sort by shared date
      final filesList = allUniqueFiles.values.toList();
      filesList.sort((a, b) {
        final dateA = DateTime.parse(a['shared_at']);
        final dateB = DateTime.parse(b['shared_at']);
        return dateB.compareTo(dateA);
      });

      print('Total unique files found: ${filesList.length}');
      return filesList;
    } catch (e, stackTrace) {
      print('Error in fetchSharedFilesWithDoctor: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Helper method to process shares and avoid duplicates
  static void _processShares(
    List<Map<String, dynamic>> shares,
    Map<String, Map<String, dynamic>> allUniqueFiles,
    String userId,
    String doctorUserId,
  ) {
    for (final share in shares) {
      final file = share['Files'];
      if (file == null) {
        print('Skipping share with null file data');
        continue;
      }

      final fileId = file['id'] as String;

      if (!allUniqueFiles.containsKey(fileId)) {
        // Determine sharing context
        String sharedBy;
        String sharedWith;

        if (share['shared_with_doctor'] == doctorUserId) {
          // Direct doctor share
          sharedBy = 'You';
          sharedWith = 'Doctor';
        } else if (share['shared_by_user_id'] == doctorUserId) {
          // Doctor shared to patient
          sharedBy = 'Doctor';
          sharedWith = 'You';
        } else if (share['shared_by_user_id'] == userId) {
          // Patient shared to doctor
          sharedBy = 'You';
          sharedWith = 'Doctor';
        } else {
          // Fallback
          sharedBy = 'Unknown';
          sharedWith = 'Unknown';
        }

        allUniqueFiles[fileId] = {
          ...file,
          'share_id': share['id'],
          'shared_at': share['shared_at'],
          'shared_by': sharedBy,
          'shared_with': sharedWith,
        };

        print('Added file: ${file['filename']} (Shared by: $sharedBy)');
      }
    }
  }

  /// Downloads and decrypts a file for immediate use
  /// Returns the decrypted bytes that can be used for preview or download
  static Future<Uint8List?> downloadAndDecryptFile({
    required String fileId,
    required String ipfsCid,
    required String userId,
  }) async {
    try {
      print('=== DOWNLOAD AND DECRYPT FILE ===');
      print('File ID: $fileId');
      print('IPFS CID: $ipfsCid');
      print('User ID: $userId');

      return await _decryptFileFromIpfs(
        cid: ipfsCid,
        fileId: fileId,
        userId: userId,
      );
    } catch (e) {
      print('Error in downloadAndDecryptFile: $e');
      return null;
    }
  }

  /// Checks if the current user has access to a specific file
  /// This is useful for validating access before attempting decryption
  static Future<bool> hasFileAccess({
    required String fileId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final fileKeyRecord =
          await supabase
              .from('File_Keys')
              .select('id')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      final hasAccess = fileKeyRecord != null;
      print('User $userId has access to file $fileId: $hasAccess');

      return hasAccess;
    } catch (e) {
      print('Error checking file access: $e');
      return false;
    }
  }

  /// Gets detailed information about a shared file including sharing context
  static Future<Map<String, dynamic>?> getSharedFileDetails({
    required String fileId,
    required String userId,
    required String doctorId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Get file details with sharing information
      final fileResponse =
          await supabase
              .from('Files')
              .select('''
            id,
            filename,
            file_type,
            file_size,
            category,
            uploaded_at,
            ipfs_cid,
            uploaded_by
          ''')
              .eq('id', fileId)
              .maybeSingle();

      if (fileResponse == null) {
        print('File not found: $fileId');
        return null;
      }

      // Get doctor's user ID
      final doctorOrgResponse =
          await supabase
              .from('Organization_User')
              .select('user_id')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorOrgResponse == null) {
        print('Doctor not found: $doctorId');
        return null;
      }

      final doctorUserId = doctorOrgResponse['user_id'] as String;

      // Get sharing details
      final shareResponse =
          await supabase
              .from('File_Shares')
              .select(
                'shared_at, shared_by_user_id, shared_with_user_id, shared_with_doctor',
              )
              .eq('file_id', fileId)
              .or(
                'shared_by_user_id.eq.$userId,shared_with_user_id.eq.$userId,shared_with_doctor.eq.$doctorUserId',
              )
              .isFilter('revoked_at', null)
              .limit(1)
              .maybeSingle();

      // Determine sharing context
      String sharedBy = 'Unknown';
      String sharedWith = 'Unknown';
      String sharedAt = DateTime.now().toIso8601String();

      if (shareResponse != null) {
        sharedAt = shareResponse['shared_at'] ?? sharedAt;

        if (shareResponse['shared_with_doctor'] == doctorUserId) {
          sharedBy = 'You';
          sharedWith = 'Doctor';
        } else if (shareResponse['shared_by_user_id'] == userId) {
          sharedBy = 'You';
          sharedWith = 'Doctor';
        } else if (shareResponse['shared_by_user_id'] == doctorUserId) {
          sharedBy = 'Doctor';
          sharedWith = 'You';
        }
      }

      return {
        ...fileResponse,
        'shared_at': sharedAt,
        'shared_by': sharedBy,
        'shared_with': sharedWith,
      };
    } catch (e) {
      print('Error getting shared file details: $e');
      return null;
    }
  }

  /// Validates that a file can be accessed in the organization context
  /// Checks both file existence and proper sharing permissions
  static Future<bool> validateOrgFileAccess({
    required String fileId,
    required String userId,
    required String doctorId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if user has file key access
      final hasAccess = await hasFileAccess(fileId: fileId, userId: userId);
      if (!hasAccess) {
        print('User does not have file key access');
        return false;
      }

      // Get doctor's user ID
      final doctorOrgResponse =
          await supabase
              .from('Organization_User')
              .select('user_id')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorOrgResponse == null) {
        print('Doctor not found for validation');
        return false;
      }

      final doctorUserId = doctorOrgResponse['user_id'] as String;

      // Check if there's a valid sharing relationship
      final shareExists =
          await supabase
              .from('File_Shares')
              .select('id')
              .eq('file_id', fileId)
              .or(
                'shared_by_user_id.eq.$userId,shared_with_user_id.eq.$userId,shared_with_doctor.eq.$doctorUserId',
              )
              .isFilter('revoked_at', null)
              .limit(1)
              .maybeSingle();

      final isValidShare = shareExists != null;
      print('Valid sharing relationship exists: $isValidShare');

      return isValidShare;
    } catch (e) {
      print('Error validating org file access: $e');
      return false;
    }
  }

  /// Revokes access to a shared file in the organization context
  static Future<bool> revokeOrgFileShare({
    required String fileId,
    required String userId,
    required String doctorId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Get doctor's user ID
      final doctorOrgResponse =
          await supabase
              .from('Organization_User')
              .select('user_id')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorOrgResponse == null) {
        print('Doctor not found for revocation');
        return false;
      }

      final doctorUserId = doctorOrgResponse['user_id'] as String;

      // Find and revoke the sharing record
      final revokeResponse = await supabase
          .from('File_Shares')
          .update({'revoked_at': DateTime.now().toIso8601String()})
          .eq('file_id', fileId)
          .or(
            'shared_by_user_id.eq.$userId,shared_with_user_id.eq.$userId,shared_with_doctor.eq.$doctorUserId',
          )
          .isFilter('revoked_at', null);

      print('Revoked sharing for file: $fileId');
      return true;
    } catch (e) {
      print('Error revoking org file share: $e');
      return false;
    }
  }
}
