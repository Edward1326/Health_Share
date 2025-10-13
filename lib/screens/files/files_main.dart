import 'package:health_share/services/files_services/file_preview.dart';
import 'package:health_share/services/files_services/file_share_to_group.dart';
import 'package:health_share/services/files_services/files_share_to_org.dart';
import 'package:health_share/services/files_services/fullscreen_file_preview.dart';

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
  Set<int> _selectedFiles = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  List<FileItem> items = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final fileData = await DecryptFileService.fetchUserFiles(user.id);

      final loadedItems =
          fileData.map((file) {
            return FileItem(
              id: file['id'] as String,
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
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool _isDocumentType(String fileType) {
    const documentTypes = [
      'PDF',
      'DOC',
      'DOCX',
      'XLS',
      'XLSX',
      'PPT',
      'PPTX',
      'TXT',
      'RTF',
      'CSV',
      'ODT',
      'DOCUMENT',
    ];
    return documentTypes.contains(fileType.toUpperCase());
  }

  bool _isImageType(String fileType) {
    const imageTypes = [
      'JPG',
      'JPEG',
      'PNG',
      'GIF',
      'BMP',
      'TIFF',
      'TIF',
      'WEBP',
      'HEIC',
      'SVG',
      'IMAGE',
    ];
    return imageTypes.contains(fileType.toUpperCase());
  }

  bool _isAudioType(String fileType) {
    const audioTypes = ['MP3', 'WAV', 'M4A', 'AAC', 'OGG', 'AUDIO'];
    return audioTypes.contains(fileType.toUpperCase());
  }

  bool _isVideoType(String fileType) {
    const videoTypes = ['MP4', 'MOV', 'AVI', 'MKV', 'WEBM', 'VIDEO'];
    return videoTypes.contains(fileType.toUpperCase());
  }

  bool _isCompressedType(String fileType) {
    const compressedTypes = ['ZIP', 'RAR', '7Z', 'ARCHIVE'];
    return compressedTypes.contains(fileType.toUpperCase());
  }

  IconData _getFileIcon(String fileType) {
    final type = fileType.toUpperCase();

    if (_isDocumentType(type)) {
      if (type == 'PDF') return Icons.picture_as_pdf_rounded;
      if (type == 'TXT') return Icons.text_snippet_rounded;
      if (['XLS', 'XLSX', 'CSV'].contains(type))
        return Icons.table_chart_rounded;
      if (['PPT', 'PPTX'].contains(type)) return Icons.slideshow_rounded;
      return Icons.description_rounded;
    } else if (_isImageType(type)) {
      return Icons.image_rounded;
    } else if (_isAudioType(type)) {
      return Icons.audio_file_rounded;
    } else if (_isVideoType(type)) {
      return Icons.video_file_rounded;
    } else if (_isCompressedType(type)) {
      return Icons.folder_zip_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String fileType) {
    final type = fileType.toUpperCase();

    if (_isDocumentType(type)) {
      if (type == 'PDF') return const Color(0xFFE53E3E);
      if (type == 'TXT') return const Color(0xFF48BB78);
      if (['XLS', 'XLSX', 'CSV'].contains(type)) return const Color(0xFF38A169);
      if (['PPT', 'PPTX'].contains(type)) return const Color(0xFFED8936);
      return const Color(0xFF4299E1);
    } else if (_isImageType(type)) {
      return const Color(0xFF667EEA);
    } else if (_isAudioType(type)) {
      return const Color(0xFF9F7AEA);
    } else if (_isVideoType(type)) {
      return const Color(0xFFED64A6);
    } else if (_isCompressedType(type)) {
      return const Color(0xFFECC94B);
    } else {
      return const Color(0xFF718096);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedDoctors() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      return await FileShareToOrgService.fetchAssignedDoctors(user.id);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserGroups(String userId) async {
    return await FileShareToGroupService.fetchUserGroups(userId);
  }

  Future<void> _showShareSelectionDialog(List<FileItem> filesToShare) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('User not logged in');
        return;
      }

      final results = await Future.wait([
        _fetchUserGroups(user.id),
        _fetchAssignedDoctors(),
      ]);

      final userGroups = results[0];
      final assignedDoctors = results[1];

      if (userGroups.isEmpty && assignedDoctors.isEmpty) {
        _showError(
          'You are not a member of any groups or assigned to any doctors',
        );
        return;
      }

      final selectedTargets =
          await showDialog<Map<String, List<Map<String, dynamic>>>>(
            context: context,
            builder: (BuildContext context) {
              return _ShareDialog(
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF416240)),
                  const SizedBox(height: 16),
                  Text('Sharing ${filesToShare.length} file(s)...'),
                ],
              ),
            ),
      );

      final fileIds = filesToShare.map((file) => file.id).toList();

      if (selectedGroups.isNotEmpty) {
        final groupIds =
            selectedGroups.map((group) => group['id'] as String).toList();
        await FileShareToGroupService.shareFilesToGroups(
          fileIds,
          groupIds,
          user.id,
        );
      }

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

      Navigator.of(context).pop();

      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });

      final totalTargets = selectedGroups.length + selectedDoctors.length;
      _showSuccess(
        'Successfully shared ${filesToShare.length} file(s) to $totalTargets recipient(s)',
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error sharing files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildBody(),
      floatingActionButton: _isSelectionMode ? null : _buildFAB(),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title:
          _isSelectionMode
              ? Text(
                '${_selectedFiles.length} selected',
                style: TextStyle(
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w600,
                ),
              )
              : Text(
                'My Files',
                style: TextStyle(
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w600,
                ),
              ),
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            icon: Icon(Icons.share_rounded, color: Color(0xFF416240)),
            onPressed: _shareSelectedFiles,
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.grey[700]),
            onPressed:
                () => setState(() {
                  _isSelectionMode = false;
                  _selectedFiles.clear();
                }),
          ),
        ] else ...[
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Colors.grey[700]),
            onPressed: _loadFiles,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF416240)),
          SizedBox(height: 16),
          Text('Loading files...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (items.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        _buildSearchBar(),
        SizedBox(height: 8),
        Expanded(child: _buildFileList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search files...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF416240),
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _selectedFilter != 'All'
                            ? Color(0xFF416240)
                            : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color:
                        _selectedFilter != 'All'
                            ? Colors.white
                            : Colors.grey[700],
                  ),
                ),
                onSelected: (value) {
                  setState(() => _selectedFilter = value);
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(value: 'All', child: Text('All Files')),
                      PopupMenuItem(
                        value: 'DOCUMENT',
                        child: Text('Documents'),
                      ),
                      PopupMenuItem(value: 'IMAGE', child: Text('Images')),
                      PopupMenuItem(value: 'AUDIO', child: Text('Audio')),
                      PopupMenuItem(value: 'VIDEO', child: Text('Videos')),
                      PopupMenuItem(
                        value: 'COMPRESSED',
                        child: Text('Compressed'),
                      ),
                    ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    final filteredItems = _filteredItems;

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text('No files found', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _selectedFiles.contains(index);

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Color(0xFF416240) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  () =>
                      _isSelectionMode
                          ? _toggleFileSelection(index)
                          : _previewFile(item),
              onLongPress: () => _enableSelectionMode(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${item.size} • ${_formatDate(item.dateAdded)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isSelectionMode)
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color:
                            isSelected ? Color(0xFF416240) : Colors.grey[400],
                        size: 24,
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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFF416240).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 50,
              color: Color(0xFF416240),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Files Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Upload your first file to get started',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _uploadFile,
            icon: Icon(Icons.upload_file_rounded),
            label: Text('Upload File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF416240),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _uploadFile,
      backgroundColor: Color(0xFF416240),
      child: Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  void _uploadFile() async {
    final success = await UploadFileService.uploadFile(context);
    if (success) await _loadFiles();
  }

  void _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;
    final selectedItems =
        _selectedFiles.map((index) => _filteredItems[index]).toList();
    await _showShareSelectionDialog(selectedItems);
  }

  void _previewFile(FileItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF416240)),
                SizedBox(height: 16),
                Text('Decrypting ${item.name}...'),
              ],
            ),
          ),
    );

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        Navigator.of(context).pop();
        _showError('User not logged in');
        return;
      }

      final hiveUsername = dotenv.env['HIVE_ACCOUNT_NAME'] ?? '';

      if (hiveUsername.isEmpty) {
        Navigator.of(context).pop();
        _showError('Hive username not configured');
        return;
      }

      final decryptedBytes = await DecryptFileService.decryptFileFromIpfs(
        cid: item.ipfsCid,
        fileId: item.id,
        userId: user.id,
        username: hiveUsername,
      );

      Navigator.of(context).pop();

      if (decryptedBytes == null || decryptedBytes.isEmpty) {
        _showError('Failed to decrypt file');
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => FullscreenFilePreview(
                fileName: item.name,
                bytes: decryptedBytes,
              ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error opening file: $e');
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
        if (_selectedFiles.isEmpty) _isSelectionMode = false;
      } else {
        _selectedFiles.add(index);
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  List<FileItem> get _filteredItems {
    List<FileItem> filtered = items;

    // Apply search filter
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

    // Apply type filter
    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((file) {
            final fileType = file.type.toUpperCase();

            switch (_selectedFilter) {
              case 'DOCUMENT':
                return _isDocumentType(fileType);
              case 'IMAGE':
                return _isImageType(fileType);
              case 'AUDIO':
                return _isAudioType(fileType);
              case 'VIDEO':
                return _isVideoType(fileType);
              case 'COMPRESSED':
                return _isCompressedType(fileType);
              default:
                return true;
            }
          }).toList();
    }

    return filtered;
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
        SnackBar(content: Text(message), backgroundColor: Color(0xFF416240)),
      );
    }
  }
}

