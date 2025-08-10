// group_file_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:basic_utils/basic_utils.dart';
import 'dart:convert';
import 'dart:typed_data';

class GroupFileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Share a file with a group - ENSURE PROPER ENCRYPTION FORMAT
  Future<bool> shareFileWithGroup({
    required String fileId,
    required String groupId,
    required String userId,
  }) async {
    try {
      print('Sharing file $fileId with group $groupId');

      // 1. Verify user is a member of the group
      final membershipCheck =
          await _supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (membershipCheck == null) {
        throw Exception('You must be a group member to share files');
      }

      // 2. Verify user owns the file
      final fileCheck =
          await _supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .eq('uploaded_by', userId)
              .maybeSingle();

      if (fileCheck == null) {
        throw Exception('File not found or you do not own this file');
      }

      // 3. Check if file is already shared with this group
      final existingShare =
          await _supabase
              .from('Group_File_Shares')
              .select()
              .eq('file_id', fileId)
              .eq('group_id', groupId)
              .maybeSingle();

      if (existingShare != null) {
        throw Exception('File is already shared with this group');
      }

      // 4. Get group's RSA public key
      final groupDetails =
          await _supabase
              .from('Group')
              .select('rsa_public_key')
              .eq('id', groupId)
              .maybeSingle();

      if (groupDetails == null) {
        throw Exception('Group not found');
      }

      final groupRsaPublicKeyPem = groupDetails['rsa_public_key'] as String;
      final groupRsaPublicKey = CryptoUtils.rsaPublicKeyFromPem(
        groupRsaPublicKeyPem,
      );

      // 5. Get the file's AES key (encrypted with user's public key)
      final userKeyRecord =
          await _supabase
              .from('File_Keys')
              .select('aes_key_encrypted, nonce_hex')
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .maybeSingle();

      if (userKeyRecord == null) {
        // Check alternative table
        final altKeyRecord =
            await _supabase
                .from('Group_File_Keys')
                .select('aes_key_encrypted, nonce_hex')
                .eq('file_id', fileId)
                .eq('recipient_type', 'user')
                .maybeSingle();

        if (altKeyRecord == null) {
          throw Exception('File encryption key not found');
        }
        userKeyRecord?.addAll(altKeyRecord);
      }

      // Ensure userKeyRecord is not null before proceeding
      if (userKeyRecord == null) {
        throw Exception('File encryption key not found');
      }

      // 6. Get user's RSA private key to decrypt the AES key
      final userData =
          await _supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', userId)
              .maybeSingle();

      if (userData == null) {
        throw Exception('User not found');
      }

      final userRsaPrivateKeyPem = userData['rsa_private_key'] as String;
      final userRsaPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(
        userRsaPrivateKeyPem,
      );

      // 7. Decrypt the AES key with user's private key
      final encryptedAesKeyBase64 =
          userKeyRecord['aes_key_encrypted'] as String;

      print('Decrypting AES key for sharing...');

      // The key should be stored as: base64(utf8(rsaEncrypted))
      String decryptedAesKeyBase64;
      try {
        // Standard decryption path
        final encryptedBytes = base64Decode(encryptedAesKeyBase64);
        final encryptedText = utf8.decode(encryptedBytes);
        decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
          encryptedText,
          userRsaPrivateKey,
        );
        print('Successfully decrypted AES key using standard format');
      } catch (e) {
        print('Standard decryption failed, trying alternative: $e');
        try {
          // Alternative: might be directly encrypted
          decryptedAesKeyBase64 = CryptoUtils.rsaDecrypt(
            encryptedAesKeyBase64,
            userRsaPrivateKey,
          );
          print('Successfully decrypted AES key using alternative format');
        } catch (e2) {
          print('Both decryption methods failed');
          throw Exception('Failed to decrypt file key: $e2');
        }
      }

      // 8. Re-encrypt the AES key with group's public key
      print('Re-encrypting AES key for group...');
      final groupEncryptedAesKey = CryptoUtils.rsaEncrypt(
        decryptedAesKeyBase64,
        groupRsaPublicKey,
      );

      // FIX: Store the encrypted data more robustly. The encrypted string
      // from rsaEncrypt may not be valid UTF-8, so we get its raw byte
      // representation and then base64 encode that.
      final groupEncryptedAesKeyString = base64Encode(
        Uint8List.fromList(groupEncryptedAesKey.codeUnits),
      );

      print('AES key re-encrypted for group');

      // 9. Store the group-encrypted key in Group_File_Keys
      await _supabase.from('Group_File_Keys').insert({
        'file_id': fileId,
        'recipient_type': 'group',
        'recipient_id': groupId,
        'aes_key_encrypted': groupEncryptedAesKeyString,
        'nonce_hex': userKeyRecord['nonce_hex'],
      });

      // 10. Create a Group_File_Shares record
      await _supabase.from('Group_File_Shares').insert({
        'file_id': fileId,
        'group_id': groupId,
        'shared_by': userId,
        'shared_at': DateTime.now().toIso8601String(),
      });

      print('File shared with group successfully');
      return true;
    } catch (e) {
      print('Error sharing file with group: $e');
      throw Exception('Failed to share file: $e');
    }
  }

  /// Get files shared with a group - Fixed to handle missing relationships
  Future<List<Map<String, dynamic>>> getGroupFiles(String groupId) async {
    try {
      print('Fetching files for group: $groupId');

      // First, get the basic file shares
      final response = await _supabase
          .from('Group_File_Shares')
          .select('*')
          .eq('group_id', groupId)
          .order('shared_at', ascending: false);

      print('Found ${response.length} file shares');

      // For each file share, get the file details and user details separately
      final List<Map<String, dynamic>> enrichedFiles = [];

      for (final share in response) {
        try {
          // Get file details
          final fileDetails =
              await _supabase
                  .from('Files')
                  .select(
                    'id, filename, file_type, file_size, uploaded_at, ipfs_cid, category',
                  )
                  .eq('id', share['file_id'])
                  .maybeSingle();

          // Get shared_by user details
          final sharedByUser =
              await _supabase
                  .from('User')
                  .select('email, person_id')
                  .eq('id', share['shared_by'])
                  .maybeSingle();

          // Get person details if available
          Map<String, dynamic>? personDetails;
          if (sharedByUser != null && sharedByUser['person_id'] != null) {
            personDetails =
                await _supabase
                    .from('Person')
                    .select('first_name, last_name')
                    .eq('id', sharedByUser['person_id'])
                    .maybeSingle();
          }

          // Combine all the data
          enrichedFiles.add({
            ...share,
            'Files': fileDetails,
            'shared_by_user': sharedByUser ?? {'email': 'Unknown'},
            'shared_by_person':
                personDetails ?? {'first_name': '', 'last_name': ''},
          });
        } catch (e) {
          print('Error enriching file share ${share['file_id']}: $e');
          // Add the share with minimal data as fallback
          enrichedFiles.add({
            ...share,
            'Files': {'filename': 'Unknown file', 'file_type': 'UNKNOWN'},
            'shared_by_user': {'email': 'Unknown'},
            'shared_by_person': {'first_name': '', 'last_name': ''},
          });
        }
      }

      print('Returning ${enrichedFiles.length} enriched file shares');
      return enrichedFiles;
    } catch (e) {
      print('Error fetching group files: $e');
      return [];
    }
  }

  /// Get user's files that can be shared with groups
  Future<List<Map<String, dynamic>>> getUserFilesForSharing(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('Files')
          .select('id, filename, file_type, file_size, uploaded_at, category')
          .eq('uploaded_by', userId)
          .order('uploaded_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user files: $e');
      return [];
    }
  }

  /// Unshare a file from a group
  Future<bool> unshareFileFromGroup({
    required String fileId,
    required String groupId,
    required String userId,
  }) async {
    try {
      // Verify user owns the file or is group owner
      final fileCheck =
          await _supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .maybeSingle();

      final groupCheck =
          await _supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .maybeSingle();

      if (fileCheck == null || groupCheck == null) {
        throw Exception('File or group not found');
      }

      final isFileOwner = fileCheck['uploaded_by'] == userId;
      final isGroupOwner = groupCheck['user_id'] == userId;

      if (!isFileOwner && !isGroupOwner) {
        throw Exception('Only file owner or group owner can unshare files');
      }

      // Remove the group-encrypted key
      await _supabase
          .from('Group_File_Keys')
          .delete()
          .eq('file_id', fileId)
          .eq('recipient_type', 'group')
          .eq('recipient_id', groupId);

      // Remove the share record
      await _supabase
          .from('Group_File_Shares')
          .delete()
          .eq('file_id', fileId)
          .eq('group_id', groupId);

      return true;
    } catch (e) {
      print('Error unsharing file: $e');
      throw Exception('Failed to unshare file: $e');
    }
  }

  /// Get groups where user can share files
  Future<List<Map<String, dynamic>>> getUserGroupsForSharing(
    String userId,
  ) async {
    try {
      // Get user's group memberships
      final memberships = await _supabase
          .from('Group_Members')
          .select('group_id')
          .eq('user_id', userId);

      // Get group details for each membership
      final List<Map<String, dynamic>> groups = [];
      for (final membership in memberships) {
        try {
          final group =
              await _supabase
                  .from('Group')
                  .select('id, name, created_at')
                  .eq('id', membership['group_id'])
                  .maybeSingle();

          if (group != null) {
            groups.add(group);
          }
        } catch (e) {
          print('Error fetching group ${membership['group_id']}: $e');
        }
      }

      return groups;
    } catch (e) {
      print('Error fetching user groups: $e');
      return [];
    }
  }

  /// Check if a file is already shared with a specific group
  Future<bool> isFileSharedWithGroup({
    required String fileId,
    required String groupId,
  }) async {
    try {
      final share =
          await _supabase
              .from('Group_File_Shares')
              .select()
              .eq('file_id', fileId)
              .eq('group_id', groupId)
              .maybeSingle();

      return share != null;
    } catch (e) {
      print('Error checking file share status: $e');
      return false;
    }
  }

  /// Get all files shared by a specific user across all groups
  Future<List<Map<String, dynamic>>> getFilesSharedByUser(String userId) async {
    try {
      final shares = await _supabase
          .from('Group_File_Shares')
          .select('*')
          .eq('shared_by', userId)
          .order('shared_at', ascending: false);

      // Enrich with file and group details
      final List<Map<String, dynamic>> enrichedShares = [];
      for (final share in shares) {
        try {
          final fileDetails =
              await _supabase
                  .from('Files')
                  .select('filename, file_type, file_size')
                  .eq('id', share['file_id'])
                  .maybeSingle();

          final groupDetails =
              await _supabase
                  .from('Group')
                  .select('name')
                  .eq('id', share['group_id'])
                  .maybeSingle();

          enrichedShares.add({
            ...share,
            'Files': fileDetails ?? {'filename': 'Unknown'},
            'Group': groupDetails ?? {'name': 'Unknown Group'},
          });
        } catch (e) {
          print('Error enriching share: $e');
        }
      }

      return enrichedShares;
    } catch (e) {
      print('Error fetching files shared by user: $e');
      return [];
    }
  }
}
