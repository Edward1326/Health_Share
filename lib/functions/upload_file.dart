import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/file_picker_service.dart';

class UploadFileService {
  // Pinata JWT token - consider moving this to environment variables
  static const String _pinataJWT =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiI1MjNmNzlmZC0xZjVmLTQ4NzUtOTQwMS01MDcyMDE3NmMyYjYiLCJlbWFpbCI6ImVkd2FyZC5xdWlhbnpvbi5yQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaW5fcG9saWN5Ijp7InJlZ2lvbnMiOlt7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6IkZSQTEifSx7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6Ik5ZQzEifV0sInZlcnNpb24iOjF9LCJtZmFfZW5hYmxlZCI6ZmFsc2UsInN0YXR1cyI6IkFDVElWRSJ9LCJhdXRoZW50aWNhdGlvblR5cGUiOiJzY29wZWRLZXkiLCJzY29wZWRLZXlLZXkiOiI5NmM3NGQxNTY4YzBlNDE4MGQ5MiIsInNjb3BlZEtleVNlY3JldCI6IjQ2MDIxYzNkYThmZDIzZDJmY2E4ZmYzNThjMGI3NmE2ODYxMzRhOWMzNDNiOTFmODY3MmIyMzhlYjE2N2FkODkiLCJleHAiOjE3ODU2ODIyMzl9.1VpMdmG4CaQ-eNxNVesfiy-P6J7p9IGLtjD9q1r5mkg';

  /// Uploads a file with encryption and stores metadata in Supabase
  /// Returns true if successful, false otherwise
  static Future<bool> uploadFile(BuildContext context) async {
    try {
      // 1. Pick a file
      final file = await FilePickerService.pickFile();
      if (file == null) return false;

      final fileBytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final fileType = fileName.split('.').last.toUpperCase();

      // 2. Generate a random AES key and nonce for GCM mode
      final aesKey = encrypt.Key.fromSecureRandom(32); // 32 bytes for AES-256
      final aesNonce = encrypt.IV.fromSecureRandom(
        12,
      ); // 12 bytes for GCM nonce (96 bits)

      // 3. Encrypt the file using GCM mode
      final aesHelper = AESHelper(aesKey.base16, aesNonce.base16);
      final encryptedBytes = aesHelper.encryptData(fileBytes);

      // 4. Get current user and their RSA public key from Supabase
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User not logged in!')));
        }
        return false;
      }

      // 5. Fetch user data and RSA public key
      final userData =
          await supabase
              .from('User')
              .select('rsa_public_key, id')
              .eq('id', user.id)
              .single();
      final rsaPublicKeyPem = userData['rsa_public_key'] as String;
      final rsaPublicKey = CryptoUtils.rsaPublicKeyFromPem(rsaPublicKeyPem);

      // 6. Encrypt the AES key with RSA
      final aesKeyBase64 = base64Encode(
        aesKey.bytes,
      ); // Convert to String first
      final rsaEncryptedBytes = CryptoUtils.rsaEncrypt(
        aesKeyBase64,
        rsaPublicKey,
      );
      final encryptedAesKeyString = base64Encode(
        utf8.encode(rsaEncryptedBytes),
      );

      // 7. Upload encrypted file to IPFS via Pinata
      final ipfsCid = await _uploadToPinata(encryptedBytes);
      if (ipfsCid == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload to IPFS')),
          );
        }
        return false;
      }

      print('Upload successful. CID: $ipfsCid');

      // 8. Insert file metadata into Supabase
      final fileInsert =
          await supabase
              .from('Files')
              .insert({
                'filename': fileName,
                'category': 'General',
                'file_type': fileType,
                'uploaded_at': DateTime.now().toIso8601String(),
                'file_size': fileBytes.length,
                'ipfs_cid': ipfsCid,
                'uploaded_by': user.id,
              })
              .select()
              .single();

      // Ensure fileId is treated as String (UUID)
      final String fileId = fileInsert['id'].toString();
      print('File inserted with ID: $fileId');

      // 9. Insert encrypted AES key and nonce into File_keys
      final success = await _storeFileKey(
        fileId: fileId, // Now explicitly String
        encryptedAesKey: encryptedAesKeyString,
        nonceHex: aesNonce.base16, // Store nonce as hex
        userId: user.id,
      );

      if (!success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File uploaded but key storage failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      // Success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded and encrypted successfully!'),
          ),
        );
      }
      return true;
    } catch (e, stackTrace) {
      print('Error uploading file: $e');
      print('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
      }
      return false;
    }
  }

  /// Uploads encrypted file bytes to Pinata IPFS
  /// Returns the IPFS CID if successful, null otherwise
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
                filename: 'encrypted.aes',
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

  /// Stores the encrypted AES key and nonce in the File_Keys table
  /// Returns true if successful, false otherwise
  static Future<bool> _storeFileKey({
    required String fileId, // Changed from dynamic to String
    required String encryptedAesKey,
    required String nonceHex,
    required String userId,
  }) async {
    try {
      print('Attempting to insert file key with:');
      print('  fileId: $fileId (type: ${fileId.runtimeType})');
      print('  userId: $userId (type: ${userId.runtimeType})');
      print('  recipient_type: user');
      print('  aes_key_encrypted length: ${encryptedAesKey.length}');
      print('  nonce_hex length: ${nonceHex.length}');

      final insertData = {
        'file_id': fileId, // Now guaranteed to be String
        'recipient_type': 'user',
        'recipient_id': null,
        'aes_key_encrypted': encryptedAesKey,
        'nonce_hex': nonceHex, // Store the nonce in hex format
      };
      print('Insert data: $insertData');

      final supabase = Supabase.instance.client;
      final result =
          await supabase.from('File_Keys').insert(insertData).select();
      print('File key inserted successfully: $result');
      return true;
    } catch (fileKeyError, stackTrace) {
      print('Error inserting file key: $fileKeyError');
      print('Error type: ${fileKeyError.runtimeType}');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}
