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

class _FilesScreenState extends State<FilesScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Set<int> _selectedFiles = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  bool _isGrid = false;
  bool _isSearchActive = false;
  String _sortOrder = 'latest'; // 'latest', 'oldest'

  List<FileItem> items = [];

  static const primaryColor = const Color(0xFF416240);
  static const accentColor = const Color(0xFFA3B18A);

  static const lightBg = Color(0xFFF8FAF8);
  static const borderColor = Color(0xFFE5E7EB);

  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _loadFiles();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
      _isGrid = !_isGrid;
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == 'latest' ? 'oldest' : 'latest';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeScreen = screenWidth > 900;

    final titleFontSize = isLargeScreen ? 24.0 : (isTablet ? 22.0 : 20.0);
    final toolbarHeight = isDesktop ? 84.0 : 220.0;

    return Scaffold(
      backgroundColor: lightBg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(toolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 12,
              vertical: 8,
            ),
            child:
                isLargeScreen
                    ? _buildDesktopAppBar(titleFontSize)
                    : _buildMobileAppBar(titleFontSize),
          ),
        ),
      ),

      body:
          _isLoading
              ? _buildLoadingState()
              : Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child:
                        _isSelectionMode
                            ? Container(
                              width: double.infinity,
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_selectedFiles.length} selected',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _clearSelection,
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _shareSelectedFiles,
                                    icon: const Icon(Icons.share_rounded),
                                    label: const Text('Share'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : const SizedBox.shrink(),
                  ),

                  Expanded(child: _buildContent()),
                ],
              ),

      floatingActionButton:
          _isSelectionMode
              ? null
              : FloatingActionButton(
                onPressed: _uploadFile,
                backgroundColor: primaryColor,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),

      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildDesktopAppBar(double titleFontSize) {
    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) {
              final offsetAnim = Tween<Offset>(
                begin: const Offset(0.0, -0.1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnim, child: child),
              );
            },
            child:
                _isSearchActive
                    ? _buildExpandedSearchField(
                      key: const ValueKey('desktop_search'),
                      width: 420,
                    )
                    : Column(
                      key: const ValueKey('desktop_title'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Files',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: titleFontSize,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All your uploaded files — secure and private',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
          ),
        ),

        const SizedBox(width: 12),

        if (!_isSearchActive) ...[
          IconButton(
            icon: Icon(
              _sortOrder == 'latest'
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: primaryColor,
            ),
            onPressed: _toggleSortOrder,
            tooltip: _sortOrder == 'latest' ? 'Latest first' : 'Oldest first',
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list_rounded,
              color:
                  _selectedFilter != 'All'
                      ? primaryColor
                      : primaryColor.withOpacity(0.6),
            ),
            onPressed: () => _showFilterSheet(context),
          ),

          IconButton(
            icon: Icon(
              _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: primaryColor,
            ),
            onPressed: _toggleLayout,
          ),
        ],

        Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
              color: primaryColor,
            ),
            onPressed: () {
              setState(() {
                if (_isSearchActive) {
                  _searchController.clear();
                  _searchQuery = '';
                  _isSearchActive = false;
                  FocusManager.instance.primaryFocus?.unfocus();
                } else {
                  _isSearchActive = true;
                }
              });
            },
            tooltip: _isSearchActive ? 'Close search' : 'Search',
          ),
        ),
      ],
    );
  }

  Widget _buildMobileAppBar(double titleFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Material(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: const InputDecoration(
                            hintText: 'Search for files',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.filter_list_rounded,
                  color:
                      _selectedFilter != 'All'
                          ? primaryColor
                          : primaryColor.withOpacity(0.6),
                ),
                onPressed: () => _showFilterSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'My Files',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    _sortOrder == 'latest'
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextButton(
                      onPressed: _toggleSortOrder,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                      child: Text(
                        _sortOrder == 'latest'
                            ? 'Last modified (newest)'
                            : 'Last modified (oldest)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: primaryColor,
              ),
              onPressed: _toggleLayout,
              iconSize: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedSearchField({Key? key, double? width}) {
    final searchField = Material(
      key: key,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _isSearchActive = false;
                  FocusManager.instance.primaryFocus?.unfocus();
                });
              },
            ),
            Expanded(
              child: TextField(
                autofocus: true,
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search files, type or name',
                  border: InputBorder.none,
                  isDense: true,
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                          : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: searchField);
    }
    return searchField;
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Loading files...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final filteredItems = _filteredItems;

    if (filteredItems.isEmpty) return _buildEmptyState();

    if (_isGrid) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: GridView.builder(
          key: ValueKey(
            'grid_${filteredItems.length}_${_selectedFilter}_${_searchQuery}_${_sortOrder}',
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                MediaQuery.of(context).size.width > 900
                    ? 4
                    : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            childAspectRatio: 0.82,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final isSelected = _selectedFiles.contains(index);
            return _buildGridCard(item, index, isSelected);
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        key: ValueKey(
          'list_${filteredItems.length}_${_selectedFilter}_${_searchQuery}_${_sortOrder}',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          final isSelected = _selectedFiles.contains(index);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryColor : borderColor,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
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
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(item.icon, color: item.color, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.size} • ${_formatDateTime(item.dateAdded)}',
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
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? primaryColor : Colors.grey[400],
                          size: 24,
                        ),
                      if (!_isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded),
                          onPressed: () => _showFileActions(item),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridCard(FileItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap:
          () =>
              _isSelectionMode
                  ? _toggleFileSelection(index)
                  : _previewFile(item),
      onLongPress: () => _enableSelectionMode(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutQuad,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.06 : 0.04),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(item.icon, color: item.color, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.size}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                if (!_isSelectionMode)
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    onPressed: () => _showFileActions(item),
                  ),
                if (_isSelectionMode)
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? primaryColor : Colors.grey[400],
                  ),
              ],
            ),
          ],
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
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 72,
              color: primaryColor.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Files Yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload documents, images, or videos. Your files are encrypted and stored securely.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _uploadFile,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
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

    // Convert 24-hour to 12-hour format
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

    // Sort by date
    if (_sortOrder == 'latest') {
      filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    } else {
      filtered.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
    }

    return filtered;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
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
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
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

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter files',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedFilter = 'All'),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedFilter == 'All',
                    onSelected: (_) => setState(() => _selectedFilter = 'All'),
                  ),
                  ChoiceChip(
                    label: const Text('Documents'),
                    selected: _selectedFilter == 'DOCUMENT',
                    onSelected:
                        (_) => setState(() => _selectedFilter = 'DOCUMENT'),
                  ),
                  ChoiceChip(
                    label: const Text('Images'),
                    selected: _selectedFilter == 'IMAGE',
                    onSelected:
                        (_) => setState(() => _selectedFilter = 'IMAGE'),
                  ),
                  ChoiceChip(
                    label: const Text('Audio'),
                    selected: _selectedFilter == 'AUDIO',
                    onSelected:
                        (_) => setState(() => _selectedFilter = 'AUDIO'),
                  ),
                  ChoiceChip(
                    label: const Text('Videos'),
                    selected: _selectedFilter == 'VIDEO',
                    onSelected:
                        (_) => setState(() => _selectedFilter = 'VIDEO'),
                  ),
                  ChoiceChip(
                    label: const Text('Compressed'),
                    selected: _selectedFilter == 'COMPRESSED',
                    onSelected:
                        (_) => setState(() => _selectedFilter = 'COMPRESSED'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFileActions(FileItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_red_eye_rounded),
                title: const Text('Preview'),
                onTap: () {
                  Navigator.pop(context);
                  _previewFile(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareSelectionDialog([item]);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showDetails(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(FileItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(item.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${item.type}'),
                const SizedBox(height: 6),
                Text('Size: ${item.size}'),
                const SizedBox(height: 6),
                Text('Uploaded: ${_formatDateTime(item.dateAdded)}'),
                const SizedBox(height: 6),
                Text('Category: ${item.category}'),
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
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF416240),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.share_rounded, color: Colors.white),
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.filesToShare.length} file(s)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
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
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
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
