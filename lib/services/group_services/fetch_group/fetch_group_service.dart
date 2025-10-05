import 'package:supabase_flutter/supabase_flutter.dart';

class FetchGroupService {
  /// Fetch all groups where user is a member
  static Future<List<Map<String, dynamic>>> fetchUserGroups(
    String userId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Group_Members')
          .select('''
            group_id,
            Group!inner(*)
          ''')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        response.map((item) => item['Group']),
      );
    } catch (e) {
      print('Error fetching user groups: $e');
      return [];
    }
  }

  /// Fetch group members
  static Future<List<Map<String, dynamic>>> fetchGroupMembers(
    String groupId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Group_Members')
          .select('''
            *,
            User!user_id(id, email, person_id)
          ''')
          .eq('group_id', groupId)
          .order('added_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading members: $e');
      rethrow;
    }
  }

  /// Get member count for a group
  static Future<int> getMemberCount(String groupId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Group_Members')
          .select('id')
          .eq('group_id', groupId);

      return response.length;
    } catch (e) {
      print('Error getting member count: $e');
      return 0;
    }
  }

  /// Get detailed members list with full user data
  static Future<List<Map<String, dynamic>>> getGroupMembersWithDetails(
    String groupId,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('Group_Members')
          .select('''
            *,
            User!user_id(email)
          ''')
          .eq('group_id', groupId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading members with details: $e');
      rethrow;
    }
  }
}
