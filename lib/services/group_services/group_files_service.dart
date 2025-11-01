import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles file operations for groups (queries + commands)
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
              uploaded_by,
              ipfs_cid,
              category
            ),
            shared_by:User!shared_by_user_id(email, Person!inner(first_name, last_name))
          ''')
          .eq('shared_with_group_id', groupId)
          .isFilter('revoked_at', null) // ✅ Only show active shares
          .isFilter('file.deleted_at', null) // ✅ Hide globally deleted files
          .order('shared_at', ascending: false);

      print('Fetched ${sharedFiles.length} shared files for group $groupId');
      return sharedFiles;
    } catch (e) {
      print('Error fetching group shared files: $e');
      return [];
    }
  }

  /// Organize files by user for UI display
  static Map<String, List<Map<String, dynamic>>> organizeFilesByUser(
    List<Map<String, dynamic>> sharedFiles,
  ) {
    Map<String, List<Map<String, dynamic>>> filesByUser = {};

    for (final shareRecord in sharedFiles) {
      final sharedByUser = shareRecord['shared_by'] ?? {};
      final userEmail = sharedByUser['email'] ?? 'Unknown User';
      final personData = sharedByUser['Person'] ?? {};
      final firstName = personData['first_name'] ?? userEmail.split('@')[0];
      final userId = shareRecord['shared_by_user_id'] ?? 'unknown';

      final userKey = '$userId|$firstName';

      if (!filesByUser.containsKey(userKey)) {
        filesByUser[userKey] = [];
      }
      filesByUser[userKey]!.add(shareRecord);
    }

    print(
      'Organized ${sharedFiles.length} files into ${filesByUser.length} user folders',
    );
    return filesByUser;
  }

  /// Revoke file sharing from a group
  /// ONLY the file owner (uploaded_by) can remove their file from the group
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

      // Check if user is the file owner (uploaded_by)
      final fileData =
          await supabase
              .from('Files')
              .select('uploaded_by')
              .eq('id', fileId)
              .single();

      final isFileOwner = fileData['uploaded_by'] == userId;

      print('Is file owner: $isFileOwner');

      if (!isFileOwner) {
        print('❌ Only the file owner can revoke this file share');
        throw Exception(
          'Only the file owner can remove this file from the group',
        );
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
      rethrow;
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
            shared_by:User!shared_by_user_id(email, Person!inner(first_name, last_name))
          ''')
          .eq('file_id', fileId)
          .isFilter('revoked_at', null);

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
          .isFilter('revoked_at', null)
          .limit(1);

      return shares.isNotEmpty;
    } catch (e) {
      print('Error checking if file is shared: $e');
      return false;
    }
  }
}
