// group_invitation_service.dart - FIXED VERSION
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupInvitationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get pending invitations for a user - FIXED with explicit relationship
  Future<List<Map<String, dynamic>>> getPendingInvitations(
    String userId,
  ) async {
    try {
      // Fix: Use explicit relationship name to avoid ambiguity
      final response = await _supabase
          .from('Group_Invitations')
          .select('''
            *,
            Group!group_invitations_group_id_fkey (
              id,
              name,
              created_at
            )
          ''')
          .eq('invitee_id', userId)
          .eq('status', 'pending')
          .order('invited_at', ascending: false);

      // Now fetch additional user details separately to avoid complex joins
      final List<Map<String, dynamic>> enrichedInvitations = [];

      for (final invitation in response) {
        try {
          // Get invited_by user details
          final invitedByUser =
              await _supabase
                  .from('User')
                  .select('email, person_id')
                  .eq('id', invitation['invited_by'])
                  .maybeSingle();

          // Get person details if available
          Map<String, dynamic>? invitedByPerson;
          if (invitedByUser != null && invitedByUser['person_id'] != null) {
            invitedByPerson =
                await _supabase
                    .from('Person')
                    .select('first_name, last_name')
                    .eq('id', invitedByUser['person_id'])
                    .maybeSingle();
          }

          enrichedInvitations.add({
            ...invitation,
            'invited_by_user': invitedByUser ?? {'email': 'Unknown'},
            'invited_by_person':
                invitedByPerson ?? {'first_name': '', 'last_name': ''},
          });
        } catch (e) {
          print('Error enriching invitation: $e');
          enrichedInvitations.add({
            ...invitation,
            'invited_by_user': {'email': 'Unknown'},
            'invited_by_person': {'first_name': '', 'last_name': ''},
          });
        }
      }

      return enrichedInvitations;
    } catch (e) {
      print('Error fetching pending invitations: $e');
      return [];
    }
  }

  /// Send invitation to a user to join a group
  Future<bool> sendGroupInvitation({
    required String groupId,
    required String invitedByUserId,
    required String inviteeEmail,
  }) async {
    try {
      print('Sending invitation to: $inviteeEmail for group: $groupId');

      // 1. Verify the inviter is a member of the group
      final inviterMembership =
          await _supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', invitedByUserId)
              .maybeSingle();

      if (inviterMembership == null) {
        throw Exception('You must be a group member to send invitations');
      }

      // 2. Find the invitee by email
      final inviteeResponse =
          await _supabase
              .from('User')
              .select('id')
              .eq('email', inviteeEmail.toLowerCase().trim())
              .maybeSingle();

      if (inviteeResponse == null) {
        throw Exception('User with email "$inviteeEmail" not found');
      }

      final inviteeId = inviteeResponse['id'];

      // 3. Check if user is already a member
      final existingMember =
          await _supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', inviteeId)
              .maybeSingle();

      if (existingMember != null) {
        throw Exception('User is already a member of this group');
      }

      // 4. Check if invitation already exists and is pending
      final existingInvitation =
          await _supabase
              .from('Group_Invitations')
              .select()
              .eq('group_id', groupId)
              .eq('invitee_id', inviteeId)
              .eq('status', 'pending')
              .maybeSingle();

      if (existingInvitation != null) {
        throw Exception('Invitation already sent to this user');
      }

      // 5. Create the invitation
      await _supabase.from('Group_Invitations').insert({
        'group_id': groupId,
        'invitee_id': inviteeId,
        'invited_by': invitedByUserId,
        'status': 'pending',
        'invited_at': DateTime.now().toIso8601String(),
      });

      print('Invitation sent successfully to: $inviteeEmail');
      return true;
    } catch (e) {
      print('Error sending invitation: $e');
      throw Exception('Failed to send invitation: $e');
    }
  }

  /// Accept a group invitation
  Future<bool> acceptInvitation({
    required String invitationId,
    required String userId,
  }) async {
    try {
      // 1. Get invitation details
      final invitation =
          await _supabase
              .from('Group_Invitations')
              .select('group_id, invitee_id, status')
              .eq('id', invitationId)
              .eq('invitee_id', userId)
              .eq('status', 'pending')
              .single();

      // 2. Add user to group members
      await _supabase.from('Group_Members').insert({
        'group_id': invitation['group_id'],
        'user_id': userId,
        'added_at': DateTime.now().toIso8601String(),
      });

      // 3. Update invitation status
      await _supabase
          .from('Group_Invitations')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invitationId);

      print('Invitation accepted successfully');
      return true;
    } catch (e) {
      print('Error accepting invitation: $e');
      throw Exception('Failed to accept invitation: $e');
    }
  }

  /// Decline a group invitation
  Future<bool> declineInvitation({
    required String invitationId,
    required String userId,
  }) async {
    try {
      // Update invitation status
      await _supabase
          .from('Group_Invitations')
          .update({
            'status': 'declined',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invitationId)
          .eq('invitee_id', userId)
          .eq('status', 'pending');

      print('Invitation declined successfully');
      return true;
    } catch (e) {
      print('Error declining invitation: $e');
      throw Exception('Failed to decline invitation: $e');
    }
  }

  /// Get sent invitations for a group - FIXED
  Future<List<Map<String, dynamic>>> getGroupInvitations(String groupId) async {
    try {
      // First get basic invitation data
      final response = await _supabase
          .from('Group_Invitations')
          .select('*')
          .eq('group_id', groupId)
          .order('invited_at', ascending: false);

      // Enrich with user details separately
      final List<Map<String, dynamic>> enrichedInvitations = [];

      for (final invitation in response) {
        try {
          // Get invitee details
          final invitee =
              await _supabase
                  .from('User')
                  .select('email, person_id')
                  .eq('id', invitation['invitee_id'])
                  .maybeSingle();

          Map<String, dynamic>? inviteePerson;
          if (invitee != null && invitee['person_id'] != null) {
            inviteePerson =
                await _supabase
                    .from('Person')
                    .select('first_name, last_name')
                    .eq('id', invitee['person_id'])
                    .maybeSingle();
          }

          // Get inviter details
          final invitedByUser =
              await _supabase
                  .from('User')
                  .select('email')
                  .eq('id', invitation['invited_by'])
                  .maybeSingle();

          enrichedInvitations.add({
            ...invitation,
            'invitee': invitee ?? {'email': 'Unknown'},
            'invitee_person':
                inviteePerson ?? {'first_name': '', 'last_name': ''},
            'invited_by_user': invitedByUser ?? {'email': 'Unknown'},
          });
        } catch (e) {
          print('Error enriching invitation: $e');
          enrichedInvitations.add(invitation);
        }
      }

      return enrichedInvitations;
    } catch (e) {
      print('Error fetching group invitations: $e');
      return [];
    }
  }

  /// Cancel a pending invitation
  Future<bool> cancelInvitation({
    required String invitationId,
    required String userId,
    required String groupId,
  }) async {
    try {
      // Verify user can cancel (either the inviter or group owner)
      final invitation =
          await _supabase
              .from('Group_Invitations')
              .select('invited_by')
              .eq('id', invitationId)
              .eq('group_id', groupId)
              .eq('status', 'pending')
              .single();

      final group =
          await _supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      final isInviter = invitation['invited_by'] == userId;
      final isGroupOwner = group['user_id'] == userId;

      if (!isInviter && !isGroupOwner) {
        throw Exception(
          'Only the inviter or group owner can cancel invitations',
        );
      }

      // Cancel the invitation
      await _supabase
          .from('Group_Invitations')
          .update({
            'status': 'cancelled',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invitationId);

      print('Invitation cancelled successfully');
      return true;
    } catch (e) {
      print('Error cancelling invitation: $e');
      throw Exception('Failed to cancel invitation: $e');
    }
  }
}
