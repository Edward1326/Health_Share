import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fast_rsa/fast_rsa.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign up with email and password + RSA
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

      // 1. Sign up with Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final authUser = authResponse.user;

      if (authUser == null) {
        throw Exception('Authentication failed');
      }

      final authUserId = authUser.id;

      // 2. Generate RSA key pair using fast_rsa
      final keyPair = await RSA.generate(2048); // 2048-bit key size

      final publicPem = keyPair.publicKey;
      final privatePem = keyPair.privateKey;

      // 3. Insert into person table
      final personInsertResponse =
          await _supabase
              .from('Person')
              .insert({
                'first_name': firstName,
                'middle_name': middleName,
                'last_name': lastName,
                'contact_number': phone,
                'created_at': DateTime.now().toIso8601String(),
                'auth_user_id': authUserId,
              })
              .select('id')
              .single();

      final personId = personInsertResponse['id'];

      // 4. Insert into users table
      await _supabase.from('User').insert({
        'id': authUserId,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'rsa_public_key': publicPem,
        'rsa_private_key': privatePem,
        'key_created_at': DateTime.now().toIso8601String(),
        'person_id': personId,
      });

      print('🔐 RSA Key Pair generated and stored.');
      return authResponse;
    } catch (e) {
      print('❌ Registration error: $e');
      throw Exception('Failed to register user: $e');
    }
  }

  // Sign in
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

  // Get current user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  // Helper method to get user's RSA keys from database
  Future<Map<String, String>?> getUserRSAKeys() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response =
          await _supabase
              .from('User')
              .select('rsa_public_key, rsa_private_key')
              .eq('id', user.id)
              .single();

      return {
        'publicKey': response['rsa_public_key'],
        'privateKey': response['rsa_private_key'],
      };
    } catch (e) {
      print('Error fetching RSA keys: $e');
      return null;
    }
  }

  // Helper method to encrypt data using user's public key with RSA-OAEP
  Future<String?> encryptData(String data) async {
    try {
      final keys = await getUserRSAKeys();
      if (keys == null) return null;

      final encrypted = await RSA.encryptOAEP(
        data,
        "",
        Hash.SHA256,
        keys['publicKey']!,
      );
      return encrypted;
    } catch (e) {
      print('Encryption error: $e');
      return null;
    }
  }

  // Helper method to decrypt data using user's private key with RSA-OAEP
  Future<String?> decryptData(String encryptedData) async {
    try {
      final keys = await getUserRSAKeys();
      if (keys == null) return null;

      final decrypted = await RSA.decryptOAEP(
        encryptedData,
        "",
        Hash.SHA256,
        keys['privateKey']!,
      );
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      return null;
    }
  }
}
