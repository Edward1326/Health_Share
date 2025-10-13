import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:health_share/services/files_services/fullscreen_file_preview.dart';
import 'package:health_share/services/org_services/org_files_decrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import services
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
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _doctorDetails;
  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoading = false;
  bool _isLoadingFiles = false;

  final Color _primaryColor = const Color(0xFF416240);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();

    _fetchDoctorDetails();
    _fetchSharedFiles();
  }

  Future<void> _fetchDoctorDetails() async {
    setState(() => _isLoading = true);

    try {
      final doctorDetails = await OrgDoctorService.fetchDoctorDetails(
        widget.doctorId,
      );

      setState(() {
        _doctorDetails = doctorDetails;
      });

      print('DEBUG: Successfully loaded doctor details');
    } catch (e, stackTrace) {
      print('DEBUG: Error in _fetchDoctorDetails: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading doctor details: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSharedFiles() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      print('❌ No current user found');
      return;
    }

    setState(() => _isLoadingFiles = true);

    try {
      final sharedFiles = await OrgFilesService.fetchSharedFiles(
        currentUser.id,
        widget.doctorId,
      );

      setState(() {
        _sharedFiles = sharedFiles;
      });

      print('✅ Successfully loaded ${_sharedFiles.length} shared files');
    } catch (e, stackTrace) {
      print('❌ ERROR in _fetchSharedFiles: $e');
      print('Stack trace: $stackTrace');
      setState(() => _sharedFiles = []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shared files: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoadingFiles = false);
    }
  }

  // ===== UI HELPER METHODS =====

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
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
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
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
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: _primaryColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    widget.orgName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white.withOpacity(0.15),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.white.withOpacity(0.15),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () async {
                      await _fetchDoctorDetails();
                      await _fetchSharedFiles();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text('Refreshed successfully'),
                              ],
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: _primaryColor,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child:
                  _isLoading
                      ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildDoctorInfoCard(),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildFilesSection(),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfoCard() {
    if (_doctorDetails == null) return const SizedBox.shrink();

    final doctorName = widget.doctorName;
    final initialChar =
        doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initialChar,
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getDoctorDepartment(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: const Color(0xFFF1F5F9),
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(Icons.email_outlined, _getDoctorEmail()),
                const SizedBox(height: 14),
                _buildInfoRow(Icons.phone_outlined, _getDoctorContact()),
                const SizedBox(height: 14),
                _buildInfoRow(
                  Icons.calendar_today_outlined,
                  'Since ${_formatJoinDate(_doctorDetails?['created_at'])}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 24, color: _primaryColor),
              const SizedBox(width: 10),
              const Text(
                'Medical Records',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingFiles
            ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(
                  color: _primaryColor,
                  strokeWidth: 2.5,
                ),
              ),
            )
            : _sharedFiles.isEmpty
            ? _buildEmptyFilesState()
            : _buildFilesList(),
      ],
    );
  }

  Widget _buildFilesList() {
    return Column(
      children: List.generate(_sharedFiles.length, (index) {
        final file = _sharedFiles[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildFileCard(file, index),
        );
      }),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file, int index) {
    final fileType = file['file_type'] ?? '';
    final fileColor = _getFileColor(fileType);
    final fileIcon = _getFileIcon(fileType);
    final fileName = file['filename'] ?? 'Unknown file';
    final fileSize = _formatFileSize(file['file_size'] ?? 0);
    final sharedDate = _formatSharedDate(file['shared_at']);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: _primaryColor,
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Decrypting file...',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _primaryColor,
                              fontSize: 15,
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red[700],
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: fileColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(fileIcon, color: fileColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                            height: 1.3,
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
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: fileColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                fileType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: fileColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fileSize,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sharedDate,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: const Color(0xFFCBD5E1),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: _primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No records yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shared medical records will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
