// decrypt_view_file.dart - COMPLETE FIX
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';

class DecryptAndViewFileService {
  /// Main entry point for file decryption - automatically detects the right method
  static Future<Uint8List?> decryptFileFromIpfs({
    required String cid,
    required String fileId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print(
        'Starting file decryption for CID: $cid, File ID: $fileId, User: $userId',
      );

      // 1. Download encrypted file from IPFS first (common for all methods)
      final encryptedBytes = await _downloadFromIPFS(cid);
      if (encryptedBytes == null) {
        print('Failed to download file from IPFS');
        return null;
      }
      print('Downloaded ${encryptedBytes.length} bytes from IPFS');

      // 2. Check if user is the owner of the file
      final fileOwnerCheck =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .maybeSingle();

      if (fileOwnerCheck != null && fileOwnerCheck['uploaded_by'] == userId) {
        print('User is the file owner, attempting personal decryption...');
        return await _decryptPersonalFile(
          encryptedBytes: encryptedBytes,
          fileId: fileId,
          userId: userId,
        );
      }

      // 3. Check if file is shared with any of user's groups
      final userGroups = await supabase
          .from('Group_Members')
          .select('group_id')
          .eq('user_id', userId);

      if (userGroups.isEmpty) {
        print('User is not a member of any groups and not the file owner');
        return null;
      }

      final groupIds = userGroups.map((g) => g['group_id'] as String).toList();

      // Check which group has this file shared
      final groupShare =
          await supabase
              .from('Group_File_Shares')
              .select('group_id')
              .eq('file_id', fileId)
              .inFilter('group_id', groupIds)
              .maybeSingle();

      if (groupShare == null) {
        print('File is not shared with any of user\'s groups');
        return null;
      }

      print('File is shared with group: ${groupShare['group_id']}');

      // 4. Try group decryption
      return await _decryptWithGroupKey(
        encryptedBytes: encryptedBytes,
        fileId: fileId,
        groupId: groupShare['group_id'],
      );
    } catch (e) {
      print('Error during file decryption: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Decrypt personal file (for file owner)
  static Future<Uint8List?> _decryptPersonalFile({
    required Uint8List encryptedBytes,
    required String fileId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Get user's RSA private key
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final rsaPrivateKeyPem = userData['rsa_private_key'] as String;
      final rsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(rsaPrivateKeyPem);
      print('Retrieved user RSA private key');

      // 2. Get encrypted AES key from File_Keys table
      final fileKeyRecord =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .maybeSingle();

      if (fileKeyRecord == null) {
        print('No personal file key found for file_id: $fileId');
        return null;
      }

      // 3. Decrypt the AES key
      final encryptedAesKeyBase64 =
          fileKeyRecord['aes_key_encrypted'] as String;
      final nonceHex = fileKeyRecord['nonce_hex'] as String;

      print('Attempting to decrypt AES key...');

      // The encrypted key is stored as: base64(utf8(rsaEncrypted))
      // So we need to: base64Decode -> utf8Decode -> rsaDecrypt
      String decryptedAesKeyBase64;
      try {
        final encryptedBytes = base64Decode(encryptedAesKeyBase64);
        final encryptedText = utf8.decode(encryptedBytes);
        decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
          encryptedText,
          rsaPrivateKey,
        );
      } catch (e) {
        print('Standard decryption failed, trying alternative format: $e');
        // Try alternative format (might be directly encrypted)
        try {
          decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
            encryptedAesKeyBase64,
            rsaPrivateKey,
          );
        } catch (e2) {
          print('Alternative decryption also failed: $e2');
          return null;
        }
      }

      // 4. Convert decrypted AES key to hex
      final aesKeyBytes = base64Decode(decryptedAesKeyBase64);
      final aesKeyHex =
          aesKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      print('AES key decrypted successfully');

      // 5. Decrypt the file
      final aesHelper = AESHelper(aesKeyHex, nonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print(
        'File decrypted successfully. Size: ${decryptedBytes.length} bytes',
      );
      return decryptedBytes;
    } catch (e) {
      print('Error during personal file decryption: $e');
      return null;
    }
  }

  /// Decrypt file using group's RSA key (for group members)
  static Future<Uint8List?> _decryptWithGroupKey({
    required Uint8List encryptedBytes,
    required String fileId,
    required String groupId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('Attempting group decryption for group: $groupId');

      // 1. Get group's RSA private key
      final groupData =
          await supabase
              .from('Group')
              .select('rsa_private_key')
              .eq('id', groupId)
              .single();

      final groupRsaPrivateKeyPem = groupData['rsa_private_key'] as String;
      final groupRsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(
        groupRsaPrivateKeyPem,
      );
      print('Retrieved group RSA private key');

      // 2. Get encrypted AES key from Group_File_Keys table
      final fileKeyRecord =
          await supabase
              .from('Group_File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'group')
              .eq('recipient_id', groupId)
              .maybeSingle();

      if (fileKeyRecord == null) {
        print('No group file key found for group: $groupId and file: $fileId');
        return null;
      }

      // 3. Decrypt the AES key using group's private key
      final encryptedAesKeyBase64 =
          fileKeyRecord['aes_key_encrypted'] as String;
      final nonceHex = fileKeyRecord['nonce_hex'] as String;

      print('Attempting to decrypt AES key with group RSA...');

      // The encrypted key is stored as: base64(utf8(rsaEncrypted))
      String decryptedAesKeyBase64;
      try {
        final encryptedBytes = base64Decode(encryptedAesKeyBase64);
        final encryptedText = utf8.decode(encryptedBytes);
        decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
          encryptedText,
          groupRsaPrivateKey,
        );
      } catch (e) {
        print(
          'Standard group decryption failed, trying alternative format: $e',
        );
        // Try alternative format
        try {
          decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
            encryptedAesKeyBase64,
            groupRsaPrivateKey,
          );
        } catch (e2) {
          print('Alternative group decryption also failed: $e2');
          return null;
        }
      }

      // 4. Convert decrypted AES key to hex
      final aesKeyBytes = base64Decode(decryptedAesKeyBase64);
      final aesKeyHex =
          aesKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      print('Group AES key decrypted successfully');

      // 5. Decrypt the file
      final aesHelper = AESHelper(aesKeyHex, nonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print(
        'Group file decrypted successfully. Size: ${decryptedBytes.length} bytes',
      );
      return decryptedBytes;
    } catch (e) {
      print('Error during group decryption: $e');
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

  /// Smart decryption for group files - automatically handles the decryption
  static Future<Uint8List?> decryptGroupFile({
    required String cid,
    required String fileId,
    required String userId,
    required String groupId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print(
        'Starting group file decryption for File ID: $fileId, Group ID: $groupId',
      );

      // 1. Verify user is a member of the group
      final memberCheck =
          await supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (memberCheck == null) {
        print('User is not a member of group: $groupId');
        return null;
      }

      // 2. Download encrypted file from IPFS
      final encryptedBytes = await _downloadFromIPFS(cid);
      if (encryptedBytes == null) {
        print('Failed to download file from IPFS');
        return null;
      }

      // 3. Try group decryption
      final result = await _decryptWithGroupKey(
        encryptedBytes: encryptedBytes,
        fileId: fileId,
        groupId: groupId,
      );

      if (result != null) {
        return result;
      }

      // 4. If group decryption fails and user is the owner, try personal decryption
      final fileOwnerCheck =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .maybeSingle();

      if (fileOwnerCheck != null && fileOwnerCheck['uploaded_by'] == userId) {
        print(
          'Group decryption failed, but user is owner. Trying personal decryption...',
        );
        return await _decryptPersonalFile(
          encryptedBytes: encryptedBytes,
          fileId: fileId,
          userId: userId,
        );
      }

      return null;
    } catch (e) {
      print('Error in decryptGroupFile: $e');
      return null;
    }
  }

  /// Fetches all files for the current user
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

  /// Fetches files shared with user's groups
  static Future<List<Map<String, dynamic>>> fetchGroupSharedFiles(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Get user's groups
      final userGroups = await supabase
          .from('Group_Members')
          .select('group_id')
          .eq('user_id', userId);

      if (userGroups.isEmpty) {
        print('User is not a member of any groups');
        return [];
      }

      final groupIds = userGroups.map((g) => g['group_id']).toList();

      // Get files shared with these groups
      final sharedFiles = await supabase
          .from('Group_File_Shares')
          .select('''
            *,
            Files (
              id,
              filename,
              file_type,
              file_size,
              uploaded_at,
              ipfs_cid,
              category
            ),
            Group (
              id,
              name
            )
          ''')
          .inFilter('group_id', groupIds)
          .order('shared_at', ascending: false);

      print('Fetched ${sharedFiles.length} group shared files');
      return List<Map<String, dynamic>>.from(sharedFiles);
    } catch (e) {
      print('Error fetching group shared files: $e');
      return [];
    }
  }

  /// Check if user has access to a file
  static Future<bool> canUserAccessFile({
    required String userId,
    required String fileId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if user owns the file
      final fileOwnerCheck =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .eq('uploaded_by', userId)
              .maybeSingle();

      if (fileOwnerCheck != null) {
        print('User owns the file');
        return true;
      }

      // Check if file is shared with any of user's groups
      final userGroups = await supabase
          .from('Group_Members')
          .select('group_id')
          .eq('user_id', userId);

      if (userGroups.isNotEmpty) {
        final groupIds = userGroups.map((g) => g['group_id']).toList();

        final groupShareCheck =
            await supabase
                .from('Group_File_Shares')
                .select()
                .eq('file_id', fileId)
                .inFilter('group_id', groupIds)
                .maybeSingle();

        if (groupShareCheck != null) {
          print('File is shared with user\'s group');
          return true;
        }
      }

      print('User does not have access to file');
      return false;
    } catch (e) {
      print('Error checking file access: $e');
      return false;
    }
  }
}
