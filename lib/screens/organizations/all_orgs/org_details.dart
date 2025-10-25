import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import services
import 'package:health_share/services/org_services/org_service.dart';
import 'package:health_share/services/org_services/org_membership_service.dart';
import 'package:health_share/services/org_services/org_doctor_service.dart';
import 'package:health_share/screens/organizations/all_orgs/doctor_profile.dart';

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
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _staggerController;
  late AnimationController _headerController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerScaleAnimation;

  Map<String, dynamic>? _organizationData;
  List<Map<String, dynamic>> _doctors = [];
  List<String> _departments = ['All'];
  String _selectedDepartment = 'All';
  bool _isLoading = true;
  bool _isLoadingDoctors = false;
  bool _hasJoined = false;
  String? _membershipStatus;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;

  // Design tokens - Updated to match FilesScreen
  static const Color _primaryColor = Color(0xFF416240);
  static const Color _accentColor = Color(0xFFA3B18A);
  static const Color _bg = Color(0xFFF8FAF8);
  static const Color _card = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          if (_tabController.index == 0) {
            _isSearchVisible = false;
            _searchController.clear();
            _searchQuery = '';
          }
        });
      }
    });

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _headerScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
    );

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadOrganizationDetails(),
      _checkMembershipStatus(),
      _loadDoctors(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
      _headerController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _staggerController.forward();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _staggerController.dispose();
    _headerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizationDetails() async {
    try {
      final orgData = await OrgService.fetchOrgDetails(widget.orgId);
      if (mounted) {
        setState(() => _organizationData = orgData);
      }
    } catch (e) {
      print('Error loading organization details: $e');
      if (mounted) {
        _showError('Error loading organization details: ${e.toString()}');
      }
    }
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoadingDoctors = true);

    try {
      final doctors = await OrgDoctorService.fetchOrgDoctors(widget.orgId);

      if (mounted) {
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
      }

      print('Successfully loaded ${_doctors.length} doctors');
    } catch (e, stackTrace) {
      print('Error loading doctors: $e');
      print('Error stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingDoctors = false;
          _doctors = [];
        });
        _showError('Error loading doctors: ${e.toString()}');
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

      if (mounted && status != null) {
        setState(() {
          _hasJoined = true;
          _membershipStatus = status;
        });
      }
    } catch (e) {
      print('Error checking membership status: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadOrganizationDetails(),
      _checkMembershipStatus(),
      _loadDoctors(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccess('Refreshed successfully');
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
    var filtered =
        _selectedDepartment == 'All'
            ? _doctors
            : _doctors
                .where((doctor) => doctor['department'] == _selectedDepartment)
                .toList();

    if (_searchQuery.isEmpty) return filtered;

    return filtered.where((doctor) {
      final fullName = _formatFullName(doctor['User']).toLowerCase();
      final dept = (doctor['department'] ?? '').toString().toLowerCase();
      final email = (doctor['User']?['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return fullName.contains(query) ||
          dept.contains(query) ||
          email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            height: 300,
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
              children: [
                _buildAppBar(context),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildTabBar(),
                Expanded(
                  child: Column(
                    children: [
                      if (_isSearchVisible && _tabController.index == 1)
                        _buildSearchField(),
                      const SizedBox(height: 20),
                      Expanded(
                        child:
                            _isLoading
                                ? _buildLoadingState()
                                : TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildDetailsContent(),
                                    _buildDoctorsContent(),
                                  ],
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          if (_tabController.index == 1)
            _buildIconButton(
              icon:
                  _isSearchVisible
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
              onTap: () {
                setState(() => _isSearchVisible = !_isSearchVisible);
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              },
            ),
          if (_tabController.index == 1) const SizedBox(width: 12),
          _buildIconButton(icon: Icons.refresh_rounded, onTap: _refreshData),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: _primaryColor.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
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
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final avatarTag = 'org_avatar_${widget.orgId}';
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return Opacity(
          opacity: _headerController.value,
          child: Transform.translate(
            offset: Offset(0, _headerSlideAnimation.value),
            child: Transform.scale(
              scale: _headerScaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primaryColor.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: _primaryColor.withOpacity(0.02),
                blurRadius: 40,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryColor.withOpacity(0.02),
                        Colors.transparent,
                        _accentColor.withOpacity(0.01),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Hero(
                      tag: avatarTag,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _primaryColor.withOpacity(0.08),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child:
                              _organizationData?['image'] != null
                                  ? Image.network(
                                    _organizationData!['image'],
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildFallbackLogo(),
                                  )
                                  : _buildFallbackLogo(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _organizationData?['name'] ?? widget.orgName,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_organizationData?['description'] != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                _organizationData!['description'],
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (_hasJoined) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: _primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Member',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_hospital_rounded,
          size: 38,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _card,
          border: Border.all(color: _primaryColor.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: _textSecondary,
          indicator: BoxDecoration(
            gradient: LinearGradient(colors: [_primaryColor, _accentColor]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          onTap: (index) {
            if (index == 0 && _isSearchVisible) {
              setState(() {
                _isSearchVisible = false;
                _searchController.clear();
                _searchQuery = '';
              });
            }
          },
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('DETAILS'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('DOCTORS'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor.withOpacity(0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: 'Search doctors...',
            hintStyle: TextStyle(
              color: _textSecondary.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.search_rounded, color: _primaryColor, size: 24),
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: _primaryColor,
                          size: 18,
                        ),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                    : null,
            filled: true,
            fillColor: _card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  _accentColor.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: _primaryColor,
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading organization data...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: _primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_organizationData?['description'] != null) ...[
              _buildInfoCard(
                icon: Icons.description_outlined,
                title: 'About',
                content: _organizationData!['description'],
              ),
              const SizedBox(height: 16),
            ],
            _buildOrganizationInfo(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
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
                child: Icon(icon, size: 22, color: _primaryColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationInfo() {
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
                  Icons.business_outlined,
                  size: 22,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Organization Info',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                      color: _primaryColor.withOpacity(0.08),
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
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: _primaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorsContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: _primaryColor,
      child: Column(
        children: [
          if (_departments.length > 1) _buildDepartmentFilter(),
          Expanded(
            child:
                _isLoadingDoctors
                    ? _buildLoadingState()
                    : _filteredDoctors.isEmpty
                    ? _buildEmptyDoctorsState()
                    : _buildDoctorsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentFilter() {
    return Container(
      color: _card,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedDepartment = dept),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border:
                isSelected
                    ? null
                    : Border.all(
                      color: _primaryColor.withOpacity(0.15),
                      width: 1.5,
                    ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            dept,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : _textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _filteredDoctors.length,
      itemBuilder: (context, index) {
        final doctor = _filteredDoctors[index];
        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final progress = (_staggerController.value - (index * 0.06)).clamp(
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
          child: _buildDoctorCard(doctor, index),
        );
      },
    );
  }

  Widget _buildEmptyDoctorsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withOpacity(0.15),
                    _accentColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_services_outlined,
                size: 56,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _selectedDepartment == 'All'
                  ? 'No Doctors Yet'
                  : 'No Doctors in $_selectedDepartment',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedDepartment == 'All'
                  ? 'This organization hasn\'t added any doctors yet'
                  : 'Try selecting a different department',
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor, int index) {
    final user = doctor['User'];
    final fullName = _formatFullName(user);
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';
    final department = doctor['department']?.toString().trim() ?? 'General';
    final email = user?['email'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => DoctorProfileScreen(
                      doctorData: doctor,
                      organizationName: widget.orgName,
                    ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _primaryColor.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _accentColor.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.medical_services_rounded,
                              size: 12,
                              color: _primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                department,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.email_rounded,
                              size: 12,
                              color: _textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textSecondary,
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
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _primaryColor,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
