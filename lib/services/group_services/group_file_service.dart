import 'dart:convert';
import 'dart:typed_data';
import 'package:health_share/services/crypto_utils.dart';
import 'package:http/http.dart' as http;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/aes_helper.dart';

class GroupFileService {
  /// Fetch all files shared with a specific group
  static Future<List<Map<String, dynamic>>> fetchGroupSharedFiles(
    String groupId,
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
          .eq('shared_with_group_id', groupId)
          .order('shared_at', ascending: false);

      print('Fetched ${sharedFiles.length} shared files for group $groupId');
      return sharedFiles;
    } catch (e) {
      print('Error fetching group shared files: $e');
      return [];
    }
  }

  /// Check if current user has access to a specific file in a group
  static Future<bool> hasGroupFileAccess(
    String fileId,
    String groupId,
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Check if user is a member of the group
      final memberCheck =
          await supabase
              .from('Group_Members')
              .select('id')
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (memberCheck == null) {
        print('User $userId is not a member of group $groupId');
        return false;
      }

      // Check if file is shared with the group
      final shareCheck =
          await supabase
              .from('File_Shares')
              .select('id')
              .eq('file_id', fileId)
              .eq('shared_with_group_id', groupId)
              .maybeSingle();

      return shareCheck != null;
    } catch (e) {
      print('Error checking group file access: $e');
      return false;
    }
  }

  /// Decrypt a shared file using group's RSA private key - UPDATED to match main flow
  static Future<Uint8List?> decryptGroupSharedFile({
    required String fileId,
    required String groupId,
    required String userId,
    required String ipfsCid,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== GROUP FILE DECRYPTION DEBUG ===');
      print('File ID: $fileId');
      print('Group ID: $groupId');
      print('User ID: $userId');
      print('IPFS CID: $ipfsCid');

      // Verify user has access to this file
      final hasAccess = await hasGroupFileAccess(fileId, groupId, userId);
      if (!hasAccess) {
        print('❌ User does not have access to this file');
        return null;
      }
      print('✓ User has access to file');

      // Download encrypted file from IPFS
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        print('❌ Failed to download file from IPFS');
        return null;
      }
      print('✓ Downloaded ${encryptedBytes.length} bytes from IPFS');

      // Get group's RSA private key
      print('Fetching group RSA private key...');
      final groupData =
          await supabase
              .from('Group')
              .select('rsa_private_key')
              .eq('id', groupId)
              .single();

      final groupRsaPrivateKeyPem = groupData['rsa_private_key'] as String;
      final groupRsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        // Changed from CryptoUtils
        groupRsaPrivateKeyPem,
      );
      print('✓ Retrieved and parsed group RSA private key');

      // Get encrypted AES key package for this group (using same format as user files)
      print('Fetching group file key package...');
      final groupFileKey =
          await supabase
              .from('File_Keys')
              .select('aes_key_encrypted')
              .eq('file_id', fileId)
              .eq('recipient_type', 'group')
              .eq('recipient_id', groupId)
              .maybeSingle();

      if (groupFileKey == null || groupFileKey['aes_key_encrypted'] == null) {
        print('❌ AES key package not found for group access to file: $fileId');
        return null;
      }

      final encryptedKeyPackage = groupFileKey['aes_key_encrypted'] as String;
      print(
        '✓ Retrieved encrypted AES key package, length: ${encryptedKeyPackage.length}',
      );

      // Decrypt AES key package using group's RSA private key (same as DecryptFileService)
      print('Decrypting AES key package...');
      final decryptedKeyJson = MyCryptoUtils.rsaDecrypt(
        // Changed from CryptoUtils
        encryptedKeyPackage,
        groupRsaPrivateKey,
      );

      // Parse the JSON to get key and nonce
      final keyData = jsonDecode(decryptedKeyJson);
      final aesKeyHex = keyData['key'] as String;
      final nonceHex = keyData['nonce'] as String;

      print('✓ Successfully decrypted AES key package');
      print('AES key length: ${aesKeyHex.length} chars');
      print('Nonce length: ${nonceHex.length} chars');

      // Create AESHelper with GCM mode and decrypt file
      print('Decrypting file data...');
      final aesHelper = AESHelper(aesKeyHex, nonceHex);
      final decryptedBytes = aesHelper.decryptData(encryptedBytes);

      print('✓ Successfully decrypted group shared file');
      print('Decrypted size: ${decryptedBytes.length} bytes');
      print('=== GROUP FILE DECRYPTION COMPLETED ===');

      return decryptedBytes;
    } catch (e, stackTrace) {
      print('❌ Error during group file decryption: $e');
      print('Stack trace: $stackTrace');
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
          '✓ Successfully downloaded from IPFS. Size: ${response.bodyBytes.length} bytes',
        );
        return response.bodyBytes;
      } else {
        print(
          '❌ Failed to fetch from IPFS: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Error downloading from IPFS: $e');
      return null;
    }
  }

  /// Revoke file sharing from a group (only file owner or group owner can do this)
  static Future<bool> revokeFileFromGroup({
    required String fileId,
    required String groupId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== REVOKING FILE ACCESS ===');
      print('File ID: $fileId');
      print('Group ID: $groupId');
      print('User ID: $userId');

      // Check if user is the file owner or group owner
      final fileData =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      final groupData =
          await supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      final isFileOwner = fileData['uploaded_by'] == userId;
      final isGroupOwner = groupData['user_id'] == userId;

      print('Is file owner: $isFileOwner');
      print('Is group owner: $isGroupOwner');

      if (!isFileOwner && !isGroupOwner) {
        print('❌ User $userId is not authorized to revoke this file share');
        return false;
      }

      // Update the File_Shares record to mark as revoked
      print('Marking share as revoked...');
      final shareResult =
          await supabase
              .from('File_Shares')
              .update({'revoked_at': DateTime.now().toIso8601String()})
              .eq('file_id', fileId)
              .eq('shared_with_group_id', groupId)
              .select();

      print('Share revocation result: $shareResult');

      // Remove the group's File_Keys record
      print('Removing group file key...');
      final keyResult =
          await supabase
              .from('File_Keys')
              .delete()
              .eq('file_id', fileId)
              .eq('recipient_type', 'group')
              .eq('recipient_id', groupId)
              .select();

      print('Key deletion result: $keyResult');
      print('✓ Successfully revoked file $fileId from group $groupId');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error revoking file from group: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get sharing information for a specific file
  static Future<Map<String, dynamic>?> getFileSharingInfo(String fileId) async {
    try {
      final supabase = Supabase.instance.client;

      final shares = await supabase
          .from('File_Shares')
          .select('''
            *,
            Group!shared_with_group_id(id, name),
            shared_by:User!shared_by_user_id(email)
          ''')
          .eq('file_id', fileId)
          .isFilter('revoked_at', null); // Only get non-revoked shares

      return {
        'file_id': fileId,
        'shares': shares,
        'total_groups_shared': shares.length,
      };
    } catch (e) {
      print('Error getting file sharing info: $e');
      return null;
    }
  }

  /// Check if a file is shared with any groups
  static Future<bool> isFileSharedWithGroups(String fileId) async {
    try {
      final supabase = Supabase.instance.client;

      final shares = await supabase
          .from('File_Shares')
          .select('id')
          .eq('file_id', fileId)
          .isFilter('revoked_at', null) // Only count non-revoked shares
          .limit(1);

      return shares.isNotEmpty;
    } catch (e) {
      print('Error checking if file is shared: $e');
      return false;
    }
  }

  /// Add a file to a group's shared files (for Supabase storage method)
  static Future<bool> addFileToGroupStorage({
    required String fileName,
    required String filePath,
    required int fileSize,
    required String groupId,
    required String uploadedBy,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Insert into Group_Files table (this seems to be what's used in GroupDetailsScreen)
      await supabase.from('Group_Files').insert({
        'group_id': groupId,
        'file_name': fileName,
        'file_path': filePath,
        'file_size': fileSize,
        'uploaded_by': uploadedBy,
        'uploaded_at': DateTime.now().toIso8601String(),
      });

      print('Successfully added file to group storage');
      return true;
    } catch (e) {
      print('Error adding file to group storage: $e');
      return false;
    }
  }

  /// Decrypt file for group member using either user's own key or group key
  /// This method tries both approaches for maximum compatibility
  static Future<Uint8List?> decryptFileForGroupMember({
    required String fileId,
    required String userId,
    required String ipfsCid,
    String? groupId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== DECRYPTING FILE FOR GROUP MEMBER ===');
      print('File ID: $fileId');
      print('User ID: $userId');
      print('Group ID: $groupId');
      print('IPFS CID: $ipfsCid');

      // Download encrypted file from IPFS first
      final encryptedBytes = await _downloadFromIPFS(ipfsCid);
      if (encryptedBytes == null) {
        print('❌ Failed to download file from IPFS');
        return null;
      }
      print('✓ Downloaded ${encryptedBytes.length} bytes from IPFS');

      // Try user's own key first (if they uploaded the file)
      print('Attempting decryption with user key...');
      try {
        final userData =
            await supabase
                .from('User')
                .select('rsa_private_key')
                .eq('id', userId)
                .single();

        final userRsaPrivateKeyPem = userData['rsa_private_key'] as String;
        final userRsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
          // Changed from CryptoUtils
          userRsaPrivateKeyPem,
        );

        final userFileKey =
            await supabase
                .from('File_Keys')
                .select('aes_key_encrypted')
                .eq('file_id', fileId)
                .eq('recipient_type', 'user')
                .isFilter('recipient_id', null) // Fixed null filtering
                .maybeSingle();

        if (userFileKey != null) {
          final encryptedKeyPackage =
              userFileKey['aes_key_encrypted'] as String;
          final decryptedKeyJson = MyCryptoUtils.rsaDecrypt(
            // Changed from CryptoUtils
            encryptedKeyPackage,
            userRsaPrivateKey,
          );
          final keyData = jsonDecode(decryptedKeyJson);
          final aesKeyHex = keyData['key'] as String;
          final nonceHex = keyData['nonce'] as String;

          final aesHelper = AESHelper(aesKeyHex, nonceHex);
          final decryptedBytes = aesHelper.decryptData(encryptedBytes);

          print('✓ Successfully decrypted using user key');
          return decryptedBytes;
        }
      } catch (userKeyError) {
        print('User key decryption failed: $userKeyError');
      }

      // If user key didn't work and we have a group ID, try group key
      if (groupId != null) {
        print('Attempting decryption with group key...');
        return await decryptGroupSharedFile(
          fileId: fileId,
          groupId: groupId,
          userId: userId,
          ipfsCid: ipfsCid,
        );
      }

      // If no group ID provided, try to find which groups this file is shared with
      print('Finding groups this file is shared with...');
      final userGroups = await supabase
          .from('Group_Members')
          .select('group_id')
          .eq('user_id', userId);

      for (final membership in userGroups) {
        final testGroupId = membership['group_id'] as String;
        print('Trying group: $testGroupId');

        final result = await decryptGroupSharedFile(
          fileId: fileId,
          groupId: testGroupId,
          userId: userId,
          ipfsCid: ipfsCid,
        );

        if (result != null) {
          print('✓ Successfully decrypted using group key: $testGroupId');
          return result;
        }
      }

      print('❌ Could not decrypt file with any available keys');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error in decryptFileForGroupMember: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
