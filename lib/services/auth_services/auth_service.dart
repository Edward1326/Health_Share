import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ============ GOOGLE SIGN IN / SIGN UP ============

  // Sign up/in with Google (Native Google Sign-In)
  Future<AuthResponse> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');

      // 1. Trigger native Google Sign-In
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled by user');
      }

      print('✅ Google Sign-In successful');

      // 2. Get Google authentication tokens
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      print('✅ Got Google tokens');

      // 3. Sign in with Supabase using Google provider
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('Failed to authenticate with Supabase');
      }

      print('✅ Authenticated with Supabase');

      // 4. Check if user profile already exists
      final existingUser =
          await _supabase
              .from('User')
              .select()
              .eq('id', authUser.id)
              .maybeSingle();

      if (existingUser == null) {
        // New user - create profile with Google data
        print('Creating new user profile from Google data...');
        await _createUserProfileFromGoogle(authUser, googleUser);
      } else {
        // Existing user - just sign them in
        print('✅ Existing user signed in');
      }

      return response;
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Helper method to create user profile from Google data
  Future<void> _createUserProfileFromGoogle(
    User authUser,
    GoogleSignInAccount googleUser,
  ) async {
    try {
      // 1. Parse Google user's name
      final nameParts = _parseFullName(googleUser.displayName ?? 'Google User');
      final firstName = nameParts['firstName'] ?? '';
      final middleName = nameParts['middleName'] ?? '';
      final lastName = nameParts['lastName'] ?? '';
      final email = googleUser.email;
      final photoUrl = googleUser.photoUrl;

      print('User: $firstName $middleName $lastName');

      // 2. Generate RSA key pair
      print('Generating RSA keys...');
      final keyPair = await RSA.generate(2048);
      final publicPem = keyPair.publicKey;
      final privatePem = keyPair.privateKey;

      // 3. Insert into person table
      print('Creating person record...');
      final personInsertResponse =
          await _supabase
              .from('Person')
              .insert({
                'first_name': firstName,
                'middle_name': middleName,
                'last_name': lastName,
                'contact_number':
                    '', // Empty since Google doesn't provide phone
                'created_at': DateTime.now().toIso8601String(),
                'auth_user_id': authUser.id,
              })
              .select('id')
              .single();

      final personId = personInsertResponse['id'];

      // 4. Insert into users table with RSA keys
      print('Creating user record with RSA keys...');
      await _supabase.from('User').insert({
        'id': authUser.id,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'rsa_public_key': publicPem,
        'rsa_private_key': privatePem,
        'key_created_at': DateTime.now().toIso8601String(),
        'person_id': personId,
        'profile_photo_url': photoUrl, // Optional: store Google profile photo
      });

      print('🔐 Google user profile and RSA keys created successfully');
    } catch (e) {
      print('❌ Error creating user profile from Google: $e');
      throw Exception('Failed to create user profile: $e');
    }
  }

  // Helper method to parse full name into first, middle, last
  Map<String, String> _parseFullName(String fullName) {
    final parts = fullName.trim().split(' ');

    String firstName = '';
    String middleName = '';
    String lastName = '';

    if (parts.isNotEmpty) {
      firstName = parts[0];
    }
    if (parts.length == 2) {
      lastName = parts[1];
    } else if (parts.length > 2) {
      middleName = parts.sublist(1, parts.length - 1).join(' ');
      lastName = parts[parts.length - 1];
    }

    return {
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
    };
  }

  // Sign out (also signs out from Google)
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _googleSignIn.signOut();
      print('✅ Signed out successfully');
    } catch (e) {
      print('❌ Sign out error: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  // ============ ORIGINAL EMAIL/PASSWORD METHODS ============

  // Sign up with email and password (WITHOUT creating user profile yet)
  // In AuthService class, replace the signUpWithEmailOnly method:

  Future<void> signUpWithEmailOnly(String email, String password) async {
    try {
      print('Checking if email already exists...');

      // 1. Check if email is already registered in User table
      final existingUser =
          await _supabase
              .from('User')
              .select()
              .eq('email', email)
              .maybeSingle();

      if (existingUser != null) {
        throw Exception(
          'Email is already registered. Please use a different email or login.',
        );
      }

      print('✅ Email is available');
      print('Registering email and password...');

      // 2. Proceed with sign up
      await _supabase.auth.signUp(email: email, password: password);
      print('✅ Email registered. Awaiting OTP verification...');
    } on Exception catch (e) {
      print('❌ Sign up error: $e');
      rethrow; // Re-throw to preserve the specific error message
    } catch (e) {
      print('❌ Sign up error: $e');
      throw Exception('Failed to register email: $e');
    }
  }

  // Send OTP to email
  Future<void> sendOTP(String email) async {
    try {
      print('Sending OTP to $email...');
      await _supabase.auth.signInWithOtp(email: email, shouldCreateUser: false);
      print('✅ OTP sent successfully');
    } catch (e) {
      print('❌ Failed to send OTP: $e');
      throw Exception('Failed to send OTP: $e');
    }
  }

  // Verify OTP and create user profile (NOW called after OTP verification)
  Future<AuthResponse> verifyOTPAndCreateProfile(
    String email,
    String token,
    String firstName,
    String middleName,
    String lastName,
    String phone,
  ) async {
    try {
      print('Verifying OTP and creating profile...');

      // 1. Verify OTP
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw Exception('OTP verification failed');
      }

      final authUserId = authUser.id;
      print('✅ OTP verified');

      // 2. Generate RSA key pair
      print('Generating RSA keys...');
      final keyPair = await RSA.generate(2048);
      final publicPem = keyPair.publicKey;
      final privatePem = keyPair.privateKey;

      // 3. Insert into person table
      print('Creating person record...');
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

      // 4. Insert into users table with RSA keys
      print('Creating user record with RSA keys...');
      await _supabase.from('User').insert({
        'id': authUserId,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'rsa_public_key': publicPem,
        'rsa_private_key': privatePem,
        'key_created_at': DateTime.now().toIso8601String(),
        'person_id': personId,
      });

      print('🔐 User profile and RSA keys created successfully');
      return response;
    } catch (e) {
      print('❌ OTP verification/profile creation error: $e');
      throw Exception('Failed to verify OTP: $e');
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

  // Hash password for comparison (to prevent reuse)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if new password is same as current password
  Future<bool> _isPasswordReused(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      try {
        await _supabase.auth.signInWithPassword(
          email: user.email!,
          password: newPassword,
        );
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      print('Error checking password reuse: $e');
      return false;
    }
  }

  // Verify OTP and change password (with password reuse prevention)
  Future<void> verifyOTPAndChangePassword(
    String email,
    String otp,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      print('Verifying OTP for password change...');

      // 1. Verify OTP
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP code');
      }

      print('✅ OTP verified');

      // 2. Re-authenticate with current password
      print('Verifying current password...');
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      print('✅ Current password verified');

      // 3. Check if new password is same as current password
      print('Checking password reuse...');
      final isReused = await _isPasswordReused(currentPassword, newPassword);
      if (isReused) {
        throw Exception(
          'New password cannot be the same as your current password',
        );
      }
      print('✅ Password is not reused');

      // 4. Update password
      print('Updating password...');
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      print('✅ Password changed successfully');

      // 5. Store password hash in password history
      try {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase.from('password_history').insert({
            'user_id': userId,
            'password_hash': _hashPassword(newPassword),
            'changed_at': DateTime.now().toIso8601String(),
          });
          print('✅ Password history recorded');
        }
      } catch (e) {
        print('⚠️ Could not record password history: $e');
      }
    } catch (e) {
      print('❌ OTP verification/password change error: $e');
      throw Exception('Failed to change password: $e');
    }
  }

  // Send OTP for password reset
  Future<void> sendPasswordResetOTP(String email) async {
    try {
      print('Sending password reset OTP to $email...');
      await _supabase.auth.signInWithOtp(email: email, shouldCreateUser: false);
      print('✅ Password reset OTP sent successfully');
    } catch (e) {
      print('❌ Failed to send password reset OTP: $e');
      throw Exception('Failed to send password reset OTP: $e');
    }
  }

  // Verify OTP for password reset
  Future<void> verifyPasswordResetOTP(String email, String otp) async {
    try {
      print('Verifying OTP for password reset...');

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP code');
      }

      print('✅ OTP verified successfully');
    } catch (e) {
      print('❌ OTP verification error: $e');
      throw Exception('Invalid or expired OTP: $e');
    }
  }

  // Update password after OTP verification
  Future<void> updatePasswordAfterVerification(String newPassword) async {
    try {
      print('Updating password...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      print('✅ Password updated successfully');

      try {
        await _supabase.from('password_history').insert({
          'user_id': user.id,
          'password_hash': _hashPassword(newPassword),
          'changed_at': DateTime.now().toIso8601String(),
        });
        print('✅ Password history recorded');
      } catch (e) {
        print('⚠️ Could not record password history: $e');
      }
    } catch (e) {
      print('❌ Password update error: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  // Reset password with OTP verification
  Future<void> resetPasswordWithOTP(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      print('Verifying OTP for password reset...');

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP code');
      }

      print('✅ OTP verified');

      print('Updating password...');
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      print('✅ Password reset successfully');

      try {
        final userId = response.user?.id;
        if (userId != null) {
          await _supabase.from('password_history').insert({
            'user_id': userId,
            'password_hash': _hashPassword(newPassword),
            'changed_at': DateTime.now().toIso8601String(),
          });
          print('✅ Password history recorded');
        }
      } catch (e) {
        print('⚠️ Could not record password history: $e');
      }
    } catch (e) {
      print('❌ Password reset error: $e');
      throw Exception('Failed to reset password: $e');
    }
  }

  // Original change password method
  Future<void> changePassword(String newPassword) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      print('✅ Password updated successfully');
    } catch (e) {
      print('❌ Failed to update password: $e');
      throw Exception('Error changing password: $e');
    }
  }
}
