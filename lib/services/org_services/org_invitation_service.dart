import 'package:supabase_flutter/supabase_flutter.dart';

class OrgInvitationService {
  static final _supabase = Supabase.instance.client;

  /// Fetch pending invitations for a user
  static Future<List<Map<String, dynamic>>> fetchUserInvitations(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('Patient')
          .select('*, Organization(name)')
          .eq('user_id', userId)
          .eq('status', 'invited');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('ERROR in OrgInvitationService.fetchUserInvitations: $e');
      rethrow;
    }
  }

  /// Accept an invitation
  static Future<void> acceptInvitation(String invitationId) async {
    try {
      await _supabase
          .from('Patient')
          .update({'status': 'accepted'})
          .eq('id', invitationId);

      print('DEBUG: Invitation accepted: $invitationId');
    } catch (e) {
      print('ERROR in OrgInvitationService.acceptInvitation: $e');
      rethrow;
    }
  }

  /// Decline an invitation
  static Future<void> declineInvitation(String invitationId) async {
    try {
      await _supabase
          .from('Patient')
          .update({'status': 'declined'})
          .eq('id', invitationId);

      print('DEBUG: Invitation declined: $invitationId');
    } catch (e) {
      print('ERROR in OrgInvitationService.declineInvitation: $e');
      rethrow;
    }
  }

  /// Get count of pending invitations
  static Future<int> getInvitationCount(String userId) async {
    try {
      final response = await _supabase
          .from('Patient')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'invited');

      return response.length;
    } catch (e) {
      print('ERROR in OrgInvitationService.getInvitationCount: $e');
      return 0;
    }
  }
}
