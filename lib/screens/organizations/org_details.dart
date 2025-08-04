import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrgDetailsScreen extends StatelessWidget {
  final String orgId;
  final String orgName;

  const OrgDetailsScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  Future<void> _joinOrganization(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to join.')),
      );
      return;
    }

    try {
      // Insert into Patient table with status 'pending'
      await supabase.from('Patient').insert({
        'user_id': user.id,
        'organization_id': orgId,
        'joined_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Join request sent!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(orgName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              orgName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667EEA),
              ),
            ),
            const SizedBox(height: 32),
            // Add more organization details here later
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _joinOrganization(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Join Organization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
