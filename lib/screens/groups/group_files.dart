// group_files.dart
import 'package:flutter/material.dart';
import 'package:health_share/services/group_file_service.dart';
import 'package:health_share/functions/decrypt_view_file.dart';
import 'package:health_share/services/file_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupFilesScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final bool isOwner;

  const GroupFilesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isOwner,
  });

  @override
  State<GroupFilesScreen> createState() => _GroupFilesScreenState();
}

class _GroupFilesScreenState extends State<GroupFilesScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final GroupFileService _groupFileService = GroupFileService();
  List<Map<String, dynamic>> _groupFiles = [];
  bool _isLoading = true;

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
    _loadGroupFiles();
  }

  Future<void> _loadGroupFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _groupFileService.getGroupFiles(widget.groupId);
      setState(() {
        _groupFiles = files;
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
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.groupName} Files',
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              '${_groupFiles.length} shared files',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.grey[600]),
            onPressed: () => _showShareFileDialog(),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
            onPressed: _loadGroupFiles,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                opacity: _fadeAnimation,
                child:
                    _groupFiles.isEmpty
                        ? _buildEmptyState()
                        : _buildFilesList(),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.folder_shared_outlined,
                color: Colors.grey[400],
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No shared files yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your files with the group to get started',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showShareFileDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Share Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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

  Widget _buildFilesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20.0),
      itemCount: _groupFiles.length,
      itemBuilder: (context, index) {
        final fileShare = _groupFiles[index];
        final file = fileShare['Files'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildFileCard(fileShare, file),
        );
      },
    );
  }

  Widget _buildFileCard(
    Map<String, dynamic> fileShare,
    Map<String, dynamic> file,
  ) {
    final sharedByUser = fileShare['shared_by_user'] ?? {};
    final sharedByPerson = fileShare['shared_by_person'] ?? {};
    final sharedByName =
        '${sharedByPerson['first_name'] ?? ''} ${sharedByPerson['last_name'] ?? ''}'
            .trim();
    final sharedByEmail = sharedByUser['email'] ?? '';

    final currentUser = Supabase.instance.client.auth.currentUser;
    final isOwnFile = fileShare['shared_by'] == currentUser?.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _previewFile(file),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getFileColor(
                          file['file_type'],
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getFileIcon(file['file_type']),
                        color: _getFileColor(file['file_type']),
                        size: 22,
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
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatFileSize(file['file_size'] ?? 0)} • ${file['file_type'] ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwnFile || widget.isOwner)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                        onSelected: (value) {
                          if (value == 'unshare') {
                            _unshareFile(file['id']);
                          }
                        },
                        itemBuilder:
                            (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'unshare',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.remove_circle_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Unshare',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF667EEA).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(
                              sharedByPerson['first_name'],
                              sharedByPerson['last_name'],
                            ),
                            style: const TextStyle(
                              color: Color(0xFF667EEA),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared by ${sharedByName.isNotEmpty ? sharedByName : sharedByEmail}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              _formatDate(fileShare['shared_at']),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
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

  void _showShareFileDialog() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      final userFiles = await _groupFileService.getUserFilesForSharing(
        currentUser.id,
      );

      if (userFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You don\'t have any files to share. Upload some files first!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF667EEA).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.share,
                            color: Color(0xFF667EEA),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Share Files with Group',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: userFiles.length,
                      itemBuilder: (context, index) {
                        final file = userFiles[index];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getFileColor(
                                file['file_type'],
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getFileIcon(file['file_type']),
                              color: _getFileColor(file['file_type']),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            file['filename'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${_formatFileSize(file['file_size'])} • ${file['file_type']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.share,
                            color: Color(0xFF667EEA),
                          ),
                          onTap: () async {
                            try {
                              await _groupFileService.shareFileWithGroup(
                                fileId: file['id'],
                                groupId: widget.groupId,
                                userId: currentUser.id,
                              );

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${file['filename']} shared with group!',
                                  ),
                                  backgroundColor: const Color(0xFF11998E),
                                ),
                              );
                              _loadGroupFiles();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
    }
  }

  void _unshareFile(String fileId) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await _groupFileService.unshareFileFromGroup(
        fileId: fileId,
        groupId: widget.groupId,
        userId: currentUser.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File unshared from group'),
          backgroundColor: Color(0xFF11998E),
        ),
      );
      _loadGroupFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _previewFile(Map<String, dynamic> file) async {
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
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        Navigator.of(context).pop();
        return;
      }

      // For group files, we need to decrypt using group's private key
      // This requires extending the DecryptAndViewFileService to handle group files
      final decryptedBytes =
          await DecryptAndViewFileService.decryptFileFromIpfs(
            cid: file['ipfs_cid'],
            fileId: file['id'],
            userId: currentUser.id,
          );

      Navigator.of(context).pop(); // Close loading dialog

      if (decryptedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decrypt file'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Use enhanced preview service
      await EnhancedFilePreviewService.previewFile(
        context,
        file['filename'],
        decryptedBytes,
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper methods
  IconData _getFileIcon(String? fileType) {
    switch (fileType?.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
        return Icons.image;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'TXT':
        return Icons.text_snippet;
      case 'XLS':
      case 'XLSX':
        return Icons.table_chart;
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String? fileType) {
    switch (fileType?.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFE53E3E);
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
        return const Color(0xFF11998E);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF2B6CB0);
      case 'TXT':
        return const Color(0xFF38A169);
      case 'XLS':
      case 'XLSX':
        return const Color(0xFF22C35E);
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFF718096);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getInitials(String? firstName, String? lastName) {
    final first =
        firstName?.isNotEmpty == true ? firstName![0].toUpperCase() : '';
    final last = lastName?.isNotEmpty == true ? lastName![0].toUpperCase() : '';
    return '$first$last';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
