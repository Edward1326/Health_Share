import 'dart:convert';
import 'package:health_share/services/crypto_utils.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/files_services/file_picker_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UploadFileService {
  // Pinata JWT token (store securely in .env)
  static final String _pinataJWT = dotenv.env['PINATA_JWT'] ?? '';

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

      // 2. Generate AES key + nonce
      final aesKey = encrypt.Key.fromSecureRandom(32); // 32 bytes = AES-256
      final aesNonce = encrypt.IV.fromSecureRandom(12); // 96-bit nonce

      // 3. Encrypt file
      final aesHelper = AESHelper(aesKey.base16, aesNonce.base16);
      final encryptedBytes = aesHelper.encryptData(fileBytes);

      // 4. Get current user
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

      // 5. Fetch user RSA public key
      final userData =
          await supabase
              .from('User')
              .select('rsa_public_key, id')
              .eq('id', user.id)
              .single();

      final rsaPublicKeyPem = userData['rsa_public_key'] as String;
      final rsaPublicKey = MyCryptoUtils.rsaPublicKeyFromPem(rsaPublicKeyPem);

      // 6. Build JSON with AES key + nonce
      final keyData = {'key': aesKey.base16, 'nonce': aesNonce.base16};
      final keyDataJson = jsonEncode(keyData);

      // 7. Encrypt JSON with RSA -> already Base64 string
      final encryptedKeyPackage = MyCryptoUtils.rsaEncrypt(
        keyDataJson,
        rsaPublicKey,
      );

      // 8. Upload encrypted file to Pinata with original filename
      final ipfsCid = await _uploadToPinata(encryptedBytes, fileName);
      if (ipfsCid == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload to IPFS')),
          );
        }
        return false;
      }
      print('Upload successful. CID: $ipfsCid');

      // 9. Insert file metadata into Supabase
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

      final String fileId = fileInsert['id'].toString();
      print('File inserted with ID: $fileId');

      // 10. Insert encrypted key package into File_Keys
      final success = await _storeFileKey(
        fileId: fileId,
        encryptedKeyPackage: encryptedKeyPackage,
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

  /// Uploads encrypted file to Pinata with original filename
  static Future<String?> _uploadToPinata(
    List<int> encryptedBytes,
    String fileName,
  ) async {
    try {
      final url = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');

      final request =
          http.MultipartRequest('POST', url)
            ..headers['Authorization'] = 'Bearer $_pinataJWT'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                encryptedBytes,
                filename:
                    fileName, // Use the original filename instead of 'encrypted.aes'
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

  /// Stores RSA-encrypted AES package in File_Keys
  static Future<bool> _storeFileKey({
    required String fileId,
    required String encryptedKeyPackage,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final insertData = {
        'file_id': fileId,
        'recipient_type': 'user',
        'recipient_id': userId,
        'aes_key_encrypted': encryptedKeyPackage,
      };

      final result =
          await supabase.from('File_Keys').insert(insertData).select();
      print('File key inserted successfully: $result');
      return true;
    } catch (fileKeyError, stackTrace) {
      print('Error inserting file key: $fileKeyError');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
}
