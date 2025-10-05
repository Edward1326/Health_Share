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

      // Get patient record
      final patientResponse =
          await _supabase
              .from('Patient')
              .select('id')
              .eq('user_id', userId)
              .single();

      final patientId = patientResponse['id'];

      // Get doctor assignments
      final assignmentResponse = await _supabase
          .from('Doctor_User_Assignment')
          .select('''
            id,
            status,
            assigned_at,
            doctor_id,
            Organization_User!doctor_id(
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
          .eq('patient_id', patientId);

      // Filter for this specific organization
      final filteredAssignments =
          assignmentResponse.where((assignment) {
            final orgUser = assignment['Organization_User'];
            return orgUser != null &&
                orgUser['organization_id'].toString() == orgId &&
                orgUser['position'] == 'Doctor';
          }).toList();

      print('DEBUG: Found ${filteredAssignments.length} assigned doctors');
      return List<Map<String, dynamic>>.from(filteredAssignments);
    } catch (e, stackTrace) {
      print('ERROR in OrgDoctorService.fetchAssignedDoctors: $e');
      print('Stack trace: $stackTrace');
      rethrow;
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
              .single();

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