class FileItem {
  final String id;
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

class _ShareDialog extends StatefulWidget {
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> doctors;
  final List<FileItem> filesToShare;

  const _ShareDialog({
    required this.groups,
    required this.doctors,
    required this.filesToShare,
  });

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog>
    with SingleTickerProviderStateMixin {
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
    if (person == null) return user['email'] ?? 'Unknown User';

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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF416240),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.share_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Files',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.filesToShare.length} file(s)',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Color(0xFF416240),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF416240),
              tabs: [
                Tab(text: 'Groups (${widget.groups.length})'),
                Tab(text: 'Doctors (${widget.doctors.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildGroupsTab(), _buildDoctorsTab()],
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed:
                          (_selectedGroupIds.isEmpty &&
                                  _selectedDoctorIds.isEmpty)
                              ? null
                              : () {
                                final selectedGroups =
                                    widget.groups
                                        .where(
                                          (g) => _selectedGroupIds.contains(
                                            g['id'],
                                          ),
                                        )
                                        .toList();
                                final selectedDoctors =
                                    widget.doctors
                                        .where(
                                          (d) => _selectedDoctorIds.contains(
                                            d['doctor_id'],
                                          ),
                                        )
                                        .toList();

                                Navigator.pop(context, {
                                  'groups': selectedGroups,
                                  'doctors': selectedDoctors,
                                });
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF416240),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Share (${_selectedGroupIds.length + _selectedDoctorIds.length})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (widget.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 48, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No groups available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: widget.groups.length,
      itemBuilder: (context, index) {
        final group = widget.groups[index];
        final groupId = group['id'] as String;
        final isSelected = _selectedGroupIds.contains(groupId);

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Color(0xFF416240) : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedGroupIds.add(groupId);
                } else {
                  _selectedGroupIds.remove(groupId);
                }
              });
            },
            title: Text(group['name'] as String),
            secondary: Icon(Icons.group_rounded, color: Color(0xFF416240)),
            activeColor: Color(0xFF416240),
          ),
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
              color: Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'No doctors available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: widget.doctors.length,
      itemBuilder: (context, index) {
        final doctor = widget.doctors[index];
        final doctorId = doctor['doctor_id'] as String;
        final isSelected = _selectedDoctorIds.contains(doctorId);

        return Container(
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Color(0xFF416240) : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedDoctorIds.add(doctorId);
                } else {
                  _selectedDoctorIds.remove(doctorId);
                }
              });
            },
            title: Text('Dr. ${_formatFullName(doctor['user'])}'),
            subtitle: Text(
              doctor['organization_name'] ?? 'Unknown Organization',
            ),
            secondary: Icon(
              Icons.medical_services_rounded,
              color: Color(0xFF416240),
            ),
            activeColor: Color(0xFF416240),
          ),
        );
      },
    );
  }
}
