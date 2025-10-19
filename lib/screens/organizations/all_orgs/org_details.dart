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

  // Design tokens
  static const primaryColor = Color(0xFF03989E);
  static const accentColor = Color(0xFF04B1B8);
  static const lightBg = Color(0xFFF8FAF8);
  static const cardBg = Colors.white;
  static const borderColor = Color(0xFFE5E7EB);

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
        _showErrorSnackbar(
          'Error loading organization details: ${e.toString()}',
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
    } catch (e, stackTrace) {
      print('Error loading doctors: $e');
      print('Error stack trace: $stackTrace');
      setState(() {
        _isLoadingDoctors = false;
        _doctors = [];
      });

      if (mounted) {
        _showErrorSnackbar('Error loading doctors: ${e.toString()}');
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
    if (dateString == null) return 'N/A';
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
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
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

  void _showErrorSnackbar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2.5,
                ),
              )
              : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Enhanced Hero Header
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    backgroundColor: primaryColor,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Material(
                        color: Colors.white.withOpacity(0.2),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          customBorder: const CircleBorder(),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 56, bottom: 60),
                      title: Text(
                        _organizationData?['name'] ?? widget.orgName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      background:
                          _organizationData?['image'] != null
                              ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _organizationData!['image'],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(color: primaryColor),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.25),
                                          Colors.black.withOpacity(0.65),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Container(color: primaryColor),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(60),
                      child: Container(
                        color: cardBg,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: primaryColor,
                          unselectedLabelColor: Colors.grey[400],
                          indicatorColor: primaryColor,
                          indicatorWeight: 3,
                          indicatorPadding: const EdgeInsets.only(bottom: 8),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          tabs: [
                            const Tab(text: 'Overview'),
                            Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Doctors'),
                                  if (_doctors.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_filteredDoctors.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
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

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Section
          if (_organizationData?['description'] != null) ...[
            _buildSectionCard(
              icon: Icons.info_outline,
              title: 'About',
              child: Text(
                _organizationData!['description'],
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Information Section
          _buildInfoSection(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final items = <Map<String, dynamic>>[];

    if (_organizationData?['organization_license'] != null) {
      items.add({
        'icon': Icons.verified_user_outlined,
        'label': 'License',
        'value': _organizationData!['organization_license'],
      });
    }

    if (_organizationData?['email'] != null) {
      items.add({
        'icon': Icons.email_outlined,
        'label': 'Email',
        'value': _organizationData!['email'],
      });
    }

    if (_organizationData?['contact_number'] != null) {
      items.add({
        'icon': Icons.phone_outlined,
        'label': 'Phone',
        'value': _organizationData!['contact_number'],
      });
    }

    if (_organizationData?['location'] != null) {
      items.add({
        'icon': Icons.location_on_outlined,
        'label': 'Location',
        'value': _organizationData!['location'],
      });
    }

    if (_organizationData?['created_at'] != null) {
      items.add({
        'icon': Icons.calendar_today_outlined,
        'label': 'Established',
        'value': _formatDate(_organizationData!['created_at']),
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_outlined,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Organization Info',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...List.generate(
            items.length,
            (index) => Column(
              children: [
                _buildInfoItem(
                  items[index]['icon'] as IconData,
                  items[index]['label'] as String,
                  items[index]['value'] as String,
                ),
                if (index < items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: Colors.grey[200],
                      height: 1,
                      thickness: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorsTab() {
    return Column(
      children: [
        if (_departments.length > 1) _buildDepartmentFilter(),
        Expanded(
          child:
              _isLoadingDoctors
                  ? Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.5,
                    ),
                  )
                  : _filteredDoctors.isEmpty
                  ? _buildEmptyDoctorsState()
                  : _buildDoctorsList(),
        ),
      ],
    );
  }

  Widget _buildDepartmentFilter() {
    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_departments.length, (index) {
            final dept = _departments[index];
            final isSelected = _selectedDepartment == dept;
            return Padding(
              padding: EdgeInsets.only(
                right: index < _departments.length - 1 ? 10 : 0,
              ),
              child: _buildDepartmentChip(dept, isSelected),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDepartmentChip(String dept, bool isSelected) {
    return Material(
      color: isSelected ? primaryColor : Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => setState(() => _selectedDepartment = dept),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                isSelected
                    ? null
                    : Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Text(
            dept,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDoctors.length,
      itemBuilder: (context, index) {
        final doctor = _filteredDoctors[index];
        final user = doctor['User'];
        return _buildDoctorCard(doctor, user, index);
      },
    );
  }

  Widget _buildEmptyDoctorsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                color: primaryColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedDepartment == 'All'
                  ? 'No Doctors Yet'
                  : 'No Doctors in $_selectedDepartment',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _selectedDepartment == 'All'
                  ? 'This organization hasn\'t added any doctors yet'
                  : 'Try selecting a different department',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    final department = doctor['department']?.toString().trim() ?? 'General';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.15),
                          primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. $fullName',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            department,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (user?['email'] != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user!['email'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
