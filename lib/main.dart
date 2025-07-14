import 'package:flutter/material.dart';
import 'package:health_share/services/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://iqrlfiwtgdnmsxhyoiaw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxcmxmaXd0Z2RubXN4aHlvaWF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg3Mzc3MDEsImV4cCI6MjA2NDMxMzcwMX0._N_v5dh3RXbBIdpngAZGd7cqLIRR-WagQbJ65laZvX8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AuthGate());
  }
}
