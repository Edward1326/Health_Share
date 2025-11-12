import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles group deletion operations
class GroupDeleteService {
  /// Delete a group and all associated data
  /// Only the group owner can delete the group
  /// This will:
  /// 1. Revoke all file shares associated with the group
  /// 2. Remove all group members
  /// 3. Delete the group itself
  static Future<bool> deleteGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== DELETING GROUP ===');
      print('Group ID: $groupId');
      print('User ID: $userId');

      // Step 1: Verify user is the group owner
      final groupData =
          await supabase
              .from('Group')
              .select('user_id, name')
              .eq('id', groupId)
              .single();

      final isOwner = groupData['user_id'] == userId;
      print('Is group owner: $isOwner');

      if (!isOwner) {
        print('❌ Only the group owner can delete this group');
        throw Exception('Only the group owner can delete this group');
      }

      // Step 2: Revoke all file shares associated with this group
      print('Revoking all file shares for group...');
      final revokeResult =
          await supabase
              .from('File_Shares')
              .update({'revoked_at': DateTime.now().toIso8601String()})
              .eq('shared_with_group_id', groupId)
              .isFilter('revoked_at', null)
              .select();

      print('Revoked ${revokeResult.length} file shares');

      // Step 3: Delete all File_Keys for this group
      print('Removing group file keys...');
      final keysResult =
          await supabase
              .from('File_Keys')
              .delete()
              .eq('recipient_type', 'group')
              .eq('recipient_id', groupId)
              .select();

      print('Removed ${keysResult.length} file keys');

      // Step 4: Remove all group members
      print('Removing all group members...');
      final membersResult =
          await supabase
              .from('Group_Members')
              .delete()
              .eq('group_id', groupId)
              .select();

      print('Removed ${membersResult.length} group members');

      // Step 5: Delete the group itself
      print('Deleting group...');
      await supabase.from('Group').delete().eq('id', groupId);

      print('✓ Successfully deleted group $groupId');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error deleting group: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if user is the owner of a group
  static Future<bool> isGroupOwner({
    required String groupId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final groupData =
          await supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      return groupData['user_id'] == userId;
    } catch (e) {
      print('Error checking group ownership: $e');
      return false;
    }
  }

  /// Get group deletion summary (what will be deleted)
  static Future<Map<String, dynamic>> getGroupDeletionSummary({
    required String groupId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Count members
      final membersCount = await supabase
          .from('Group_Members')
          .select('id')
          .eq('group_id', groupId);

      // Count active file shares
      final fileSharesCount = await supabase
          .from('File_Shares')
          .select('id')
          .eq('shared_with_group_id', groupId)
          .isFilter('revoked_at', null);

      return {
        'members_count': membersCount.length,
        'file_shares_count': fileSharesCount.length,
      };
    } catch (e) {
      print('Error getting deletion summary: $e');
      return {'members_count': 0, 'file_shares_count': 0};
    }
  }
}
