import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fast_rsa/fast_rsa.dart';

/// Handles group CRUD operations (CREATE, UPDATE, DELETE)
class GroupManagementService {
  /// Create a new group with RSA key generation
  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== CREATING NEW GROUP ===');
      print('Group Name: $name');
      print('Owner User ID: $userId');

      // Step 1: Generate RSA key pair (2048 bits)
      print('Generating RSA key pair (2048 bits)...');
      final keyPair = await RSA.generate(2048);
      final publicKeyPem = keyPair.publicKey;
      final privateKeyPem = keyPair.privateKey;
      print('✓ RSA keys generated successfully');

      // Step 2: Insert into Group table with keys
      print('Creating group in database...');
      final groupResponse =
          await supabase
              .from('Group')
              .insert({
                'name': name,
                'user_id': userId,
                'rsa_public_key': publicKeyPem,
                'rsa_private_key': privateKeyPem,
              })
              .select()
              .single();

      print('✓ Group created with ID: ${groupResponse['id']}');

      // Step 3: Add creator as first member in Group_Members
      print('Adding creator as first member...');
      await supabase.from('Group_Members').insert({
        'group_id': groupResponse['id'],
        'user_id': userId,
      });

      print('✓ Creator added as group member');
      print('=== GROUP CREATION COMPLETED ===');

      // Step 4: Return created group data
      return groupResponse;
    } catch (e, stackTrace) {
      print('❌ Error creating group: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update group information (optional for future use)
  static Future<bool> updateGroup({
    required String groupId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== UPDATING GROUP ===');
      print('Group ID: $groupId');
      print('Updates: $updates');

      await supabase.from('Group').update(updates).eq('id', groupId);

      print('✓ Group updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating group: $e');
      rethrow;
    }
  }

  /// Delete group (optional for future use)
  static Future<bool> deleteGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== DELETING GROUP ===');
      print('Group ID: $groupId');
      print('User ID: $userId');

      // Verify user is group owner
      final groupData =
          await supabase
              .from('Group')
              .select('user_id')
              .eq('id', groupId)
              .single();

      if (groupData['user_id'] != userId) {
        throw Exception('Only the group owner can delete the group');
      }

      // Delete group (cascade will handle members and files)
      await supabase.from('Group').delete().eq('id', groupId);

      print('✓ Group deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting group: $e');
      rethrow;
    }
  }
}
