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
}
