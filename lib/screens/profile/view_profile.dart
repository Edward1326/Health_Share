import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewProfileScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userEmail;

  const ViewProfileScreen({
    super.key,
    required this.userId,
    this.userName,
    required this.userEmail,
  });

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // User data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response =
          await _supabase
              .from('Person')
              .select('*')
              .eq('auth_user_id', widget.userId)
              .single();

      setState(() {
        _userData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  String _getFullName() {
    if (_userData == null) return 'Loading...';

    final firstName = _userData!['first_name'] ?? '';
    final middleName = _userData!['middle_name'] ?? '';
    final lastName = _userData!['last_name'] ?? '';

    return [
      firstName,
      middleName,
      lastName,
    ].where((name) => name.isNotEmpty).join(' ');
  }

  String _getInitials() {
    if (_userData == null) return '?';
    final firstName = _userData!['first_name'] ?? '';
    final lastName = _userData!['last_name'] ?? '';

    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0];
    if (lastName.isNotEmpty) initials += lastName[0];

    return initials.toUpperCase();
  }

  String _getUserEmail() {
    return _userData?['email'] ?? widget.userEmail ?? 'No email';
  }

  String _formatArrayValue(dynamic values) {
    if (values == null) {
      return 'Not provided';
    } else if (values is List) {
      return values.isNotEmpty ? values.join(', ') : 'Not provided';
    } else if (values is String) {
      return values.isNotEmpty ? values : 'Not provided';
    }
    return 'Not provided';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text(
          'User Profile',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF416240),
          strokeWidth: 2.5,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to load profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF416240),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildInfoSection(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  items: [
                    _InfoItem('Full Name', _getFullName()),
                    _InfoItem('Email', _getUserEmail()),
                    _InfoItem(
                      'Contact',
                      _userData!['contact_number'] ?? 'Not provided',
                    ),
                    _InfoItem(
                      'Address',
                      _userData!['address'] ?? 'Not provided',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoSection(
                  title: 'Medical Information',
                  icon: Icons.medical_information_outlined,
                  items: [
                    _InfoItem(
                      'Blood Type',
                      _userData!['blood_type'] ?? 'Not provided',
                    ),
                    _InfoItem('Sex', _userData!['sex'] ?? 'Not provided'),
                    _InfoItem(
                      'Allergies',
                      _formatArrayValue(_userData!['allergies']),
                    ),
                    _InfoItem(
                      'Medical Conditions',
                      _formatArrayValue(_userData!['medical_conditions']),
                    ),
                    _InfoItem(
                      'Disabilities',
                      _formatArrayValue(_userData!['disabilities']),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final imageUrl = _userData?['image'];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          children: [
            if (imageUrl != null && imageUrl.toString().isNotEmpty)
              CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFF416240).withOpacity(0.1),
                backgroundImage: NetworkImage(imageUrl),
              )
            else
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF416240).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF416240),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _getFullName(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _getUserEmail(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF416240)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildInfoRow(items[i].label, items[i].value),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem(this.label, this.value);
}
