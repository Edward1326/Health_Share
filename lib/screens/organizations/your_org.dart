import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:health_share/services/files_services/decrypt_file.dart';
import 'package:health_share/services/files_services/file_preview.dart';
import 'package:health_share/services/org_services/org_file_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class YourOrgDetailsScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const YourOrgDetailsScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<YourOrgDetailsScreen> createState() => _YourOrgDetailsScreenState();
}

class _YourOrgDetailsScreenState extends State<YourOrgDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoadingDoctors = false;
  bool _isLoadingFiles = false;

  Map<String, dynamic>? _organizationDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    _loadOrganizationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Helper function to format full name from Person data within User
  String _formatFullName(Map<String, dynamic> user) {
    // Access Person data nested within User
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

    if (nameParts.isEmpty) {
      return user['email'] ?? 'Unknown User';
    }

    return nameParts.join(' ');
  }

  Future<void> _loadOrganizationData() async {
    await Future.wait([
      _loadOrganizationDetails(),
      _loadDoctors(),
      _loadSharedFiles(),
    ]);
  }

  Future<void> _loadOrganizationDetails() async {
    try {
      final response =
          await Supabase.instance.client
              .from('Organization')
              .select('*')
              .eq('id', widget.orgId)
              .single();

      setState(() {
        _organizationDetails = response;
      });
    } catch (e) {
      print('Error loading organization details: $e');
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoadingDoctors = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Use OrgFileService to get assigned doctors
      final doctors = await OrgFileService.getAssignedDoctors(
        widget.orgId,
        currentUser.id,
      );

      setState(() {
        _doctors = doctors;
        _isLoadingDoctors = false;
      });

      print('Loaded ${_doctors.length} doctors for this organization');
    } catch (e) {
      print('Error loading doctors: $e');
      setState(() => _isLoadingDoctors = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading doctors: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSharedFiles() async {
    setState(() => _isLoadingFiles = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Use OrgFileService to fetch doctor files for patient
      final files = await OrgFileService.fetchDoctorFilesForPatient(
        widget.orgId,
        currentUser.id,
      );

      setState(() {
        _sharedFiles = files;
        _isLoadingFiles = false;
      });

      print('Loaded ${_sharedFiles.length} files from doctors');
    } catch (e) {
      print('Error loading shared files: $e');
      setState(() => _isLoadingFiles = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _previewFile(Map<String, dynamic> file) async {
    try {
      print('=== Starting enhanced file preview process ===');
      print('File: ${file['filename']}');
      print('File ID: ${file['id']}');
      print('IPFS CID: ${file['ipfs_cid']}');
      print('Organization ID: ${widget.orgId}');

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        print('ERROR: No authenticated user');
        return;
      }

      print('Auth user email: ${currentUser.email}');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get current user ID from database
      print('Fetching user ID from database...');
      final userResponse =
          await Supabase.instance.client
              .from('User')
              .select('id')
              .eq('email', currentUser.email!)
              .single();

      final userId = userResponse['id'];
      print('Database user ID: $userId');

      // Check if patient has access to this doctor's file
      final hasAccess = await OrgFileService.hasPatientDoctorFileAccess(
        file['id'],
        widget.orgId,
        userId,
      );

      print('Has patient-doctor file access: $hasAccess');

      if (!hasAccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You do not have access to this file. Please contact your doctor.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Use the enhanced decryption method
      final decryptedBytes = await OrgFileService.decryptOrgSharedFileEnhanced(
        fileId: file['id'],
        orgId: widget.orgId,
        userId: userId,
        ipfsCid: file['ipfs_cid'],
      );

      Navigator.of(context).pop();

      if (decryptedBytes != null) {
        print('Enhanced decryption successful, opening preview...');
        await EnhancedFilePreviewService.previewFile(
          context,
          file['filename'],
          decryptedBytes,
        );
      } else {
        print('All enhanced decryption attempts failed');

        // Provide detailed error message based on what we know
        String errorMessage = 'Failed to decrypt file. ';

        // Check what keys exist to provide better error message
        final userFileKey =
            await Supabase.instance.client
                .from('File_Keys')
                .select('id')
                .eq('file_id', file['id'])
                .eq('recipient_type', 'user')
                .eq('recipient_id', userId)
                .maybeSingle();

        final orgFileKey =
            await Supabase.instance.client
                .from('File_Keys')
                .select('id')
                .eq('file_id', file['id'])
                .eq('recipient_type', 'organization')
                .eq('recipient_id', widget.orgId)
                .maybeSingle();

        if (userFileKey == null && orgFileKey == null) {
          errorMessage +=
              'Access keys are missing. Please ask your doctor to reshare this file.';
        } else {
          errorMessage += 'Decryption keys may be corrupted or incompatible.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Contact Support',
              textColor: Colors.white,
              onPressed: () {
                // You can implement support contact functionality here
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      Navigator.of(context).pop();
      print('ERROR in _previewFile: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String? dateString) {
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
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.description;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.orgName,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Your Organization',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadOrganizationData,
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18),
                      const SizedBox(width: 8),
                      Text('Members'),
                      if (_doctors.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_doctors.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_shared, size: 18),
                      const SizedBox(width: 8),
                      Text('Files'),
                      if (_sharedFiles.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_sharedFiles.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [_buildMembersTab(), _buildFilesTab()],
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_isLoadingDoctors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.people_outline,
                  color: Colors.grey[400],
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No doctors assigned',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You don\'t have any assigned doctors from this organization yet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        final user = doctor['User'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatFullName(user),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Doctor',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? 'No email',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (doctor['department'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          doctor['department'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Assigned ${_formatDate(doctor['assigned_at'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    if (_isLoadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sharedFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.folder_open,
                  color: Colors.grey[400],
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No files shared',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your doctors haven\'t shared any files with you yet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _sharedFiles.length,
      itemBuilder: (context, index) {
        final file = _sharedFiles[index];
        final uploader = file['User'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _previewFile(file),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getFileIcon(file['file_type']),
                        color: Colors.orange[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file['filename'] ?? 'Unknown file',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.medical_services,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Dr. ${_formatFullName(uploader)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _formatFileSize(file['file_size']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(file['uploaded_at']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.visibility,
                        color: Colors.grey[600],
                        size: 16,
                      ),
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
}
