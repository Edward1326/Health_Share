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

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _disabilitiesController;

  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  String? _selectedBloodType;
  String? _selectedSex;

  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _oldImagePath;

  bool _isLoading = false;
  bool _isUploadingImage = false;

  // Design tokens matching ProfileScreen
  static const Color _primaryColor = Color(0xFF416240);
  static const Color _accentColor = Color(0xFFA3B18A);
  static const Color _bg = Color(0xFFF8FAF8);
  static const Color _card = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);

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

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _staggerController.forward();
    });
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

    if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      _oldImagePath = _extractImagePath(_uploadedImageUrl!);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _disabilitiesController.dispose();
    super.dispose();
  }

  bool _isValidPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    return cleanPhone.length == 11 && RegExp(r'^\d{11}$').hasMatch(cleanPhone);
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

  String? _extractImagePath(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 3) {
        return pathSegments.last;
      }
    } catch (e) {
      debugPrint('Error extracting image path: $e');
    }
    return null;
  }

  Future<void> _deleteOldImage(String imagePath) async {
    try {
      await _supabase.storage.from('profile-images').remove([imagePath]);
      debugPrint('Old image deleted: $imagePath');
    } catch (e) {
      debugPrint('Error deleting old image: $e');
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

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          _showError('Image size must be less than 5MB');
        }
        setState(() => _isUploadingImage = false);
        return;
      }

      setState(() {
        _selectedImage = file;
      });

      final fileExt = path.extension(file.path);
      final fileName =
          'profile_${widget.userData['id']}_${DateTime.now().millisecondsSinceEpoch}$fileExt';

      if (_oldImagePath != null) {
        await _deleteOldImage(_oldImagePath!);
      }

      await _supabase.storage
          .from('profile-images')
          .upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _supabase.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      await _supabase
          .from('Person')
          .update({'image': publicUrl})
          .eq('id', widget.userData['id']);

      setState(() {
        _uploadedImageUrl = publicUrl;
        _oldImagePath = fileName;
      });

      if (mounted) {
        _showSuccess('Profile image updated successfully!');
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        _showError('Error uploading image: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _contactController.text.trim();
    if (phone.isNotEmpty && !_isValidPhoneNumber(phone)) {
      _showError('Phone number must be exactly 11 digits');
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
        _showSuccess('Profile updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error updating profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(message),
            ],
          ),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildStaggeredCard(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final progress = (_staggerController.value - (index * 0.15)).clamp(
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
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primaryColor.withOpacity(0.08),
                  _accentColor.withOpacity(0.05),
                  _bg,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [_buildAppBar(context), Expanded(child: _buildBody())],
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
          Material(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            shadowColor: _primaryColor.withOpacity(0.1),
            child: InkWell(
              onTap: () => Navigator.pop(context),
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
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Edit Profile',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Material(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              onTap: _isLoading ? null : _saveProfile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStaggeredCard(0, _buildProfileImageCard()),
                const SizedBox(height: 24),
                _buildStaggeredCard(1, _buildContactInfoCard()),
                const SizedBox(height: 16),
                _buildStaggeredCard(2, _buildMedicalInfoCard()),
                const SizedBox(height: 20),
                _buildStaggeredCard(3, _buildCancelButton()),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImageCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primaryColor.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _primaryColor.withOpacity(0.02),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primaryColor.withOpacity(0.12),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child:
                        _isUploadingImage
                            ? Center(
                              child: CircularProgressIndicator(
                                color: _primaryColor,
                                strokeWidth: 3,
                              ),
                            )
                            : _selectedImage != null
                            ? Image.file(_selectedImage!, fit: BoxFit.cover)
                            : (_uploadedImageUrl != null &&
                                _uploadedImageUrl!.isNotEmpty)
                            ? Image.network(
                              _uploadedImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_primaryColor, _accentColor],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                );
                              },
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryColor,
                                  ),
                                );
                              },
                            )
                            : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_primaryColor, _accentColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: _primaryColor,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      onTap: _isUploadingImage ? null : _pickAndUploadImage,
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to change photo',
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primaryColor.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
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
                child: const Icon(
                  Icons.contact_phone_rounded,
                  size: 22,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
            'Address',
            _addressController,
            Icons.location_on_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Contact Number',
            _contactController,
            Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primaryColor.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
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
                child: const Icon(
                  Icons.medical_information_rounded,
                  size: 22,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Medical Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDropdownField(
            'Blood Type',
            _selectedBloodType,
            _bloodTypes,
            Icons.bloodtype_rounded,
            (value) => setState(() => _selectedBloodType = value),
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            'Sex',
            _selectedSex,
            _sexOptions,
            Icons.person_rounded,
            (value) => setState(() => _selectedSex = value),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Allergies (comma-separated)',
            _allergiesController,
            Icons.warning_amber_rounded,
            maxLines: 2,
            hintText: 'e.g., Peanuts, Shellfish, Penicillin',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Medical Conditions (comma-separated)',
            _medicalConditionsController,
            Icons.medical_services_rounded,
            maxLines: 2,
            hintText: 'e.g., Diabetes, Hypertension',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            'Disabilities (comma-separated)',
            _disabilitiesController,
            Icons.accessible_rounded,
            maxLines: 2,
            hintText: 'e.g., Visual Impairment, Mobility Issues',
          ),
        ],
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
          style: const TextStyle(
            fontSize: 13,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: _primaryColor.withOpacity(0.6),
              size: 20,
            ),
            hintText: hintText,
            hintStyle: TextStyle(
              color: _textSecondary.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _primaryColor.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _primaryColor.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
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
          style: const TextStyle(
            fontSize: 13,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: _primaryColor.withOpacity(0.6),
              size: 20,
            ),
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _primaryColor.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _primaryColor.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
            style: TextStyle(
              color: _textSecondary.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(
            255,
            255,
            0,
            0,
          ), // 🔴 Dark red (same darkness as 0xFF416240)
          foregroundColor: Colors.white, // ⚪ Text color
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
