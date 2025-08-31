import 'package:flutter/material.dart';
import 'package:health_share/services/files_services/file_preview.dart';
import 'package:health_share/services/org_services/files_decrypt_org.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    // Fetch both doctor details and shared files
    _fetchDoctorDetails();
    _fetchSharedFiles();
  }

  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoadingFiles = false;

  //-------------------------------------------------------------------------------------------------------------------------------
  Future<void> _fetchSharedFiles() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      print('❌ No current user found');
      return;
    }

    setState(() => _isLoadingFiles = true);

    try {
      print('=== ENHANCED DEBUG FETCH SHARED FILES ===');
      print('Current user: ${currentUser.email}');
      print('Doctor ID from widget: ${widget.doctorId}');
      print('Doctor name: ${widget.doctorName}');

      // STEP 1: Get current user's database ID
      print('\n--- Step 1: Fetching user data ---');
      final userResponse =
          await Supabase.instance.client
              .from('User')
              .select('id, email')
              .eq('email', currentUser.email!)
              .maybeSingle();

      if (userResponse == null) {
        throw Exception('User not found in database: ${currentUser.email}');
      }

      final userId = userResponse['id'] as String;
      print('✓ User ID: $userId');

      // STEP 2: Get patient record
      print('\n--- Step 2: Fetching patient data ---');
      final patientResponse =
          await Supabase.instance.client
              .from('Patient')
              .select('id, user_id')
              .eq('user_id', userId)
              .maybeSingle();

      if (patientResponse == null) {
        print('❌ No patient record found for user: $userId');
        setState(() => _sharedFiles = []);
        return;
      }

      final patientId = patientResponse['id'] as String;
      print('✓ Patient ID: $patientId');

      // STEP 3: Get doctor's user ID from Organization_User
      print('\n--- Step 3: Fetching doctor user data ---');
      final doctorOrgResponse =
          await Supabase.instance.client
              .from('Organization_User')
              .select('user_id, position, department')
              .eq('id', widget.doctorId)
              .maybeSingle();

      if (doctorOrgResponse == null) {
        throw Exception('Doctor not found: ${widget.doctorId}');
      }

      final doctorUserId = doctorOrgResponse['user_id'] as String;
      print('✓ Doctor user ID: $doctorUserId');
      print('✓ Doctor position: ${doctorOrgResponse['position']}');

      // STEP 4: Get all shared files using multiple approaches
      print('\n--- Step 4: Querying shared files (comprehensive approach) ---');

      final Map<String, Map<String, dynamic>> allUniqueFiles = {};

      // Approach 1: Direct doctor shares (shared_with_doctor field)
      print('  Approach 1: Files shared directly to doctor...');
      final directDoctorShares = await Supabase.instance.client
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            revoked_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id,
              filename,
              file_type,
              file_size,
              category,
              uploaded_at,
              sha256_hash
            )
          ''')
          .eq('shared_with_doctor', doctorUserId)
          .isFilter('revoked_at', null);

      print('    Found ${directDoctorShares.length} direct doctor shares');
      _processShares(directDoctorShares, allUniqueFiles, userId, doctorUserId);

      // Approach 2: User-to-user shares (patient to doctor)
      print('  Approach 2: Patient to doctor user shares...');
      final patientToDoctorShares = await Supabase.instance.client
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            revoked_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id,
              filename,
              file_type,
              file_size,
              category,
              uploaded_at,
              sha256_hash
            )
          ''')
          .eq('shared_by_user_id', userId)
          .eq('shared_with_user_id', doctorUserId)
          .isFilter('revoked_at', null);

      print(
        '    Found ${patientToDoctorShares.length} patient-to-doctor shares',
      );
      _processShares(
        patientToDoctorShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // Approach 3: Doctor-to-patient shares
      print('  Approach 3: Doctor to patient user shares...');
      final doctorToPatientShares = await Supabase.instance.client
          .from('File_Shares')
          .select('''
            id,
            file_id,
            shared_at,
            revoked_at,
            shared_by_user_id,
            shared_with_user_id,
            shared_with_doctor,
            Files!inner(
              id,
              filename,
              file_type,
              file_size,
              category,
              uploaded_at,
              sha256_hash
            )
          ''')
          .eq('shared_by_user_id', doctorUserId)
          .eq('shared_with_user_id', userId)
          .isFilter('revoked_at', null);

      print(
        '    Found ${doctorToPatientShares.length} doctor-to-patient shares',
      );
      _processShares(
        doctorToPatientShares,
        allUniqueFiles,
        userId,
        doctorUserId,
      );

      // Approach 4: Check for files where current user has access via File_Keys
      // and doctor also has access (indicating shared files)
      print('  Approach 4: Cross-referencing File_Keys...');

      // Get all files the current user has access to
      final userFileKeys = await Supabase.instance.client
          .from('File_Keys')
          .select('file_id')
          .eq('recipient_type', 'user')
          .eq('recipient_id', userId);

      final userFileIds =
          userFileKeys.map((fk) => fk['file_id'] as String).toList();
      print('    Current user has access to ${userFileIds.length} files');

      if (userFileIds.isNotEmpty) {
        // Check which of these files the doctor also has access to
        final doctorFileKeys = await Supabase.instance.client
            .from('File_Keys')
            .select('file_id')
            .eq('recipient_type', 'user')
            .eq('recipient_id', doctorUserId)
            .inFilter('file_id', userFileIds);

        final sharedFileIds =
            doctorFileKeys.map((fk) => fk['file_id'] as String).toList();
        print(
          '    Doctor also has access to ${sharedFileIds.length} of these files',
        );

        if (sharedFileIds.isNotEmpty) {
          // Get the file details for these shared files
          final sharedFilesDetails = await Supabase.instance.client
              .from('Files')
              .select('''
                id,
                filename,
                file_type,
                file_size,
                category,
                uploaded_at,
                sha256_hash
              ''')
              .inFilter('id', sharedFileIds);

          // For files found via File_Keys, we need to determine sharing direction
          for (final file in sharedFilesDetails) {
            final fileId = file['id'] as String;
            if (!allUniqueFiles.containsKey(fileId)) {
              // Try to find the sharing record to determine direction
              final shareRecord =
                  await Supabase.instance.client
                      .from('File_Shares')
                      .select(
                        'shared_by_user_id, shared_with_user_id, shared_at, shared_with_doctor',
                      )
                      .eq('file_id', fileId)
                      .or(
                        'shared_by_user_id.eq.$userId,shared_with_user_id.eq.$userId,shared_with_doctor.eq.$doctorUserId',
                      )
                      .isFilter('revoked_at', null)
                      .limit(1)
                      .maybeSingle();

              String sharedBy = 'Unknown';
              String sharedWith = 'Unknown';
              String sharedAt = DateTime.now().toIso8601String();

              if (shareRecord != null) {
                sharedAt = shareRecord['shared_at'] ?? sharedAt;

                if (shareRecord['shared_with_doctor'] == doctorUserId) {
                  sharedBy = 'You';
                  sharedWith = widget.doctorName;
                } else if (shareRecord['shared_by_user_id'] == userId) {
                  sharedBy = 'You';
                  sharedWith = widget.doctorName;
                } else if (shareRecord['shared_by_user_id'] == doctorUserId) {
                  sharedBy = widget.doctorName;
                  sharedWith = 'You';
                }
              }

              allUniqueFiles[fileId] = {
                ...file,
                'shared_at': sharedAt,
                'shared_by': sharedBy,
                'shared_with': sharedWith,
              };

              print(
                '    ✓ Added via File_Keys: ${file['filename']} (Shared by: $sharedBy)',
              );
            }
          }
        }
      }

      // STEP 5: Sort and set state
      final filesList = allUniqueFiles.values.toList();
      filesList.sort((a, b) {
        final dateA = DateTime.parse(a['shared_at']);
        final dateB = DateTime.parse(b['shared_at']);
        return dateB.compareTo(dateA);
      });

      print('\n--- Final Results ---');
      print('Total unique files found: ${filesList.length}');
      for (final file in filesList) {
        print('  • ${file['filename']} (Shared by: ${file['shared_by']})');
      }

      setState(() {
        _sharedFiles = filesList;
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
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingFiles = false);
    }
  }

  // Helper method to process shares and avoid duplicates
  void _processShares(
    List<Map<String, dynamic>> shares,
    Map<String, Map<String, dynamic>> allUniqueFiles,
    String userId,
    String doctorUserId,
  ) {
    for (final share in shares) {
      final file = share['Files'];
      if (file == null) {
        print('    ⚠️  Skipping share with null file data');
        continue;
      }

      final fileId = file['id'] as String;

      if (!allUniqueFiles.containsKey(fileId)) {
        // Determine sharing context
        String sharedBy;
        String sharedWith;

        if (share['shared_with_doctor'] == doctorUserId) {
          // Direct doctor share
          sharedBy = 'You';
          sharedWith = widget.doctorName;
        } else if (share['shared_by_user_id'] == doctorUserId) {
          // Doctor shared to patient
          sharedBy = widget.doctorName;
          sharedWith = 'You';
        } else if (share['shared_by_user_id'] == userId) {
          // Patient shared to doctor
          sharedBy = 'You';
          sharedWith = widget.doctorName;
        } else {
          // Fallback
          sharedBy = 'Unknown';
          sharedWith = 'Unknown';
        }

        allUniqueFiles[fileId] = {
          ...file,
          'share_id': share['id'],
          'shared_at': share['shared_at'],
          'shared_by': sharedBy,
          'shared_with': sharedWith,
        };

        print('    ✓ Added file: ${file['filename']} (Shared by: $sharedBy)');
      }
    }
  }

  //-------------------------------------------------------------------------------------------------------------------------------
  // Helper function to format file size
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

  // Helper function to get file icon
  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Helper function to get file color
  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'txt':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  // Helper function to format shared date
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
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  Future<void> _fetchDoctorDetails() async {
    setState(() => _isLoading = true);

    try {
      print('DEBUG: Fetching doctor details for doctor ID: ${widget.doctorId}');

      // Get detailed doctor information
      final response =
          await Supabase.instance.client
              .from('Organization_User')
              .select('''
            id,
            position,
            department,
            created_at,
            User!inner(
              id,
              email,
              Person(
                first_name,
                last_name,
                contact_number,
                sex
              )
            )
          ''')
              .eq('id', widget.doctorId)
              .eq('position', 'Doctor')
              .single();

      print('DEBUG: Doctor details response: $response');

      setState(() {
        _doctorDetails = response;
      });

      print('DEBUG: Successfully loaded doctor details');
    } catch (e, stackTrace) {
      print('DEBUG: Error in _fetchDoctorDetails: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading doctor details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: Colors.grey[600], size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.doctorName,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              widget.orgName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () async {
                await _fetchDoctorDetails();
                await _fetchSharedFiles(); // Also refresh files
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Information refreshed'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icon(Icons.refresh, color: Colors.grey[600], size: 22),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDoctorInfoCard(),
                      const SizedBox(height: 24),
                      _buildFilesSection(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildDoctorInfoCard() {
    if (_doctorDetails == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    color: Colors.blue[600],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.doctorName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getDoctorDepartment(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.email, 'Email', _getDoctorEmail()),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.phone, 'Contact', _getDoctorContact()),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.calendar_today,
              'Joined',
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
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[600]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared Medical Files',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Files shared between you and ${widget.doctorName}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () async {
                  await _fetchSharedFiles();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Files refreshed'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.refresh, color: Colors.grey[600], size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _isLoadingFiles
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
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
      children: [
        // Files count header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.folder, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '${_sharedFiles.length} shared file${_sharedFiles.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Files list
        ...List.generate(_sharedFiles.length, (index) {
          final file = _sharedFiles[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFileCard(file),
          );
        }),
      ],
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final fileType = file['file_type'] ?? '';
    final fileColor = _getFileColor(fileType);
    final fileIcon = _getFileIcon(fileType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // In OrgDoctorsFilesScreen, update the _buildFileCard method's InkWell onTap:
          onTap: () async {
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
                        Text('Decrypting ${file['filename']}...'),
                      ],
                    ),
                  ),
            );

            try {
              // Get file metadata if needed
              final fileMetadata = await OrgFilesDecryptService.getFileMetadata(
                file['id'],
              );

              if (fileMetadata == null) {
                throw Exception('File metadata not found');
              }

              // Decrypt the file
              final decryptedBytes =
                  await OrgFilesDecryptService.decryptSharedFileSimple(
                    fileId: file['id'],
                    ipfsCid: fileMetadata['ipfs_cid'],
                  );

              Navigator.of(context).pop(); // Close loading dialog

              if (decryptedBytes == null) {
                throw Exception('Failed to decrypt file');
              }

              // Use your existing preview service
              await EnhancedFilePreviewService.previewFile(
                context,
                file['filename'],
                decryptedBytes,
              );
            } catch (e) {
              Navigator.of(context).pop(); // Close loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening file: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // File icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(fileIcon, color: fileColor, size: 24),
                ),
                const SizedBox(width: 16),
                // File details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file['filename'] ?? 'Unknown file',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              fileType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatFileSize(file['file_size'] ?? 0),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            file['shared_by'] == 'You'
                                ? Icons.upload
                                : Icons.download,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Shared by ${file['shared_by']} • ${_formatSharedDate(file['shared_at'])}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      if (file['category'] != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            file['category'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Action arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Shared Files Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No files have been shared between you and ${widget.doctorName} yet. Files will appear here once they are shared.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureChip('Prescriptions', Icons.medication),
              const SizedBox(width: 12),
              _buildFeatureChip('Lab Results', Icons.science),
              const SizedBox(width: 12),
              _buildFeatureChip('Reports', Icons.description),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
