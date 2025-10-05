import 'package:supabase_flutter/supabase_flutter.dart';

class OrgMembershipService {
  static final _supabase = Supabase.instance.client;

  /// Fetch organizations that user has joined (accepted status)
  static Future<List<Map<String, dynamic>>> fetchJoinedOrgs(
    String userId,
  ) async {
    try {
      print('DEBUG: fetchJoinedOrgs for user: $userId');

      // Get organizations where this user is an accepted patient
      final patientResponse = await _supabase
          .from('Patient')
          .select('organization_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if (patientResponse.isEmpty) {
        print('DEBUG: No accepted patient records found');
        return [];
      }

      // Extract organization IDs
      final orgIds =
          patientResponse
              .map((patient) => patient['organization_id'])
              .where((id) => id != null)
              .toSet()
              .toList();

      print('DEBUG: Organization IDs: $orgIds');

      // Get organization details
      final orgResponse = await _supabase
          .from('Organization')
          .select('*')
          .inFilter('id', orgIds)
          .order('name', ascending: true);

      print('DEBUG: Found ${orgResponse.length} joined organizations');
      return List<Map<String, dynamic>>.from(orgResponse);
    } catch (e, stackTrace) {
      print('ERROR in OrgMembershipService.fetchJoinedOrgs: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if user is a member of an organization
  static Future<String?> checkMembershipStatus(
    String orgId,
    String userId,
  ) async {
    try {
      final response =
          await _supabase
              .from('Patient')
              .select('status')
              .eq('user_id', userId)
              .eq('organization_id', orgId)
              .maybeSingle();

      return response?['status'] as String?;
    } catch (e) {
      print('ERROR in OrgMembershipService.checkMembershipStatus: $e');
      return null;
    }
  }

  /// Request to join an organization
  static Future<void> joinOrg(String orgId, String userId) async {
    try {
      await _supabase.from('Patient').insert({
        'user_id': userId,
        'organization_id': orgId,
        'joined_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      print('DEBUG: Join request created for org: $orgId, user: $userId');
    } catch (e) {
      print('ERROR in OrgMembershipService.joinOrg: $e');
      rethrow;
    }
  }
}
