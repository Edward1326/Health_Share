import 'package:flutter/material.dart';
import 'package:health_share/services/files_services/file_preview.dart';
import 'package:health_share/services/group_services/group_file_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final Map<String, dynamic> groupData;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupData,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCurrentUser();
    _fetchMembers();
    _fetchSharedFiles();
  }

  Future<void> _getCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _currentUserId = user?.id;
    });
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('Group_Members')
          .select('''
            *,
            User!user_id(id, email, person_id)
          ''')
          .eq('group_id', widget.groupId)
          .order('added_at', ascending: true);

      print('DEBUG: Members response: $response'); // Debug line

      setState(() {
        _members = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('DEBUG: Error loading members: $e'); // Debug line
      _showError('Error loading members: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSharedFiles() async {
    try {
      // Use the new GroupFileService instead of the old method
      final sharedFiles = await GroupFileService.fetchGroupSharedFiles(
        widget.groupId,
      );

      setState(() {
        _sharedFiles = sharedFiles;
      });

      print(
        'Loaded ${_sharedFiles.length} shared files for group ${widget.groupId}',
      );
    } catch (e) {
      print('Error fetching shared files: $e');
      setState(() {
        _sharedFiles = [];
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF667EEA),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              '${_members.length} members',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'invite') {
                _showInviteDialog();
              } else if (value == 'leave') {
                _showLeaveGroupDialog();
              } else if (value == 'refresh') {
                _refreshData();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 16),
                        SizedBox(width: 8),
                        Text('Invite Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 16),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Leave Group',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF667EEA),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF667EEA),
          tabs: const [Tab(text: 'Members'), Tab(text: 'Shared Files')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMembersTab(), _buildFilesTab()],
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No members found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final user = member['User'];
        final isOwner = member['user_id'] == widget.groupData['user_id'];
        final isCurrentUser = member['user_id'] == _currentUserId;

        // Add null safety checks
        if (user == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Text(
              'Error: User data not found',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final email = user['email'] ?? 'Unknown User';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF667EEA),
              radius: 24,
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isCurrentUser)
                        Text(
                          'You',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Owner',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Joined: ${member['added_at'] != null ? _formatDate(member['added_at']) : 'Unknown'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _sharedFiles.isEmpty
        ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No files shared yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Files shared with this group will appear here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        : RefreshIndicator(
          onRefresh: _fetchSharedFiles,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sharedFiles.length,
            itemBuilder: (context, index) {
              final shareRecord = _sharedFiles[index];
              return _buildSharedFileCard(shareRecord);
            },
          ),
        );
  }

  Widget _buildSharedFileCard(Map<String, dynamic> shareRecord) {
    final fileData = shareRecord['file'] ?? {};
    final sharedByUser = shareRecord['shared_by'] ?? {};

    final fileName = fileData['filename'] ?? 'Unknown File';
    final fileType = _getFileType(fileName);
    final fileSize = _formatFileSize(fileData['file_size'] ?? 0);
    final sharedDate = _formatDate(shareRecord['shared_at']);
    final sharedByEmail = sharedByUser['email'] ?? 'Unknown User';
    final uploadDate = _formatDate(fileData['uploaded_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getFileIconColor(fileType),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getFileIcon(fileType), color: Colors.white, size: 24),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$fileSize • Shared by $sharedByEmail',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              'Shared: $sharedDate • Uploaded: $uploadDate',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'preview') {
              _previewSharedFile(shareRecord);
            } else if (value == 'remove') {
              _removeFileFromGroup(shareRecord);
            } else if (value == 'info') {
              _showFileInfo(shareRecord);
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'preview',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 16),
                      SizedBox(width: 8),
                      Text('Preview'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Text('File Info'),
                    ],
                  ),
                ),
                // Only show remove option if user is the file sharer or group owner
                if (shareRecord['shared_by_user_id'] == _currentUserId ||
                    widget.groupData['user_id'] == _currentUserId)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Remove Share',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
        ),
      ),
    );
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return extension;
  }

  IconData _getFileIcon(String fileType) {
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

  Color _getFileIconColor(String fileType) {
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String dateString) {
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

  Future<void> _previewSharedFile(Map<String, dynamic> shareRecord) async {
    try {
      final fileData = shareRecord['file'];
      final fileName = fileData['filename'] ?? 'Unknown File';
      final fileId = fileData['id'];
      final ipfsCid = fileData['ipfs_cid'];

      if (_currentUserId == null) {
        _showError('User not logged in');
        return;
      }

      // Show loading indicator
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

      // Use GroupFileService to decrypt the shared file
      final decryptedBytes = await GroupFileService.decryptGroupSharedFile(
        fileId: fileId,
        groupId: widget.groupId,
        userId: _currentUserId!,
        ipfsCid: ipfsCid,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (decryptedBytes == null) {
        _showError('Failed to decrypt file or access denied');
        return;
      }

      // Use your existing EnhancedFilePreviewService
      await EnhancedFilePreviewService.previewFile(
        context,
        fileName,
        decryptedBytes,
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      _showError('Error previewing file: $e');
    }
  }

  Future<void> _removeFileFromGroup(Map<String, dynamic> shareRecord) async {
    final fileData = shareRecord['file'];
    final fileName = fileData['filename'] ?? 'Unknown File';
    final fileId = fileData['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Remove File Share'),
            content: Text(
              'Remove "$fileName" from this group? Group members will no longer be able to access this file.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && _currentUserId != null) {
      try {
        final success = await GroupFileService.revokeFileFromGroup(
          fileId: fileId,
          groupId: widget.groupId,
          userId: _currentUserId!,
        );

        if (success) {
          await _fetchSharedFiles(); // Refresh list
          _showSuccess('File share removed from group');
        } else {
          _showError('Failed to remove file share');
        }
      } catch (e) {
        _showError('Error removing file share: $e');
      }
    }
  }

  void _showFileInfo(Map<String, dynamic> shareRecord) {
    final fileData = shareRecord['file'];
    final sharedByUser = shareRecord['shared_by'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(fileData['filename'] ?? 'File Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('File Type', fileData['file_type'] ?? 'Unknown'),
                _buildInfoRow(
                  'File Size',
                  _formatFileSize(fileData['file_size'] ?? 0),
                ),
                _buildInfoRow('Category', fileData['category'] ?? 'General'),
                _buildInfoRow(
                  'Uploaded',
                  _formatDate(fileData['uploaded_at'] ?? ''),
                ),
                _buildInfoRow('Shared By', sharedByUser['email'] ?? 'Unknown'),
                _buildInfoRow(
                  'Shared On',
                  _formatDate(shareRecord['shared_at'] ?? ''),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    await Future.wait([_fetchMembers(), _fetchSharedFiles()]);
    _showSuccess('Data refreshed');
  }

  Future<void> _inviteUser(String email) async {
    try {
      // Find user by email from custom User table
      final userResponse =
          await Supabase.instance.client
              .from('User')
              .select('id')
              .eq('email', email)
              .maybeSingle();

      if (userResponse == null) {
        _showError('User not found with this email');
        return;
      }

      // Check if user is already a member
      final memberCheck =
          await Supabase.instance.client
              .from('Group_Members')
              .select('id')
              .eq('group_id', widget.groupId)
              .eq('user_id', userResponse['id'])
              .maybeSingle();

      if (memberCheck != null) {
        _showError('User is already a member of this group');
        return;
      }

      // Check for existing pending invitation
      final inviteCheck =
          await Supabase.instance.client
              .from('Group_Invitations')
              .select('id')
              .eq('group_id', widget.groupId)
              .eq('invitee_id', userResponse['id'])
              .eq('status', 'pending')
              .maybeSingle();

      if (inviteCheck != null) {
        _showError('Invitation already sent to this user');
        return;
      }

      // Send invitation
      await Supabase.instance.client.from('Group_Invitations').insert({
        'group_id': widget.groupId,
        'invitee_id': userResponse['id'],
        'invited_by': _currentUserId,
        'status': 'pending',
      });

      _showSuccess('Invitation sent to $email');
    } catch (e) {
      _showError('Error sending invitation: $e');
    }
  }

  void _showInviteDialog() {
    final TextEditingController emailController = TextEditingController();
    bool isInviting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Invite Member'),
              content: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter user\'s email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              actions: [
                TextButton(
                  onPressed: isInviting ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isInviting
                          ? null
                          : () async {
                            if (emailController.text.isNotEmpty) {
                              setDialogState(() => isInviting = true);
                              await _inviteUser(emailController.text);
                              Navigator.pop(context);
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      isInviting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text('Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Leave Group'),
            content: Text(
              'Are you sure you want to leave "${widget.groupName}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _leaveGroup();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  Future<void> _leaveGroup() async {
    try {
      await Supabase.instance.client
          .from('Group_Members')
          .delete()
          .eq('group_id', widget.groupId)
          .eq('user_id', _currentUserId!);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate group was left
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Left "${widget.groupName}" successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('Error leaving group: $e');
    }
  }
}
