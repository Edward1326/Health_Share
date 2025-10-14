import 'package:flutter/material.dart';
import 'package:health_share/services/group_services/group_files_service.dart';
import 'package:health_share/services/group_services/group_functions.dart';

class UserFilesScreen extends StatefulWidget {
  final String groupId;
  final String memberId;
  final String memberName;
  final List<Map<String, dynamic>> memberFiles;

  const UserFilesScreen({
    super.key,
    required this.groupId,
    required this.memberId,
    required this.memberName,
    required this.memberFiles,
  });

  @override
  State<UserFilesScreen> createState() => _UserFilesScreenState();
}

class _UserFilesScreenState extends State<UserFilesScreen>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _files;
  bool _isLoading = false;
  String? _currentUserId;
  bool _isGroupOwner = false;
  String _sortBy = 'date';
  late AnimationController _animationController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryColor = Color(0xFF416240);
  static const Color accentColor = Color(0xFF6A8E6E);

  @override
  void initState() {
    super.initState();
    _files = widget.memberFiles;
    _currentUserId = GroupFunctions.getCurrentUserId();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFiles() async {
    setState(() => _isLoading = true);
    try {
      final sharedFiles = await GroupFileService.fetchGroupSharedFiles(
        widget.groupId,
      );
      final filesByUser = GroupFileService.organizeFilesByUser(sharedFiles);

      final userKey = filesByUser.keys.firstWhere(
        (key) => key.startsWith(widget.memberId),
        orElse: () => '',
      );

      if (userKey.isNotEmpty) {
        setState(() {
          _files = filesByUser[userKey]!;
          _sortFiles();
        });
        _showSuccess('Files refreshed');
      } else {
        setState(() => _files = []);
      }
    } catch (e) {
      _showError('Error refreshing files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sortFiles() {
    switch (_sortBy) {
      case 'name':
        _files.sort((a, b) {
          final nameA = a['file']['filename'] ?? '';
          final nameB = b['file']['filename'] ?? '';
          return nameA.compareTo(nameB);
        });
        break;
      case 'size':
        _files.sort((a, b) {
          final sizeA = a['file']['file_size'] ?? 0;
          final sizeB = b['file']['file_size'] ?? 0;
          return sizeB.compareTo(sizeA);
        });
        break;
      case 'date':
      default:
        _files.sort((a, b) {
          final dateA = a['shared_at'] ?? '';
          final dateB = b['shared_at'] ?? '';
          return dateB.compareTo(dateA);
        });
    }
  }

  List<Map<String, dynamic>> get _filteredFiles {
    if (_searchQuery.isEmpty) return _files;
    return _files
        .where(
          (file) => (file['file']['filename'] ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading files...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _refreshFiles,
                color: primaryColor,
                child: CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(child: _buildMemberHeader()),
                    SliverToBoxAdapter(child: _buildSearchAndFilters()),
                    if (_filteredFiles.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return _buildAnimatedFileCard(
                              _filteredFiles[index],
                              index,
                            );
                          }, childCount: _filteredFiles.length),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: primaryColor.withOpacity(0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            customBorder: const CircleBorder(),
            child: const Icon(Icons.arrow_back_rounded, color: primaryColor),
          ),
        ),
      ),
      title: Text(
        '${widget.memberName}\'s Files',
        style: TextStyle(
          color: Colors.grey[900],
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryColor),
            onPressed: _refreshFiles,
            tooltip: 'Refresh',
          ),
        ),
      ],
    );
  }

  Widget _buildMemberHeader() {
    final totalSize = _files.fold<int>(
      0,
      (sum, file) => sum + ((file['file']?['file_size'] ?? 0) as int),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Row(
        children: [
          Hero(
            tag: 'user_avatar_${widget.memberId}',
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.memberName.isNotEmpty
                      ? widget.memberName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.memberName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.folder_rounded,
                      '${_files.length} file${_files.length == 1 ? '' : 's'}',
                    ),
                    _buildInfoChip(
                      Icons.storage_rounded,
                      GroupFunctions.formatFileSize(totalSize),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search files...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: primaryColor.withOpacity(0.6),
                size: 20,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: primaryColor.withOpacity(0.6),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _searchController.clear();
                        },
                      )
                      : null,
              filled: true,
              fillColor: primaryColor.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Date', 'date', Icons.access_time_rounded),
                      const SizedBox(width: 8),
                      _buildSortChip(
                        'Name',
                        'name',
                        Icons.sort_by_alpha_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildSortChip('Size', 'size', Icons.data_usage_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _sortBy = value;
            _sortFiles();
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? primaryColor : primaryColor.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedFileCard(Map<String, dynamic> shareRecord, int index) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            (index / (_filteredFiles.length + 1)) * 0.6,
            1.0,
            curve: Curves.easeOut,
          ),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index / (_filteredFiles.length + 1)) * 0.6,
              1.0,
              curve: Curves.easeOut,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildFileCard(shareRecord),
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> shareRecord) {
    final fileData = shareRecord['file'] ?? {};
    final fileName = fileData['filename'] ?? 'Unknown File';
    final fileType = GroupFunctions.getFileType(fileName);
    final fileSize = GroupFunctions.formatFileSize(fileData['file_size'] ?? 0);
    final sharedDate = GroupFunctions.formatDate(shareRecord['shared_at']);
    final fileCategory = fileData['category'] ?? 'General';

    final canRemoveShare = GroupFunctions.canUserRemoveShare(
      isGroupOwner: _isGroupOwner,
      currentUserId: _currentUserId,
      shareRecord: shareRecord,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _previewSharedFile(shareRecord),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GroupFunctions.getFileIconColor(fileType),
                        GroupFunctions.getFileIconColor(
                          fileType,
                        ).withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: GroupFunctions.getFileIconColor(
                          fileType,
                        ).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    GroupFunctions.getFileIcon(fileType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.grey[900],
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildFileInfoTag(
                            Icons.folder_outlined,
                            fileCategory,
                            accentColor,
                          ),
                          _buildFileInfoTag(
                            Icons.storage_rounded,
                            fileSize,
                            Colors.blue,
                          ),
                          _buildFileInfoTag(
                            Icons.calendar_today_rounded,
                            sharedDate,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                size: 18,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Preview',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'info',
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Details',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (canRemoveShare)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildFileInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 56,
                color: primaryColor.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No files found'
                  : 'No Files Shared Yet',
              style: TextStyle(
                fontSize: 22,
                color: Colors.grey[900],
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with different keywords'
                  : "${widget.memberName} hasn't shared any files yet",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _searchQuery = '');
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('Clear Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
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
      builder: (context) {
        return AlertDialog(
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
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Remove Share',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            'Remove "$fileName" from this group? Members will no longer be able to access it.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Remove',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && _currentUserId != null) {
      try {
        final success = await GroupFileService.revokeFileFromGroup(
          fileId: fileId,
          groupId: widget.groupId,
          userId: _currentUserId!,
        );

        if (success) {
          await _refreshFiles();
          _showSuccess('File share removed');
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
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'File Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'File Name',
                    fileData['filename'] ?? 'Unknown',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'File Type',
                    fileData['file_type'] ?? 'Unknown',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'File Size',
                    GroupFunctions.formatFileSize(fileData['file_size'] ?? 0),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Category',
                    fileData['category'] ?? 'General',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Uploaded',
                    GroupFunctions.formatDate(fileData['uploaded_at'] ?? ''),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Shared By',
                    sharedByUser['email'] ?? 'Unknown',
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Shared On',
                    GroupFunctions.formatDate(shareRecord['shared_at'] ?? ''),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryColor.withOpacity(0.15)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[900],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
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
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
