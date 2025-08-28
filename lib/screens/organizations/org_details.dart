import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrgDetailsScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const OrgDetailsScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  State<OrgDetailsScreen> createState() => _OrgDetailsScreenState();
}

class _OrgDetailsScreenState extends State<OrgDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _organizationData;
  List<Map<String, dynamic>> _doctors = [];
  List<String> _departments = ['All'];
  String _selectedDepartment = 'All';
  bool _isLoading = true;
  bool _isLoadingDoctors = false;
  bool _hasJoined = false;
  String? _membershipStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrganizationDetails();
    _checkMembershipStatus();
    _loadDoctors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        _organizationData = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading organization details: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading organization details: ${e.toString()}',
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoadingDoctors = true);

    try {
      // First, get all Organization_User records for doctors in this organization
      final orgUserResponse = await Supabase.instance.client
          .from('Organization_User')
          .select('*')
          .eq('organization_id', widget.orgId)
          .eq('position', 'Doctor');

      print('Organization_User response: $orgUserResponse');

      if (orgUserResponse.isEmpty) {
        print('No doctors found in Organization_User table');
        setState(() {
          _doctors = [];
          _isLoadingDoctors = false;
        });
        return;
      }

      // Extract user IDs
      final userIds = orgUserResponse.map((doc) => doc['user_id']).toList();
      print('User IDs to fetch: $userIds');

      // Now fetch the User details with Person information
      final userResponse = await Supabase.instance.client
          .from('User')
          .select('''
            id,
            email,
            Person(first_name, middle_name, last_name)
          ''')
          .inFilter('id', userIds);

      print('User response: $userResponse');

      // Combine the data
      final combinedDoctors = <Map<String, dynamic>>[];
      for (final orgUser in orgUserResponse) {
        final user = userResponse.firstWhere(
          (u) => u['id'] == orgUser['user_id'],
          orElse: () => <String, dynamic>{},
        );

        if (user.isNotEmpty) {
          combinedDoctors.add({...orgUser, 'User': user});
        }
      }

      setState(() {
        _doctors = combinedDoctors;
        _isLoadingDoctors = false;

        // Extract unique departments, handle null/empty departments
        final departmentSet = <String>{};
        for (final doctor in _doctors) {
          final dept = doctor['department']?.toString().trim();
          if (dept != null && dept.isNotEmpty) {
            departmentSet.add(dept);
          }
        }

        final sortedDepartments = departmentSet.toList()..sort();
        _departments = ['All', ...sortedDepartments];
      });

      print('Successfully loaded ${_doctors.length} doctors');
      print('Departments found: $_departments');
    } catch (e) {
      print('Error loading doctors: $e');
      print('Error stack trace: ${e.toString()}');
      setState(() {
        _isLoadingDoctors = false;
        _doctors = [];
      });

      // Show error to user
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

  Future<void> _checkMembershipStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final response =
          await supabase
              .from('Patient')
              .select('status')
              .eq('user_id', user.id)
              .eq('organization_id', widget.orgId)
              .maybeSingle();

      if (response != null) {
        setState(() {
          _hasJoined = true;
          _membershipStatus = response['status'];
        });
      }
    } catch (e) {
      print('Error checking membership status: $e');
    }
  }

  Future<void> _joinOrganization() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You must be logged in to join.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      await supabase.from('Patient').insert({
        'user_id': user.id,
        'organization_id': widget.orgId,
        'joined_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      setState(() {
        _hasJoined = true;
        _membershipStatus = 'pending';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Join request sent successfully!'),
            backgroundColor: Colors.green[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: ${e.toString()}'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  String _formatFullName(Map<String, dynamic>? user) {
    if (user == null) return 'Unknown Doctor';

    final person = user['Person'];
    if (person == null) {
      return user['email'] ?? 'Unknown Doctor';
    }

    final firstName = person['first_name']?.toString().trim() ?? '';
    final middleName = person['middle_name']?.toString().trim() ?? '';
    final lastName = person['last_name']?.toString().trim() ?? '';

    List<String> nameParts = [];
    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    if (nameParts.isEmpty) {
      return user['email'] ?? 'Unknown Doctor';
    }

    return nameParts.join(' ');
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not available';
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'accepted':
      case 'active':
        return const Color(0xFF10B981);
      case 'declined':
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Pending Approval';
      case 'accepted':
      case 'active':
        return 'Active Member';
      case 'declined':
      case 'rejected':
        return 'Request Declined';
      default:
        return 'Unknown';
    }
  }

  List<Map<String, dynamic>> get _filteredDoctors {
    if (_selectedDepartment == 'All') {
      return _doctors;
    }
    return _doctors
        .where((doctor) => doctor['department'] == _selectedDepartment)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading organization...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              )
              : CustomScrollView(
                slivers: [
                  // Modern Sliver App Bar
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background with Image or Gradient
                          _organizationData?['image'] != null
                              ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _organizationData!['image'],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildGradientBackground(),
                                  ),
                                  // Dark gradient overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.2),
                                          Colors.black.withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : _buildGradientBackground(),

                          // Glassmorphism effect at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 120,
                            child: ClipRRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Content
                          Positioned(
                            bottom: 80,
                            left: 24,
                            right: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withOpacity(0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Healthcare Provider',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _organizationData?['name'] ?? widget.orgName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 4),
                                        blurRadius: 8,
                                        color: Colors.black26,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_organizationData?['location'] != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _organizationData!['location'],
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF1F2937),
                          size: 18,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(70),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            labelColor: const Color(0xFF1F2937),
                            unselectedLabelColor: const Color(0xFF6B7280),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.info_outline_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Overview'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.medical_services_outlined,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Doctors'),
                                    if (_doctors.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${_filteredDoctors.length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
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
                  ),

                  // Tab Content
                  SliverFillRemaining(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildDetailsTab(), _buildDoctorsTab()],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_hospital_rounded,
          size: 100,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Section
          if (_organizationData?['description'] != null) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'About',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _organizationData!['description'],
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Quick Info Cards
          _buildQuickInfoCards(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCards() {
    final cards = <Widget>[];

    if (_organizationData?['organization_license'] != null) {
      cards.add(
        _buildInfoCard(
          icon: Icons.verified_user_rounded,
          label: 'License',
          value: _organizationData!['organization_license'],
          gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
        ),
      );
    }

    if (_organizationData?['email'] != null) {
      cards.add(
        _buildInfoCard(
          icon: Icons.email_rounded,
          label: 'Email',
          value: _organizationData!['email'],
          gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        ),
      );
    }

    if (_organizationData?['contact_number'] != null) {
      cards.add(
        _buildInfoCard(
          icon: Icons.phone_rounded,
          label: 'Contact',
          value: _organizationData!['contact_number'],
          gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        ),
      );
    }

    if (_organizationData?['created_at'] != null) {
      cards.add(
        _buildInfoCard(
          icon: Icons.calendar_today_rounded,
          label: 'Since',
          value: _formatDate(_organizationData!['created_at']),
          gradient: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: cards,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsTab() {
    return Column(
      children: [
        // Department Filter Pills
        if (_departments.length > 1)
          Container(
            height: 56,
            margin: const EdgeInsets.only(top: 8),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _departments.length,
              itemBuilder: (context, index) {
                final department = _departments[index];
                final isSelected = _selectedDepartment == department;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDepartment = department;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            isSelected
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFF60A5FA),
                                    Color(0xFF3B82F6),
                                  ],
                                )
                                : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border:
                            isSelected
                                ? null
                                : Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1.5,
                                ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF3B82F6,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                      ),
                      child: Center(
                        child: Text(
                          department,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Doctors List
        Expanded(
          child:
              _isLoadingDoctors
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading doctors...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  : _filteredDoctors.isEmpty
                  ? _buildEmptyDoctorsState()
                  : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = _filteredDoctors[index];
                      final user = doctor['User'];
                      return _buildDoctorCard(doctor, user, index);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildEmptyDoctorsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.1),
                  const Color(0xFF60A5FA).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: Color(0xFF3B82F6),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _selectedDepartment == 'All'
                ? 'No Doctors Available'
                : 'No Doctors in $_selectedDepartment',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _selectedDepartment == 'All'
                  ? 'This organization hasn\'t added any doctors yet'
                  : 'Try selecting a different department',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_selectedDepartment != 'All') ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDepartment = 'All';
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'View All Departments',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoctorCard(
    Map<String, dynamic> doctor,
    Map<String, dynamic>? user,
    int index,
  ) {
    final fullName = _formatFullName(user);
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';

    // Create gradient colors based on index for variety
    final gradients = [
      [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      [const Color(0xFFEF4444), const Color(0xFFDC2626)],
    ];

    final gradient = gradients[index % gradients.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Could add doctor detail view here
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar with gradient
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Doctor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dr. $fullName',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              color: gradient[0],
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Department Badge
                      if (doctor['department'] != null &&
                          doctor['department']
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                gradient[0].withOpacity(0.1),
                                gradient[1].withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: gradient[0].withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            doctor['department'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: gradient[0],
                            ),
                          ),
                        ),
                      ],

                      // Email
                      if (user?['email'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user!['email'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),

                      // Join Date
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Joined ${_formatDate(doctor['created_at'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
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
}
