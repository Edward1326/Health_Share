import 'package:health_share/services/files_services/file_share_to_group.dart';
import 'package:health_share/services/files_services/files_share_to_org.dart';
import 'package:health_share/services/files_services/fullscreen_file_preview.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';

import 'package:health_share/services/files_services/upload_file.dart';
import 'package:health_share/services/files_services/decrypt_file.dart';
import 'package:health_share/services/files_services/file_delete.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Set<int> _selectedFiles = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  bool _isList = true;

  List<FileItem> items = [];

  static const primaryColor = Color(0xFF416240);
  static const accentColor = Color(0xFFA3B18A);
  static const lightBg = Color(0xFFF8FAF8);
  static const borderColor = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF1A1A2E);

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
    _loadFiles();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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

      // Fetch only non-deleted files
      final fileData = await supabase
          .from('Files')
          .select('*')
          .eq('uploaded_by', user.id)
          .isFilter('deleted_at', null)
          .order('uploaded_at', ascending: false);

      final loadedItems =
          fileData.map((file) {
            return FileItem(
              id: file['id'] as String,
              name: file['filename'] ?? 'Unknown file',
              type: file['file_type'] ?? 'UNKNOWN',
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
        _showError('Error loading files: $e');
      }
    }
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
                  const CircularProgressIndicator(color: primaryColor),
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

  void _toggleLayout() {
    setState(() {
      _isList = !_isList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F0E3), // soft light green top
                  Colors.white, // white bottom
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                _buildSearchBar(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child:
                      _isSelectionMode
                          ? _buildSelectionBar()
                          : const SizedBox.shrink(),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : _buildUploadFAB(),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'My Files',
              style: TextStyle(
                color: primaryColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      color: primaryColor.withOpacity(0.5),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search files...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        hintStyle: TextStyle(
                          color: primaryColor.withOpacity(0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: primaryColor.withOpacity(0.5),
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter dropdown button
          _buildFilterButton(),
          const SizedBox(width: 12),
          // Grid/List toggle button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleLayout,
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  _isList ? Icons.grid_view_rounded : Icons.view_list_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      initialValue: _selectedFilter,
      onSelected: (String newValue) {
        setState(() => _selectedFilter = newValue);
      },
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 8),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              _selectedFilter != 'All'
                  ? primaryColor.withOpacity(0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _selectedFilter != 'All'
                    ? primaryColor.withOpacity(0.3)
                    : primaryColor.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.filter_list_rounded,
          color:
              _selectedFilter != 'All'
                  ? primaryColor
                  : primaryColor.withOpacity(0.7),
          size: 22,
        ),
      ),
      itemBuilder:
          (BuildContext context) => [
            _buildFilterMenuItem('All', Icons.folder_rounded, primaryColor),
            _buildFilterMenuItem(
              'DOCUMENT',
              Icons.description_rounded,
              const Color(0xFF4299E1),
            ),
            _buildFilterMenuItem(
              'IMAGE',
              Icons.image_rounded,
              const Color(0xFF667EEA),
            ),
            _buildFilterMenuItem(
              'AUDIO',
              Icons.audio_file_rounded,
              const Color(0xFF9F7AEA),
            ),
            _buildFilterMenuItem(
              'VIDEO',
              Icons.video_file_rounded,
              const Color(0xFFED64A6),
            ),
            _buildFilterMenuItem(
              'COMPRESSED',
              Icons.folder_zip_rounded,
              const Color(0xFFECC94B),
            ),
          ],
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(
    String value,
    IconData icon,
    Color color,
  ) {
    final labels = {
      'All': 'All Files',
      'DOCUMENT': 'Documents',
      'IMAGE': 'Images',
      'AUDIO': 'Audio',
      'VIDEO': 'Videos',
      'COMPRESSED': 'Compressed',
    };

    final isSelected = _selectedFilter == value;

    return PopupMenuItem(
      value: value,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                labels[value] ?? value,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_selectedFiles.length} selected',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: primaryColor,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearSelection,
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _shareSelectedFiles,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadFAB() {
    return FloatingActionButton(
      onPressed: _uploadFile,
      backgroundColor: primaryColor,
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: Colors.white),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    accentColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3.5,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading files...',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child:
            _filteredItems.isEmpty
                ? _buildEmptyState()
                : _isList
                ? _buildFileList()
                : _buildFileGrid(),
      ),
    );
  }

  Widget _buildFileList() {
    final filteredItems = _filteredItems;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _selectedFiles.contains(index);
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 250 + (index * 40)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildFileCard(item, index, isSelected),
          ),
        );
      },
    );
  }

  Widget _buildFileGrid() {
    final filteredItems = _filteredItems;
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 900) {
      crossAxisCount = 3;
    } else if (screenWidth < 600) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _selectedFiles.contains(index);
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 250 + (index * 40)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.9 + (value * 0.1), child: child),
            );
          },
          child: _buildGridCard(item, index, isSelected),
        );
      },
    );
  }

  Widget _buildFileCard(FileItem item, int index, bool isSelected) {
    final uploadedDate = _formatDateTime(item.dateAdded);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            () =>
                _isSelectionMode
                    ? _toggleFileSelection(index)
                    : _previewFile(item),
        onLongPress: () => _enableSelectionMode(index),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : primaryColor.withOpacity(0.08),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.color.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: item.color.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: item.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: textPrimary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            uploadedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: textPrimary.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isSelectionMode)
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? primaryColor : Colors.grey[400],
                  size: 24,
                )
              else
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.more_vert_rounded,
                      color: primaryColor,
                      size: 16,
                    ),
                  ),
                  color: Colors.white,
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  offset: const Offset(0, 8),
                  onSelected: (value) {
                    if (value == 'preview') {
                      _previewFile(item);
                    } else if (value == 'share') {
                      _showShareSelectionDialog([item]);
                    } else if (value == 'details') {
                      _showDetails(item);
                    } else if (value == 'delete') {
                      _confirmDeleteFile(item);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'preview',
                          height: 48,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.remove_red_eye_rounded,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Preview',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          height: 48,
                          child: Row(
                            children: [
                              Icon(
                                Icons.share_rounded,
                                size: 18,
                                color: primaryColor,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Share',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'details',
                          height: 48,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          height: 48,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Delete',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFFD32F2F),
                                ),
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
    );
  }

  Widget _buildGridCard(FileItem item, int index, bool isSelected) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            () =>
                _isSelectionMode
                    ? _toggleFileSelection(index)
                    : _previewFile(item),
        onLongPress: () => _enableSelectionMode(index),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : primaryColor.withOpacity(0.08),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(item.icon, color: item.color, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: item.color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      item.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: item.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                      color: Colors.white,
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'preview') {
                          _previewFile(item);
                        } else if (value == 'share') {
                          _showShareSelectionDialog([item]);
                        } else if (value == 'details') {
                          _showDetails(item);
                        } else if (value == 'delete') {
                          _confirmDeleteFile(item);
                        }
                      },
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'preview',
                              height: 48,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.remove_red_eye_rounded,
                                      size: 16,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Preview',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              height: 48,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.share_rounded,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Share',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'details',
                              height: 48,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Details',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              height: 48,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                  if (_isSelectionMode)
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? primaryColor : Colors.grey[400],
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: textPrimary.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatDate(item.dateAdded),
                      style: TextStyle(
                        color: textPrimary.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.15),
                    accentColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                color: primaryColor.withOpacity(0.4),
                size: 56,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No files found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isEmpty
                  ? 'Upload your first file to get started'
                  : 'Try a different search term',
              style: TextStyle(
                fontSize: 15,
                color: textPrimary.withOpacity(0.6),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
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
                const CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 16),
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

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedFiles.clear();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$day/$month/$year $hour:$minute $period';
  }

  List<FileItem> get _filteredItems {
    List<FileItem> filtered = items;

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
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showDetails(FileItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 22,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'File Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name', item.name),
                const SizedBox(height: 12),
                _buildDetailRow('Type', item.type.toUpperCase()),
                const SizedBox(height: 12),
                _buildDetailRow('Uploaded', _formatDateTime(item.dateAdded)),
                const SizedBox(height: 12),
                _buildDetailRow('Category', item.category),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.08), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: textPrimary.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows confirmation dialog before deleting a file
  void _confirmDeleteFile(FileItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    size: 22,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Delete File',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to delete this file?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.orange[800],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action cannot be undone. The file will be permanently undecryptable.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteFile(item);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
    );
  }

  /// Deletes a file and reloads the file list
  Future<void> _deleteFile(FileItem item) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('User not logged in');
        return;
      }

      // Fetch file details including hash
      final fileData =
          await supabase.from('Files').select('*').eq('id', item.id).single();

      // Calculate or fetch file hash
      // Note: If you don't have sha256_hash in your Files table,
      // you'll need to compute it or use a placeholder
      final fileHash = fileData['sha256_hash'] ?? 'hash_not_available';

      final success = await FileDeleteService.deleteFile(
        fileId: item.id,
        fileName: item.name,
        fileHash: fileHash,
        userId: user.id,
        context: context,
      );

      if (success) {
        await _loadFiles();
      }
    } catch (e) {
      _showError('Error deleting file: $e');
    }
  }
}

