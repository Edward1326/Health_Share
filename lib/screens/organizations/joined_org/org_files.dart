import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:health_share/services/files_services/fullscreen_file_preview.dart';
import 'package:health_share/services/org_services/org_files_decrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/org_services/org_doctor_service.dart';
import 'package:health_share/services/org_services/org_files_service.dart';

class OrgDoctorsFilesScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String orgName;
  final String assignmentId;

  const OrgDoctorsFilesScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.orgName,
    required this.assignmentId,
  });

  @override
  State<OrgDoctorsFilesScreen> createState() => _OrgDoctorsFilesScreenState();
}

class _OrgDoctorsFilesScreenState extends State<OrgDoctorsFilesScreen>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late AnimationController _headerController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerScaleAnimation;

  Map<String, dynamic>? _doctorDetails;
  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoading = true;
  bool _isLoadingFiles = false;
  String? _currentUserId;
  String? _doctorUserId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  String _sortOrder = 'all';

  // Colors
  late Color _primaryColor;
  late Color _accentColor;
  late Color _bg;
  late Color _card;
  late Color _textPrimary;
  late Color _textSecondary;

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _headerScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
    );

    _initializeColors();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _initializeScreen();
  }

  void _initializeColors() {
    _primaryColor = const Color(0xFF416240);
    _accentColor = const Color(0xFFA3B18A);
    _bg = const Color(0xFFF7F9FC);
    _card = Colors.white;
    _textPrimary = const Color(0xFF1A1A2E);
    _textSecondary = const Color(0xFF6B7280);
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchDoctorDetails(), _fetchSharedFiles()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _headerController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _staggerController.forward();
    }
  }

  Future<void> _fetchDoctorDetails() async {
    try {
      final doctorDetails = await OrgDoctorService.fetchDoctorDetails(
        widget.doctorId,
      );
      if (mounted) {
        setState(() {
          _doctorDetails = doctorDetails;
          _doctorUserId = doctorDetails?['User']?['id'];
        });
      }
    } catch (e) {
      if (mounted) _showError('Error loading doctor details: $e');
    }
  }

  Future<void> _fetchSharedFiles() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingFiles = true);

    try {
      final sharedFiles = await OrgFilesService.fetchSharedFiles(
        currentUser.id,
        widget.doctorId,
      );
      if (mounted) setState(() => _sharedFiles = sharedFiles);
    } catch (e) {
      if (mounted) {
        setState(() => _sharedFiles = []);
        _showError('Error loading shared files: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingFiles = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchDoctorDetails(), _fetchSharedFiles()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccess('Refreshed successfully');
    }
  }

  void _toggleSortOrder() {
    setState(() {
      if (_sortOrder == 'all') {
        _sortOrder = 'you';
      } else if (_sortOrder == 'you') {
        _sortOrder = 'doctor';
      } else {
        _sortOrder = 'all';
      }
    });
  }

  // In your _OrgDoctorsFilesScreenState class, update the _filteredFiles getter:

  List<Map<String, dynamic>> get _filteredFiles {
    var filtered =
        _sharedFiles.where((file) {
          if (_searchQuery.isEmpty) return true;
          final name = (file['filename'] ?? '').toLowerCase();
          final type = (file['file_type'] ?? '').toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) || type.contains(query);
        }).toList();

    // Filter by who shared the file
    if (_sortOrder == 'patient') {
      // Show files shared by the patient (current user)
      filtered =
          filtered.where((file) {
            final sharedBy = file['shared_by_user_id'];
            return sharedBy == _currentUserId;
          }).toList();
    } else if (_sortOrder == 'doctor') {
      // Show files shared by the doctor
      filtered =
          filtered.where((file) {
            final sharedBy = file['shared_by_user_id'];
            return sharedBy == _doctorUserId;
          }).toList();
    }
    // 'all' shows everything, no additional filtering needed

    // Sort by shared_at date (newest first)
    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a['shared_at'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['shared_at'] ?? '') ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  bool _canRemoveFile(Map<String, dynamic> file) {
    final fileOwnerId = file['uploaded_by'];
    return _currentUserId == fileOwnerId;
  }

  Future<void> _removeFileFromDoctor(Map<String, dynamic> file) async {
    if (_currentUserId == null || _doctorUserId == null) {
      _showError('User not logged in');
      return;
    }

    final fileName = file['filename'] ?? 'Unknown File';
    final fileId = file['id'];

    final confirm = await _showRemoveDialog(fileName);

    if (confirm == true) {
      try {
        final success = await OrgFilesService.revokeFileFromDoctor(
          fileId: fileId,
          doctorUserId: _doctorUserId!,
          userId: _currentUserId!,
        );

        if (success) {
          await _fetchSharedFiles();
          _showSuccess('File share removed');
        } else {
          _showError('Failed to remove file share');
        }
      } catch (e) {
        _showError('Error removing file share: $e');
      }
    }
  }

  Future<bool?> _showRemoveDialog(String fileName) {
    return showDialog<bool>(
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
                    'Remove "$fileName" from ${widget.doctorName}? The doctor will no longer be able to access it.',
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
          ),
    );
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final fileName = file['filename'] ?? 'Unknown file';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 20),
                  Text(
                    'Downloading file...',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      final fileMetadata = await OrgFilesDecryptService.getFileMetadata(
        file['id'],
      );

      if (fileMetadata == null) throw Exception('File metadata not found');

      final decryptedBytes =
          await OrgFilesDecryptService.decryptSharedFileSimple(
            fileId: file['id'],
            ipfsCid: fileMetadata['ipfs_cid'],
          );

      if (decryptedBytes == null) throw Exception('Failed to decrypt file');

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String filePath = '${directory.path}/$fileName';
      int counter = 1;
      while (await File(filePath).exists()) {
        final nameWithoutExt =
            fileName.contains('.')
                ? fileName.substring(0, fileName.lastIndexOf('.'))
                : fileName;
        final ext =
            fileName.contains('.') ? '.${fileName.split('.').last}' : '';
        filePath = '${directory.path}/$nameWithoutExt($counter)$ext';
        counter++;
      }

      await File(filePath).writeAsBytes(decryptedBytes);

      Navigator.of(context).pop();
      _showSuccess('File downloaded to ${directory.path}');
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error: ${e.toString()}');
    }
  }

  void _showFileInfo(Map<String, dynamic> file) {
    // Determine who shared the file based on shared_by_user_id
    String sharedByDisplay = 'Unknown';
    final sharedByUserId = file['shared_by_user_id'];

    if (sharedByUserId == _currentUserId) {
      sharedByDisplay = 'You';
    } else if (sharedByUserId == _doctorUserId) {
      sharedByDisplay = '${widget.doctorName}';
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: _card,
            child: SingleChildScrollView(
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
                    _buildDetailRow('File Name', file['filename'] ?? 'Unknown'),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'File Type',
                      file['file_type'] ?? 'Unknown',
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'File Size',
                      _formatFileSize(file['file_size'] ?? 0),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Shared By', sharedByDisplay),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Shared On',
                      _formatSharedDate(file['shared_at']),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
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
                  ],
                ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _primaryColor.withOpacity(0.1),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return const Color(0xFFA855F7);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF059669);
      case 'txt':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFEA580C);
    }
  }

  String _formatSharedDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);

      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;
      if (hour == 0) hour = 12;

      final timeStr = '$hour:$minute $period';

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year $timeStr';
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _getDoctorEmail() {
    return _doctorDetails?['User']?['email'] ?? 'No email';
  }

  String _getDoctorContact() {
    final person = _doctorDetails?['User']?['Person'];
    return person?['contact_number'] ?? 'No contact number';
  }

  String _getDoctorDepartment() {
    return _doctorDetails?['department'] ?? 'General Medicine';
  }

  String _formatJoinDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _headerController.dispose();
    _searchController.dispose();
    super.dispose();
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
                    onRefresh: _refreshData,
                    color: _primaryColor,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: const SizedBox(height: 20)),
                        SliverToBoxAdapter(child: _buildDoctorInfoCard()),
                        SliverToBoxAdapter(child: const SizedBox(height: 28)),
                        if (_isSearchVisible)
                          SliverToBoxAdapter(child: _buildSearchField()),
                        SliverToBoxAdapter(
                          child: SizedBox(height: _isSearchVisible ? 20 : 0),
                        ),
                        if (_isLoading)
                          SliverFillRemaining(child: _buildLoadingState())
                        else
                          _buildFilesList(),
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
          const Spacer(),
          _buildSortDropdown(), // Replace the sort icon button with dropdown
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
          _buildIconButton(icon: Icons.refresh_rounded, onTap: _refreshData),
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

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.08), width: 1.5),
      ),
      child: DropdownButton<String>(
        value: _sortOrder,
        underline: const SizedBox(),
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: _primaryColor,
          size: 24,
        ),
        borderRadius: BorderRadius.circular(16),
        dropdownColor: Colors.white,
        elevation: 8,
        style: TextStyle(
          color: _textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() => _sortOrder = newValue);
          }
        },
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.people_rounded,
                    color: _primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('All Files'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'patient',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.blue,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Patient'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'doctor',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Doctor'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return Opacity(
          opacity: _headerController.value,
          child: Transform.translate(
            offset: Offset(0, _headerSlideAnimation.value),
            child: Transform.scale(
              scale: _headerScaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
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
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _accentColor],
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
                        widget.doctorName.isNotEmpty
                            ? widget.doctorName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
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
                          widget.doctorName,
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
                        const SizedBox(height: 6),
                        Text(
                          widget.orgName,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_rounded, color: _primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${_sharedFiles.length}',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Medical Records',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorInfoCard() {
    if (_doctorDetails == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _primaryColor.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medical_information_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Doctor Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildInfoRow(
              Icons.local_hospital_rounded,
              'Department',
              _getDoctorDepartment(),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(Icons.email_rounded, 'Email', _getDoctorEmail()),
            const SizedBox(height: 14),
            _buildInfoRow(Icons.phone_rounded, 'Contact', _getDoctorContact()),
            const SizedBox(height: 14),
            _buildInfoRow(
              Icons.calendar_today_rounded,
              'Since',
              _formatJoinDate(_doctorDetails?['created_at']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
            hintText: 'Search files or types',
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
            'Loading medical records...',
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

  Widget _buildFilesList() {
    final display = _filteredFiles;

    if (_isLoadingFiles) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3.5,
            ),
          ),
        ),
      );
    }

    if (display.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          icon: Icons.folder_open_rounded,
          title: _searchQuery.isEmpty ? 'No Records Yet' : 'No Files Found',
          subtitle:
              _searchQuery.isEmpty
                  ? 'Shared medical records will appear here'
                  : 'Try adjusting your search',
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.medical_services_rounded,
                    color: _primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Shared Medical Files',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${display.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _primaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Files List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: display.length,
              itemBuilder: (context, index) {
                final file = display[index];
                return AnimatedBuilder(
                  animation: _staggerController,
                  builder: (context, child) {
                    final progress = (_staggerController.value - (index * 0.06))
                        .clamp(0.0, 1.0);
                    return Opacity(
                      opacity: progress,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - progress)),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index == display.length - 1 ? 100 : 12,
                    ),
                    child: _buildFileCard(file),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final fileType = file['file_type'] ?? '';
    final fileColor = _getFileColor(fileType);
    final fileIcon = _getFileIcon(fileType);
    final fileName = file['filename'] ?? 'Unknown file';
    final sharedDate = _formatSharedDate(file['shared_at']);
    final canRemove = _canRemoveFile(file);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
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
                        const SizedBox(height: 20),
                        Text(
                          'Decrypting file...',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          );

          try {
            final fileMetadata = await OrgFilesDecryptService.getFileMetadata(
              file['id'],
            );

            if (fileMetadata == null) {
              throw Exception('File metadata not found');
            }

            final decryptedBytes =
                await OrgFilesDecryptService.decryptSharedFileSimple(
                  fileId: file['id'],
                  ipfsCid: fileMetadata['ipfs_cid'],
                );

            Navigator.of(context).pop();

            if (decryptedBytes == null) {
              throw Exception('Failed to decrypt file');
            }

            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => FullscreenFilePreview(
                      fileName: fileName,
                      bytes: decryptedBytes,
                    ),
              ),
            );
          } catch (e) {
            Navigator.of(context).pop();
            _showError('Error: ${e.toString()}');
          }
        },
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
                  color: fileColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: fileColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(fileIcon, color: fileColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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
                            color: fileColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: fileColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            fileType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: fileColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: _textSecondary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sharedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: _textSecondary.withOpacity(0.7),
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
                offset: const Offset(0, 8),
                onSelected: (value) {
                  if (value == 'info') {
                    _showFileInfo(file);
                  } else if (value == 'download') {
                    _downloadFile(file);
                  } else if (value == 'remove') {
                    _removeFileFromDoctor(file);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'info',
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
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Colors.blue[700],
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
                        value: 'download',
                        height: 48,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.download_rounded,
                                size: 16,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Download',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canRemove)
                        const PopupMenuItem(
                          value: 'remove',
                          height: 48,
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
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              child: Icon(icon, size: 56, color: _primaryColor),
            ),
            const SizedBox(height: 28),
            Text(
              title,
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
              subtitle,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
