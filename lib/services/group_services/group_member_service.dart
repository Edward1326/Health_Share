import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles group member operations (WRITE operations only)
/// READ operations remain in FetchGroupService
class GroupMemberService {
  /// Add a member to a group by email (owner only)
  static Future<bool> addMemberToGroup({
    required String groupId,
    required String email,
    required String addedBy,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== ADDING MEMBER TO GROUP ===');
      print('Group ID: $groupId');
      print('Email: $email');
      print('Added by: $addedBy');

      // Step 1: Verify addedBy is group owner
      print('Verifying permissions...');
      final groupData =
          await supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      if (groupData['user_id'] != addedBy) {
        print('❌ Only group owner can add members');
        throw Exception('Only the group owner can add members');
      }

      print('✓ User is group owner');

      // Step 2: Find user by email in User table
      print('Looking up user by email...');
      final userResponse =
          await supabase
              .from('User')
              .select('id')
              .eq('email', email)
              .maybeSingle();

      if (userResponse == null) {
        print('❌ User not found with email: $email');
        throw Exception('User not found with this email');
      }

      final userId = userResponse['id'];
      print('✓ User found with ID: $userId');

      // Step 3: Check if user already exists in Group_Members
      print('Checking if user is already a member...');
      final memberCheck =
          await supabase
              .from('Group_Members')
              .select('id')
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (memberCheck != null) {
        print('❌ User is already a member');
        throw Exception('User is already a member of this group');
      }

      print('✓ User is not yet a member');

      // Step 4: Insert into Group_Members
      print('Adding user to group...');
      await supabase.from('Group_Members').insert({
        'group_id': groupId,
        'user_id': userId,
      });

      print('✓ Successfully added $email to group $groupId');
      print('=== MEMBER ADDITION COMPLETED ===');
      return true;
    } catch (e) {
      print('❌ Error adding member: $e');
      rethrow;
    }
  }

  /// Remove member from group (by group owner)
  static Future<bool> removeMemberFromGroup({
    required String groupId,
    required String userId,
    required String removedBy,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== REMOVING MEMBER FROM GROUP ===');
      print('Group ID: $groupId');
      print('User to remove: $userId');
      print('Removed by: $removedBy');

      // Step 1: Verify removedBy is group owner
      print('Verifying permissions...');
      final groupData =
          await supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      if (groupData['user_id'] != removedBy) {
        print('❌ Only group owner can remove members');
        throw Exception('Only the group owner can remove members');
      }

      print('✓ User is group owner');

      // Step 2: Prevent removing owner
      if (userId == groupData['user_id']) {
        print('❌ Cannot remove group owner');
        throw Exception('Cannot remove the group owner');
      }

      print('✓ User is not the owner');

      // Step 3: Delete from Group_Members
      print('Removing member...');
      await supabase
          .from('Group_Members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      print('✓ Successfully removed member from group');
      print('=== MEMBER REMOVAL COMPLETED ===');
      return true;
    } catch (e) {
      print('❌ Error removing member: $e');
      rethrow;
    }
  }

  /// User leaves group themselves
  static Future<bool> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== USER LEAVING GROUP ===');
      print('Group ID: $groupId');
      print('User ID: $userId');

      // Step 1: Check if user is group owner (prevent leaving)
      print('Checking if user is group owner...');
      final groupData =
          await supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      if (groupData['user_id'] == userId) {
        print('❌ Group owner cannot leave the group');
        throw Exception(
          'Group owner cannot leave the group. Delete the group instead.',
        );
      }

      print('✓ User is not the owner');

      // Step 2: Delete from Group_Members
      print('Removing user from group...');
      await supabase
          .from('Group_Members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      print('✓ Successfully left group $groupId');
      print('=== LEAVE GROUP COMPLETED ===');
      return true;
    } catch (e) {
      print('❌ Error leaving group: $e');
      rethrow;
    }
  }
}
