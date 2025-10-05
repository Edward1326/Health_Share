import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:health_share/services/hive_service/public_key_recovery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:health_share/screens/groups/group_details.dart';
import 'package:health_share/screens/organizations/org_doctors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedIndex = 0;

  bool _isLoading = true;
  Map<String, dynamic>? _lastAccessedGroup;
  Map<String, dynamic>? _lastAccessedOrganization;
  List<Map<String, dynamic>> _assignedDoctors = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();

    _loadHomeData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // First, get the patient record for this user
      final patientResponse =
          await supabase
              .from('Patient')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();

      String? patientId = patientResponse?['id'];

      // Fetch last accessed group from Group_Members table
      final groupMemberResponse =
          await supabase
              .from('Group_Members')
              .select('group_id, Group!inner(*)')
              .eq('user_id', user.id)
              .order('added_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (groupMemberResponse != null && groupMemberResponse['Group'] != null) {
        _lastAccessedGroup = groupMemberResponse['Group'];
      }

      // Fetch last accessed organization from Patient table
      final orgResponse =
          await supabase
              .from('Patient')
              .select('organization_id, Organization!inner(id, name)')
              .eq('user_id', user.id)
              .eq('status', 'accepted')
              .order('joined_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (orgResponse != null && orgResponse['Organization'] != null) {
        _lastAccessedOrganization = orgResponse['Organization'];
        print(
          'DEBUG Home: Found organization: ${_lastAccessedOrganization!['name']}',
        );
      } else {
        print('DEBUG Home: No accepted organization found');
      }

      // Fetch assigned doctors only if we have a patient ID
      if (patientId != null) {
        final doctorsResponse = await supabase
            .from('Doctor_User_Assignment')
            .select('''
              id,
              doctor_id,
              status,
              assigned_at,
              Organization_User!doctor_id(
                id,
                department,
                organization_id,
                User!inner(
                  id,
                  email,
                  Person(first_name, middle_name, last_name)
                ),
                Organization!organization_id(name)
              )
            ''')
            .eq('patient_id', patientId)
            .eq('status', 'active')
            .limit(2);

        // Process the doctors response
        _assignedDoctors =
            doctorsResponse.map((assignment) {
              final orgUser = assignment['Organization_User'];
              return {
                'doctor_id': assignment['doctor_id'],
                'user': orgUser['User'],
                'department': orgUser['department'],
                'organization_name':
                    orgUser['Organization']?['name'] ?? 'Unknown Organization',
              };
            }).toList();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading home data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _checkPublicKey() {
    try {
      final wifPostingKey = dotenv.env['HIVE_POSTING_WIF'];

      if (wifPostingKey == null || wifPostingKey.isEmpty) {
        throw Exception('HIVE_POSTING_WIF not found in .env file');
      }

      final pubKey = deriveHivePublicKey(wifPostingKey);

      print("Public Key: $pubKey");
      print("Account Name: ${dotenv.env['HIVE_ACCOUNT_NAME']}");
      print("Node URL: ${dotenv.env['HIVE_NODE_URL']}");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Public key printed to console"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error deriving public key: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Welcome, User',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Icon(
                                Icons.notifications_outlined,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Quick Access Section
                          const Text(
                            'Quick Access',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick Access Cards Grid
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAccessCard(
                                  title:
                                      _lastAccessedGroup?['name'] ??
                                      'Group name',
                                  icon: Icons.group,
                                  onTap: () {
                                    if (_lastAccessedGroup != null) {
                                      // Navigate directly to GroupDetailsScreen with proper parameters
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => GroupDetailsScreen(
                                                groupId:
                                                    _lastAccessedGroup!['id'],
                                                groupName:
                                                    _lastAccessedGroup!['name'] ??
                                                    'Group',
                                                groupData: _lastAccessedGroup!,
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('No group joined yet'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickAccessCard(
                                  title:
                                      _lastAccessedOrganization?['name'] ??
                                      'Organization name',
                                  icon: Icons.business,
                                  onTap: () {
                                    if (_lastAccessedOrganization != null) {
                                      // Navigate to DoctorsScreen (Your Organizations view)
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => DoctorsScreen(
                                                orgId:
                                                    _lastAccessedOrganization!['id'],
                                                orgName:
                                                    _lastAccessedOrganization!['name'] ??
                                                    'Organization',
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No organization joined yet',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Upload File Card
                          Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.48,
                              child: _QuickAccessCard(
                                title: 'Upload a file',
                                icon: Icons.upload_file,
                                onTap: () {
                                  Navigator.pushNamed(context, '/files');
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Doctors Assigned Section
                          const Text(
                            'Doctors Assigned',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_assignedDoctors.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Center(
                                child: Text(
                                  'No doctors assigned yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._assignedDoctors.map(
                              (doctor) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DoctorCard(
                                  doctor: doctor,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/doctor-profile',
                                      arguments: doctor['doctor_id'],
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
          ),
        ),
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D4A3E), Color(0xFF3D2C4A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Decorative illustration
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.3,
                child: Icon(
                  Icons.favorite,
                  size: 100,
                  color: Colors.red.shade300,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onTap;

  const _DoctorCard({required this.doctor, required this.onTap});

  String _formatFullName(Map<String, dynamic> user) {
    final person = user['Person'];
    if (person == null) return user['email'] ?? 'Unknown Doctor';

    final firstName = person['first_name']?.toString().trim() ?? '';
    final middleName = person['middle_name']?.toString().trim() ?? '';
    final lastName = person['last_name']?.toString().trim() ?? '';

    List<String> nameParts = [];
    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    return nameParts.isEmpty
        ? (user['email'] ?? 'Unknown Doctor')
        : nameParts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final doctorUser = doctor['user'];
    final doctorName = _formatFullName(doctorUser);
    final organizationName =
        doctor['organization_name'] ?? 'Unknown Organization';
    final email = doctorUser['email'] ?? '';
    final department = doctor['department'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. $doctorName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (department != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        department,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Joined Aug 9, 2025',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
