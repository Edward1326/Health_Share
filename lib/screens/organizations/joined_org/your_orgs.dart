import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/screens/organizations/joined_org/org_doctors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/org_services/org_membership_service.dart';
import 'package:health_share/services/org_services/org_invitation_service.dart';

class YourOrgsScreen extends StatefulWidget {
  const YourOrgsScreen({super.key});

  @override
  State<YourOrgsScreen> createState() => _YourOrgsScreenState();
}

class _YourOrgsScreenState extends State<YourOrgsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _toggleIconController;

  int _selectedIndex = 3;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _joinedOrganizations = [];
  List<Map<String, dynamic>> _invitations = [];

  bool _isLoading = false;
  int _invitationCount = 0;
  bool _isList = true;

  // --- Updated color palette ---
  static const primaryColor = Color(0xFF03989E);
  static const accentColor = Color(0xFF4DC5C8);
  static const lightBg = Color(0xFFF6FAFA);
  static const borderColor = Color(0xFFE3E8E8);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _toggleIconController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeController.forward();
    _slideController.forward();
    _toggleIconController.value = _isList ? 0.0 : 1.0;

    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchJoinedOrganizations(), _fetchInvitations()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchJoinedOrganizations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final orgs = await OrgMembershipService.fetchJoinedOrgs(user.id);
      setState(() => _joinedOrganizations = orgs);
    } catch (e) {
      _showError('Error loading joined organizations: $e');
    }
  }

  Future<void> _fetchInvitations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final invites = await OrgInvitationService.fetchUserInvitations(user.id);
      setState(() {
        _invitations = invites;
        _invitationCount = invites.length;
      });
    } catch (e) {
      _showError('Error loading invitations: $e');
    }
  }

  Future<void> _handleInvitation(String id, String status) async {
    try {
      if (status == 'accepted') {
        await OrgInvitationService.acceptInvitation(id);
      } else {
        await OrgInvitationService.declineInvitation(id);
      }
      await _fetchInitialData();
      _showSuccess(
        status == 'accepted' ? 'Invitation accepted!' : 'Invitation declined.',
      );
    } catch (e) {
      _showError('Failed to process invitation: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredOrganizations {
    if (_searchQuery.isEmpty) return _joinedOrganizations;
    return _joinedOrganizations
        .where(
          (org) => (org['name'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 2;
  }

  void _toggleLayout() {
    setState(() {
      _isList = !_isList;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _toggleIconController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final isLargeScreen = screenWidth > 900;

    final titleFontSize = isLargeScreen ? 24.0 : (isTablet ? 22.0 : 20.0);
    final toolbarHeight = isDesktop ? 84.0 : 140.0;

    return Scaffold(
      backgroundColor: lightBg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(toolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 12,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search + invitations row
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged:
                                      (v) => setState(() => _searchQuery = v),
                                  decoration: const InputDecoration(
                                    hintText: 'Search organizations',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Invitation icon with badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.mail_outline_rounded,
                              color:
                                  _invitationCount > 0
                                      ? primaryColor
                                      : primaryColor.withOpacity(0.55),
                              size: 24,
                            ),
                            onPressed: _showInvitationsDialog,
                          ),
                        ),
                        if (_invitationCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.6,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  '$_invitationCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My Organizations',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                      ),
                    ),
                    // Animated toggle icon
                    GestureDetector(
                      onTap: _toggleLayout,
                      child: AnimatedBuilder(
                        animation: _toggleIconController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _toggleIconController.value * 0.5 * 3.14159,
                            child: Icon(
                              _isList
                                  ? Icons.grid_view_rounded
                                  : Icons.view_list_rounded,
                              color: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.5,
                    ),
                  )
                  : _filteredOrganizations.isEmpty
                  ? _buildEmptyState()
                  : _isList
                  ? _buildOrgList()
                  : _buildOrgGrid(),
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  // ---------------- List view (matches OrgsScreen style) ----------------
  Widget _buildOrgList() {
    final orgs = _filteredOrganizations;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth > 900 ? 60.0 : (screenWidth > 600 ? 40.0 : 16.0);

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      itemCount: orgs.length,
      itemBuilder: (context, i) {
        final org = orgs[i];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 250 + (i * 40)),
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
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => DoctorsScreen(
                          orgId: org['id'],
                          orgName: org['name'],
                        ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      child: Image.network(
                        org['image'] ?? '',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: primaryColor.withOpacity(0.08),
                              child: Icon(
                                Icons.business_rounded,
                                color: primaryColor.withOpacity(0.4),
                                size: 40,
                              ),
                            ),
                      ),
                    ),

                    // Right content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              org['name'] ?? 'Unnamed Organization',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              org['description'] ?? 'No description available',
                              style: TextStyle(
                                fontSize: 13,
                                color: primaryColor.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
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

  // ---------------- Grid view (matches OrgsScreen style) ----------------
  Widget _buildOrgGrid() {
    final orgs = _filteredOrganizations;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth > 900 ? 60.0 : (screenWidth > 600 ? 40.0 : 16.0);

    final crossAxisCount = _getCrossAxisCount(context);

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: orgs.length,
      itemBuilder: (context, i) {
        final org = orgs[i];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 250 + (i * 40)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(scale: 0.9 + (value * 0.1), child: child),
            );
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          DoctorsScreen(orgId: org['id'], orgName: org['name']),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        org['image'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: primaryColor.withOpacity(0.08),
                              child: Icon(
                                Icons.business_rounded,
                                color: primaryColor.withOpacity(0.4),
                                size: 50,
                              ),
                            ),
                      ),
                    ),
                  ),

                  // Bottom details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            org['name'] ?? 'Unnamed Organization',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: primaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            org['description'] ?? 'No description available',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor.withOpacity(0.7),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- Empty state ----------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_rounded,
                color: primaryColor.withOpacity(0.3),
                size: 56,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No organizations joined yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Accept an invitation or browse all organizations to join',
              style: TextStyle(
                fontSize: 15,
                color: primaryColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Invitations dialog ----------------
  void _showInvitationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Invitations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child:
                _invitations.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 64,
                            color: primaryColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending invitations',
                            style: TextStyle(
                              fontSize: 16,
                              color: primaryColor.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _invitations.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final inv = _invitations[index];
                        final name =
                            inv['Organization']?['name'] ?? 'Unknown Org';
                        return Container(
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.06),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _handleInvitation(
                                          inv['id'].toString(),
                                          'accepted',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _handleInvitation(
                                          inv['id'].toString(),
                                          'declined',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.cancel_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Decline'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        side: const BorderSide(
                                          color: Colors.red,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }
  }

  void _showSuccess(String msg) {
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
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }
  }
}
