import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:basic_utils/basic_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:health_share/screens/navbar/navbar_main.dart';
import 'package:health_share/services/aes_helper.dart';
import 'package:health_share/services/file_picker_service.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _selectedIndex = 1;
  Set<int> _selectedFiles = {}; // Track selected files
  bool _isSelectionMode = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Add sort and filter options
  String _selectedFileType = 'All';
  String _sortBy = 'dateDesc'; // Options: dateDesc, dateAsc, nameAsc, nameDesc

  // List of available file types for filter
  final List<String> _fileTypes = ['All', 'PDF', 'Image', 'Document'];

  List<FileItem> items = [
    FileItem(
      name: 'medical_report.pdf',
      type: 'PDF',
      size: '2.4 MB',
      icon: Icons.picture_as_pdf,
      color: const Color(0xFFE53E3E),
      dateAdded: DateTime.now(),
    ),
    FileItem(
      name: 'xray_result.jpg',
      type: 'Image',
      size: '1.8 MB',
      icon: Icons.image,
      color: const Color(0xFF11998E),
      dateAdded: DateTime.now().subtract(const Duration(days: 1)),
    ),
    // Add more sample files as needed
  ];

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
              icon: const Icon(Icons.upload),
              onPressed: _uploadFile,
              color: Colors.grey[700],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: items.isEmpty ? _buildEmptyState() : _buildFilesList(),
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
    // 1. Pick a file
    final file = await FilePickerService.pickFile();
    if (file == null) return;

    final fileBytes = await file.readAsBytes();
    final fileName = file.path.split('/').last;
    final fileType = fileName.split('.').last.toUpperCase();

    // 2. Generate a random AES key and IV for this file
    final aesKey = encrypt.Key.fromSecureRandom(32); // 32 bytes for AES-256
    final aesIv = encrypt.IV.fromSecureRandom(16); // 16 bytes for AES CBC

    // 3. Encrypt the file - Fix: Use proper hex strings
    final aesHelper = AESHelper(aesKey.base16, aesIv.base16);
    final encryptedBytes = aesHelper.encryptData(fileBytes);

    // 4. Get current user and their RSA public key from Supabase
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not logged in!')));
      }
      return;
    }

    try {
      final userData =
          await supabase
              .from('User')
              .select('rsa_public_key, id')
              .eq('id', user.id)
              .single();
      final rsaPublicKeyPem = userData['rsa_public_key'] as String;
      final rsaPublicKey = CryptoUtils.rsaPublicKeyFromPem(rsaPublicKeyPem);

      // 5. Encrypt the AES key with RSA - Fix: Use proper types
      final aesKeyBase64 = base64Encode(
        aesKey.bytes,
      ); // Convert to String first
      final rsaEncryptedBytes = CryptoUtils.rsaEncrypt(
        aesKeyBase64,
        rsaPublicKey,
      );
      final encryptedAesKeyString = base64Encode(
        utf8.encode(rsaEncryptedBytes),
      );

      // 6. Upload encrypted file to IPFS
      final url = Uri.parse('https://api.pinata.cloud/pinning/pinFileToIPFS');
      const String jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiI1MjNmNzlmZC0xZjVmLTQ4NzUtOTQwMS01MDcyMDE3NmMyYjYiLCJlbWFpbCI6ImVkd2FyZC5xdWlhbnpvbi5yQGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaW5fcG9saWN5Ijp7InJlZ2lvbnMiOlt7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6IkZSQTEifSx7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6Ik5ZQzEifV0sInZlcnNpb24iOjF9LCJtZmFfZW5hYmxlZCI6ZmFsc2UsInN0YXR1cyI6IkFDVElWRSJ9LCJhdXRoZW50aWNhdGlvblR5cGUiOiJzY29wZWRLZXkiLCJzY29wZWRLZXlLZXkiOiI5NmM3NGQxNTY4YzBlNDE4MGQ5MiIsInNjb3BlZEtleVNlY3JldCI6IjQ2MDIxYzNkYThmZDIzZDJmY2E4ZmYzNThjMGI3NmE2ODYxMzRhOWMzNDNiOTFmODY3MmIyMzhlYjE2N2FkODkiLCJleHAiOjE3ODU2ODIyMzl9.1VpMdmG4CaQ-eNxNVesfiy-P6J7p9IGLtjD9q1r5mkg'; // 🔐 Replace with your new valid JWT token

      final request =
          http.MultipartRequest('POST', url)
            ..headers['Authorization'] = 'Bearer $jwt'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                encryptedBytes,
                filename: 'encrypted.aes',
              ),
            );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload to Pinata: ${response.body}'),
            ),
          );
        }
        return;
      }

      final ipfsJson = jsonDecode(response.body);
      final ipfsCid =
          ipfsJson['IpfsHash'] as String; // 👈 This is your CID from Pinata

      print('Upload successful. CID: $ipfsCid');

      // 7. Insert file metadata into Supabase
      final fileInsert =
          await supabase
              .from('Files')
              .insert({
                'filename': fileName,
                'category': 'General',
                'file_type': fileType,
                'uploaded_at': DateTime.now().toIso8601String(),
                'file_size': fileBytes.length,
                'ipfs_cid':
                    ipfsCid, // ✅ Now ipfsCid is properly defined in scope
                'uploaded_by': user.id,
              })
              .select()
              .single();
      final fileId = fileInsert['id'];
      print('File inserted with ID: $fileId');

      // 8. Insert encrypted AES key into File_keys
      print('Attempting to insert file key with:');
      print('  fileId: $fileId (type: ${fileId.runtimeType})');
      print('  userId: ${user.id} (type: ${user.id.runtimeType})');
      print('  recipient_type: user');
      print('  aes_key_encrypted length: ${encryptedAesKeyString.length}');

      try {
        final insertData = {
          'file_id': fileId,
          'recipient_type': 'user',
          'recipient_id': null,
          'aes_key_encrypted': encryptedAesKeyString,
        };
        print('Insert data: $insertData');

        final result =
            await supabase.from('File_Keys').insert(insertData).select();
        print('File key inserted successfully: $result');
      } catch (fileKeyError) {
        print('Error inserting file key: $fileKeyError');
        print('Error type: ${fileKeyError.runtimeType}');

        // Even if file key insertion fails, we can still show partial success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File uploaded but key storage failed: $fileKeyError',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return; // Exit early to avoid showing success message
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded and encrypted successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
      }
    }
  }

  void _shareSelectedFiles() {
    // TODO: Implement file sharing
  }

  void _previewFile(FileItem item) {
    // TODO: Implement file preview
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
    // Simple date formatting
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
          filtered.where((file) => file.type == _selectedFileType).toList();
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

  // Add this widget between AppBar and FilesList
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
                      items: [
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class FileItem {
  final String name;
  final String type;
  final String size;
  final IconData icon;
  final Color color;
  final DateTime dateAdded;

  FileItem({
    required this.name,
    required this.type,
    required this.size,
    required this.icon,
    required this.color,
    required this.dateAdded,
  });
}
