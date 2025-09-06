import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}
