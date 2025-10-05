import 'package:flutter/material.dart';
import 'package:health_share/services/group_services/files_service_group.dart';
import 'package:health_share/services/group_services/group_functions.dart';
import 'package:health_share/services/group_services/fetch_group_service.dart';
import 'package:health_share/services/group_services/group_member_service.dart';

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
  Map<String, List<Map<String, dynamic>>> _filesByUser = {};
  bool _isLoading = false;
  String? _currentUserId;
  bool _isGroupOwner = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    _currentUserId = GroupFunctions.getCurrentUserId();
    _isGroupOwner = GroupFunctions.isUserGroupOwner(
      _currentUserId,
      widget.groupData,
    );
    await Future.wait([_fetchMembers(), _fetchSharedFiles()]);
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      _members = await FetchGroupService.fetchGroupMembers(widget.groupId);
    } catch (e) {
      _showError('Error loading members: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSharedFiles() async {
    try {
      final sharedFiles = await GroupFileService.fetchGroupSharedFiles(
        widget.groupId,
      );
      final filesByUser = GroupFileService.organizeFilesByUser(sharedFiles);
      setState(() {
        _filesByUser = filesByUser;
      });
    } catch (e) {
      setState(() {
        _filesByUser = {};
      });
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([_fetchMembers(), _fetchSharedFiles()]);
    _showSuccess('Data refreshed');
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
              if (value == 'add_member') {
                _showAddMemberDialog();
              } else if (value == 'leave') {
                _showLeaveGroupDialog();
              } else if (value == 'refresh') {
                _refreshData();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'add_member',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 16),
                        SizedBox(width: 8),
                        Text('Add Members'),
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
                'Joined: ${member['added_at'] != null ? GroupFunctions.formatDate(member['added_at']) : 'Unknown'}',
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

    return _filesByUser.isEmpty
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
            itemCount: _filesByUser.keys.length,
            itemBuilder: (context, index) {
              final userKey = _filesByUser.keys.elementAt(index);
              final userFiles = _filesByUser[userKey]!;
              final firstName = userKey.split('|')[1];

              return _buildUserFileFolder(firstName, userFiles);
            },
          ),
        );
  }

  Widget _buildUserFileFolder(
    String firstName,
    List<Map<String, dynamic>> userFiles,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      child: ExpansionTile(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF667EEA),
              radius: 20,
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName Files',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${userFiles.length} file${userFiles.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        children:
            userFiles
                .map((shareRecord) => _buildSharedFileCard(shareRecord))
                .toList(),
      ),
    );
  }

  Widget _buildSharedFileCard(Map<String, dynamic> shareRecord) {
    final fileData = shareRecord['file'] ?? {};
    final fileName = fileData['filename'] ?? 'Unknown File';
    final fileType = GroupFunctions.getFileType(fileName);
    final fileSize = GroupFunctions.formatFileSize(fileData['file_size'] ?? 0);
    final sharedDate = GroupFunctions.formatDate(shareRecord['shared_at']);
    final uploadDate = GroupFunctions.formatDate(fileData['uploaded_at'] ?? '');

    final canRemoveShare = GroupFunctions.canUserRemoveShare(
      isGroupOwner: _isGroupOwner,
      currentUserId: _currentUserId,
      shareRecord: shareRecord,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: GroupFunctions.getFileIconColor(fileType),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            GroupFunctions.getFileIcon(fileType),
            color: Colors.white,
            size: 20,
          ),
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
            const SizedBox(height: 2),
            Text(
              fileSize,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            Text(
              'Shared: $sharedDate • Uploaded: $uploadDate',
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
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
                if (canRemoveShare)
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

  Future<void> _previewSharedFile(Map<String, dynamic> shareRecord) async {
    if (_currentUserId == null) {
      _showError('User not logged in');
      return;
    }

    try {
      await GroupFunctions.previewSharedFile(
        context: context,
        shareRecord: shareRecord,
        userId: _currentUserId!,
        groupId: widget.groupId,
      );
    } catch (e) {
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
          await _fetchSharedFiles();
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
                  GroupFunctions.formatFileSize(fileData['file_size'] ?? 0),
                ),
                _buildInfoRow('Category', fileData['category'] ?? 'General'),
                _buildInfoRow(
                  'Uploaded',
                  GroupFunctions.formatDate(fileData['uploaded_at'] ?? ''),
                ),
                _buildInfoRow('Shared By', sharedByUser['email'] ?? 'Unknown'),
                _buildInfoRow(
                  'Shared On',
                  GroupFunctions.formatDate(shareRecord['shared_at'] ?? ''),
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

  void _showAddMemberDialog() {
    final TextEditingController emailController = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Add Member'),
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
                  onPressed: isAdding ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isAdding
                          ? null
                          : () async {
                            if (emailController.text.isNotEmpty) {
                              setDialogState(() => isAdding = true);
                              try {
                                await GroupMemberService.addMemberToGroup(
                                  groupId: widget.groupId,
                                  email: emailController.text,
                                );
                                await _fetchMembers();
                                Navigator.pop(context);
                                _showSuccess(
                                  '${emailController.text} added to group successfully',
                                );
                              } catch (e) {
                                setDialogState(() => isAdding = false);
                                _showError(
                                  e.toString().replaceAll('Exception: ', ''),
                                );
                              }
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
                      isAdding
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
                          : const Text('Add Member'),
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
      await GroupMemberService.leaveGroup(
        groupId: widget.groupId,
        userId: _currentUserId!,
      );

      if (mounted) {
        Navigator.pop(context, true);
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
}
