import 'package:flutter/material.dart';
import 'package:health_share/services/files_services/file_preview.dart';
import 'package:health_share/services/group_services/files_decrypt_group.dart';
import 'package:health_share/services/group_services/fetch_group_service.dart';
import 'package:health_share/services/group_services/files_service_group.dart';
import 'package:health_share/services/group_services/group_management_service.dart';
import 'package:health_share/services/group_services/group_member_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contains utility functions and UI helpers for Groups screens
/// Business logic has been moved to dedicated service files
class GroupFunctions {
  // ==================== USER & AUTH ====================

  /// Get current user ID
  static String? getCurrentUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  /// Check if user is group owner
  static bool isUserGroupOwner(String? userId, Map<String, dynamic> groupData) {
    return userId == groupData['user_id'];
  }

  // ==================== GROUP OPERATIONS ====================

  /// Fetch all groups for a user
  static Future<List<Map<String, dynamic>>> fetchUserGroups(
    String userId,
  ) async {
    try {
      return await FetchGroupService.fetchUserGroups(userId);
    } catch (e) {
      print('Error fetching groups: $e');
      rethrow;
    }
  }

  /// Create a new group with RSA keys
  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    required String userId,
  }) async {
    try {
      return await GroupManagementService.createGroup(
        name: name,
        userId: userId,
      );
    } catch (e) {
      print('Error creating group: $e');
      rethrow;
    }
  }

  /// Leave a group
  static Future<bool> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      return await GroupMemberService.leaveGroup(
        groupId: groupId,
        userId: userId,
      );
    } catch (e) {
      print('Error leaving group: $e');
      rethrow;
    }
  }

  // ==================== MEMBER OPERATIONS ====================

  /// Fetch group members
  static Future<List<Map<String, dynamic>>> fetchGroupMembers(
    String groupId,
  ) async {
    try {
      return await FetchGroupService.fetchGroupMembers(groupId);
    } catch (e) {
      print('Error loading members: $e');
      rethrow;
    }
  }

  /// Get member count for a group
  static Future<int> getMemberCount(String groupId) async {
    try {
      return await FetchGroupService.getMemberCount(groupId);
    } catch (e) {
      print('Error getting member count: $e');
      return 0;
    }
  }

  /// Get detailed members list
  static Future<List<Map<String, dynamic>>> getGroupMembersWithDetails(
    String groupId,
  ) async {
    try {
      return await FetchGroupService.getGroupMembersWithDetails(groupId);
    } catch (e) {
      print('Error loading members with details: $e');
      rethrow;
    }
  }

  /// Add member to group
  static Future<bool> addMemberToGroup({
    required String groupId,
    required String email,
  }) async {
    try {
      return await GroupMemberService.addMemberToGroup(
        groupId: groupId,
        email: email,
      );
    } catch (e) {
      print('Error adding member: $e');
      rethrow;
    }
  }

  // ==================== FILE OPERATIONS ====================

  /// Fetch shared files for a group
  static Future<List<Map<String, dynamic>>> fetchGroupSharedFiles(
    String groupId,
  ) async {
    try {
      return await GroupFileService.fetchGroupSharedFiles(groupId);
    } catch (e) {
      print('Error fetching shared files: $e');
      return [];
    }
  }

  /// Organize files by user for display
  static Map<String, List<Map<String, dynamic>>> organizeFilesByUser(
    List<Map<String, dynamic>> sharedFiles,
  ) {
    return GroupFileService.organizeFilesByUser(sharedFiles);
  }

  /// Preview a shared file
  static Future<void> previewSharedFile({
    required BuildContext context,
    required Map<String, dynamic> shareRecord,
    required String userId,
    required String groupId,
  }) async {
    try {
      final fileData = shareRecord['file'];
      final fileName = fileData['filename'] ?? 'Unknown File';
      final fileId = fileData['id'];
      final ipfsCid = fileData['ipfs_cid'];

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Decrypting $fileName...'),
                ],
              ),
            ),
      );

      final decryptedBytes = await FilesDecryptGroup.decryptGroupSharedFile(
        fileId: fileId,
        groupId: groupId,
        userId: userId,
        ipfsCid: ipfsCid,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (decryptedBytes == null) {
        throw Exception('Failed to decrypt file or access denied');
      }

      await EnhancedFilePreviewService.previewFile(
        context,
        fileName,
        decryptedBytes,
      );
    } catch (e) {
      Navigator.of(context).pop(); // Ensure dialog is closed
      rethrow;
    }
  }

  /// Remove file from group
  static Future<bool> removeFileFromGroup({
    required String fileId,
    required String groupId,
    required String userId,
    required Map<String, dynamic> shareRecord,
    required bool isGroupOwner,
  }) async {
    try {
      final canRemoveShare =
          isGroupOwner || shareRecord['shared_by_user_id'] == userId;

      if (!canRemoveShare) {
        throw Exception(
          'Only the file owner or group admin can remove this share',
        );
      }

      return await GroupFileService.revokeFileFromGroup(
        fileId: fileId,
        groupId: groupId,
        userId: userId,
      );
    } catch (e) {
      print('Error removing file from group: $e');
      rethrow;
    }
  }

  // ==================== UTILITY FUNCTIONS ====================

  /// Format file size to human readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format date to human readable string
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  /// Get file type from filename
  static String getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return extension;
  }

  /// Get icon for file type
  static IconData getFileIcon(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Get color for file type icon
  static Color getFileIconColor(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
        return Colors.teal;
      case 'zip':
      case 'rar':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  /// Check if user can remove share
  static bool canUserRemoveShare({
    required bool isGroupOwner,
    required String? currentUserId,
    required Map<String, dynamic> shareRecord,
  }) {
    return isGroupOwner || shareRecord['shared_by_user_id'] == currentUserId;
  }

  /// Filter groups by search query
  static List<Map<String, dynamic>> filterGroups(
    List<Map<String, dynamic>> groups,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return groups;
    return groups
        .where(
          (group) => (group['name'] ?? '').toString().toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }
}
