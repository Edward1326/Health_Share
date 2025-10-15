import 'package:supabase_flutter/supabase_flutter.dart';

class OrgService {
  static final _supabase = Supabase.instance.client;

  /// Fetch all organizations ordered by name
  static Future<List<Map<String, dynamic>>> fetchAllOrgs() async {
    try {
      final response = await _supabase
          .from('Organization')
          .select()
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('ERROR in OrgService.fetchAllOrgs: $e');
      rethrow;
    }
  }

  /// Fetch single organization details by ID
  static Future<Map<String, dynamic>?> fetchOrgDetails(String orgId) async {
    try {
      final response =
          await _supabase
              .from('Organization')
              .select('*')
              .eq('id', orgId)
              .single();

      return response;
    } catch (e) {
      print('ERROR in OrgService.fetchOrgDetails: $e');
      rethrow;
    }
  }

  static Future fetchJoinedOrgs() async {}
}
