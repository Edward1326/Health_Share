import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _disabilitiesController;

  // Dropdowns
  String? _selectedBloodType;
  String? _selectedSex;

  // Upload image
  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _oldImagePath; // Track old image for deletion

  bool _isLoading = false;
  bool _isUploadingImage = false;

  final List<String> _bloodTypes = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

  final List<String> _sexOptions = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _addressController = TextEditingController(
      text: widget.userData['address'] ?? '',
    );
    _contactController = TextEditingController(
      text: widget.userData['contact_number'] ?? '',
    );
    _allergiesController = TextEditingController(
      text: widget.userData['allergies'] ?? '',
    );
    _medicalConditionsController = TextEditingController(
      text: widget.userData['medical_conditions'] ?? '',
    );
    _disabilitiesController = TextEditingController(
      text: widget.userData['disabilities'] ?? '',
    );
    _selectedBloodType = widget.userData['blood_type'];
    _selectedSex = widget.userData['sex'];
    _uploadedImageUrl = widget.userData['image'];

    // Extract old image path if exists
    if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      _oldImagePath = _extractImagePath(_uploadedImageUrl!);
    }
  }

  bool _isValidPhoneNumber(String phone) {
    // Remove any spaces or dashes
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    // Check if it contains exactly 11 digits
    return cleanPhone.length == 11 && RegExp(r'^\d{11}$').hasMatch(cleanPhone);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _contactController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _disabilitiesController.dispose();
    super.dispose();
  }

  String _formatInput(String text) {
    if (text.trim().isEmpty) return '';
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) => _capitalizeWords(item))
        .join(', ');
  }

  String _capitalizeWords(String text) {
    return text
        .split(' ')
        .map(
          (word) =>
              word.isEmpty
                  ? word
                  : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  // Extract filename from full URL
  String? _extractImagePath(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 3) {
        // URL format: .../storage/v1/object/public/profile-images/filename
        return pathSegments.last;
      }
    } catch (e) {
      debugPrint('Error extracting image path: $e');
    }
    return null;
  }

  // Delete old image from storage
  Future<void> _deleteOldImage(String imagePath) async {
    try {
      await _supabase.storage.from('profile-images').remove([imagePath]);
      debugPrint('Old image deleted: $imagePath');
    } catch (e) {
      debugPrint('Error deleting old image: $e');
      // Don't throw error, just log it
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isUploadingImage = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingImage = false);
        return;
      }

      final file = File(result.files.single.path!);

      // Validate file size (max 5MB)
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image size must be less than 5MB'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return;
      }

      setState(() {
        _selectedImage = file;
      });

      // Generate unique filename
      final fileExt = path.extension(file.path);
      final fileName =
          'profile_${widget.userData['id']}_${DateTime.now().millisecondsSinceEpoch}$fileExt';

      // Delete old image if exists
      if (_oldImagePath != null) {
        await _deleteOldImage(_oldImagePath!);
      }

      // Upload new image
      final uploadPath = await _supabase.storage
          .from('profile-images')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      // Update Person table with new image URL
      await _supabase
          .from('Person')
          .update({'image': publicUrl})
          .eq('id', widget.userData['id']);

      setState(() {
        _uploadedImageUrl = publicUrl;
        _oldImagePath = fileName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ ADD THIS VALIDATION HERE (right after form validation)
    final phone = _contactController.text.trim();
    if (phone.isNotEmpty && !_isValidPhoneNumber(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Phone number must be exactly 11 digits')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = {
        'address':
            _addressController.text.trim().isEmpty
                ? null
                : _capitalizeWords(_addressController.text.trim()),
        'contact_number':
            _contactController.text.trim().isEmpty
                ? null
                : _contactController.text.trim(),
        'blood_type': _selectedBloodType,
        'sex': _selectedSex,
        'allergies':
            _formatInput(_allergiesController.text).isEmpty
                ? null
                : _formatInput(_allergiesController.text),
        'medical_conditions':
            _formatInput(_medicalConditionsController.text).isEmpty
                ? null
                : _formatInput(_medicalConditionsController.text),
        'disabilities':
            _formatInput(_disabilitiesController.text).isEmpty
                ? null
                : _formatInput(_disabilitiesController.text),
      };

      await _supabase
          .from('Person')
          .update(updateData)
          .eq('id', widget.userData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          'Edit Profile',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF667EEA),
                      ),
                    )
                    : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF667EEA),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF667EEA).withOpacity(0.2),
                            border: Border.all(
                              color: const Color(0xFF667EEA).withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child:
                                _isUploadingImage
                                    ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF667EEA),
                                      ),
                                    )
                                    : _selectedImage != null
                                    ? Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    )
                                    : (_uploadedImageUrl != null &&
                                        _uploadedImageUrl!.isNotEmpty)
                                    ? Image.network(
                                      _uploadedImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.white,
                                        );
                                      },
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF667EEA),
                                          ),
                                        );
                                      },
                                    )
                                    : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap:
                                _isUploadingImage ? null : _pickAndUploadImage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF667EEA),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to change photo',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              _buildSectionCard(
                title: 'Contact Information',
                icon: Icons.contact_phone_outlined,
                children: [
                  _buildTextField(
                    'Address',
                    _addressController,
                    Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Contact Number',
                    _contactController,
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildSectionCard(
                title: 'Medical Information',
                icon: Icons.medical_information_outlined,
                children: [
                  _buildDropdownField(
                    'Blood Type',
                    _selectedBloodType,
                    _bloodTypes,
                    Icons.bloodtype_outlined,
                    (value) => setState(() => _selectedBloodType = value),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Sex',
                    _selectedSex,
                    _sexOptions,
                    Icons.person_outline,
                    (value) => setState(() => _selectedSex = value),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Allergies (comma-separated)',
                    _allergiesController,
                    Icons.warning_amber_outlined,
                    maxLines: 2,
                    hintText: 'e.g., Peanuts, Shellfish, Penicillin',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Medical Conditions (comma-separated)',
                    _medicalConditionsController,
                    Icons.medical_services_outlined,
                    maxLines: 2,
                    hintText: 'e.g., Diabetes, Hypertension',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Disabilities (comma-separated)',
                    _disabilitiesController,
                    Icons.accessible_outlined,
                    maxLines: 2,
                    hintText: 'e.g., Visual Impairment, Mobility Issues',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF667EEA), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF667EEA), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    IconData icon,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items:
              options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
          hint: Text(
            'Select $label',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}
