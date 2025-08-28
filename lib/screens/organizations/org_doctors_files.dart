import 'package:flutter/material.dart';
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
  // Add this to your _OrgDoctorsFilesScreenState class

  List<Map<String, dynamic>> _sharedFiles = [];
  bool _isLoadingFiles = false;

  Future<void> _fetchSharedFiles() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingFiles = true);

    try {
      final doctorId = widget.doctorId;
      final doctorName = widget.doctorName;

      print(
        'DEBUG: Fetching shared files between doctor $doctorId and current user',
      );

      // Get current user's database ID
      final userResponse =
          await Supabase.instance.client
              .from('User')
              .select('id')
              .eq('email', currentUser.email!)
              .single();

      final userId = userResponse['id'];
      print('DEBUG: Current user ID: $userId');

      // Get patient record for current user
      final patientResponse =
          await Supabase.instance.client
              .from('Patient')
              .select('id')
              .eq('user_id', userId)
              .single();

      final patientId = patientResponse['id'];
      print('DEBUG: Patient ID: $patientId');

      // Get doctor's user ID from Organization_User
      final doctorResponse =
          await Supabase.instance.client
              .from('Organization_User')
              .select('User!inner(id)')
              .eq('id', doctorId)
              .single();

      final doctorUserId = doctorResponse['User']['id'];
      print('DEBUG: Doctor user ID: $doctorUserId');

      // Query File_Shares to get files shared between doctor and patient
      // Using separate queries for better control and debugging

      // Query 1: Files shared by doctor to patient
      final doctorToPatientShares = await Supabase.instance.client
          .from('File_Shares')
          .select('''
          id,
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

      print('DEBUG: Doctor to patient shares: $doctorToPatientShares');

      // Query 2: Files shared by patient to doctor
      final patientToDoctorShares = await Supabase.instance.client
          .from('File_Shares')
          .select('''
          id,
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

      print('DEBUG: Patient to doctor shares: $patientToDoctorShares');

      // Query 3: Files shared with doctor directly (using shared_with_doctor field)
      final directDoctorShares = await Supabase.instance.client
          .from('File_Shares')
          .select('''
          id,
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
          .eq('shared_with_doctor', doctorId)
          .isFilter('revoked_at', null);

      print('DEBUG: Direct doctor shares: $directDoctorShares');

      // Combine all share results
      final allShares = [
        ...doctorToPatientShares,
        ...patientToDoctorShares,
        ...directDoctorShares,
      ];

      // Process the results to get unique files with sharing context
      final Map<String, Map<String, dynamic>> uniqueFiles = {};

      for (final share in allShares) {
        final file = share['Files'];
        final fileId = file['id'];

        if (!uniqueFiles.containsKey(fileId)) {
          // Determine sharing context
          String sharedBy;
          String sharedWith;

          if (share['shared_by_user_id'] == doctorUserId) {
            sharedBy = doctorName;
            sharedWith = 'You';
          } else if (share['shared_by_user_id'] == userId) {
            sharedBy = 'You';
            sharedWith = doctorName;
          } else {
            // Shared with doctor directly
            sharedBy = 'You';
            sharedWith = doctorName;
          }

          uniqueFiles[fileId] = {
            ...file,
            'share_id': share['id'],
            'shared_at': share['shared_at'],
            'shared_by': sharedBy,
            'shared_with': sharedWith,
          };
        }
      }

      final filesList = uniqueFiles.values.toList();

      // Sort by most recently shared first
      filesList.sort((a, b) {
        final dateA = DateTime.parse(a['shared_at']);
        final dateB = DateTime.parse(b['shared_at']);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _sharedFiles = filesList;
      });

      print('DEBUG: Successfully loaded ${_sharedFiles.length} shared files');
    } catch (e, stackTrace) {
      print('DEBUG: Error in _fetchSharedFiles: $e');
      print('DEBUG: Stack trace: $stackTrace');
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Doctor information refreshed'),
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

  // Replace the existing _buildFilesSection() method with this updated version

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
          onTap: () {
            // TODO: Implement file preview/download
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File preview coming soon'),
                duration: Duration(seconds: 2),
              ),
            );
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

  Widget _buildComingSoonCard() {
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
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 48,
              color: Colors.blue[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Files Coming Soon',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'File sharing and management features will be available here soon. You\'ll be able to view prescriptions, lab results, and other medical documents shared by your doctor.',
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
