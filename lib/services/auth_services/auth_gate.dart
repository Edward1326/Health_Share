import 'package:flutter/material.dart';
import 'package:health_share/screens/files/files_main.dart';
import 'package:health_share/screens/home/home.dart';
import 'package:health_share/screens/login/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Force a check of the current session when the widget initializes
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    // Add a small delay to ensure Supabase is fully initialized
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {});
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
        // Show loading indicator while waiting for initial connection
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Get the current session
        final session = snapshot.hasData ? snapshot.data!.session : null;

        // Debug logging (remove in production)
        print(
          'AuthGate: Session state - ${session != null ? "AUTHENTICATED" : "NOT AUTHENTICATED"}',
        );
        if (session != null) {
          print('AuthGate: User ID - ${session.user.id}');
          print('AuthGate: User Email - ${session.user.email}');
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
