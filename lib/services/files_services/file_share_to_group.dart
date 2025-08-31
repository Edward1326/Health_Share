import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/crypto_utils.dart';

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
      final userRsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        userRsaPrivateKeyPem,
      );

      // Share with each group
      for (final groupId in groupIds) {
        await _shareFilesToSingleGroup(
          fileIds,
          groupId,
          userRsaPrivateKey,
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
    dynamic userRsaPrivateKey,
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
      final groupRsaPublicKey = MyCryptoUtils.rsaPublicKeyFromPem(
        groupRsaPublicKeyPem,
      );

      print('\n--- Processing group: $groupName ($groupId) ---');

      for (final fileId in fileIds) {
        await _shareFileToGroup(
          fileId,
          groupId,
          groupName,
          groupRsaPublicKey,
          userRsaPrivateKey,
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
    dynamic groupRsaPublicKey,
    dynamic userRsaPrivateKey,
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

      // Get user's encrypted AES key
      final userFileKey =
          await _supabase
              .from('File_Keys')
              .select('aes_key_encrypted')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', userId)
              .single();

      final encryptedKeyPackage = userFileKey['aes_key_encrypted'] as String;

      // Check encrypted package size
      final encryptedBytes = base64Decode(encryptedKeyPackage);
      if (encryptedBytes.length > 256) {
        print('❌ ERROR: Encrypted key package too large for RSA decryption');
        print('  File: $fileId, Size: ${encryptedBytes.length} bytes');
        return;
      }

      // Decrypt and re-encrypt for group using MyCryptoUtils
      final decryptedKeyJson = MyCryptoUtils.rsaDecrypt(
        encryptedKeyPackage,
        userRsaPrivateKey,
      );

      final groupEncryptedKeyPackage = MyCryptoUtils.rsaEncrypt(
        decryptedKeyJson,
        groupRsaPublicKey,
      );

      // Create share record
      await _supabase.from('File_Shares').insert({
        'file_id': fileId,
        'shared_with_group_id': groupId,
        'shared_by_user_id': userId,
        'shared_at': DateTime.now().toIso8601String(),
      });

      // Create group key record
      await _supabase.from('File_Keys').insert({
        'file_id': fileId,
        'recipient_type': 'group',
        'recipient_id': groupId,
        'aes_key_encrypted': groupEncryptedKeyPackage,
      });

      print('✓ File $fileId shared with group $groupName');
    } catch (e) {
      print('❌ Error sharing file $fileId with group $groupName: $e');
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
          .eq('user_id', userId);

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
}
