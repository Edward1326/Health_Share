// group_details.dart
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:health_share/services/group_service.dart';
import 'package:health_share/services/group_invitation_service.dart';
import 'package:health_share/services/group_file_service.dart';
import 'package:health_share/functions/decrypt_view_file.dart';
import 'package:health_share/services/file_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isOwner;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isOwner,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  final GroupService _groupService = GroupService();
  final GroupInvitationService _invitationService = GroupInvitationService();
  final GroupFileService _groupFileService = GroupFileService();

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _groupFiles = [];
  Map<String, dynamic>? _groupDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      print('Loading group data for group: ${widget.groupId}');

      // Load data sequentially to avoid race conditions
      final details = await _groupService.getGroupDetails(widget.groupId);
      final members = await _groupService.getGroupMembers(widget.groupId);
      final files = await _groupFileService.getGroupFiles(widget.groupId);

      print(
        'Group data loaded: ${details?['name']}, Members: ${members.length}, Files: ${files.length}',
      );

      if (mounted) {
        setState(() {
          _groupDetails = details;
          _members = members;
          _groupFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading group data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading group data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.groupName,
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.grey[600]),
            onPressed: _showInviteMemberDialog,
          ),
          if (widget.isOwner)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteGroupDialog();
                }
              },
              itemBuilder:
                  (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Group',
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
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Files (${_groupFiles.length})'),
            Tab(text: 'Members (${_members.length})'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildGroupInfoCard(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildFilesTab(), _buildMembersTab()],
                      ),
                    ),
                    if (!widget.isOwner) _buildLeaveGroupButton(),
                  ],
                ),
              ),
    );
  }

  Widget _buildGroupInfoCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.isOwner ? 'Group Owner' : 'Member',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.folder_shared,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${_groupFiles.length} shared files',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 24),
              Icon(
                Icons.people,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${_members.length} members',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        // Upload Files Button
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildUploadFilesButton(),
        ),
        // Files List
        Expanded(
          child:
              _groupFiles.isEmpty
                  ? _buildEmptyFilesState()
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: _groupFiles.length,
                    itemBuilder: (context, index) {
                      final fileShare = _groupFiles[index];
                      final file = fileShare['Files'];
                      if (file == null) return const SizedBox.shrink();
                      return _buildFileCard(fileShare, file);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    return _members.isEmpty
        ? _buildEmptyMembersState()
        : ListView.builder(
          padding: const EdgeInsets.all(20.0),
          itemCount: _members.length,
          itemBuilder: (context, index) => _buildMemberCard(_members[index]),
        );
  }

  Widget _buildUploadFilesButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showShareFileDialog,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: const Text(
          'Share Files with Group',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_shared_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No shared files yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share files with the group to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMembersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No members yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite people to join this group',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(
    Map<String, dynamic> fileShare,
    Map<String, dynamic> file,
  ) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwnFile = fileShare['shared_by'] == currentUser?.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getFileColor(file['file_type']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFileIcon(file['file_type']),
            color: _getFileColor(file['file_type']),
            size: 20,
          ),
        ),
        title: Text(
          file['filename'] ?? 'Unknown file',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_formatFileSize(file['file_size'] ?? 0)} • ${file['file_type'] ?? 'Unknown'}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing:
            isOwnFile || widget.isOwner
                ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'unshare') _unshareFile(file['id']);
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'unshare',
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Unshare',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                )
                : null,
        onTap: () => _previewGroupFile(file),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final user = member['User'] ?? {};
    final person = member['Person'] ?? {};
    final isOwner = member['user_id'] == _groupDetails?['user_id'];
    final memberName =
        '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF667EEA).withOpacity(0.1),
          child: Text(
            _getInitials(person['first_name'], person['last_name']),
            style: const TextStyle(
              color: Color(0xFF667EEA),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          memberName.isNotEmpty ? memberName : user['email'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          user['email'] ?? '',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing:
            isOwner
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11998E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Owner',
                    style: TextStyle(
                      color: Color(0xFF11998E),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
                : widget.isOwner
                ? PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'remove') _showRemoveMemberDialog(member);
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_remove,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Remove',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                )
                : null,
      ),
    );
  }

  Widget _buildLeaveGroupButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showLeaveGroupDialog,
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label: const Text(
            'Leave Group',
            style: TextStyle(
              color: Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withOpacity(0.2)),
            ),
          ),
        ),
      ),
    );
  }

  // Action Methods
  void _showShareFileDialog() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      final userFiles = await _groupFileService.getUserFilesForSharing(
        currentUser.id,
      );
      if (!mounted) return;
      if (userFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You don\'t have any files to share. Upload some files first!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Share Files with Group'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: userFiles.length,
                  itemBuilder: (context, index) {
                    final file = userFiles[index];
                    return ListTile(
                      leading: Icon(_getFileIcon(file['file_type'])),
                      title: Text(file['filename']),
                      subtitle: Text(
                        '${_formatFileSize(file['file_size'])} • ${file['file_type']}',
                      ),
                      trailing: const Icon(Icons.share),
                      onTap: () async {
                        try {
                          await _groupFileService.shareFileWithGroup(
                            fileId: file['id'],
                            groupId: widget.groupId,
                            userId: currentUser.id,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${file['filename']} shared with group!',
                              ),
                            ),
                          );
                          _loadGroupData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _previewGroupFile(Map<String, dynamic> file) async {
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
                Text('Decrypting ${file['filename']}...'),
              ],
            ),
          ),
    );
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        Navigator.of(context).pop();
        return;
      }
      // Use the existing decryptFileFromIpfs method which should work for both personal and group files
      final decryptedBytes =
          await DecryptAndViewFileService.decryptFileFromIpfs(
            cid: file['ipfs_cid'],
            fileId: file['id'],
            userId: currentUser.id,
          );
      Navigator.of(context).pop();
      if (decryptedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decrypt file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await EnhancedFilePreviewService.previewFile(
        context,
        file['filename'],
        decryptedBytes,
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _unshareFile(String fileId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await _groupFileService.unshareFileFromGroup(
        fileId: fileId,
        groupId: widget.groupId,
        userId: currentUser.id,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File unshared from group')));
      _loadGroupData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Dialog Methods
  void _showInviteMemberDialog() {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Invite Member'),
            content: TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter email address',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (emailController.text.trim().isEmpty) return;
                  try {
                    final currentUser =
                        Supabase.instance.client.auth.currentUser;
                    if (currentUser == null) return;
                    await _groupService.inviteUserToGroup(
                      groupId: widget.groupId,
                      userId: currentUser.id,
                      memberEmail: emailController.text.trim(),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Invitation sent to ${emailController.text.trim()}!',
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );
  }

  void _showRemoveMemberDialog(Map<String, dynamic> member) {
    final person = member['Person'] ?? {};
    final memberName =
        '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'.trim();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Text('Remove $memberName from the group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final currentUser =
                        Supabase.instance.client.auth.currentUser;
                    if (currentUser == null) return;

                    await _groupService.removeMemberFromGroup(
                      groupId: widget.groupId,
                      adminUserId: currentUser.id,
                      memberId: member['user_id'],
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$memberName removed from group')),
                    );
                    _loadGroupData();
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                  try {
                    final currentUser =
                        Supabase.instance.client.auth.currentUser;
                    if (currentUser == null) return;

                    await _groupService.leaveGroup(
                      groupId: widget.groupId,
                      userId: currentUser.id,
                    );

                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Left group successfully')),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Leave',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group'),
            content: Text(
              'Are you sure you want to delete "${widget.groupName}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final currentUser =
                        Supabase.instance.client.auth.currentUser;
                    if (currentUser == null) return;

                    await _groupService.deleteGroup(
                      groupId: widget.groupId,
                      userId: currentUser.id,
                    );

                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Group deleted successfully'),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  // Helper methods
  String _getInitials(String? firstName, String? lastName) {
    final first =
        firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : '';
    final last = lastName?.isNotEmpty == true ? lastName![0].toUpperCase() : '';
    return '$first$last';
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType?.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
        return Icons.image;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'TXT':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String? fileType) {
    switch (fileType?.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFE53E3E);
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
        return const Color(0xFF11998E);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF2B6CB0);
      case 'TXT':
        return const Color(0xFF38A169);
      default:
        return const Color(0xFF718096);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
