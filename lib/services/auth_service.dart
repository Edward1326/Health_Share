import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
    String firstName,
    String middleName,
    String lastName,
    String phone,
  ) async {
    try {
      print('Starting registration...');

      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      print('Auth signup successful: ${authResponse.user != null}');

      if (authResponse.user != null) {
        final userId = authResponse.user!.id;

        // Insert into person
        final personInsert =
            await _supabase
                .from('Person')
                .insert({
                  'first_name': firstName,
                  'middle_name': middleName,
                  'last_name': lastName,
                  'contact_number': phone,
                  'created_at': DateTime.now().toIso8601String(),
                  'auth_user_id': userId,
                })
                .select()
                .single();

        print('Inserted into person: $personInsert');

        // Insert into users table
        await _supabase.from('User').insert({
          'id': userId,
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
          'rsa_public_key': '', // Add actual key logic later
          'rsa_private_key': '',
          'key_created_at': DateTime.now().toIso8601String(),
          'person_id': personInsert['id'],
        });

        print('Inserted into users table!');
      }

      return authResponse;
    } catch (e) {
      print('❌ Registration error: $e');
      throw Exception('Failed to register user: $e');
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }
}
