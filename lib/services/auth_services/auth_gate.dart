import 'package:flutter/material.dart';
import 'package:health_share/screens/files/files_main.dart';
import 'package:health_share/screens/login/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;
  bool _isCheckingProfile = false;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      print('');
      print('╔═══════════════════════════════════════════╗');
      print('║        AUTH STATE CHANGED                 ║');
      print('╚═══════════════════════════════════════════╝');
      print('Event: $event');
      print('Session: ${session != null ? "EXISTS" : "NULL"}');

      if (session != null) {
        print('User ID: ${session.user.id}');
        print('Email: ${session.user.email}');
        print('Email Confirmed: ${session.user.emailConfirmedAt != null}');

        // Skip profile check for password recovery events
        if (event == AuthChangeEvent.passwordRecovery) {
          print('⏭️ Skipping profile check (password recovery)');
          return;
        }

        // CRITICAL: Skip profile check if email is NOT confirmed
        // This means user is still in registration flow (hasn't verified OTP yet)
        if (session.user.emailConfirmedAt == null) {
          print(
            '⏭️ Skipping profile check (email not confirmed - registration in progress)',
          );
          print('   User needs to verify OTP first');
          return;
        }

        // Only check profile for confirmed users on signedIn or tokenRefreshed
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed) {
          // Add LONGER delay (3 seconds) to give login screen time to catch error and show dialog
          Future.delayed(const Duration(milliseconds: 3000), () {
            if (mounted && _supabase.auth.currentSession != null) {
              _checkUserProfile(session.user.id);
            }
          });
        }
      }
      print('');
    });

    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkUserProfile(String userId) async {
    if (_isCheckingProfile) return;

    // Double-check: Don't check profile if email is not confirmed
    final currentUser = _supabase.auth.currentUser;
    if (currentUser?.emailConfirmedAt == null) {
      print('⏭️ Email not confirmed, skipping profile check');
      return;
    }

    setState(() {
      _isCheckingProfile = true;
    });

    try {
      print('');
      print('🔍 PROFILE CHECK: Validating user profile...');

      final userProfile =
          await _supabase.from('User').select().eq('id', userId).maybeSingle();

      if (userProfile == null) {
        print('❌ PROFILE CHECK FAILED: No profile found for user $userId');
        print(
          '   This is an incomplete registration (email confirmed but no profile)',
        );
        print('   Signing out user...');

        // Sign out user if no profile exists
        await _supabase.auth.signOut();

        print('✅ User signed out due to missing profile');
        // Don't show snackbar - let login screen handle the error message
      } else {
        print('✅ PROFILE CHECK PASSED: Profile exists');
        print('   Person ID: ${userProfile['person_id']}');
        print('   Email: ${userProfile['email']}');
      }
      print('');
    } catch (e) {
      print('❌ PROFILE CHECK ERROR: $e');

      // On error, sign out for safety
      try {
        await _supabase.auth.signOut();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        _supabase.auth.currentSession,
      ),
      builder: (context, snapshot) {
        // Show loading indicator while checking or waiting
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isCheckingProfile) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Validating session...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Get the current session
        final session = snapshot.hasData ? snapshot.data!.session : null;

        // Debug logging
        print(
          'AuthGate: Session state - ${session != null ? "AUTHENTICATED" : "NOT AUTHENTICATED"}',
        );
        if (session != null) {
          print('AuthGate: User ID - ${session.user.id}');
          print('AuthGate: User Email - ${session.user.email}');
          print(
            'AuthGate: Email Confirmed - ${session.user.emailConfirmedAt != null}',
          );
        }

        // Navigate based on session state
        if (session != null) {
          return const FilesScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
