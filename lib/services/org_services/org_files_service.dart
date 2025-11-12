import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrgFilesService {
  static final _supabase = Supabase.instance.client;

  /// Fetch files shared between a user and doctor
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

      // APPROACH 1: Direct doctor shares (fixed - only for current user)
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
              id, filename, file_type, file_size, category, uploaded_at, sha256_hash, uploaded_by
            )
          ''')
          .eq('shared_with_doctor', doctorUserId)
          .eq(
            'shared_by_user_id',
            userId,
          ) // ✅ Only include files shared by THIS user
          .isFilter('revoked_at', null);

      print('Approach 1 results: ${directDoctorShares.length}');
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
              id, filename, file_type, file_size, category, uploaded_at, sha256_hash, uploaded_by
            )
          ''')
          .eq('shared_by_user_id', userId)
          .eq('shared_with_user_id', doctorUserId)
          .isFilter('revoked_at', null);

      print('Approach 2 results: ${patientToDoctorShares.length}');
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
              id, filename, file_type, file_size, category, uploaded_at, sha256_hash, uploaded_by
            )
          ''')
          .eq('shared_by_user_id', doctorUserId)
          .eq('shared_with_user_id', userId)
          .isFilter('revoked_at', null);

      print('Approach 3 results: ${doctorToPatientShares.length}');
      _processShares(
        doctorToPatientShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // ✅ Approach 4 (File_Keys cross-reference) has been removed completely

      // Sort by shared_at date and return
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
          'shared_by_user_id': share['shared_by_user_id'],
        };
      }
    }
  }

  /// Revokes a file from an organization/doctor
  ///
  /// This method:
  /// - Soft-revokes the file share in File_Shares (sets revoked_at)
  /// - Removes the doctor's AES key from File_Keys (crypto-erasure)
  /// - Does NOT delete the file from Files table
  /// - Preserves audit trail for compliance
  ///
  /// Parameters:
  /// - fileId: The ID of the file to revoke
  /// - doctorId: The doctor's user ID (from Organization_User.user_id)
  /// - userId: The current user ID (must be file owner)
  /// - context: Optional BuildContext for showing feedback messages
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> revokeFileFromOrganization({
    required String fileId,
    required String doctorId,
    required String userId,
    BuildContext? context,
  }) async {
    try {
      print('=== REVOKING FILE FROM ORGANIZATION ===');
      print('File ID: $fileId');
      print('Doctor User ID: $doctorId');
      print('Current User ID: $userId');

      // STEP 0: Verify ownership
      final fileData =
          await _supabase
              .from('Files')
              .select('uploaded_by, filename, deleted_at')
              .eq('id', fileId)
              .maybeSingle();

      if (fileData == null) {
        throw Exception('File not found');
      }

      // Check if file is already deleted by owner
      if (fileData['deleted_at'] != null) {
        throw Exception('This file has been deleted by the owner');
      }

      final isFileOwner = fileData['uploaded_by'] == userId;
      final fileName = fileData['filename'] ?? 'Unknown file';

      print('Is file owner: $isFileOwner');
      print('File name: $fileName');

      if (!isFileOwner) {
        throw Exception('Only the file owner can revoke access to this file');
      }

      // 📝 STEP 1: Soft-revoke file shares (preserve audit trail)
      // This marks the share as revoked but keeps the record for compliance
      print('Soft-revoking file shares...');
      final revokeResult =
          await _supabase
              .from('File_Shares')
              .update({'revoked_at': DateTime.now().toIso8601String()})
              .eq('file_id', fileId)
              .or(
                'shared_with_doctor.eq.$doctorId,shared_with_user_id.eq.$doctorId',
              )
              .isFilter('revoked_at', null) // Only revoke active shares
              .select();

      final revokedCount = revokeResult.length;
      print('✓ Soft-revoked $revokedCount file share(s)');

      if (revokedCount == 0) {
        print('⚠️ No active shares found to revoke');
        if (context != null && context.mounted) {
          _showWarning(
            context,
            'No active shares found for this file and doctor',
          );
        }
        return false;
      }

      // 🔐 STEP 2: Delete doctor's AES key (crypto-erasure)
      // This makes the file undecryptable for the doctor
      print('Removing doctor AES key...');
      final keyResult =
          await _supabase
              .from('File_Keys')
              .delete()
              .eq('file_id', fileId)
              .eq('recipient_type', 'user')
              .eq('recipient_id', doctorId)
              .select();

      final keysDeleted = keyResult.length;
      print('✓ Deleted $keysDeleted AES key(s) (crypto-erasure complete)');

      // NOTE: We do NOT modify the Files table here
      // deleted_at in Files is only set when the owner deletes the file

      print('✓ Successfully revoked file "$fileName" from doctor');

      if (context != null && context.mounted) {
        _showSuccess(
          context,
          'File share revoked successfully! The doctor can no longer access this file.',
        );
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ Error revoking file from organization: $e');
      print('Stack trace: $stackTrace');

      if (context != null && context.mounted) {
        _showError(context, 'Error revoking file: $e');
      }

      return false;
    }
  }

  /// Revokes multiple files from an organization/doctor at once
  ///
  /// Useful for batch revocations from the UI
  ///
  /// Returns a map with:
  /// - successCount: Number of successfully revoked files
  /// - failureCount: Number of failed revocations
  /// - failedFiles: List of file names that failed
  static Future<Map<String, dynamic>> revokeMultipleFilesFromOrganization({
    required List<String> fileIds,
    required String doctorId,
    required String userId,
    BuildContext? context,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final List<String> failedFiles = [];

    for (final fileId in fileIds) {
      final success = await revokeFileFromOrganization(
        fileId: fileId,
        doctorId: doctorId,
        userId: userId,
        context: null, // Don't show individual messages
      );

      if (success) {
        successCount++;
      } else {
        failureCount++;
        failedFiles.add(fileId);
      }
    }

    if (context != null && context.mounted) {
      if (failureCount == 0) {
        _showSuccess(
          context,
          'All $successCount file(s) revoked successfully!',
        );
      } else {
        _showWarning(
          context,
          'Revoked $successCount file(s). Failed to revoke $failureCount file(s).',
        );
      }
    }

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'failedFiles': failedFiles,
      'totalProcessed': fileIds.length,
    };
  }

  /// Check if a file share is currently active (not revoked, not deleted)
  ///
  /// This is useful for UI display logic to determine if a file should be shown
  ///
  /// Returns true if the share is active, false otherwise
  static Future<bool> isFileShareActive({
    required String fileId,
    required String doctorId,
  }) async {
    try {
      final result =
          await _supabase
              .from('File_Shares')
              .select('id, Files!inner(deleted_at)')
              .eq('file_id', fileId)
              .or(
                'shared_with_doctor.eq.$doctorId,shared_with_user_id.eq.$doctorId',
              )
              .isFilter('revoked_at', null) // Share not revoked
              .maybeSingle();

      if (result == null) {
        return false;
      }

      // Check if the file itself is deleted
      final fileDeletedAt = result['Files']?['deleted_at'];
      if (fileDeletedAt != null) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking if file share is active: $e');
      return false;
    }
  }

  /// Get the revocation status of a file for a specific doctor
  ///
  /// Returns a map with:
  /// - isActive: Whether the share is currently active
  /// - revokedAt: When the share was revoked (if applicable)
  /// - fileDeletedAt: When the file was deleted (if applicable)
  /// - canBeReactivated: Whether the share can be reactivated
  static Future<Map<String, dynamic>?> getFileShareStatus({
    required String fileId,
    required String doctorId,
  }) async {
    try {
      final result =
          await _supabase
              .from('File_Shares')
              .select('revoked_at, Files!inner(deleted_at)')
              .eq('file_id', fileId)
              .or(
                'shared_with_doctor.eq.$doctorId,shared_with_user_id.eq.$doctorId',
              )
              .maybeSingle();

      if (result == null) {
        return {
          'isActive': false,
          'revokedAt': null,
          'fileDeletedAt': null,
          'canBeReactivated': false,
          'reason': 'No share record found',
        };
      }

      final revokedAt = result['revoked_at'];
      final fileDeletedAt = result['Files']?['deleted_at'];

      final isActive = revokedAt == null && fileDeletedAt == null;
      final canBeReactivated = revokedAt != null && fileDeletedAt == null;

      return {
        'isActive': isActive,
        'revokedAt': revokedAt,
        'fileDeletedAt': fileDeletedAt,
        'canBeReactivated': canBeReactivated,
        'reason': _getStatusReason(isActive, revokedAt, fileDeletedAt),
      };
    } catch (e) {
      print('Error getting file share status: $e');
      return null;
    }
  }

  /// Helper to determine the status reason
  static String _getStatusReason(
    bool isActive,
    String? revokedAt,
    String? fileDeletedAt,
  ) {
    if (fileDeletedAt != null) {
      return 'File deleted by owner';
    }
    if (revokedAt != null) {
      return 'Share revoked';
    }
    if (isActive) {
      return 'Share active';
    }
    return 'Unknown status';
  }

  /// Reactivate a previously revoked file share
  ///
  /// This sets revoked_at back to NULL, allowing the doctor to access the file again
  /// Note: This requires the AES key to be re-shared to the doctor
  ///
  /// Parameters:
  /// - fileId: The ID of the file to reactivate
  /// - doctorId: The doctor's user ID
  /// - userId: The current user ID (must be file owner)
  /// - context: Optional BuildContext for showing feedback messages
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> reactivateFileShare({
    required String fileId,
    required String doctorId,
    required String userId,
    BuildContext? context,
  }) async {
    try {
      print('=== REACTIVATING FILE SHARE ===');
      print('File ID: $fileId');
      print('Doctor User ID: $doctorId');

      // Verify ownership
      final fileData =
          await _supabase
              .from('Files')
              .select('uploaded_by, deleted_at')
              .eq('id', fileId)
              .maybeSingle();

      if (fileData == null) {
        throw Exception('File not found');
      }

      if (fileData['deleted_at'] != null) {
        throw Exception('Cannot reactivate share for deleted file');
      }

      if (fileData['uploaded_by'] != userId) {
        throw Exception('Only the file owner can reactivate shares');
      }

      // Reactivate by setting revoked_at to NULL
      await _supabase
          .from('File_Shares')
          .update({'revoked_at': null})
          .eq('file_id', fileId)
          .or(
            'shared_with_doctor.eq.$doctorId,shared_with_user_id.eq.$doctorId',
          )
          .not('revoked_at', 'is', null); // Only reactivate revoked shares

      print('✓ File share reactivated');

      // NOTE: The AES key needs to be re-shared to the doctor
      // This should be handled by the file sharing service

      if (context != null && context.mounted) {
        _showSuccess(
          context,
          'File share reactivated! The doctor can now access this file again.',
        );
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ Error reactivating file share: $e');
      print('Stack trace: $stackTrace');

      if (context != null && context.mounted) {
        _showError(context, 'Error reactivating file share: $e');
      }

      return false;
    }
  }

  /// Check if a file is shared with any doctors
  static Future<bool> isFileSharedWithDoctors(String fileId) async {
    try {
      final shares = await _supabase
          .from('File_Shares')
          .select('id')
          .eq('file_id', fileId)
          .not('shared_with_doctor', 'is', null)
          .isFilter('revoked_at', null)
          .limit(1);

      return shares.isNotEmpty;
    } catch (e) {
      print('Error checking if file is shared with doctors: $e');
      return false;
    }
  }

  /// Get sharing information for a specific file with doctors
  static Future<Map<String, dynamic>?> getFileDoctorSharingInfo(
    String fileId,
  ) async {
    try {
      final shares = await _supabase
          .from('File_Shares')
          .select('''
            *,
            shared_with_user:User!shared_with_doctor(email, Person(first_name, last_name)),
            shared_by:User!shared_by_user_id(email)
          ''')
          .eq('file_id', fileId)
          .not('shared_with_doctor', 'is', null)
          .isFilter('revoked_at', null);

      return {
        'file_id': fileId,
        'shares': shares,
        'total_doctors_shared': shares.length,
      };
    } catch (e) {
      print('Error getting file sharing info: $e');
      return null;
    }
  }

  // ============================================================================
  // UI FEEDBACK HELPERS
  // ============================================================================

  static void _showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _showWarning(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF57C00),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
