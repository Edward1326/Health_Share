import 'package:health_share/services/files_services/file_preview.dart';
import 'package:health_share/services/files_services/file_share_to_group.dart';
import 'package:health_share/services/files_services/files_share_to_org.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';

import 'package:health_share/services/files_services/upload_file.dart';
import 'package:health_share/services/files_services/decrypt_file.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _selectedIndex = 1;
  Set<int> _selectedFiles = {}; // Track selected files
  bool _isSelectionMode = false;
  bool _isLoading = true; // Add loading state

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Add sort and filter options
  String _selectedFileType = 'All';
  String _sortBy = 'dateDesc'; // Options: dateDesc, dateAsc, nameAsc, nameDesc

  // List of available file types for filter
  final List<String> _fileTypes = [
    'All',
    'PDF',
    'IMAGE',
    'DOCUMENT',
    'TXT',
    'DOC',
    'DOCX',
  ];

  // Replace static items with real data from Supabase
  List<FileItem> items = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  /// Load files from Supabase
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final fileData = await DecryptFileService.fetchUserFiles(user.id);

      final loadedItems =
          fileData.map((file) {
            return FileItem(
              id: file['id'] as String, // Changed from int to String
              name: file['filename'] ?? 'Unknown file',
              type: file['file_type'] ?? 'UNKNOWN',
              size: _formatFileSize(file['file_size'] ?? 0),
              icon: _getFileIcon(file['file_type'] ?? 'UNKNOWN'),
              color: _getFileColor(file['file_type'] ?? 'UNKNOWN'),
              dateAdded:
                  DateTime.tryParse(file['uploaded_at'] ?? '') ??
                  DateTime.now(),
              ipfsCid: file['ipfs_cid'] ?? '',
              category: file['category'] ?? 'General',
            );
          }).toList();

      setState(() {
        items = loadedItems;
        _isLoading = false;
      });

      print('Loaded ${items.length} files from database');
    } catch (e) {
      print('Error loading files: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
      }
    }
  }

  /// Format file size in human readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get appropriate icon for file type
  IconData _getFileIcon(String fileType) {
    switch (fileType.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
      case 'IMAGE':
        return Icons.image;
      case 'DOC':
      case 'DOCX':
      case 'DOCUMENT':
        return Icons.description;
      case 'TXT':
        return Icons.text_snippet;
      case 'XLS':
      case 'XLSX':
        return Icons.table_chart;
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Get appropriate color for file type
  Color _getFileColor(String fileType) {
    switch (fileType.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFE53E3E);
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
      case 'IMAGE':
        return const Color(0xFF11998E);
      case 'DOC':
      case 'DOCX':
      case 'DOCUMENT':
        return const Color(0xFF2B6CB0);
      case 'TXT':
        return const Color(0xFF38A169);
      case 'XLS':
      case 'XLSX':
        return const Color(0xFF22C35E);
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFF718096);
    }
  }

  // Fetch assigned doctors using the new service
  Future<List<Map<String, dynamic>>> _fetchAssignedDoctors() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      return await FileShareToOrgService.fetchAssignedDoctors(user.id);
    } catch (e) {
      print('Error fetching assigned doctors: $e');
      return [];
    }
  }

  // Helper method to fetch user groups using the new service
  Future<List<Map<String, dynamic>>> _fetchUserGroups(String userId) async {
    return await FileShareToGroupService.fetchUserGroups(userId);
  }

  // Enhanced sharing dialog with both groups and doctors
  Future<void> _showShareSelectionDialog(List<FileItem> filesToShare) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('User not logged in');
        return;
      }

      // Fetch both groups and doctors
      final Future<List<Map<String, dynamic>>> groupsFuture = _fetchUserGroups(
        user.id,
      );
      final Future<List<Map<String, dynamic>>> doctorsFuture =
          _fetchAssignedDoctors();

      final results = await Future.wait([groupsFuture, doctorsFuture]);
      final userGroups = results[0];
      final assignedDoctors = results[1];

      if (userGroups.isEmpty && assignedDoctors.isEmpty) {
        _showError(
          'You are not a member of any groups or assigned to any doctors',
        );
        return;
      }

      // Show enhanced selection dialog
      final selectedTargets =
          await showDialog<Map<String, List<Map<String, dynamic>>>>(
            context: context,
            builder: (BuildContext context) {
              return _EnhancedShareSelectionDialog(
                groups: userGroups,
                doctors: assignedDoctors,
                filesToShare: filesToShare,
              );
            },
          );

      if (selectedTargets != null &&
          (selectedTargets['groups']!.isNotEmpty ||
              selectedTargets['doctors']!.isNotEmpty)) {
        await _shareFilesToTargets(filesToShare, selectedTargets);
      }
    } catch (e) {
      _showError('Error loading sharing options: $e');
    }
  }

  // Simplified sharing method that delegates to the appropriate services
  Future<void> _shareFilesToTargets(
    List<FileItem> filesToShare,
    Map<String, List<Map<String, dynamic>>> selectedTargets,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('User not logged in');
        return;
      }

      final selectedGroups = selectedTargets['groups']!;
      final selectedDoctors = selectedTargets['doctors']!;

      print('=== ENHANCED SHARING DEBUG ===');
      print('User ID: ${user.id}');
      print('Files to share: ${filesToShare.length}');
      print('Groups selected: ${selectedGroups.length}');
      print('Doctors selected: ${selectedDoctors.length}');

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
                  Text(
                    'Sharing ${filesToShare.length} file(s) to ${selectedGroups.length} group(s) and ${selectedDoctors.length} doctor(s)...',
                  ),
                ],
              ),
            ),
      );

      // Extract file IDs
      final fileIds = filesToShare.map((file) => file.id).toList();

      // Share with groups using the dedicated service
      if (selectedGroups.isNotEmpty) {
        final groupIds =
            selectedGroups.map((group) => group['id'] as String).toList();
        await FileShareToGroupService.shareFilesToGroups(
          fileIds,
          groupIds,
          user.id,
        );
      }

      // Share with doctors using the dedicated service
      if (selectedDoctors.isNotEmpty) {
        final doctorIds =
            selectedDoctors
                .map((doctor) => doctor['doctor_id'] as String)
                .toList();
        await FileShareToOrgService.shareFilesToDoctors(
          fileIds,
          doctorIds,
          user.id,
        );
      }

      Navigator.of(context).pop(); // Close loading dialog

      // Exit selection mode
      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });

      final totalTargets = selectedGroups.length + selectedDoctors.length;
      _showSuccess(
        'Successfully shared ${filesToShare.length} file(s) to $totalTargets recipient(s)',
      );
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in _shareFilesToTargets: $e');
      print('Stack trace: $stackTrace');
      Navigator.of(context).pop(); // Close loading dialog
      _showError('Error sharing files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isSelectionMode ? '${_selectedFiles.length} Selected' : 'My Files',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareSelectedFiles,
              color: Colors.grey[700],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed:
                  () => setState(() {
                    _isSelectionMode = false;
                    _selectedFiles.clear();
                  }),
              color: Colors.grey[700],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFiles,
              color: Colors.grey[700],
            ),
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _uploadFile,
              color: Colors.grey[700],
            ),
          ],
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildSearchAndFilterBar(),
                  Expanded(
                    child:
                        items.isEmpty ? _buildEmptyState() : _buildFilesList(),
                  ),
                ],
              ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  // Update _buildFilesList to use filtered and sorted items
  Widget _buildFilesList() {
    final filteredItems = _filteredAndSortedItems;

    if (filteredItems.isEmpty) {
      return Center(
        child: Text(
          'No files match your search criteria',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _selectedFiles.contains(index);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color:
                isSelected
                    ? const Color(0xFF667EEA).withOpacity(0.1)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap:
                  () =>
                      _isSelectionMode
                          ? _toggleFileSelection(index)
                          : _previewFile(item),
              onLongPress: () => _enableSelectionMode(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFF667EEA)
                            : Colors.grey.withOpacity(0.1),
                  ),
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
                          Row(
                            children: [
                              Text(
                                item.size,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(item.dateAdded),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleFileSelection(index),
                        activeColor: const Color(0xFF667EEA),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
              Icons.upload_file_outlined,
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
            'Upload files to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _uploadFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadFile() async {
    final success = await UploadFileService.uploadFile(context);

    // Refresh the file list if upload was successful
    if (success) {
      await _loadFiles(); // Reload files from database
    }
  }

  void _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final selectedItems =
        _selectedFiles.map((index) => _filteredAndSortedItems[index]).toList();

    await _showShareSelectionDialog(selectedItems);
  }

  void _previewFile(FileItem item) async {
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
                Text('Verifying and decrypting ${item.name}...'),
              ],
            ),
          ),
    );

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in')));
        return;
      }

      // ✅ Fetch Hive username from .env instead of Supabase
      final hiveUsername = dotenv.env['HIVE_ACCOUNT_NAME'] ?? '';

      if (hiveUsername.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hive username not configured. Please check your .env file.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      print(
        'Starting blockchain verification and decryption for file: ${item.name}',
      );
      print('File ID: ${item.id}, IPFS CID: ${item.ipfsCid}');
      print('Hive Username (from .env): $hiveUsername');

      // Use the new DecryptFileService with blockchain verification
      final decryptedBytes = await DecryptFileService.decryptFileFromIpfs(
        cid: item.ipfsCid,
        fileId: item.id,
        userId: user.id,
        username: hiveUsername, // ← now comes from .env
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (decryptedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to decrypt file. Blockchain verification may have failed.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );

      if (decryptedBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Decrypted file is empty'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Use enhanced preview service
      await EnhancedFilePreviewService.previewFile(
        context,
        item.name,
        decryptedBytes,
      );
    } catch (e, stackTrace) {
      Navigator.of(context).pop();
      print('Error in _previewFile: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _enableSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedFiles.add(index);
    });
  }

  void _toggleFileSelection(int index) {
    setState(() {
      if (_selectedFiles.contains(index)) {
        _selectedFiles.remove(index);
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(index);
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Filter and sort files
  List<FileItem> get _filteredAndSortedItems {
    List<FileItem> filtered = items;

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (file) => file.name.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }

    // Apply file type filter
    if (_selectedFileType != 'All') {
      filtered =
          filtered
              .where(
                (file) =>
                    file.type.toUpperCase() == _selectedFileType.toUpperCase(),
              )
              .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'dateDesc':
        filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case 'dateAsc':
        filtered.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case 'nameAsc':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'nameDesc':
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return filtered;
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Filter and Sort Options
          Row(
            children: [
              // File Type Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFileType,
                      items:
                          _fileTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFileType = newValue;
                          });
                        }
                      },
                      hint: const Text('File Type'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort Options
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'dateDesc',
                          child: Text('Newest First'),
                        ),
                        DropdownMenuItem(
                          value: 'dateAsc',
                          child: Text('Oldest First'),
                        ),
                        DropdownMenuItem(
                          value: 'nameAsc',
                          child: Text('Name A-Z'),
                        ),
                        DropdownMenuItem(
                          value: 'nameDesc',
                          child: Text('Name Z-A'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortBy = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    _searchController.dispose();
    super.dispose();
  }
}

class FileItem {
  final String id; // Changed from int to String
  final String name;
  final String type;
  final String size;
  final IconData icon;
  final Color color;
  final DateTime dateAdded;
  final String ipfsCid;
  final String category;

  FileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.icon,
    required this.color,
    required this.dateAdded,
    required this.ipfsCid,
    required this.category,
  });
}

/// Enhanced Dialog widget for selecting both groups and doctors
class _EnhancedShareSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> doctors;
  final List<FileItem> filesToShare;

  const _EnhancedShareSelectionDialog({
    required this.groups,
    required this.doctors,
    required this.filesToShare,
  });

  @override
  State<_EnhancedShareSelectionDialog> createState() =>
      _EnhancedShareSelectionDialogState();
}

class _EnhancedShareSelectionDialogState
    extends State<_EnhancedShareSelectionDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedGroupIds = {};
  final Set<String> _selectedDoctorIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatFullName(Map<String, dynamic> user) {
    final person = user['Person'];
    if (person == null) {
      return user['email'] ?? 'Unknown User';
    }

    final firstName = person['first_name']?.toString().trim() ?? '';
    final middleName = person['middle_name']?.toString().trim() ?? '';
    final lastName = person['last_name']?.toString().trim() ?? '';

    List<String> nameParts = [];
    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    return nameParts.isEmpty
        ? (user['email'] ?? 'Unknown User')
        : nameParts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Share ${widget.filesToShare.length} file(s)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Text(
              'Choose groups and doctors to share with:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 16),
                        const SizedBox(width: 6),
                        Text('Groups (${widget.groups.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services, size: 16),
                        const SizedBox(width: 6),
                        Text('Doctors (${widget.doctors.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildGroupsTab(), _buildDoctorsTab()],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed:
              (_selectedGroupIds.isEmpty && _selectedDoctorIds.isEmpty)
                  ? null
                  : () {
                    final selectedGroups =
                        widget.groups
                            .where(
                              (group) =>
                                  _selectedGroupIds.contains(group['id']),
                            )
                            .toList();
                    final selectedDoctors =
                        widget.doctors
                            .where(
                              (doctor) => _selectedDoctorIds.contains(
                                doctor['doctor_id'],
                              ),
                            )
                            .toList();

                    Navigator.pop(context, {
                      'groups': selectedGroups,
                      'doctors': selectedDoctors,
                    });
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667EEA),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Share (${_selectedGroupIds.length + _selectedDoctorIds.length})',
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    if (widget.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No groups available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.groups.length,
      itemBuilder: (context, index) {
        final group = widget.groups[index];
        final groupId = group['id'] as String;
        final isSelected = _selectedGroupIds.contains(groupId);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedGroupIds.add(groupId);
              } else {
                _selectedGroupIds.remove(groupId);
              }
            });
          },
          title: Text(
            group['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text('Group'),
          secondary: CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Icon(Icons.group, color: Colors.blue[600], size: 20),
          ),
          activeColor: const Color(0xFF667EEA),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }

  Widget _buildDoctorsTab() {
    if (widget.doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No assigned doctors',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.doctors.length,
      itemBuilder: (context, index) {
        final doctor = widget.doctors[index];
        final doctorId = doctor['doctor_id'] as String;
        final isSelected = _selectedDoctorIds.contains(doctorId);
        final doctorUser = doctor['user'];

        return CheckboxListTile(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedDoctorIds.add(doctorId);
              } else {
                _selectedDoctorIds.remove(doctorId);
              }
            });
          },
          title: Text(
            'Dr. ${_formatFullName(doctorUser)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doctor['organization_name'] ?? 'Unknown Organization'),
              if (doctor['department'] != null)
                Text(
                  doctor['department'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),
          secondary: CircleAvatar(
            backgroundColor: Colors.green[50],
            child: Icon(
              Icons.medical_services,
              color: Colors.green[600],
              size: 20,
            ),
          ),
          activeColor: const Color(0xFF667EEA),
          controlAffinity: ListTileControlAffinity.leading,
          isThreeLine: doctor['department'] != null,
        );
      },
    );
  }
}
