import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import services
import 'package:health_share/services/org_services/org_service.dart';
import 'package:health_share/services/org_services/org_membership_service.dart';
import 'package:health_share/services/org_services/org_doctor_service.dart';

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

  // Color Scheme
  static const Color primaryGreen = Color(0xFF4A7C59);
  static const Color lightGreen = Color(0xFF6B9B7A);
  static const Color paleGreen = Color(0xFFE8F5E9);
  static const Color accentGreen = Color(0xFF2E5C3F);
  static const Color darkGreen = Color(0xFF1B4332);

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
      final orgData = await OrgService.fetchOrgDetails(widget.orgId);

      setState(() {
        _organizationData = orgData;
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
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading details: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red[700],
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
      final doctors = await OrgDoctorService.fetchOrgDoctors(widget.orgId);

      setState(() {
        _doctors = doctors;
        _isLoadingDoctors = false;

        // Extract unique departments
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
    } catch (e, stackTrace) {
      print('Error loading doctors: $e');
      print('Error stack trace: $stackTrace');
      setState(() {
        _isLoadingDoctors = false;
        _doctors = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error loading doctors: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      final status = await OrgMembershipService.checkMembershipStatus(
        widget.orgId,
        user.id,
      );

      if (status != null) {
        setState(() {
          _hasJoined = true;
          _membershipStatus = status;
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
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('You must be logged in to join'),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    try {
      await OrgMembershipService.joinOrg(widget.orgId, user.id);

      setState(() {
        _hasJoined = true;
        _membershipStatus = 'pending';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Join request sent successfully!'),
              ],
            ),
            backgroundColor: primaryGreen,
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
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to join: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red[700],
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
        return primaryGreen;
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [paleGreen.withOpacity(0.3), Colors.white],
          ),
        ),
        child:
            _isLoading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading organization...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
                : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [_buildAppBar()];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [_buildDetailsTab(), _buildDoctorsTab()],
                  ),
                ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
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
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                : _buildGradientBackground(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 140,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.15),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 90,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryGreen.withOpacity(0.9),
                          lightGreen.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 6,
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
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                          blurRadius: 12,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  ),
                  if (_organizationData?['location'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _organizationData!['location'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryGreen, size: 20),
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
                color: primaryGreen.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            height: 50,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: paleGreen.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: paleGreen, width: 1.5),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(colors: [primaryGreen, lightGreen]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 19),
                      SizedBox(width: 8),
                      Text('Overview'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 19),
                      const SizedBox(width: 8),
                      const Text('Doctors'),
                      if (_doctors.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_filteredDoctors.length}',
                            style: const TextStyle(
                              fontSize: 11,
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
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, lightGreen, accentGreen],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_hospital_rounded,
          size: 100,
          color: Colors.white.withOpacity(0.25),
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_organizationData?['description'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, paleGreen.withOpacity(0.3)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: paleGreen, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryGreen, lightGreen],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGreen.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'About',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _organizationData!['description'],
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Colors.grey[700],
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _buildQuickInfoCards(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
          gradient: [primaryGreen, lightGreen],
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
          gradient: [accentGreen, darkGreen],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive grid
        final crossAxisCount = constraints.maxWidth > 400 ? 2 : 1;
        final childAspectRatio = constraints.maxWidth > 400 ? 1.5 : 2.5;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: cards,
        );
      },
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, gradient[0].withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradient[0].withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.15),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
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
        if (_departments.length > 1)
          Container(
            height: 60,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
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
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            isSelected
                                ? LinearGradient(
                                  colors: [primaryGreen, lightGreen],
                                )
                                : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border:
                            isSelected
                                ? null
                                : Border.all(color: paleGreen, width: 2),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                                : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                      ),
                      child: Center(
                        child: Text(
                          department,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
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
        Expanded(
          child:
              _isLoadingDoctors
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryGreen,
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
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    physics: const BouncingScrollPhysics(),
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
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [paleGreen, paleGreen.withOpacity(0.5)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.medical_services_outlined,
              color: primaryGreen,
              size: 56,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _selectedDepartment == 'All'
                ? 'No Doctors Available'
                : 'No Doctors in $_selectedDepartment',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              _selectedDepartment == 'All'
                  ? 'This organization hasn\'t added any doctors yet'
                  : 'Try selecting a different department',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_selectedDepartment != 'All') ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedDepartment = 'All';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: primaryGreen.withOpacity(0.4),
              ),
              child: const Text(
                'View All Departments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

    final gradients = [
      [primaryGreen, lightGreen],
      [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      [accentGreen, darkGreen],
      [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      [const Color(0xFFEF4444), const Color(0xFFDC2626)],
    ];

    final gradient = gradients[index % gradients.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, gradient[0].withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gradient[0].withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dr. $fullName',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  gradient[0].withOpacity(0.15),
                                  gradient[1].withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              color: gradient[0],
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (doctor['department'] != null &&
                          doctor['department']
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                gradient[0].withOpacity(0.15),
                                gradient[1].withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: gradient[0].withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            doctor['department'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gradient[0],
                            ),
                          ),
                        ),
                      ],
                      if (user?['email'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 15,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user!['email'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Joined ${_formatDate(doctor['created_at'])}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
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
