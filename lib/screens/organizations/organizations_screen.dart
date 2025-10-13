import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/screens/organizations/org_details.dart';
import 'package:health_share/screens/organizations/org_doctors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/services/org_services/org_service.dart';
import 'package:health_share/services/org_services/org_membership_service.dart';
import 'package:health_share/services/org_services/org_invitation_service.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _selectedIndex = 3;
  int _selectedTab = 0; // 0: All Orgs, 1: Joined

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _allOrganizations = [];
  List<Map<String, dynamic>> _joinedOrganizations = [];
  List<Map<String, dynamic>> _invitations = [];

  bool _isLoading = false;
  int _invitationCount = 0;

  static const primaryColor = Color(0xFF416240);
  static const lightBg = Color(0xFFF8FAF8);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchAllOrganizations(),
      _fetchJoinedOrganizations(),
      _fetchInvitations(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAllOrganizations() async {
    try {
      final orgs = await OrgService.fetchAllOrgs();
      setState(() => _allOrganizations = orgs);
    } catch (e) {
      _showError('Error loading organizations: $e');
    }
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

  List<Map<String, dynamic>> get _currentOrganizations =>
      _selectedTab == 0 ? _allOrganizations : _joinedOrganizations;

  List<Map<String, dynamic>> get _filteredOrganizations {
    if (_searchQuery.isEmpty) return _currentOrganizations;
    return _currentOrganizations
        .where(
          (org) => (org['name'] ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Organizations',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: primaryColor),
            onPressed: _fetchInitialData,
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.mail_outline_rounded,
                  color:
                      _invitationCount > 0
                          ? primaryColor
                          : primaryColor.withOpacity(0.5),
                ),
                onPressed: _showInvitationsDialog,
              ),
              if (_invitationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
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
            ],
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildTabs(isWide),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildSearchBar(),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                      : _filteredOrganizations.isEmpty
                      ? _buildEmptyState()
                      : _buildOrgGrid(isWide),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildTabs(bool isWide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: lightBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildTabButton('All Organizations', 0, Icons.apartment_rounded),
            _buildTabButton('Your Organizations', 1, Icons.groups_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index, IconData icon) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        color: Colors.white,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search organizations...',
          hintStyle: TextStyle(color: primaryColor.withOpacity(0.4)),
          prefixIcon: Icon(Icons.search, color: primaryColor.withOpacity(0.5)),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: primaryColor.withOpacity(0.5),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOrgGrid(bool isWide) {
    final orgs = _filteredOrganizations;
    final crossAxisCount = isWide ? 2 : 1;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isWide ? 2.8 : 2.3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: orgs.length,
      itemBuilder: (context, i) => _buildOrgCard(orgs[i]),
    );
  }

  Widget _buildOrgCard(Map<String, dynamic> org) {
    final joined = _selectedTab == 1;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (c) =>
                      joined
                          ? DoctorsScreen(
                            orgId: org['id'],
                            orgName: org['name'],
                          )
                          : OrgDetailsScreen(
                            orgId: org['id'],
                            orgName: org['name'],
                          ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: lightBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  joined ? Icons.verified_user_rounded : Icons.business_rounded,
                  color: primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org['name'] ?? 'Unnamed Organization',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      org['description'] ?? 'No description available',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryColor.withOpacity(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (joined)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Joined',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apartment_rounded,
            size: 80,
            color: primaryColor.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedTab == 1
                ? 'No organizations joined yet'
                : 'No organizations found',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTab == 1
                ? 'Accept an invitation to join an organization'
                : 'Try refreshing or checking later',
            style: TextStyle(color: primaryColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  void _showInvitationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.mail_outline_rounded, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'Invitations',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child:
                _invitations.isEmpty
                    ? const Text('No pending invitations')
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          _invitations.map((inv) {
                            final name =
                                inv['Organization']?['name'] ?? 'Unknown Org';
                            return Card(
                              color: lightBg,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.business_rounded,
                                  color: primaryColor,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _handleInvitation(
                                          inv['id'].toString(),
                                          'accepted',
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _handleInvitation(
                                          inv['id'].toString(),
                                          'declined',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: primaryColor,
      ),
    );
  }
}
