import 'package:flutter/material.dart';
import 'package:health_share/screens/navbar/navbar_main.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _selectedIndex = 1;
  List<FileItem> items = [
    FileItem(
      name: 'Documents',
      type: FileType.folder,
      size: '24 files',
      icon: Icons.folder,
      color: const Color(0xFF667EEA),
    ),
    FileItem(
      name: 'Images',
      type: FileType.folder,
      size: '156 files',
      icon: Icons.folder,
      color: const Color(0xFF11998E),
    ),
    FileItem(
      name: 'project_plan.pdf',
      type: FileType.file,
      size: '2.4 MB',
      icon: Icons.picture_as_pdf,
      color: const Color(0xFFE53E3E),
    ),
    FileItem(
      name: 'presentation.pptx',
      type: FileType.file,
      size: '8.1 MB',
      icon: Icons.slideshow,
      color: const Color(0xFFD69E2E),
    ),
  ];

  String currentPath = 'Files';
  List<String> breadcrumbs = ['Files'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentPath,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            if (breadcrumbs.length > 1)
              Text(
                breadcrumbs.join(' / '),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showCreateFolderDialog,
            icon: Icon(
              Icons.create_new_folder_outlined,
              color: Colors.grey[700],
            ),
          ),
          IconButton(
            onPressed: _showAddFileOptions,
            icon: Icon(Icons.add, color: Colors.grey[700]),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Storage info card
              _buildStorageCard(),
              const SizedBox(height: 24),

              // Files list
              Expanded(
                child:
                    items.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _buildFileItem(items[index], index);
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildStorageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_outlined,
              color: Color(0xFF667EEA),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud Storage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '2.4 GB of 15 GB used',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.16,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF667EEA),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onItemTap(item),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.size,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _onMenuSelected(value, item, index),
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 12),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.grey[400],
                    size: 20,
                  ),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.folder_open_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No files yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a folder or upload files to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showCreateFolderDialog,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('New Folder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showAddFileOptions,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Files'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF667EEA)),
                  foregroundColor: const Color(0xFF667EEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onItemTap(FileItem item) {
    if (item.type == FileType.folder) {
      // Navigate into folder
      setState(() {
        currentPath = item.name;
        breadcrumbs.add(item.name);
        // Clear items or load folder contents
        items = []; // For demo, show empty folder
      });
    } else {
      // Open file
      _showFilePreview(item);
    }
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create New Folder'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Folder name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    _createFolder(controller.text);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _showAddFileOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF667EEA),
                  ),
                  title: const Text('Photos'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFiles('photos');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.videocam_outlined,
                    color: Color(0xFF667EEA),
                  ),
                  title: const Text('Videos'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFiles('videos');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF667EEA),
                  ),
                  title: const Text('Documents'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFiles('documents');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.upload_file_outlined,
                    color: Color(0xFF667EEA),
                  ),
                  title: const Text('Browse Files'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFiles('browse');
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _createFolder(String name) {
    setState(() {
      items.add(
        FileItem(
          name: name,
          type: FileType.folder,
          size: '0 files',
          icon: Icons.folder,
          color: const Color(0xFF667EEA),
        ),
      );
    });
  }

  void _addFiles(String type) {
    // Simulate adding files
    final fileNames = {
      'photos': ['photo_1.jpg', 'photo_2.png'],
      'videos': ['video_1.mp4'],
      'documents': ['document.pdf', 'spreadsheet.xlsx'],
      'browse': ['file.txt'],
    };

    final icons = {
      'photos': Icons.image,
      'videos': Icons.video_file,
      'documents': Icons.description,
      'browse': Icons.insert_drive_file,
    };

    setState(() {
      for (String fileName in fileNames[type] ?? []) {
        items.add(
          FileItem(
            name: fileName,
            type: FileType.file,
            size: '${(1 + (items.length % 10))} MB',
            icon: icons[type] ?? Icons.insert_drive_file,
            color: const Color(0xFF11998E),
          ),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${fileNames[type]?.length ?? 0} files'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onMenuSelected(String value, FileItem item, int index) {
    switch (value) {
      case 'rename':
        _showRenameDialog(item, index);
        break;
      case 'delete':
        _deleteItem(index);
        break;
    }
  }

  void _showRenameDialog(FileItem item, int index) {
    final controller = TextEditingController(text: item.name);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    setState(() {
                      items[index].name = controller.text;
                    });
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Rename'),
              ),
            ],
          ),
    );
  }

  void _deleteItem(int index) {
    setState(() {
      items.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFilePreview(FileItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(item.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 64, color: item.color),
                const SizedBox(height: 16),
                Text('Size: ${item.size}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Open file logic here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open'),
              ),
            ],
          ),
    );
  }
}

class FileItem {
  String name;
  FileType type;
  String size;
  IconData icon;
  Color color;

  FileItem({
    required this.name,
    required this.type,
    required this.size,
    required this.icon,
    required this.color,
  });
}

enum FileType { folder, file }
