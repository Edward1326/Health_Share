import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers for editable fields
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalConditionsController;
  late TextEditingController _currentMedicationsController;
  late TextEditingController _disabilitiesController;

  // Dropdown values
  String? _selectedBloodType;
  String? _selectedSex;

  // Blood type options
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

  // Sex options
  final List<String> _sexOptions = ['Male', 'Female'];

  bool _isLoading = false;

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

    // Convert arrays to comma-separated strings
    _allergiesController = TextEditingController(
      text: _listToString(widget.userData['allergies']),
    );
    _medicalConditionsController = TextEditingController(
      text: _listToString(widget.userData['medical_conditions']),
    );
    _currentMedicationsController = TextEditingController(
      text: _listToString(widget.userData['current_medications']),
    );
    _disabilitiesController = TextEditingController(
      text: _listToString(widget.userData['disabilities']),
    );

    // Set dropdown values
    _selectedBloodType = widget.userData['blood_type'];
    _selectedSex = widget.userData['sex'];
  }

  // UPDATED METHOD - Now handles both List and String types
  String _listToString(dynamic list) {
    if (list == null) return '';
    if (list is String) return list; // Handle string type
    if (list is List && list.isEmpty) return '';
    if (list is List) return list.join(', ');
    return '';
  }

  List<String> _stringToList(String text) {
    if (text.trim().isEmpty) return [];
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _contactController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _currentMedicationsController.dispose();
    _disabilitiesController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare update data
      final updateData = {
        'address':
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        'contact_number':
            _contactController.text.trim().isEmpty
                ? null
                : _contactController.text.trim(),
        'blood_type': _selectedBloodType,
        'sex': _selectedSex,
        'allergies': _stringToList(_allergiesController.text),
        'medical_conditions': _stringToList(_medicalConditionsController.text),
        'current_medications': _stringToList(
          _currentMedicationsController.text,
        ),
        'disabilities': _stringToList(_disabilitiesController.text),
      };

      // Update the person record
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
        Navigator.pop(context, true); // Return true to indicate success
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              // Contact Information Section
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

              // Medical Information Section
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
                    'Current Medications (comma-separated)',
                    _currentMedicationsController,
                    Icons.medication_outlined,
                    maxLines: 2,
                    hintText: 'e.g., Aspirin, Metformin',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Disabilities (comma-separated)',
                    _disabilitiesController,
                    Icons.accessible_outlined,
                    maxLines: 2,
                    hintText: 'e.g., Visual impairment, Mobility issues',
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Cancel Button
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            filled: true,
            fillColor: Colors.white,
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
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}
