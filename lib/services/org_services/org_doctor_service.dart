import 'package:supabase_flutter/supabase_flutter.dart';

class OrgDoctorService {
  static final _supabase = Supabase.instance.client;

  /// Fetch all doctors in an organization
  static Future<List<Map<String, dynamic>>> fetchOrgDoctors(
    String orgId,
  ) async {
    try {
      print('DEBUG: fetchOrgDoctors for org: $orgId');

      // Get Organization_User records for doctors
      final orgUserResponse = await _supabase
          .from('Organization_User')
          .select('*')
          .eq('organization_id', orgId)
          .eq('position', 'Doctor');

      if (orgUserResponse.isEmpty) {
        print('DEBUG: No doctors found');
        return [];
      }

      // Extract user IDs
      final userIds = orgUserResponse.map((doc) => doc['user_id']).toList();

      // Fetch User details with Person information
      final userResponse = await _supabase
          .from('User')
          .select('id, email, Person(first_name, middle_name, last_name)')
          .inFilter('id', userIds);

      // Combine the data
      final combinedDoctors = <Map<String, dynamic>>[];
      for (final orgUser in orgUserResponse) {
        final user = userResponse.firstWhere(
          (u) => u['id'] == orgUser['user_id'],
          orElse: () => <String, dynamic>{},
        );

        if (user.isNotEmpty) {
          combinedDoctors.add({...orgUser, 'User': user});
        }
      }

      print('DEBUG: Loaded ${combinedDoctors.length} doctors');
      return combinedDoctors;
    } catch (e, stackTrace) {
      print('ERROR in OrgDoctorService.fetchOrgDoctors: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetch doctors assigned to a user in an organization
  static Future<List<Map<String, dynamic>>> fetchAssignedDoctors(
    String userId,
    String orgId,
  ) async {
    try {
      print('DEBUG: fetchAssignedDoctors for user: $userId, org: $orgId');

      // Get all patient records for this user
      final patientResponse = await _supabase
          .from('Patient')
          .select('id, organization_id')
          .eq('user_id', userId);

      if (patientResponse.isEmpty) {
        print('DEBUG: No patient record found for user');
        return [];
      }

      // Find the patient record for this specific organization
      final patientRecord = patientResponse.firstWhere(
        (p) => p['organization_id'].toString() == orgId,
        orElse: () => <String, dynamic>{},
      );

      if (patientRecord.isEmpty) {
        print('DEBUG: No patient record found for this organization');
        return [];
      }

      final patientId = patientRecord['id'];

      // Get doctor assignments with proper filtering
      final assignmentResponse = await _supabase
          .from('Doctor_User_Assignment')
          .select('''
            id,
            status,
            assigned_at,
            doctor_id,
            Organization_User!inner(
              id,
              position,
              department,
              organization_id,
              User!inner(
                id,
                email,
                Person(first_name, last_name)
              )
            )
          ''')
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .eq('Organization_User.organization_id', orgId)
          .eq('Organization_User.position', 'Doctor');

      print('DEBUG: Found ${assignmentResponse.length} assigned doctors');

      // Ensure proper data structure
      final List<Map<String, dynamic>> validAssignments = [];
      for (final assignment in assignmentResponse) {
        if (assignment['Organization_User'] != null) {
          validAssignments.add(Map<String, dynamic>.from(assignment));
        }
      }

      return validAssignments;
    } catch (e, stackTrace) {
      print('ERROR in OrgDoctorService.fetchAssignedDoctors: $e');
      print('Stack trace: $stackTrace');

      // Return empty list instead of rethrowing to prevent UI crash
      return [];
    }
  }

  /// Fetch detailed information about a specific doctor
  static Future<Map<String, dynamic>?> fetchDoctorDetails(
    String doctorId,
  ) async {
    try {
      print('DEBUG: fetchDoctorDetails for doctor: $doctorId');

      final response =
          await _supabase
              .from('Organization_User')
              .select('''
            id,
            position,
            department,
            created_at,
            User!inner(
              id,
              email,
              Person(first_name, last_name, contact_number, sex)
            )
          ''')
              .eq('id', doctorId)
              .eq('position', 'Doctor')
              .maybeSingle();

      return response;
    } catch (e, stackTrace) {
      print('ERROR in OrgDoctorService.fetchDoctorDetails: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get list of departments in an organization
  static Future<List<String>> getDoctorDepartments(String orgId) async {
    try {
      final response = await _supabase
          .from('Organization_User')
          .select('department')
          .eq('organization_id', orgId)
          .eq('position', 'Doctor');

      final departmentSet = <String>{};
      for (final doctor in response) {
        final dept = doctor['department']?.toString().trim();
        if (dept != null && dept.isNotEmpty) {
          departmentSet.add(dept);
        }
      }

      final sortedDepartments = departmentSet.toList()..sort();
      return sortedDepartments;
    } catch (e) {
      print('ERROR in OrgDoctorService.getDoctorDepartments: $e');
      return [];
    }
  }
}
