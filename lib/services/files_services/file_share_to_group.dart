import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fast_rsa/fast_rsa.dart';

class FileShareToGroupService {
  static final _supabase = Supabase.instance.client;

  /// Share files with selected groups
  static Future<void> shareFilesToGroups(
    List<String> fileIds,
    List<String> groupIds,
    String userId,
  ) async {
    try {
      print('=== GROUP SHARING DEBUG ===');
      print('User ID: $userId');
      print('Files to share: ${fileIds.length}');
      print('Groups selected: ${groupIds.length}');

      // Get user's RSA private key
      final userData =
          await _supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .single();

      final userRsaPrivateKeyPem = userData['rsa_private_key'] as String;

      // Share with each group
      for (final groupId in groupIds) {
        await _shareFilesToSingleGroup(
          fileIds,
          groupId,
          userRsaPrivateKeyPem,
          userId,
        );
      }

      print('✅ Successfully shared files to all groups');
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in shareFilesToGroups: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Share files with a single group
  static Future<void> _shareFilesToSingleGroup(
    List<String> fileIds,
    String groupId,
    String userRsaPrivateKeyPem,
    String userId,
  ) async {
    try {
      // Get group details
      final groupData =
          await _supabase
              .from('Group')
              .select('name, rsa_public_key')
              .eq('id', groupId)
              .single();

      final groupName = groupData['name'] as String;
      final groupRsaPublicKeyPem = groupData['rsa_public_key'] as String;

      print('\n--- Processing group: $groupName ($groupId) ---');

      for (final fileId in fileIds) {
        await _shareFileToGroup(
          fileId,
          groupId,
          groupName,
          groupRsaPublicKeyPem,
          userRsaPrivateKeyPem,
          userId,
        );
      }
    } catch (e) {
      print('❌ Error processing group $groupId: $e');
      rethrow;
    }
  }

  /// Share a single file with a group
  static Future<void> _shareFileToGroup(
    String fileId,
    String groupId,
    String groupName,
    String groupRsaPublicKeyPem,
    String userRsaPrivateKeyPem,
    String userId,
  ) async {
    try {
      print('Processing file $fileId for group $groupName');

      // Check if already shared
      final existingShare =
          await _supabase
              .from('File_Shares')
              .select('id')
              .eq('file_id', fileId)
              .eq('shared_with_group_id', groupId)
              .maybeSingle();

      if (existingShare != null) {
        print(
          '⚠️  File $fileId already shared with group $groupName, skipping...',
        );
        return;
      }

      // Get user's encrypted AES key package
      final userFileKey =
          await _supabase
              .from('File_Keys')
              .select('aes_key_encrypted')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .single();

      final encryptedKeyPackage = userFileKey['aes_key_encrypted'] as String;

      // Validate encrypted package size (RSA has limitations)
      final encryptedBytes = base64Decode(encryptedKeyPackage);
      if (encryptedBytes.length > 512) {
        // More conservative limit for RSA
        print('❌ ERROR: Encrypted key package too large for RSA decryption');
        print('  File: $fileId, Size: ${encryptedBytes.length} bytes');
        throw Exception('Encrypted key package exceeds RSA limits');
      }

      // Decrypt AES key package using user's private key (with fallback)
      String? decryptedKeyJson;
      try {
        // Try RSA-OAEP first
        decryptedKeyJson = await RSA.decryptOAEP(
          encryptedKeyPackage,
          "",
          Hash.SHA256,
          userRsaPrivateKeyPem,
        );
        print(
          '✓ Successfully decrypted AES key package using RSA-OAEP for file $fileId',
        );
      } catch (e) {
        print('RSA-OAEP decryption failed, trying PKCS1v15 fallback: $e');
        try {
          decryptedKeyJson = await RSA.decryptPKCS1v15(
            encryptedKeyPackage,
            userRsaPrivateKeyPem,
          );
          print(
            '✓ Successfully decrypted AES key package using PKCS1v15 fallback for file $fileId',
          );
        } catch (fallbackError) {
          print(
            '❌ Both RSA-OAEP and PKCS1v15 decryption failed: $fallbackError',
          );
          rethrow;
        }
      }

      // Re-encrypt the key package for the group using group's public key with RSA-OAEP
      final groupEncryptedKeyPackage = await RSA.encryptOAEP(
        decryptedKeyJson,
        "",
        Hash.SHA256,
        groupRsaPublicKeyPem,
      );

      print(
        '✓ Successfully re-encrypted AES key package using RSA-OAEP for group $groupName',
      );

      // Validate the re-encrypted package
      final reEncryptedBytes = base64Decode(groupEncryptedKeyPackage);
      if (reEncryptedBytes.length > 512) {
        print('❌ ERROR: Re-encrypted key package too large');
        throw Exception('Re-encrypted key package exceeds RSA limits');
      }

      // Create share record
      await _supabase.from('File_Shares').insert({
        'file_id': fileId,
        'shared_with_group_id': groupId,
        'shared_by_user_id': userId,
        'shared_at': DateTime.now().toIso8601String(),
      });

      print('✓ Created share record for file $fileId');

      // Create group key record
      await _supabase.from('File_Keys').insert({
        'file_id': fileId,
        'recipient_type': 'group',
        'recipient_id': groupId,
        'aes_key_encrypted': groupEncryptedKeyPackage,
      });

      print('✓ File $fileId shared with group $groupName successfully');
    } catch (e, stackTrace) {
      print('❌ Error sharing file $fileId with group $groupName: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetch user groups for sharing selection
  static Future<List<Map<String, dynamic>>> fetchUserGroups(
    String userId,
  ) async {
    try {
      final groupsResponse = await _supabase
          .from('Group_Members')
          .select('''
            group_id,
            Group!inner(id, name)
          ''')
          .eq('user_id', userId)
          .order('Group(name)', ascending: true);

      return groupsResponse
          .map(
            (item) => {
              'id': item['Group']['id'],
              'name': item['Group']['name'],
            },
          )
          .toList();
    } catch (e) {
      print('Error fetching user groups: $e');
      return [];
    }
  }

  /// Check if files are already shared with specific groups
  static Future<Map<String, Set<String>>> getExistingGroupShares(
    List<String> fileIds,
    List<String> groupIds,
  ) async {
    try {
      final existingShares = await _supabase
          .from('File_Shares')
          .select('file_id, shared_with_group_id')
          .inFilter('file_id', fileIds)
          .inFilter('shared_with_group_id', groupIds);

      final Map<String, Set<String>> result = {};

      for (final share in existingShares) {
        final fileId = share['file_id'] as String;
        final groupId = share['shared_with_group_id'] as String;

        if (!result.containsKey(fileId)) {
          result[fileId] = <String>{};
        }
        result[fileId]!.add(groupId);
      }

      return result;
    } catch (e) {
      print('Error checking existing group shares: $e');
      return {};
    }
  }

  /// Get group members count for UI display
  static Future<int> getGroupMemberCount(String groupId) async {
    try {
      final response = await _supabase
          .from('Group_Members')
          .select('id')
          .eq('group_id', groupId);

      return response.length;
    } catch (e) {
      print('Error fetching group member count: $e');
      return 0;
    }
  }

  /// Validate that user has access to file before sharing
  static Future<bool> validateUserFileAccess(
    String fileId,
    String userId,
  ) async {
    try {
      // Check if user owns the file
      final fileData =
          await _supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      if (fileData['uploaded_by'] == userId) {
        return true;
      }

      // Check if user has access via File_Keys
      final keyAccess =
          await _supabase
              .from('File_Keys')
              .select('id')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .maybeSingle();

      return keyAccess != null;
    } catch (e) {
      print('Error validating user file access: $e');
      return false;
    }
  }

  /// Remove file share from group (revoke access)
  static Future<bool> revokeFileFromGroup({
    required String fileId,
    required String groupId,
    required String userId,
  }) async {
    try {
      // Validate user has permission to revoke
      final hasAccess = await validateUserFileAccess(fileId, userId);
      if (!hasAccess) {
        print('User $userId does not have access to file $fileId');
        return false;
      }

      // Delete share record
      await _supabase
          .from('File_Shares')
          .delete()
          .eq('file_id', fileId)
          .eq('shared_with_group_id', groupId);

      // Delete group key record
      await _supabase
          .from('File_Keys')
          .delete()
          .eq('file_id', fileId)
          .eq('recipient_type', 'group')
          .eq('recipient_id', groupId);

      print('✓ Successfully revoked file $fileId from group $groupId');
      return true;
    } catch (e) {
      print('❌ Error revoking file from group: $e');
      return false;
    }
  }
}
