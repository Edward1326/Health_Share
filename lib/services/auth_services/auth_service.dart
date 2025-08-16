import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/asymmetric/api.dart'
    as crypto; // For RSA key types

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

      // 2. Generate RSA key pair
      final helper = RsaKeyHelper();
      final pair = await helper.computeRSAKeyPair(helper.getSecureRandom());

      final crypto.RSAPublicKey publicKey =
          pair.publicKey as crypto.RSAPublicKey;
      final crypto.RSAPrivateKey privateKey =
          pair.privateKey as crypto.RSAPrivateKey;

      final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
      final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

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
}
