// upload_file_group.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/file_picker_service.dart';

class UploadFileToGroupService {
  // Pinata JWT token - consider moving this to environment variables
  static const String _pinataJWT =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiI1MjNmNzlmZC0xZjVmLTQ4NzUtOTQwMS01MDcyMDE3NmMyYjYiLCJlbWFpbCI6ImVkd2FyZC5xdWlhbnpvbi5yQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaW5fcG9saWN5Ijp7InJlZ2lvbnMiOlt7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6IkZSQTEifSx7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6Ik5ZQzEifV0sInZlcnNpb24iOjF9LCJtZmFfZW5hYmxlZCI6ZmFsc2UsInN0YXR1cyI6IkFDVElWRSJ9LCJhdXRoZW50aWNhdGlvblR5cGUiOiJzY29wZWRLZXkiLCJzY29wZWRLZXlLZXkiOiI5NmM3NGQxNTY4YzBlNDE4MGQ5MiIsInNjb3BlZEtleVNlY3JldCI6IjQ2MDIxYzNkYThmZDIzZDJmY2E4ZmYzNThjMGI3NmE2ODYxMzRhOWMzNDNiOTFmODY3MmIyMzhlYjE2N2FkODkiLCJleHAiOjE3ODU2ODIyMzl9.1VpMdmG4CaQ-eNxNVesfiy-P6J7p9IGLtjD9q1r5mkg';

  /// Uploads a file directly to a group with group encryption
  /// All group members can decrypt and view the file
  static Future<bool> uploadFileToGroup(
    BuildContext context,
    String groupId,
  ) async {
    try {
      // 1. Pick a file
      final file = await FilePickerService.pickFile();
      if (file == null) return false;

      final fileBytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final fileType = fileName.split('.').last.toUpperCase();

      // Show progress dialog
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
                  Text('Uploading $fileName to group...'),
                ],
              ),
            ),
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User not logged in!')));
        }
        return false;
      }

      // 2. Verify user is a member of the group
      final membershipCheck =
          await supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', user.id)
              .maybeSingle();

      if (membershipCheck == null) {
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be a group member to upload files'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // 3. Generate a random AES key and nonce for GCM mode
      final aesKey = encrypt.Key.fromSecureRandom(32); // 32 bytes for AES-256
      final aesNonce = encrypt.IV.fromSecureRandom(
        12,
      ); // 12 bytes for GCM nonce

      // 4. Encrypt the file using GCM mode
      final aesHelper = AESHelper(aesKey.base16, aesNonce.base16);
      final encryptedBytes = aesHelper.encryptData(fileBytes);

      // 5. Get group's RSA public key
      final groupData =
          await supabase
              .from('Group')
              .select('rsa_public_key')
              .eq('id', groupId)
              .single();

      final groupRsaPublicKeyPem = groupData['rsa_public_key'] as String;
      final groupRsaPublicKey = CryptoUtils.rsaPublicKeyFromPem(
        groupRsaPublicKeyPem,
      );

      // 6. Encrypt the AES key with group's RSA public key
      final aesKeyBase64 = base64Encode(aesKey.bytes);
      final groupEncryptedAesKey = CryptoUtils.rsaEncrypt(
        aesKeyBase64,
        groupRsaPublicKey,
      );
      final groupEncryptedAesKeyString = base64Encode(
        utf8.encode(groupEncryptedAesKey),
      );

      // 7. Also encrypt AES key with user's RSA public key (for personal access)
      final userData =
          await supabase
              .from('User')
              .select('rsa_public_key')
              .eq('id', user.id)
              .single();

      final userRsaPublicKeyPem = userData['rsa_public_key'] as String;
      final userRsaPublicKey = CryptoUtils.rsaPublicKeyFromPem(
        userRsaPublicKeyPem,
      );

      final userEncryptedAesKey = CryptoUtils.rsaEncrypt(
        aesKeyBase64,
        userRsaPublicKey,
      );
      final userEncryptedAesKeyString = base64Encode(
        utf8.encode(userEncryptedAesKey),
      );

      // 8. Upload encrypted file to IPFS via Pinata
      final ipfsCid = await _uploadToPinata(encryptedBytes);
      if (ipfsCid == null) {
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload to IPFS')),
          );
        }
        return false;
      }

      print('Upload successful. CID: $ipfsCid');

      // 9. Insert file metadata into Files table
      final fileInsert =
          await supabase
              .from('Files')
              .insert({
                'filename': fileName,
                'category': 'Group Share',
                'file_type': fileType,
                'uploaded_at': DateTime.now().toIso8601String(),
                'file_size': fileBytes.length,
                'ipfs_cid': ipfsCid,
                'uploaded_by': user.id,
              })
              .select()
              .single();

      final String fileId = fileInsert['id'].toString();
      print('File inserted with ID: $fileId');

      // 10. Store encrypted keys for both user and group access
      await Future.wait([
        // User's personal access key
        _storeFileKey(
          fileId: fileId,
          encryptedAesKey: userEncryptedAesKeyString,
          nonceHex: aesNonce.base16,
          recipientType: 'user',
          recipientId: null,
        ),
        // Group access key
        _storeGroupFileKey(
          fileId: fileId,
          encryptedAesKey: groupEncryptedAesKeyString,
          nonceHex: aesNonce.base16,
          groupId: groupId,
        ),
      ]);

      // 11. Create Group_File_Shares record
      await supabase.from('Group_File_Shares').insert({
        'file_id': fileId,
        'group_id': groupId,
        'shared_by': user.id,
        'shared_at': DateTime.now().toIso8601String(),
      });

      Navigator.of(context).pop(); // Close progress dialog

      // Success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName uploaded to group successfully!'),
            backgroundColor: const Color(0xFF11998E),
          ),
        );
      }
      return true;
    } catch (e, stackTrace) {
      print('Error uploading file to group: $e');
      print('Stack trace: $stackTrace');

      // Close progress dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Uploads encrypted file bytes to Pinata IPFS
  static Future<String?> _uploadToPinata(List<int> encryptedBytes) async {
    try {
      final url = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');

      final request =
          http.MultipartRequest('POST', url)
            ..headers['Authorization'] = 'Bearer $_pinataJWT'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                encryptedBytes,
                filename: 'encrypted_group_file.aes',
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

  /// Stores the encrypted AES key in the File_Keys table (for user access)
  static Future<bool> _storeFileKey({
    required String fileId,
    required String encryptedAesKey,
    required String nonceHex,
    required String recipientType,
    required String? recipientId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final insertData = {
        'file_id': fileId,
        'recipient_type': recipientType,
        'recipient_id': recipientId,
        'aes_key_encrypted': encryptedAesKey,
        'nonce_hex': nonceHex,
      };

      await supabase.from('File_Keys').insert(insertData);
      print('File key stored successfully for $recipientType');
      return true;
    } catch (e) {
      print('Error storing file key: $e');
      return false;
    }
  }

  /// Stores the encrypted AES key in the Group_File_Keys table (for group access)
  static Future<bool> _storeGroupFileKey({
    required String fileId,
    required String encryptedAesKey,
    required String nonceHex,
    required String groupId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final insertData = {
        'file_id': fileId,
        'recipient_type': 'group',
        'recipient_id': groupId,
        'aes_key_encrypted': encryptedAesKey,
        'nonce_hex': nonceHex,
      };

      await supabase.from('Group_File_Keys').insert(insertData);
      print('Group file key stored successfully');
      return true;
    } catch (e) {
      print('Error storing group file key: $e');
      return false;
    }
  }
}
