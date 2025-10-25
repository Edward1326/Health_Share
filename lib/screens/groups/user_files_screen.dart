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
  late AnimationController _staggerController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  String _selectedFilter = 'All';

  // Colors matching GroupDetailsScreen
  late Color _primaryColor;
  late Color _accentColor;
  late Color _bg;
  late Color _card;
  late Color _textPrimary;
  late Color _textSecondary;

  @override
  void initState() {
    super.initState();
    _files = widget.memberFiles;
    _currentUserId = GroupFunctions.getCurrentUserId();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initializeColors();
    _staggerController.forward();
  }

  void _initializeColors() {
    _primaryColor = const Color(0xFF416240);
    _accentColor = const Color(0xFFA3B18A);
    _bg = const Color(0xFFF7F9FC);
    _card = Colors.white;
    _textPrimary = const Color(0xFF1A1A2E);
    _textSecondary = const Color(0xFF6B7280);
  }

  @override
  void dispose() {
    _staggerController.dispose();
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

  List<Map<String, dynamic>> get _filteredFiles {
    List<Map<String, dynamic>> filtered = _files;

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (file) => (file['file']['filename'] ?? '')
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()),
              )
              .toList();
    }

    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((file) {
            final fileType = (file['file']['file_type'] ?? '').toUpperCase();
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

    // Default sort by latest (shared_at descending)
    filtered.sort((a, b) {
      final dateA = a['shared_at'] ?? '';
      final dateB = b['shared_at'] ?? '';
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  bool _canRemoveFile(Map<String, dynamic> shareRecord) {
    final fileData = shareRecord['file'];
    final fileOwnerId = fileData['uploaded_by'];
    return _currentUserId == fileOwnerId;
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
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshFiles,
                    color: _primaryColor,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: const SizedBox(height: 20)),
                        if (_isSearchVisible)
                          SliverToBoxAdapter(child: _buildSearchField()),
                        SliverToBoxAdapter(child: const SizedBox(height: 20)),
                        if (_isLoading)
                          SliverFillRemaining(child: _buildLoadingState())
                        else if (_filteredFiles.isEmpty)
                          SliverFillRemaining(child: _buildEmptyState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildFilterDropdown()),
          const SizedBox(width: 12),
          _buildIconButton(
            icon:
                _isSearchVisible
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
            onTap: () {
              setState(() => _isSearchVisible = !_isSearchVisible);
              if (!_isSearchVisible) {
                _searchController.clear();
                _searchQuery = '';
              }
            },
          ),
          const SizedBox(width: 12),
          _buildIconButton(icon: Icons.refresh_rounded, onTap: _refreshFiles),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: _primaryColor.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _primaryColor.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _primaryColor.withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'user_avatar_${widget.memberId}',
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor, _primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.memberName.isNotEmpty
                        ? widget.memberName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.memberName}'s Files",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildCompactStat(
                        icon: Icons.description_rounded,
                        value: '${_files.length}',
                        color: _primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _selectedFilter != 'All'
                  ? _primaryColor.withOpacity(0.3)
                  : _primaryColor.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: DropdownButton<String>(
        value: _selectedFilter,
        underline: const SizedBox(),
        isExpanded: true,
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color:
              _selectedFilter != 'All'
                  ? _primaryColor
                  : _primaryColor.withOpacity(0.6),
          size: 24,
        ),
        borderRadius: BorderRadius.circular(16),
        dropdownColor: Colors.white,
        elevation: 8,
        style: TextStyle(
          color: _textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() => _selectedFilter = newValue);
          }
        },
        items: [
          _buildDropdownItem('All', Icons.folder_rounded, _primaryColor),
          _buildDropdownItem(
            'DOCUMENT',
            Icons.description_rounded,
            const Color(0xFF4299E1),
          ),
          _buildDropdownItem(
            'IMAGE',
            Icons.image_rounded,
            const Color(0xFF667EEA),
          ),
          _buildDropdownItem(
            'AUDIO',
            Icons.audio_file_rounded,
            const Color(0xFF9F7AEA),
          ),
          _buildDropdownItem(
            'VIDEO',
            Icons.video_file_rounded,
            const Color(0xFFED64A6),
          ),
          _buildDropdownItem(
            'COMPRESSED',
            Icons.folder_zip_rounded,
            const Color(0xFFECC94B),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(
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

    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(labels[value] ?? value),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withOpacity(0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Search files...',
            hintStyle: TextStyle(
              color: _textSecondary.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.search_rounded, color: _primaryColor, size: 24),
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: _primaryColor,
                          size: 18,
                        ),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                    : null,
            filled: true,
            fillColor: _card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  _accentColor.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading files...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFileCard(Map<String, dynamic> shareRecord, int index) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final progress = (_staggerController.value - (index * 0.08)).clamp(
          0.0,
          1.0,
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildFileCard(shareRecord),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> shareRecord) {
    final fileData = shareRecord['file'] ?? {};
    final fileName = fileData['filename'] ?? 'Unknown File';
    final fileType = GroupFunctions.getFileType(fileName);
    final sharedDate = GroupFunctions.formatDate(shareRecord['shared_at']);
    final canRemove = _canRemoveFile(shareRecord);

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: () => _previewSharedFile(shareRecord),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _primaryColor.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GroupFunctions.getFileIconColor(
                      fileType,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: GroupFunctions.getFileIconColor(
                        fileType,
                      ).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    GroupFunctions.getFileIcon(fileType),
                    color: GroupFunctions.getFileIconColor(fileType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _textPrimary,
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
                              color: GroupFunctions.getFileIconColor(
                                fileType,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: GroupFunctions.getFileIconColor(
                                  fileType,
                                ).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              fileType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: GroupFunctions.getFileIconColor(
                                  fileType,
                                ),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sharedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
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
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: _primaryColor,
                      size: 16,
                    ),
                  ),
                  color: Colors.white,
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 8),
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
                        PopupMenuItem(
                          value: 'info',
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
                        if (canRemove)
                          PopupMenuItem(
                            value: 'remove',
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
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withOpacity(0.15),
                    _accentColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 56,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No files found'
                  : 'No Files Shared Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with different keywords'
                  : "${widget.memberName} hasn't shared any files yet",
              style: TextStyle(
                color: _textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _accentColor],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _searchQuery = '');
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text(
                    'Clear Search',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: _card,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Remove Share',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Remove "$fileName" from this group? Members will no longer be able to access it.',
                  style: TextStyle(
                    fontSize: 15,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          side: BorderSide(
                            color: _textSecondary.withOpacity(0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: _card,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primaryColor.withOpacity(0.15),
                          _accentColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: _primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'File Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
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
                            GroupFunctions.formatFileSize(
                              fileData['file_size'] ?? 0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Uploaded',
                            GroupFunctions.formatDate(
                              fileData['uploaded_at'] ?? '',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Shared By',
                            (sharedByUser['Person'] != null &&
                                    sharedByUser['Person']['first_name'] !=
                                        null)
                                ? '${sharedByUser['Person']['first_name']} ${sharedByUser['Person']['last_name'] ?? ''}'
                                    .trim()
                                : sharedByUser['email']?.split('@')[0] ??
                                    'Unknown',
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Shared On',
                            GroupFunctions.formatDate(
                              shareRecord['shared_at'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _accentColor],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: _textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primaryColor.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
