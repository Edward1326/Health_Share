import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/screens/organizations/org_details.dart';
import 'package:health_share/screens/organizations/org_doctors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import services
import 'package:health_share/services/org_services/org_service.dart';
import 'package:health_share/services/org_services/org_membership_service.dart';
import 'package:health_share/services/org_services/org_invitation_service.dart';

class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key});

  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 3;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _allOrganizations = [];
  List<Map<String, dynamic>> _joinedOrganizations = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _isLoading = false;
  int _invitationCount = 0;

  int _selectedTab = 0;

  // Color Scheme
  static const Color primaryGreen = Color(0xFF4A7C59);
  static const Color lightGreen = Color(0xFF6B9B7A);
  static const Color paleGreen = Color(0xFFE8F5E9);
  static const Color accentGreen = Color(0xFF2E5C3F);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchAllOrganizations(), _fetchInvitations()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAllData() async {
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
      final organizations = await OrgService.fetchAllOrgs();

      setState(() {
        _allOrganizations = organizations;
      });

      print('DEBUG: Loaded ${_allOrganizations.length} organizations');
    } catch (e) {
      print('DEBUG: Error loading all organizations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading organizations: ${e.toString()}'),
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

  Future<void> _fetchJoinedOrganizations() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final organizations = await OrgMembershipService.fetchJoinedOrgs(
        currentUser.id,
      );

      setState(() {
        _joinedOrganizations = organizations;
      });

      print(
        'DEBUG: Successfully loaded ${_joinedOrganizations.length} joined organizations',
      );
    } catch (e, stackTrace) {
      print('DEBUG: Error in _fetchJoinedOrganizations: $e');
      print('DEBUG: Stack trace: $stackTrace');
      setState(() => _joinedOrganizations = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading joined organizations: ${e.toString()}',
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

  Future<void> _fetchInvitations() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final invitations = await OrgInvitationService.fetchUserInvitations(
        currentUser.id,
      );

      setState(() {
        _invitations = invitations;
        _invitationCount = _invitations.length;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invitations: ${e.toString()}'),
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

  Future<void> _handleInvitationResponse(
    String invitationId,
    String status,
  ) async {
    try {
      if (status == 'accepted') {
        await OrgInvitationService.acceptInvitation(invitationId);
      } else {
        await OrgInvitationService.declineInvitation(invitationId);
      }

      await _fetchAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == 'accepted' ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  status == 'accepted'
                      ? 'Invitation accepted successfully!'
                      : 'Invitation declined',
                ),
              ],
            ),
            backgroundColor:
                status == 'accepted' ? primaryGreen : Colors.orange[700],
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
            content: Text('Error: ${e.toString()}'),
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

  void _showInvitationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, paleGreen.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryGreen, lightGreen],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.mail,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invitations',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_invitations.length} pending',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      _invitations.isEmpty
                          ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: paleGreen,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_circle_outline,
                                      size: 64,
                                      color: primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'All caught up!',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No pending invitations',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _invitations.length,
                            itemBuilder: (context, index) {
                              final invitation = _invitations[index];
                              final orgName =
                                  invitation['Organization']?['name'] ??
                                  'Unknown Organization';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: paleGreen,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryGreen.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  primaryGreen,
                                                  lightGreen,
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Icon(
                                              Icons.business,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  orgName,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Invited ${_formatDate(invitation['created_at'])}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                _handleInvitationResponse(
                                                  invitation['id'].toString(),
                                                  'accepted',
                                                );
                                                Navigator.pop(context);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryGreen,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check, size: 20),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Accept',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                _handleInvitationResponse(
                                                  invitation['id'].toString(),
                                                  'declined',
                                                );
                                                Navigator.pop(context);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    Colors.red[600],
                                                side: BorderSide(
                                                  color: Colors.red[600]!,
                                                  width: 2,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.close, size: 20),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Decline',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'today';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  List<Map<String, dynamic>> get _currentOrganizations {
    return _selectedTab == 0 ? _allOrganizations : _joinedOrganizations;
  }

  List<Map<String, dynamic>> get _filteredOrganizations {
    final orgs = _currentOrganizations;
    if (_searchQuery.isEmpty) return orgs;
    return orgs
        .where(
          (org) => (org['name'] ?? '').toString().toLowerCase().contains(
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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              paleGreen.withOpacity(0.3),
              Colors.white,
              paleGreen.withOpacity(0.2),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildTabSelector(),
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      Expanded(
                        child:
                            _isLoading
                                ? Center(
                                  child: CircularProgressIndicator(
                                    color: primaryGreen,
                                  ),
                                )
                                : _buildOrganizationsList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, lightGreen],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organizations',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Discover & Connect',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        await _fetchAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text('Organizations refreshed'),
                                ],
                              ),
                              backgroundColor: primaryGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _showInvitationsDialog,
                          icon: Icon(
                            Icons.mail_outline,
                            color:
                                _invitationCount > 0
                                    ? Colors.white
                                    : Colors.white70,
                            size: 24,
                          ),
                        ),
                      ),
                      if (_invitationCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            child: Text(
                              '$_invitationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedTab != 0) {
                    setState(() {
                      _selectedTab = 0;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient:
                        _selectedTab == 0
                            ? LinearGradient(colors: [primaryGreen, lightGreen])
                            : null,
                    color: _selectedTab == 0 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow:
                        _selectedTab == 0
                            ? [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore,
                        size: 20,
                        color:
                            _selectedTab == 0 ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color:
                              _selectedTab == 0
                                  ? Colors.white
                                  : Colors.grey[600],
                        ),
                      ),
                      if (_selectedTab == 0 &&
                          _allOrganizations.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_allOrganizations.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedTab != 1) {
                    setState(() {
                      _selectedTab = 1;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                    if (_joinedOrganizations.isEmpty) {
                      _fetchJoinedOrganizations();
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient:
                        _selectedTab == 1
                            ? LinearGradient(colors: [primaryGreen, lightGreen])
                            : null,
                    color: _selectedTab == 1 ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow:
                        _selectedTab == 1
                            ? [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color:
                            _selectedTab == 1 ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Joined',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color:
                              _selectedTab == 1
                                  ? Colors.white
                                  : Colors.grey[600],
                        ),
                      ),
                      if (_selectedTab == 1 &&
                          _joinedOrganizations.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_joinedOrganizations.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: paleGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextFormField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: TextStyle(color: Colors.grey[800], fontSize: 16),
          decoration: InputDecoration(
            hintText:
                _selectedTab == 0
                    ? 'Search all organizations...'
                    : 'Search your organizations...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
            prefixIcon: Icon(Icons.search, color: primaryGreen, size: 24),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[400],
                        size: 22,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationsList() {
    final filteredOrgs = _filteredOrganizations;
    if (filteredOrgs.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: filteredOrgs.length,
      itemBuilder: (context, index) {
        final org = filteredOrgs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildOrganizationCard(org),
        );
      },
    );
  }

  Widget _buildOrganizationCard(Map<String, dynamic> org) {
    final isJoined = _selectedTab == 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isJoined) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => DoctorsScreen(
                      orgId: org['id'],
                      orgName: org['name'] ?? 'No Name',
                    ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => OrgDetailsScreen(
                      orgId: org['id'],
                      orgName: org['name'] ?? 'No Name',
                    ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, paleGreen.withOpacity(0.2)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isJoined ? primaryGreen.withOpacity(0.3) : paleGreen,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          isJoined
                              ? [primaryGreen, lightGreen]
                              : [paleGreen, lightGreen.withOpacity(0.3)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isJoined ? Icons.verified : Icons.business,
                    color: isJoined ? Colors.white : primaryGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              org['name'] ?? 'No Name',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (isJoined)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryGreen, lightGreen],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Member',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        org['description'] ?? 'No description available',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: paleGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: primaryGreen,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isJoinedTab = _selectedTab == 1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
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
                isJoinedTab ? Icons.business_outlined : Icons.search_off,
                color: primaryGreen,
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isJoinedTab
                  ? 'No organizations joined yet'
                  : _searchQuery.isNotEmpty
                  ? 'No organizations found'
                  : 'No organizations available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isJoinedTab
                  ? 'Accept invitations or explore\norganizations to get started'
                  : _searchQuery.isNotEmpty
                  ? 'Try searching with different keywords'
                  : 'Check back later for new organizations',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (isJoinedTab) ...[
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => setState(() => _selectedTab = 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 8,
                  shadowColor: primaryGreen.withOpacity(0.4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.explore, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Explore Organizations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
