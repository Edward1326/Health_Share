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
  String _sortBy = 'date'; // 'date', 'name', 'size'
  late AnimationController _animationController;

  // Color Palette
  static const Color primaryGreen = Color(0xFF5F8D4E);
  static const Color lightCream = Color(0xFFFFF8F0);
  static const Color warmGray = Color(0xFF6B7280);
  static const Color cardBackground = Colors.white;
  static const Color backgroundGray = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _files = widget.memberFiles;
    _currentUserId = GroupFunctions.getCurrentUserId();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
        _showSuccess('Files refreshed successfully');
      } else {
        setState(() {
          _files = [];
        });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1F2937) : backgroundGray,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark),
          SliverToBoxAdapter(
            child:
                _isLoading
                    ? const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      ),
                    )
                    : _buildBody(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF111827) : primaryGreen,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: _refreshFiles,
            tooltip: 'Refresh files',
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  isDark
                      ? [const Color(0xFF111827), const Color(0xFF1F2937)]
                      : [primaryGreen, const Color(0xFF4A7C3A)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.folder_shared,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Shared Files',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.memberName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: lightCream,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_files.length} ${_files.length == 1 ? 'file' : 'files'} shared',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_files.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Column(children: [_buildSortBar(isDark), _buildFilesList(isDark)]);
  }

  Widget _buildSortBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 20,
            color: isDark ? Colors.white70 : warmGray,
          ),
          const SizedBox(width: 8),
          Text(
            'Sort by:',
            style: TextStyle(
              color: isDark ? Colors.white70 : warmGray,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Date', 'date', isDark),
                  const SizedBox(width: 8),
                  _buildSortChip('Name', 'name', isDark),
                  const SizedBox(width: 8),
                  _buildSortChip('Size', 'size', isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, bool isDark) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortFiles();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? primaryGreen
                  : (isDark ? const Color(0xFF4B5563) : lightCream),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? primaryGreen
                    : (isDark ? Colors.white24 : Colors.grey.withOpacity(0.2)),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : warmGray),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFilesList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _refreshFiles,
      color: primaryGreen,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (index / _files.length) * 0.5,
                  1.0,
                  curve: Curves.easeOut,
                ),
              ),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    (index / _files.length) * 0.5,
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              child: _buildModernFileCard(_files[index], isDark),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernFileCard(Map<String, dynamic> shareRecord, bool isDark) {
    final fileData = shareRecord['file'] ?? {};
    final fileName = fileData['filename'] ?? 'Unknown File';
    final fileType = GroupFunctions.getFileType(fileName);
    final fileSize = GroupFunctions.formatFileSize(fileData['file_size'] ?? 0);
    final sharedDate = GroupFunctions.formatDate(shareRecord['shared_at']);

    final canRemoveShare = GroupFunctions.canUserRemoveShare(
      isGroupOwner: _isGroupOwner,
      currentUserId: _currentUserId,
      shareRecord: shareRecord,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF374151) : cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _previewSharedFile(shareRecord),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // File Icon
                Hero(
                  tag: 'file_${fileData['id']}',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          GroupFunctions.getFileIconColor(fileType),
                          GroupFunctions.getFileIconColor(
                            fileType,
                          ).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: GroupFunctions.getFileIconColor(
                            fileType,
                          ).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      GroupFunctions.getFileIcon(fileType),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // File Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.grey[900],
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.data_usage_rounded,
                            size: 14,
                            color: isDark ? Colors.white54 : warmGray,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            fileSize,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : warmGray,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sharedDate,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions Menu
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : lightCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white70 : warmGray,
                      size: 20,
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
                                  color: primaryGreen,
                                ),
                                const SizedBox(width: 12),
                                const Text('Preview File'),
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
                                const Text('File Details'),
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
                                    'Remove Share',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                        ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
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
                color: isDark ? const Color(0xFF374151) : lightCream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 56,
                color: isDark ? Colors.white38 : primaryGreen.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Files Shared Yet',
              style: TextStyle(
                fontSize: 22,
                color: isDark ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "${widget.memberName} hasn't shared any files\nwith this group yet.",
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white54 : warmGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _refreshFiles,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: isDark ? Colors.white10 : lightCream,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? const Color(0xFF374151) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Remove File Share', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(
            'Remove "$fileName" from this group? Members will no longer be able to access this file.',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white70 : warmGray),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
          _showSuccess('File share removed successfully');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDark ? const Color(0xFF374151) : Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileData['filename'] ?? 'File Details',
                    style: const TextStyle(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF4B5563) : lightCream,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(
                    'File Type',
                    fileData['file_type'] ?? 'Unknown',
                    isDark,
                  ),
                  _buildInfoRow(
                    'File Size',
                    GroupFunctions.formatFileSize(fileData['file_size'] ?? 0),
                    isDark,
                  ),
                  _buildInfoRow(
                    'Category',
                    fileData['category'] ?? 'General',
                    isDark,
                  ),
                  _buildInfoRow(
                    'Uploaded',
                    GroupFunctions.formatDate(fileData['uploaded_at'] ?? ''),
                    isDark,
                  ),
                  _buildInfoRow(
                    'Shared By',
                    sharedByUser['email'] ?? 'Unknown',
                    isDark,
                  ),
                  _buildInfoRow(
                    'Shared On',
                    GroupFunctions.formatDate(shareRecord['shared_at'] ?? ''),
                    isDark,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white70 : warmGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
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
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
