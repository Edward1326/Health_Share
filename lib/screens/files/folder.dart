import 'package:flutter/material.dart';

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  List<Map<String, dynamic>> files = [
    {
      'name': 'Project Proposal.pdf',
      'size': '2.4 MB',
      'type': 'PDF',
      'icon': Icons.picture_as_pdf,
      'color': Colors.red,
      'date': '2 hours ago',
    },
    {
      'name': 'Design Assets.zip',
      'size': '15.7 MB',
      'type': 'ZIP',
      'icon': Icons.archive_outlined,
      'color': Colors.orange,
      'date': '1 day ago',
    },
    {
      'name': 'Meeting Notes.docx',
      'size': '1.2 MB',
      'type': 'DOCX',
      'icon': Icons.description_outlined,
      'color': Colors.blue,
      'date': '3 days ago',
    },
  ];

  List<Map<String, dynamic>> sharedUsers = [
    {
      'name': 'Sarah Wilson',
      'email': 'sarah.wilson@example.com',
      'role': 'Editor',
      'avatar': 'SW',
      'color': const Color(0xFF667EEA),
    },
    {
      'name': 'Mike Johnson',
      'email': 'mike.johnson@example.com',
      'role': 'Viewer',
      'avatar': 'MJ',
      'color': const Color(0xFF11998E),
    },
    {
      'name': 'Emma Davis',
      'email': 'emma.davis@example.com',
      'role': 'Editor',
      'avatar': 'ED',
      'color': const Color(0xFFE056FD),
    },
  ];

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Files',
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            Text(
              '${files.length} files • ${sharedUsers.length} members',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[600]),
            onPressed: () {
              // Implement search
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF667EEA),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF667EEA),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Files'), Tab(text: 'Sharing')],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [_buildFilesTab(), _buildSharingTab()],
        ),
      ),
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        // Add Files Button
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildAddFilesButton(),
        ),

        // Files List
        Expanded(
          child:
              files.isEmpty
                  ? _buildEmptyFilesState()
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      return _buildFileItem(files[index], index);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildSharingTab() {
    return Column(
      children: [
        // Share Button
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: _buildShareButton(),
        ),

        // Shared Users List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: sharedUsers.length,
            itemBuilder: (context, index) {
              return _buildSharedUserItem(sharedUsers[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddFilesButton() {
    return Container(
      width: double.infinity,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddFilesDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.upload_file_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add Files',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11998E), Color(0xFF38BDF8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998E).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showShareDialog(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Share Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Open file
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: file['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(file['icon'], color: file['color'], size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file['name'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${file['size']} • ${file['date']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteFile(index);
                    } else if (value == 'download') {
                      _showSnackBar('File downloaded', const Color(0xFF11998E));
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Download'),
                            ],
                          ),
                        ),
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
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedUserItem(Map<String, dynamic> user, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: user['color'],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  user['avatar'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['email'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          user['role'] == 'Editor'
                              ? const Color(0xFF11998E).withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user['role'],
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            user['role'] == 'Editor'
                                ? const Color(0xFF11998E)
                                : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onSelected: (value) {
                if (value == 'revoke') {
                  _revokeAccess(index);
                } else if (value == 'change_role') {
                  _showChangeRoleDialog(index);
                }
              },
              itemBuilder:
                  (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'change_role',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Change Role'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'revoke',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove_outlined,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Revoke Access',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No files yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first file to this folder',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showAddFilesDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add Files',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 24),
              _buildFileOption(
                title: 'Upload from Device',
                subtitle: 'Select files from your device',
                icon: Icons.upload_file_outlined,
                color: const Color(0xFF667EEA),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar(
                    'File upload feature coming soon',
                    const Color(0xFF667EEA),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildFileOption(
                title: 'Take Photo',
                subtitle: 'Capture a new photo',
                icon: Icons.camera_alt_outlined,
                color: const Color(0xFF11998E),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar(
                    'Camera feature coming soon',
                    const Color(0xFF11998E),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildFileOption(
                title: 'Scan Document',
                subtitle: 'Scan a document with camera',
                icon: Icons.document_scanner_outlined,
                color: const Color(0xFFE056FD),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar(
                    'Document scanner coming soon',
                    const Color(0xFFE056FD),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog() {
    final TextEditingController emailController = TextEditingController();
    String selectedRole = 'Viewer';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF11998E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            color: Color(0xFF11998E),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Share Folder',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Permission Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Viewer'),
                            subtitle: const Text('Can view files only'),
                            value: 'Viewer',
                            groupValue: selectedRole,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedRole = value!;
                              });
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Editor'),
                            subtitle: const Text('Can view and edit files'),
                            value: 'Editor',
                            groupValue: selectedRole,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedRole = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (emailController.text.trim().isNotEmpty) {
                              _shareFolder(
                                emailController.text.trim(),
                                selectedRole,
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF11998E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeRoleDialog(int index) {
    String currentRole = sharedUsers[index]['role'];
    String newRole = currentRole;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Change Role for ${sharedUsers[index]['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Viewer'),
                    subtitle: const Text('Can view files only'),
                    value: 'Viewer',
                    groupValue: newRole,
                    onChanged: (value) {
                      setDialogState(() {
                        newRole = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Editor'),
                    subtitle: const Text('Can view and edit files'),
                    value: 'Editor',
                    groupValue: newRole,
                    onChanged: (value) {
                      setDialogState(() {
                        newRole = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      sharedUsers[index]['role'] = newRole;
                    });
                    Navigator.pop(context);
                    _showSnackBar(
                      'Role updated successfully',
                      const Color(0xFF11998E),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF11998E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteFile(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete File'),
          content: Text(
            'Are you sure you want to delete "${files[index]['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  files.removeAt(index);
                });
                Navigator.pop(context);
                _showSnackBar('File deleted successfully', Colors.red);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _revokeAccess(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Revoke Access'),
          content: Text('Remove access for "${sharedUsers[index]['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  sharedUsers.removeAt(index);
                });
                Navigator.pop(context);
                _showSnackBar('Access revoked successfully', Colors.red);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Revoke'),
            ),
          ],
        );
      },
    );
  }

  void _shareFolder(String email, String role) {
    final colors = [
      const Color(0xFF667EEA),
      const Color(0xFF11998E),
      const Color(0xFFE056FD),
      const Color(0xFFF093FB),
    ];

    setState(() {
      sharedUsers.add({
        'name': email.split('@')[0].replaceAll('.', ' ').toUpperCase(),
        'email': email,
        'role': role,
        'avatar': email.substring(0, 2).toUpperCase(),
        'color': colors[sharedUsers.length % colors.length],
      });
    });

    _showSnackBar('Folder shared successfully', const Color(0xFF11998E));
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
