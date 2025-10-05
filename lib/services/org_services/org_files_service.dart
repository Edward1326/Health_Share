import 'package:supabase_flutter/supabase_flutter.dart';

class OrgFilesService {
  static final _supabase = Supabase.instance.client;

  /// Fetch files shared between a user and doctor
  static Future<List<Map<String, dynamic>>> fetchSharedFiles(
    String userId,
    String doctorId,
  ) async {
    try {
      print('=== FETCH SHARED FILES ===');
      print('User ID: $userId');
      print('Doctor ID: $doctorId');

      // Get doctor's user ID from Organization_User
      final doctorOrgResponse =
          await _supabase
              .from('Organization_User')
              .select('user_id, position, department')
              .eq('id', doctorId)
              .maybeSingle();

      if (doctorOrgResponse == null) {
        throw Exception('Doctor not found: $doctorId');
      }

      final doctorUserId = doctorOrgResponse['user_id'] as String;
      print('Doctor user ID: $doctorUserId');

      // Map to store unique files (keyed by file_id)
      final Map<String, Map<String, dynamic>> allUniqueFiles = {};

      // APPROACH 1: Direct doctor shares
      print('Approach 1: Direct doctor shares...');
      final directDoctorShares = await _supabase
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id, filename, file_type, file_size, category, uploaded_at, sha256_hash
            )
          ''')
          .eq('shared_with_doctor', doctorUserId)
          .isFilter('revoked_at', null);

      _processShares(directDoctorShares, allUniqueFiles, userId, doctorUserId);

      // APPROACH 2: Patient to doctor shares
      print('Approach 2: Patient to doctor shares...');
      final patientToDoctorShares = await _supabase
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id, filename, file_type, file_size, category, uploaded_at, sha256_hash
            )
          ''')
          .eq('shared_by_user_id', userId)
          .eq('shared_with_user_id', doctorUserId)
          .isFilter('revoked_at', null);

      _processShares(
        patientToDoctorShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // APPROACH 3: Doctor to patient shares
      print('Approach 3: Doctor to patient shares...');
      final doctorToPatientShares = await _supabase
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id, filename, file_type, file_size, category, uploaded_at, sha256_hash
            )
          ''')
          .eq('shared_by_user_id', doctorUserId)
          .eq('shared_with_user_id', userId)
          .isFilter('revoked_at', null);

      _processShares(
        doctorToPatientShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // APPROACH 4: Cross-reference File_Keys
      print('Approach 4: Cross-referencing File_Keys...');
      final userFileKeys = await _supabase
          .from('File_Keys')
          .select('file_id')
          .eq('recipient_type', 'user')
          .eq('recipient_id', userId);

      final userFileIds =
          userFileKeys.map((fk) => fk['file_id'] as String).toList();

      if (userFileIds.isNotEmpty) {
        final doctorFileKeys = await _supabase
            .from('File_Keys')
            .select('file_id')
            .eq('recipient_type', 'user')
            .eq('recipient_id', doctorUserId)
            .inFilter('file_id', userFileIds);

        final sharedFileIds =
            doctorFileKeys.map((fk) => fk['file_id'] as String).toList();

        if (sharedFileIds.isNotEmpty) {
          final sharedFilesDetails = await _supabase
              .from('Files')
              .select(
                'id, filename, file_type, file_size, category, uploaded_at, sha256_hash',
              )
              .inFilter('id', sharedFileIds);

          for (final file in sharedFilesDetails) {
            final fileId = file['id'] as String;
            if (!allUniqueFiles.containsKey(fileId)) {
              // Try to find sharing record
              final shareRecord =
                  await _supabase
                      .from('File_Shares')
                      .select(
                        'shared_by_user_id, shared_with_user_id, shared_at, shared_with_doctor',
                      )
                      .eq('file_id', fileId)
                      .or(
                        'shared_by_user_id.eq.$userId,shared_with_user_id.eq.$userId,shared_with_doctor.eq.$doctorUserId',
                      )
                      .isFilter('revoked_at', null)
                      .limit(1)
                      .maybeSingle();

              String sharedBy = 'Unknown';
              String sharedWith = 'Unknown';
              String sharedAt = DateTime.now().toIso8601String();

              if (shareRecord != null) {
                sharedAt = shareRecord['shared_at'] ?? sharedAt;

                if (shareRecord['shared_with_doctor'] == doctorUserId) {
                  sharedBy = 'You';
                  sharedWith = 'Doctor';
                } else if (shareRecord['shared_by_user_id'] == userId) {
                  sharedBy = 'You';
                  sharedWith = 'Doctor';
                } else if (shareRecord['shared_by_user_id'] == doctorUserId) {
                  sharedBy = 'Doctor';
                  sharedWith = 'You';
                }
              }

              allUniqueFiles[fileId] = {
                ...file,
                'shared_at': sharedAt,
                'shared_by': sharedBy,
                'shared_with': sharedWith,
              };
            }
          }
        }
      }

      // Sort by date and return
      final filesList = allUniqueFiles.values.toList();
      filesList.sort((a, b) {
        final dateA = DateTime.parse(a['shared_at']);
        final dateB = DateTime.parse(b['shared_at']);
        return dateB.compareTo(dateA);
      });

      print('Total unique files found: ${filesList.length}');
      return filesList;
    } catch (e, stackTrace) {
      print('ERROR in OrgFilesService.fetchSharedFiles: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Helper to process shares and avoid duplicates
  static void _processShares(
    List<Map<String, dynamic>> shares,
    Map<String, Map<String, dynamic>> allUniqueFiles,
    String userId,
    String doctorUserId,
  ) {
    for (final share in shares) {
      final file = share['Files'];
      if (file == null) continue;

      final fileId = file['id'] as String;
      if (!allUniqueFiles.containsKey(fileId)) {
        String sharedBy;
        String sharedWith;

        if (share['shared_with_doctor'] == doctorUserId) {
          sharedBy = 'You';
          sharedWith = 'Doctor';
        } else if (share['shared_by_user_id'] == doctorUserId) {
          sharedBy = 'Doctor';
          sharedWith = 'You';
        } else if (share['shared_by_user_id'] == userId) {
          sharedBy = 'You';
          sharedWith = 'Doctor';
        } else {
          sharedBy = 'Unknown';
          sharedWith = 'Unknown';
        }

        allUniqueFiles[fileId] = {
          ...file,
          'share_id': share['id'],
          'shared_at': share['shared_at'],
          'shared_by': sharedBy,
          'shared_with': sharedWith,
        };
      }
    }
  }
}
