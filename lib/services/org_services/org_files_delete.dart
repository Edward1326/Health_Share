import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling file revocation from organizations/doctors
///
/// This service implements a secure revocation strategy that:
/// 1. Soft-revokes file shares (preserves audit trail)
/// 2. Deletes the organization/doctor's AES key (crypto-erasure)
/// 3. Does NOT modify the Files table (owner retains file)
/// 4. Maintains separation between revocation and deletion
///
/// Key Concepts:
/// - revoked_at: When a file share was revoked (soft delete)
/// - deleted_at: When the file owner deleted the file (separate operation)
class OrgFilesDeleteService {
  static final _supabase = Supabase.instance.client;

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
  /// - context: BuildContext for showing feedback messages
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> revokeFileFromOrganization({
    required String fileId,
    required String doctorId,
    required String userId,
    required BuildContext context,
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
        if (context.mounted) {
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

      if (context.mounted) {
        _showSuccess(
          context,
          'File share revoked successfully! The doctor can no longer access this file.',
        );
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ Error revoking file from organization: $e');
      print('Stack trace: $stackTrace');

      if (context.mounted) {
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
    required BuildContext context,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final List<String> failedFiles = [];

    for (final fileId in fileIds) {
      final success = await revokeFileFromOrganization(
        fileId: fileId,
        doctorId: doctorId,
        userId: userId,
        context: context,
      );

      if (success) {
        successCount++;
      } else {
        failureCount++;
        failedFiles.add(fileId);
      }
    }

    if (context.mounted) {
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
  /// - context: BuildContext for showing feedback messages
  ///
  /// Returns true if successful, false otherwise
  static Future<bool> reactivateFileShare({
    required String fileId,
    required String doctorId,
    required String userId,
    required BuildContext context,
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

      if (context.mounted) {
        _showSuccess(
          context,
          'File share reactivated! The doctor can now access this file again.',
        );
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ Error reactivating file share: $e');
      print('Stack trace: $stackTrace');

      if (context.mounted) {
        _showError(context, 'Error reactivating file share: $e');
      }

      return false;
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
