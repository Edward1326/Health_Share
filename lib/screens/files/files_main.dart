import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:health_share/services/files_services/file_preview.dart';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/files_services/file_picker_service.dart';
import 'package:health_share/services/files_services/upload_file.dart';
import 'package:health_share/services/files_services/decrypt_file.dart';
import 'package:health_share/services/crypto_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _selectedIndex = 1;
  Set<int> _selectedFiles = {}; // Track selected files
  bool _isSelectionMode = false;
  bool _isLoading = true; // Add loading state

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Add sort and filter options
  String _selectedFileType = 'All';
  String _sortBy = 'dateDesc'; // Options: dateDesc, dateAsc, nameAsc, nameDesc

  // List of available file types for filter
  final List<String> _fileTypes = [
    'All',
    'PDF',
    'IMAGE',
    'DOCUMENT',
    'TXT',
    'DOC',
    'DOCX',
  ];

  // Replace static items with real data from Supabase
  List<FileItem> items = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // Add this debug method to your _FilesScreenState class

  Future<void> _debugFileKeys(String fileId) async {
    try {
      final supabase = Supabase.instance.client;

      print('=== FILE KEYS DEBUG ===');
      print('File ID: $fileId');

      // Check all File_Keys entries for this file
      final allKeys = await supabase
          .from('File_Keys')
          .select('*')
          .eq('file_id', fileId);

      print('Total keys found: ${allKeys.length}');

      for (final key in allKeys) {
        print('Key entry:');
        print('  - Recipient Type: ${key['recipient_type']}');
        print('  - Recipient ID: ${key['recipient_id']}');
        print('  - Has encrypted key: ${key['aes_key_encrypted'] != null}');
        if (key['aes_key_encrypted'] != null) {
          print(
            '  - Key length: ${key['aes_key_encrypted'].toString().length}',
          );
        }
      }

      // Check File_Shares for this file
      final shares = await supabase
          .from('File_Shares')
          .select('*')
          .eq('file_id', fileId);

      print('File shares found: ${shares.length}');
      for (final share in shares) {
        print('Share entry:');
        print('  - Shared with group: ${share['shared_with_group_id']}');
        print('  - Shared by: ${share['shared_by_user_id']}');
        print('  - Shared at: ${share['shared_at']}');
        print('  - Revoked at: ${share['revoked_at']}');
      }

      print('=== END FILE KEYS DEBUG ===');
    } catch (e, stack) {
      print('Error in debug: $e');
      print(stack);
    }
  }

  // Also add this method to test the sharing process step by step
  Future<void> _testSharingProcess() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        print('No user logged in');
        return;
      }

      print('=== SHARING PROCESS TEST ===');

      // 1. Check user's RSA keys
      print('1. Checking user RSA keys...');
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key, rsa_public_key')
              .eq('id', user.id)
              .single();

      print('User has private key: ${userData['rsa_private_key'] != null}');
      print('User has public key: ${userData['rsa_public_key'] != null}');

      if (userData['rsa_private_key'] != null) {
        print(
          'Private key length: ${userData['rsa_private_key'].toString().length}',
        );
      }

      // 2. Check user's groups
      print('\n2. Checking user groups...');
      final userGroups = await supabase
          .from('Group_Members')
          .select('''
          group_id,
          role,
          Group!inner(id, name, rsa_public_key, rsa_private_key)
        ''')
          .eq('user_id', user.id);

      print('User is member of ${userGroups.length} groups');

      for (final membership in userGroups) {
        final group = membership['Group'];
        print('Group: ${group['name']} (${group['id']})');
        print('  - Role: ${membership['role']}');
        print('  - Has public key: ${group['rsa_public_key'] != null}');
        print('  - Has private key: ${group['rsa_private_key'] != null}');

        if (group['rsa_public_key'] != null) {
          print(
            '  - Public key length: ${group['rsa_public_key'].toString().length}',
          );
        }
      }

      // 3. Test encryption/decryption
      print('\n3. Testing encryption/decryption...');
      if (userGroups.isNotEmpty) {
        final testGroup = userGroups.first['Group'];
        final groupPublicKeyPem = testGroup['rsa_public_key'];
        final groupPrivateKeyPem = testGroup['rsa_private_key'];

        if (groupPublicKeyPem != null && groupPrivateKeyPem != null) {
          try {
            final groupPublicKey = CryptoUtils.rsaPublicKeyFromPem(
              groupPublicKeyPem,
            );
            final groupPrivateKey = CryptoUtils.rsaPrivateKeyFromPem(
              groupPrivateKeyPem,
            );

            final testData = '{"key":"test123","nonce":"test456"}';
            print('Test data: $testData');

            final encrypted = CryptoUtils.rsaEncrypt(testData, groupPublicKey);
            print('Encrypted length: ${encrypted.length}');

            final decrypted = CryptoUtils.rsaDecrypt(
              encrypted,
              groupPrivateKey,
            );
            print('Decrypted: $decrypted');
            print(
              'Encryption test: ${testData == decrypted ? "PASSED" : "FAILED"}',
            );
          } catch (cryptoError) {
            print('Crypto test failed: $cryptoError');
          }
        } else {
          print('Group missing RSA keys');
        }
      }

      print('=== END SHARING PROCESS TEST ===');
    } catch (e, stack) {
      print('Error in sharing process test: $e');
      print(stack);
    }
  }

  /// Load files from Supabase
  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final fileData = await DecryptFileService.fetchUserFiles(user.id);

      final loadedItems =
          fileData.map((file) {
            return FileItem(
              id: file['id'] as String, // Changed from int to String
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

      print('Loaded ${items.length} files from database');
    } catch (e) {
      print('Error loading files: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
      }
    }
  }

  /// Format file size in human readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get appropriate icon for file type
  IconData _getFileIcon(String fileType) {
    switch (fileType.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
      case 'IMAGE':
        return Icons.image;
      case 'DOC':
      case 'DOCX':
      case 'DOCUMENT':
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

  /// Get appropriate color for file type
  Color _getFileColor(String fileType) {
    switch (fileType.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFE53E3E);
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
      case 'IMAGE':
        return const Color(0xFF11998E);
      case 'DOC':
      case 'DOCX':
      case 'DOCUMENT':
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isSelectionMode ? '${_selectedFiles.length} Selected' : 'My Files',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareSelectedFiles,
              color: Colors.grey[700],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed:
                  () => setState(() {
                    _isSelectionMode = false;
                    _selectedFiles.clear();
                  }),
              color: Colors.grey[700],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFiles,
              color: Colors.grey[700],
            ),
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _uploadFile,
              color: Colors.grey[700],
            ),
          ],
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildSearchAndFilterBar(),
                  Expanded(
                    child:
                        items.isEmpty ? _buildEmptyState() : _buildFilesList(),
                  ),
                ],
              ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  // Update _buildFilesList to use filtered and sorted items
  Widget _buildFilesList() {
    final filteredItems = _filteredAndSortedItems;

    if (filteredItems.isEmpty) {
      return Center(
        child: Text(
          'No files match your search criteria',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isSelected = _selectedFiles.contains(index);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color:
                isSelected
                    ? const Color(0xFF667EEA).withOpacity(0.1)
                    : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap:
                  () =>
                      _isSelectionMode
                          ? _toggleFileSelection(index)
                          : _previewFile(item),
              onLongPress: () => _enableSelectionMode(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected
                            ? const Color(0xFF667EEA)
                            : Colors.grey.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                item.size,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(item.dateAdded),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleFileSelection(index),
                        activeColor: const Color(0xFF667EEA),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.upload_file_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No files yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload files to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _uploadFile,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload Files'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadFile() async {
    final success = await UploadFileService.uploadFile(context);

    // Refresh the file list if upload was successful
    if (success) {
      await _loadFiles(); // Reload files from database
    }
  }

  void _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final selectedItems =
        _selectedFiles.map((index) => _filteredAndSortedItems[index]).toList();

    await _showGroupSelectionDialog(selectedItems);
  }

  /// Show dialog to select groups for sharing files
  Future<void> _showGroupSelectionDialog(List<FileItem> filesToShare) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('User not logged in');
        return;
      }

      // Fetch user's groups
      final groupsResponse = await supabase
          .from('Group_Members')
          .select('''
            group_id,
            Group!inner(id, name)
          ''')
          .eq('user_id', user.id);

      final userGroups =
          groupsResponse
              .map(
                (item) => {
                  'id': item['Group']['id'],
                  'name': item['Group']['name'],
                },
              )
              .toList();

      if (userGroups.isEmpty) {
        _showError('You are not a member of any groups');
        return;
      }

      // Show group selection dialog
      final selectedGroups = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (BuildContext context) {
          return _GroupSelectionDialog(
            groups: userGroups,
            filesToShare: filesToShare,
          );
        },
      );

      if (selectedGroups != null && selectedGroups.isNotEmpty) {
        await _shareFilesToGroups(filesToShare, selectedGroups);
      }
    } catch (e) {
      _showError('Error loading groups: $e');
    }
  }

  /// Share selected files to selected groups - UPDATED for new encryption flow
  /// Share selected files to selected groups - FIXED for base64 encoding
  /// Share selected files to selected groups - FIXED for base64 encoding
  Future<void> _shareFilesToGroups(
    List<FileItem> filesToShare,
    List<Map<String, dynamic>> selectedGroups,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showError('User not logged in');
        return;
      }

      print('=== SHARING DEBUG ===');
      print('User ID: ${user.id}');
      print('Files to share: ${filesToShare.length}');
      print('Groups selected: ${selectedGroups.length}');

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
                  Text(
                    'Sharing ${filesToShare.length} file(s) to ${selectedGroups.length} group(s)...',
                  ),
                ],
              ),
            ),
      );

      // Get user's RSA private key for decrypting AES keys
      print('Fetching user RSA private key...');
      final userData =
          await supabase
              .from('User')
              .select('rsa_private_key')
              .eq('id', user.id)
              .single();

      final userRsaPrivateKeyPem = userData['rsa_private_key'] as String;
      print('User RSA key length: ${userRsaPrivateKeyPem.length}');

      final userRsaPrivateKey = MyCryptoUtils.rsaPrivateKeyFromPem(
        userRsaPrivateKeyPem,
      );
      print('RSA private key parsed successfully');

      for (final group in selectedGroups) {
        final groupId = group['id'] as String;
        final groupName = group['name'] as String;

        print('\n--- Processing group: $groupName ($groupId) ---');

        try {
          // Get group's RSA public key
          print('Fetching group RSA public key...');
          final groupData =
              await supabase
                  .from('Group')
                  .select('rsa_public_key')
                  .eq('id', groupId)
                  .single();

          final groupRsaPublicKeyPem = groupData['rsa_public_key'] as String;
          print('Group RSA key length: ${groupRsaPublicKeyPem.length}');

          final groupRsaPublicKey = MyCryptoUtils.rsaPublicKeyFromPem(
            groupRsaPublicKeyPem,
          );
          print('Group RSA public key parsed successfully');

          for (final file in filesToShare) {
            print('\n  Processing file: ${file.name} (${file.id})');

            try {
              // Get file's encrypted AES key package from user's File_Keys
              print('  Fetching user file key...');
              final userFileKey =
                  await supabase
                      .from('File_Keys')
                      .select('aes_key_encrypted')
                      .eq('file_id', file.id)
                      .eq('recipient_type', 'user')
                      .isFilter(
                        'recipient_id',
                        null,
                      ) // Add explicit user ID check
                      .single();

              final encryptedKeyPackage =
                  userFileKey['aes_key_encrypted'] as String;
              print(
                '  User file key retrieved, length: ${encryptedKeyPackage.length}',
              );

              // Decrypt the AES key package using user's RSA private key
              print('  Decrypting AES key package...');
              final decryptedKeyJson = MyCryptoUtils.rsaDecrypt(
                encryptedKeyPackage,
                userRsaPrivateKey,
              );
              print('  AES key decrypted successfully');

              // Re-encrypt the same JSON with group's RSA public key
              print('  Re-encrypting for group...');
              final groupEncryptedKeyPackage = MyCryptoUtils.rsaEncrypt(
                decryptedKeyJson,
                groupRsaPublicKey,
              );

              print(
                '  Group encryption successful, base64 length: ${groupEncryptedKeyPackage.length}',
              );

              print(
                '  Group encryption successful, base64 length: ${groupEncryptedKeyPackage.length}',
              );

              // Check if file is already shared with this group
              print('  Checking for existing share...');
              final existingShare =
                  await supabase
                      .from('File_Shares')
                      .select('id')
                      .eq('file_id', file.id)
                      .eq('shared_with_group_id', groupId)
                      .maybeSingle();

              if (existingShare == null) {
                print('  Creating new file share...');

                // Create file share record
                final shareResult =
                    await supabase.from('File_Shares').insert({
                      'file_id': file.id,
                      'shared_with_group_id': groupId,
                      'shared_by_user_id': user.id,
                      'shared_at': DateTime.now().toIso8601String(),
                    }).select();

                print('  File share created: ${shareResult.first['id']}');

                // Create group file key record with base64 encoded encrypted package
                print('  Creating group file key...');
                final keyResult =
                    await supabase.from('File_Keys').insert({
                      'file_id': file.id,
                      'recipient_type': 'group',
                      'recipient_id': groupId,
                      'aes_key_encrypted':
                          groupEncryptedKeyPackage, // Now base64 encoded
                    }).select();

                print('  Group file key created: ${keyResult.first}');
                print(
                  '  ✓ File ${file.name} shared successfully with $groupName',
                );
              } else {
                print('  File already shared with this group, skipping...');
              }
            } catch (fileError, fileStack) {
              print('  ❌ Error processing file ${file.name}: $fileError');
              print('  File stack trace: $fileStack');
              // Continue with next file instead of failing completely
            }
          }

          print('--- Completed group: $groupName ---');
        } catch (groupError, groupStack) {
          print('❌ Error processing group $groupName: $groupError');
          print('Group stack trace: $groupStack');
          // Continue with next group instead of failing completely
        }
      }

      Navigator.of(context).pop(); // Close loading dialog

      // Exit selection mode
      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });

      print('=== SHARING COMPLETED ===');
      _showSuccess(
        'Successfully shared ${filesToShare.length} file(s) to ${selectedGroups.length} group(s)',
      );
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR in _shareFilesToGroups: $e');
      print('Stack trace: $stackTrace');

      Navigator.of(context).pop(); // Close loading dialog
      _showError('Error sharing files: $e');
    }
  }

  // ADDITIONAL DEBUGGING METHOD TO CHECK USER'S GROUP MEMBERSHIP:
  Future<void> _debugGroupMembership() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        print('No user logged in');
        return;
      }

      print('=== GROUP MEMBERSHIP DEBUG ===');
      print('User ID: ${user.id}');

      // Check Group_Members table
      final membershipData = await supabase
          .from('Group_Members')
          .select('*')
          .eq('user_id', user.id);

      print('Group memberships found: ${membershipData.length}');
      for (final membership in membershipData) {
        print(
          '  - Group ID: ${membership['group_id']}, Role: ${membership['role']}',
        );
      }

      // Check actual groups
      final groupsResponse = await supabase
          .from('Group_Members')
          .select('''
          group_id,
          role,
          Group!inner(id, name, rsa_public_key)
        ''')
          .eq('user_id', user.id);

      print('Groups with details: ${groupsResponse.length}');
      for (final item in groupsResponse) {
        final group = item['Group'];
        print('  - Group: ${group['name']} (${group['id']})');
        print('    Role: ${item['role']}');
        print('    Has RSA key: ${group['rsa_public_key'] != null}');
        if (group['rsa_public_key'] != null) {
          print(
            '    RSA key length: ${group['rsa_public_key'].toString().length}',
          );
        }
      }
    } catch (e, stack) {
      print('Error debugging group membership: $e');
      print('Stack trace: $stack');
    }
  }

  void _previewFile(FileItem item) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in')));
        return;
      }

      print('Starting decryption for file: ${item.name}');
      print('File ID: ${item.id}, IPFS CID: ${item.ipfsCid}');

      // Use the new DecryptFileService
      final decryptedBytes = await DecryptFileService.decryptFileFromIpfs(
        cid: item.ipfsCid,
        fileId: item.id,
        userId: user.id,
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

      print(
        'Successfully decrypted file. Size: ${decryptedBytes.length} bytes',
      );

      // Verify decrypted data is not empty
      if (decryptedBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Decrypted file is empty'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Use enhanced preview service
      await EnhancedFilePreviewService.previewFile(
        context,
        item.name,
        decryptedBytes,
      );
    } catch (e, stackTrace) {
      Navigator.of(context).pop(); // Close loading dialog
      print('Error in _previewFile: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
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
        if (_selectedFiles.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFiles.add(index);
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Filter and sort files
  List<FileItem> get _filteredAndSortedItems {
    List<FileItem> filtered = items;

    // Apply search query
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

    // Apply file type filter
    if (_selectedFileType != 'All') {
      filtered =
          filtered
              .where(
                (file) =>
                    file.type.toUpperCase() == _selectedFileType.toUpperCase(),
              )
              .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'dateDesc':
        filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case 'dateAsc':
        filtered.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case 'nameAsc':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'nameDesc':
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return filtered;
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter and Sort Options
          Row(
            children: [
              // File Type Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFileType,
                      items:
                          _fileTypes.map((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedFileType = newValue;
                          });
                        }
                      },
                      hint: const Text('File Type'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort Options
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'dateDesc',
                          child: Text('Newest First'),
                        ),
                        DropdownMenuItem(
                          value: 'dateAsc',
                          child: Text('Oldest First'),
                        ),
                        DropdownMenuItem(
                          value: 'nameAsc',
                          child: Text('Name A-Z'),
                        ),
                        DropdownMenuItem(
                          value: 'nameDesc',
                          child: Text('Name Z-A'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortBy = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF667EEA),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class FileItem {
  final String id; // Changed from int to String
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

/// Dialog widget for selecting groups to share files with
class _GroupSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> groups;
  final List<FileItem> filesToShare;

  const _GroupSelectionDialog({
    required this.groups,
    required this.filesToShare,
  });

  @override
  State<_GroupSelectionDialog> createState() => __GroupSelectionDialogState();
}

class __GroupSelectionDialogState extends State<_GroupSelectionDialog> {
  final Set<String> _selectedGroupIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Share ${widget.filesToShare.length} file(s) with groups'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select the groups you want to share these files with:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.groups.length,
                itemBuilder: (context, index) {
                  final group = widget.groups[index];
                  final groupId = group['id'] as String;
                  final isSelected = _selectedGroupIds.contains(groupId);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedGroupIds.add(groupId);
                        } else {
                          _selectedGroupIds.remove(groupId);
                        }
                      });
                    },
                    title: Text(
                      group['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    activeColor: const Color(0xFF667EEA),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed:
              _selectedGroupIds.isEmpty
                  ? null
                  : () {
                    final selectedGroups =
                        widget.groups
                            .where(
                              (group) =>
                                  _selectedGroupIds.contains(group['id']),
                            )
                            .toList();
                    Navigator.pop(context, selectedGroups);
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667EEA),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Share with ${_selectedGroupIds.length} group(s)'),
        ),
      ],
    );
  }
}
