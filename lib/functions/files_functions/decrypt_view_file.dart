import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';

class DecryptAndViewFileService {
  static Future<Uint8List?> decryptFileFromIpfs({
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
      print('Retrieved RSA private key from user data');

      // 3. Get encrypted AES key and nonce from Supabase
      final fileKeyRecord =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .maybeSingle();

      if (fileKeyRecord == null || fileKeyRecord['aes_key_encrypted'] == null) {
        print('AES key not found in File_Keys for file_id: $fileId');
        return null;
      }

      final encryptedAesKeyBase64 =
          fileKeyRecord['aes_key_encrypted'] as String;
      print('Retrieved encrypted AES key from database');

      // 4. Decrypt AES key with RSA private key
      final rsaEncryptedBytes = base64Decode(encryptedAesKeyBase64);
      final rsaEncryptedText = utf8.decode(rsaEncryptedBytes);
      final rsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
      final decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
        rsaEncryptedText,
        rsaPrivateKey,
      );
      final decryptedAesKeyBytes = base64Decode(decryptedAesKeyBase64);

      print('Successfully decrypted AES key with RSA');

      // 5. Convert AES key bytes to hex string
      final aesKeyHex =
          decryptedAesKeyBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();

      // 6. Get nonce from database
      String nonceHex;
      if (fileKeyRecord['nonce_hex'] != null) {
        nonceHex = fileKeyRecord['nonce_hex'] as String;
        print('Retrieved nonce from database: $nonceHex');
      } else {
        print('Error: nonce_hex not found in database for file_id: $fileId');
        return null;
      }

      // 7. Create AESHelper with GCM mode and decrypt file
      final aesHelper = AESHelper(aesKeyHex, nonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );
      print("Decrypted file size: ${decryptedBytes.length}");

      return decryptedBytes;
    } catch (e) {
      print('Error during decryption flow: $e');
      print('Stack trace: ${StackTrace.current}');
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

  /// Fetches all files for the current user from Supabase
  static Future<List<Map<String, dynamic>>> fetchUserFiles(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final files = await supabase
          .from('Files')
          .select(
            'id, filename, file_type, file_size, uploaded_at, ipfs_cid, category',
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
