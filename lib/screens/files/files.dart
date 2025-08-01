import 'package:flutter/material.dart';

class FileScreen extends StatefulWidget {
  const FileScreen({super.key});

  @override
  State<FileScreen> createState() => _FileScreenState();
}

class _FileScreenState extends State<FileScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _folderDescriptionController =
      TextEditingController();

  List<Map<String, dynamic>> folders = [
    {
      'name': 'Projects',
      'files': 24,
      'icon': Icons.work_outline,
      'color': const Color(0xFF667EEA),
      'date': 'Today',
    },
    {
      'name': 'Documents',
      'files': 18,
      'icon': Icons.description_outlined,
      'color': const Color(0xFF11998E),
      'date': 'Yesterday',
    },
    {
      'name': 'Photos',
      'files': 156,
      'icon': Icons.photo_outlined,
      'color': const Color(0xFFE056FD),
      'date': '2 days ago',
    },
  ];

  @override
  void initState() {
    super.initState();
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
    _folderNameController.dispose();
    _folderDescriptionController.dispose();
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
          'Files',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[600]),
            onPressed: () {
              // Implement search
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Create Folder Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildCreateFolderButton(),
            ),

            // Folders List
            Expanded(
              child:
                  folders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          return _buildFolderItem(folders[index], index);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateFolderButton() {
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
          onTap: () => _showCreateFolderDialog(),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Create New Folder',
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

  Widget _buildFolderItem(Map<String, dynamic> folder, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            // Navigate to folder details
            Navigator.pushNamed(context, '/folder');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: folder['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(folder['icon'], color: folder['color'], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${folder['files']} files',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        folder['date'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteFolderDialog(index);
                    } else if (value == 'rename') {
                      _showRenameFolderDialog(index);
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Rename'),
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

  Widget _buildEmptyState() {
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
              Icons.folder_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No folders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first folder to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    _folderNameController.clear();
    _folderDescriptionController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                        color: const Color(0xFF667EEA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.create_new_folder_outlined,
                        color: Color(0xFF667EEA),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create New Folder',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _folderNameController,
                  decoration: InputDecoration(
                    labelText: 'Folder Name',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _folderDescriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                        _createFolder();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667EEA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteFolderDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Folder'),
          content: Text(
            'Are you sure you want to delete "${folders[index]['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  folders.removeAt(index);
                });
                Navigator.pop(context);
                _showSnackBar('Folder deleted successfully', Colors.red);
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

  void _showRenameFolderDialog(int index) {
    _folderNameController.text = folders[index]['name'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                const Text(
                  'Rename Folder',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _folderNameController,
                  decoration: InputDecoration(
                    labelText: 'New Folder Name',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                        setState(() {
                          folders[index]['name'] = _folderNameController.text;
                        });
                        Navigator.pop(context);
                        _showSnackBar(
                          'Folder renamed successfully',
                          const Color(0xFF11998E),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667EEA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Rename'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createFolder() {
    if (_folderNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a folder name', Colors.red);
      return;
    }

    final colors = [
      const Color(0xFF667EEA),
      const Color(0xFF11998E),
      const Color(0xFFE056FD),
      const Color(0xFFF093FB),
      const Color(0xFF38BDF8),
    ];

    final icons = [
      Icons.folder_outlined,
      Icons.work_outline,
      Icons.photo_outlined,
      Icons.description_outlined,
      Icons.music_note_outlined,
    ];

    setState(() {
      folders.add({
        'name': _folderNameController.text.trim(),
        'files': 0,
        'icon': icons[folders.length % icons.length],
        'color': colors[folders.length % colors.length],
        'date': 'Just now',
      });
    });

    _showSnackBar('Folder created successfully', const Color(0xFF11998E));
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
