import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fast_rsa/fast_rsa.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ IMPORTANT: Add your Web Client ID here (from Google Cloud Console)
  // This is the OAUTH 2.0 Web Application Client ID (NOT Android Client ID)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '849402611639-1khgppikvge4kljpjsjvmfp0s0aqlb8s.apps.googleusercontent.com', // ← REPLACE THIS!
  );

  // ============ GOOGLE SIGN IN / SIGN UP ============

  Future<AuthResponse> signInWithGoogle() async {
    User? authUser;
    GoogleSignInAccount? googleUser;

    try {
      print('');
      print('╔═══════════════════════════════════════════╗');
      print('║     GOOGLE SIGN-IN PROCESS STARTED       ║');
      print('╚═══════════════════════════════════════════╝');
      print('');

      // 1. Trigger native Google Sign-In
      print('Step 1/5: Triggering native Google Sign-In...');
      googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('❌ User cancelled Google Sign-In');
        throw Exception('Google Sign-In cancelled by user');
      }

      print('✅ Google Sign-In successful');
      print('   📧 Email: ${googleUser.email}');
      print('   👤 Display Name: ${googleUser.displayName}');
      print('   🆔 Google ID: ${googleUser.id}');

      // 2. Get Google authentication tokens
      print('');
      print('Step 2/5: Getting authentication tokens...');
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        print('❌ Failed to get tokens');
        print('   Access Token: ${accessToken != null ? "EXISTS" : "NULL"}');
        print('   ID Token: ${idToken != null ? "EXISTS" : "NULL"}');
        throw Exception('Failed to get Google authentication tokens');
      }

      print('✅ Got Google tokens successfully');
      print('   🔑 Access Token: ${accessToken.substring(0, 20)}...');
      print('   🔑 ID Token: ${idToken.substring(0, 20)}...');

      // 3. Sign in with Supabase using Google provider
      print('');
      print('Step 3/5: Authenticating with Supabase...');
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      authUser = response.user;
      if (authUser == null) {
        print('❌ Supabase authentication failed - no user returned');
        throw Exception('Failed to authenticate with Supabase');
      }

      print('✅ Authenticated with Supabase');
      print('   🆔 Supabase User ID: ${authUser.id}');
      print('   📧 Supabase Email: ${authUser.email}');

      // 4. Check if user profile already exists
      print('');
      print('Step 4/5: Checking for existing user profile...');
      print('   Querying "User" table for id: ${authUser.id}');

      final existingUser =
          await _supabase
              .from('User')
              .select()
              .eq('id', authUser.id)
              .maybeSingle();

      if (existingUser == null) {
        print('   ℹ️  No existing profile found - NEW USER');
        print('');
        print('Step 5/5: Creating new user profile...');
        print('═══════════════════════════════════════════');

        // CRITICAL: Actually create the profile
        await _createUserProfileFromGoogle(authUser, googleUser);

        print('═══════════════════════════════════════════');
        print('✅ Profile creation completed successfully!');
      } else {
        print('   ✅ Existing profile found - RETURNING USER');
        print('   Person ID: ${existingUser['person_id']}');
        print('   Email: ${existingUser['email']}');
      }

      print('');
      print('╔═══════════════════════════════════════════╗');
      print('║   GOOGLE SIGN-IN COMPLETED SUCCESSFULLY  ║');
      print('╚═══════════════════════════════════════════╝');
      print('');

      return response;
    } catch (e, stackTrace) {
      print('');
      print('╔═══════════════════════════════════════════╗');
      print('║         GOOGLE SIGN-IN FAILED!            ║');
      print('╚═══════════════════════════════════════════╝');
      print('');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('');
      print('Stack Trace:');
      print(stackTrace.toString());
      print('');

      // If we have authUser, try to clean up
      if (authUser != null) {
        try {
          print('🧹 Cleaning up: Signing out from Supabase...');
          await _supabase.auth.signOut();
        } catch (_) {}
      }

      if (googleUser != null) {
        try {
          print('🧹 Cleaning up: Signing out from Google...');
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      throw Exception('Google Sign-In failed: $e');
    }
  }

  // Helper method to create user profile from Google data
  Future<void> _createUserProfileFromGoogle(
    User authUser,
    GoogleSignInAccount googleUser,
  ) async {
    print('');
    print('═══════════════════════════════════════════');
    print('🔧 CREATING USER PROFILE FROM GOOGLE DATA');
    print('═══════════════════════════════════════════');

    try {
      // 1. Parse Google user's name
      final nameParts = _parseFullName(googleUser.displayName ?? 'Google User');
      final firstName = nameParts['firstName'] ?? '';
      final middleName = nameParts['middleName'] ?? '';
      final lastName = nameParts['lastName'] ?? '';
      final email = googleUser.email;
      final photoUrl = googleUser.photoUrl;

      print('👤 Parsed Name:');
      print('   First: $firstName');
      print('   Middle: $middleName');
      print('   Last: $lastName');
      print('   Email: $email');
      print('   Photo URL: $photoUrl');
      print('   Auth User ID: ${authUser.id}');

      // 2. Generate RSA key pair
      print('');
      print('🔐 Generating RSA key pair (2048 bits)...');
      final keyPair = await RSA.generate(2048);
      final publicPem = keyPair.publicKey;
      final privatePem = keyPair.privateKey;
      print('✅ RSA keys generated successfully');
      print('   Public Key Length: ${publicPem.length} chars');
      print('   Private Key Length: ${privatePem.length} chars');

      // 3. Insert into Person table
      print('');
      print('📝 Step 1/2: Creating Person record...');
      print('   Inserting into "Person" table with data:');
      print('   {');
      print('     first_name: "$firstName",');
      print('     middle_name: "$middleName",');
      print('     last_name: "$lastName",');
      print('     contact_number: "",');
      print('     auth_user_id: "${authUser.id}"');
      print('   }');

      final personInsertResponse =
          await _supabase
              .from('Person')
              .insert({
                'first_name': firstName,
                'middle_name': middleName,
                'last_name': lastName,
                'contact_number': '',
                'created_at': DateTime.now().toIso8601String(),
                'auth_user_id': authUser.id,
              })
              .select('id')
              .single();

      final personId = personInsertResponse['id'];
      print('✅ Person record created successfully!');
      print('   Person ID: $personId');

      // 4. Insert into User table with RSA keys
      print('');
      print('📝 Step 2/2: Creating User record with RSA keys...');
      print('   Inserting into "User" table with data:');
      print('   {');
      print('     id: "${authUser.id}",');
      print('     email: "$email",');
      print('     person_id: "$personId",');

      print('   }');

      await _supabase.from('User').insert({
        'id': authUser.id,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
        'rsa_public_key': publicPem,
        'rsa_private_key': privatePem,
        'key_created_at': DateTime.now().toIso8601String(),
        'person_id': personId,
      });

      print('✅ User record created successfully!');
      print('');
      print('🎉 PROFILE CREATION COMPLETE!');
      print('═══════════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ERROR CREATING USER PROFILE ❌❌❌');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('');
      print('Stack Trace:');
      print(stackTrace.toString());
      print('═══════════════════════════════════════════');
      print('');

      // Re-throw with more context
      throw Exception('Failed to create user profile from Google data: $e');
    }
  }

  // Helper method to parse full name into first, middle, last
  Map<String, String> _parseFullName(String fullName) {
    print('');
    print('📝 Parsing full name: "$fullName"');

    // Clean and split the name
    final parts = fullName.trim().split(RegExp(r'\s+'));
    print('   Split into ${parts.length} parts: $parts');

    String firstName = '';
    String middleName = '';
    String lastName = '';

    if (parts.isEmpty) {
      print('   ⚠️  No name parts found, using default "User"');
      firstName = 'User';
    } else if (parts.length == 1) {
      // Only first name
      firstName = parts[0];
      print('   ✓ Single name detected');
    } else if (parts.length == 2) {
      // First and last name only
      firstName = parts[0];
      lastName = parts[1];
      print('   ✓ First and last name detected');
    } else if (parts.length == 3) {
      // First, middle, and last name
      firstName = parts[0];
      middleName = parts[1];
      lastName = parts[2];
      print('   ✓ First, middle, and last name detected');
    } else {
      // More than 3 parts: first, multiple middle names, last
      firstName = parts[0];
      middleName = parts.sublist(1, parts.length - 1).join(' ');
      lastName = parts[parts.length - 1];
      print('   ✓ Complex name with multiple middle names detected');
    }

    print('   Result:');
    print('     First:  "$firstName"');
    print('     Middle: "$middleName"');
    print('     Last:   "$lastName"');

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

  // ============ EMAIL/PASSWORD REGISTRATION & LOGIN ============

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

      // 2. Proceed with sign up (Supabase sends OTP automatically)
      await _supabase.auth.signUp(email: email, password: password);
      print('✅ Email registered. OTP sent automatically by Supabase');
    } on Exception catch (e) {
      print('❌ Sign up error: $e');
      rethrow;
    } catch (e) {
      print('❌ Sign up error: $e');
      throw Exception('Failed to register email: $e');
    }
  }

  // Send OTP to email (for resend functionality)
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

  // Verify OTP and create user profile
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

  // ============ PASSWORD MANAGEMENT ============

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

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

  Future<void> verifyOTPAndChangePassword(
    String email,
    String otp,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      print('Verifying OTP for password change...');

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );

      if (response.user == null) {
        throw Exception('Invalid OTP code');
      }

      print('✅ OTP verified');

      print('Verifying current password...');
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      print('✅ Current password verified');

      print('Checking password reuse...');
      final isReused = await _isPasswordReused(currentPassword, newPassword);
      if (isReused) {
        throw Exception(
          'New password cannot be the same as your current password',
        );
      }
      print('✅ Password is not reused');

      print('Updating password...');
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      print('✅ Password changed successfully');

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