class FileItem {
  final String id;
  final String name;
  final String type;
  final IconData icon;
  final Color color;
  final DateTime dateAdded;
  final String ipfsCid;
  final String category;

  FileItem({
    required this.id,
    required this.name,
    required this.type,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF416240),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Files',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${widget.filesToShare.length} file(s) selected',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF416240),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF416240),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF416240),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        backgroundColor: const Color(0xFF416240),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Share (${_selectedGroupIds.length + _selectedDoctorIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
            const SizedBox(height: 16),
            Text(
              'No groups available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.groups.length,
      itemBuilder: (context, index) {
        final group = widget.groups[index];
        final groupId = group['id'] as String;
        final isSelected = _selectedGroupIds.contains(groupId);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF416240) : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
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
            title: Text(
              group['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            secondary: const Icon(
              Icons.group_rounded,
              color: Color(0xFF416240),
            ),
            activeColor: const Color(0xFF416240),
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
            const SizedBox(height: 16),
            Text(
              'No doctors available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.doctors.length,
      itemBuilder: (context, index) {
        final doctor = widget.doctors[index];
        final doctorId = doctor['doctor_id'] as String;
        final isSelected = _selectedDoctorIds.contains(doctorId);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF416240) : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
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
            title: Text(
              'Dr. ${_formatFullName(doctor['user'])}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              doctor['organization_name'] ?? 'Unknown Organization',
              style: const TextStyle(fontSize: 13),
            ),
            secondary: const Icon(
              Icons.medical_services_rounded,
              color: Color(0xFF416240),
            ),
            activeColor: const Color(0xFF416240),
          ),
        );
      },
    );
  }
}
