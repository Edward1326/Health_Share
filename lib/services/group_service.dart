// group_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/asymmetric/api.dart' as crypto;

class GroupService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new group with RSA key pair
  Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String userId,
  }) async {
    try {
      print('Creating group: $name for user: $userId');

      // Show immediate feedback - start the process

      // 1. Generate RSA key pair for the group (this is the slow part)
      print('Generating RSA key pair...');
      final helper = RsaKeyHelper();
      final pair = await helper.computeRSAKeyPair(helper.getSecureRandom());
      final crypto.RSAPublicKey publicKey =
          pair.publicKey as crypto.RSAPublicKey;
      final crypto.RSAPrivateKey privateKey =
          pair.privateKey as crypto.RSAPrivateKey;
      final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
      final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
      print('RSA key pair generated successfully');

      // 2. Insert group into Group table
      print('Inserting group into database...');
      final groupResponse =
          await _supabase
              .from('Group')
              .insert({
                'name': name,
                'created_at': DateTime.now().toIso8601String(),
                'user_id': userId,
                'rsa_public_key': publicPem,
                'rsa_private_key': privatePem,
              })
              .select()
              .single();

      final groupId = groupResponse['id'];
      print('Group created with ID: $groupId');

      // 3. Add creator as first member
      print('Adding creator as group member...');
      await _supabase.from('Group_Members').insert({
        'group_id': groupId,
        'user_id': userId,
        'added_at': DateTime.now().toIso8601String(),
      });

      print('Group creation completed successfully');
      return groupResponse;
    } catch (e) {
      print('Error creating group: $e');
      throw Exception('Failed to create group: $e');
    }
  }

  /// Get all groups for a specific user
  Future<List<Map<String, dynamic>>> getUserGroups(String userId) async {
    try {
      final response = await _supabase
          .from('Group_Members')
          .select('''
            *,
            Group (
              id,
              name,
              created_at,
              user_id
            )
          ''')
          .eq('user_id', userId)
          .order('added_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user groups: $e');
      return [];
    }
  }

  /// Get all available groups (for joining)
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    try {
      final response = await _supabase
          .from('Group')
          .select('id, name, created_at, user_id')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all groups: $e');
      return [];
    }
  }

  /// Join a group
  Future<bool> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Check if user is already a member
      final existingMember =
          await _supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (existingMember != null) {
        throw Exception('You are already a member of this group');
      }

      // Add user to group
      await _supabase.from('Group_Members').insert({
        'group_id': groupId,
        'user_id': userId,
        'added_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error joining group: $e');
      throw Exception('Failed to join group: $e');
    }
  }

  /// Leave a group
  Future<bool> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('Group_Members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('Error leaving group: $e');
      throw Exception('Failed to leave group: $e');
    }
  }

  /// Get group members
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      print('Fetching members for group: $groupId');

      final response = await _supabase
          .from('Group_Members')
          .select('''
            *,
            User!Group_Members_user_id_fkey (
              email,
              person_id
            )
          ''')
          .eq('group_id', groupId)
          .order('added_at', ascending: true);

      print('Found ${response.length} group members');

      // Now get person details for each member
      final List<Map<String, dynamic>> membersWithPersons = [];

      for (final member in response) {
        try {
          final user = member['User'];
          if (user != null && user['person_id'] != null) {
            final personResponse =
                await _supabase
                    .from('Person')
                    .select('first_name, last_name')
                    .eq('id', user['person_id'])
                    .maybeSingle();

            membersWithPersons.add({
              ...member,
              'User': user,
              'Person': personResponse ?? {'first_name': '', 'last_name': ''},
            });
          } else {
            // Add member without person details
            membersWithPersons.add({
              ...member,
              'User': user ?? {'email': ''},
              'Person': {'first_name': '', 'last_name': ''},
            });
          }
        } catch (e) {
          print('Error getting person details for member: $e');
          // Add member without person details as fallback
          membersWithPersons.add({
            ...member,
            'User': member['User'] ?? {'email': ''},
            'Person': {'first_name': '', 'last_name': ''},
          });
        }
      }

      print(
        'Returning ${membersWithPersons.length} members with person details',
      );
      return membersWithPersons;
    } catch (e) {
      print('Error fetching group members: $e');
      return [];
    }
  }

  /// Get group details by ID with member count
  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    try {
      // Get group details
      final groupResponse =
          await _supabase.from('Group').select('*').eq('id', groupId).single();

      // Get member count
      final memberCountResponse = await _supabase
          .from('Group_Members')
          .select('id')
          .eq('group_id', groupId);

      final memberCount = memberCountResponse.length;

      print('Group details: ${groupResponse['name']}, Members: $memberCount');

      return {...groupResponse, 'member_count': memberCount};
    } catch (e) {
      print('Error fetching group details: $e');
      return null;
    }
  }

  /// Send invitation to join a group (any group member can invite)
  Future<bool> inviteUserToGroup({
    required String groupId,
    required String userId,
    required String memberEmail,
  }) async {
    try {
      // 1. Verify the user is a member of the group
      final existingUserMembership =
          await _supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', userId)
              .maybeSingle();

      if (existingUserMembership == null) {
        throw Exception('You must be a group member to invite others');
      }

      // 2. Find the user by email
      final userResponse =
          await _supabase
              .from('User')
              .select('id')
              .eq('email', memberEmail.toLowerCase().trim())
              .maybeSingle();

      if (userResponse == null) {
        throw Exception('User with email "$memberEmail" not found');
      }

      final memberId = userResponse['id'];

      // 3. Check if user is already a member
      final existingMember =
          await _supabase
              .from('Group_Members')
              .select()
              .eq('group_id', groupId)
              .eq('user_id', memberId)
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
              .eq('invitee_id', memberId)
              .eq('status', 'pending')
              .maybeSingle();

      if (existingInvitation != null) {
        throw Exception('Invitation already sent to this user');
      }

      // 5. Create the invitation
      await _supabase.from('Group_Invitations').insert({
        'group_id': groupId,
        'invitee_id': memberId,
        'invited_by': userId,
        'status': 'pending',
        'invited_at': DateTime.now().toIso8601String(),
      });

      print('Invitation sent successfully: $memberEmail');
      return true;
    } catch (e) {
      print('Error sending invitation: $e');
      throw Exception('Failed to send invitation: $e');
    }
  }

  /// Remove a member from a group (admin only)
  Future<bool> removeMemberFromGroup({
    required String groupId,
    required String adminUserId,
    required String memberId,
  }) async {
    try {
      // 1. Verify the admin is the group owner
      final group =
          await _supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      if (group['user_id'] != adminUserId) {
        throw Exception('Only group owner can remove members');
      }

      // 2. Prevent owner from removing themselves
      if (memberId == adminUserId) {
        throw Exception('Group owner cannot remove themselves');
      }

      // 3. Remove the member
      await _supabase
          .from('Group_Members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', memberId);

      print('Member removed successfully');
      return true;
    } catch (e) {
      print('Error removing member: $e');
      throw Exception('Failed to remove member: $e');
    }
  }

  /// Delete a group (only by creator)
  Future<bool> deleteGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Verify user is the group creator
      final group =
          await _supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      if (group['user_id'] != userId) {
        throw Exception('Only group creator can delete the group');
      }

      // Delete all group members first
      await _supabase.from('Group_Members').delete().eq('group_id', groupId);

      // Delete the group
      await _supabase.from('Group').delete().eq('id', groupId);

      return true;
    } catch (e) {
      print('Error deleting group: $e');
      throw Exception('Failed to delete group: $e');
    }
  }

  /// Debug method to check group membership
  Future<void> debugGroupMembership(String groupId) async {
    try {
      print('=== DEBUG: Group Membership for $groupId ===');

      // Check raw Group_Members table
      final rawMembers = await _supabase
          .from('Group_Members')
          .select('*')
          .eq('group_id', groupId);

      print('Raw Group_Members count: ${rawMembers.length}');
      for (final member in rawMembers) {
        print('  - Member: ${member['user_id']}, Added: ${member['added_at']}');
      }

      // Check group details
      final group =
          await _supabase
              .from('Group')
              .select('name, user_id')
              .eq('id', groupId)
              .single();

      print('Group: ${group['name']}, Owner: ${group['user_id']}');
      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  /// Search users by email for adding to group
  Future<List<Map<String, dynamic>>> searchUsersByEmail(
    String emailQuery,
  ) async {
    try {
      if (emailQuery.trim().isEmpty) return [];

      print('Searching for users with email containing: $emailQuery');

      // First, get users by email
      final userResponse = await _supabase
          .from('User')
          .select('id, email, person_id')
          .ilike('email', '%${emailQuery.trim().toLowerCase()}%')
          .limit(10);

      print('Found ${userResponse.length} users');

      // Then get person details for each user
      final List<Map<String, dynamic>> results = [];
      for (final user in userResponse) {
        try {
          final personResponse =
              await _supabase
                  .from('Person')
                  .select('first_name, last_name')
                  .eq('id', user['person_id'])
                  .maybeSingle();

          results.add({
            'id': user['id'],
            'email': user['email'],
            'Person': personResponse ?? {'first_name': '', 'last_name': ''},
          });
        } catch (e) {
          print('Error getting person details for user ${user['id']}: $e');
          // Add user without person details
          results.add({
            'id': user['id'],
            'email': user['email'],
            'Person': {'first_name': '', 'last_name': ''},
          });
        }
      }

      print('Returning ${results.length} search results');
      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}
