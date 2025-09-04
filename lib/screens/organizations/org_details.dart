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
      appBar: AppBar(
        title: Text(orgName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              orgName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667EEA),
              ),
            ),
            const SizedBox(height: 32),
            // Add more organization details here later
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _joinOrganization(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Join Organization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
