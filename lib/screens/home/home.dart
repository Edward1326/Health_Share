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

      final patientResponse =
          await supabase
              .from('Patient')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();

      String? patientId = patientResponse?['id'];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Beautiful backdrop
          _buildBackdrop(),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : RefreshIndicator(
                          onRefresh: _loadHomeData,
                          color: const Color(0xFF4A7C59),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header section with backdrop
                                _buildHeaderSection(),

                                // Content with white background
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFB),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(30),
                                      topRight: Radius.circular(30),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 28),

                                        // Quick Access Section
                                        _buildSectionHeader(
                                          'Quick Access',
                                          Icons.dashboard_rounded,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildQuickAccessGrid(),
                                        const SizedBox(height: 32),

                                        // Doctors Assigned Section
                                        _buildSectionHeader(
                                          'Your Care Team',
                                          Icons.medical_services_rounded,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDoctorsSection(),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MainNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildBackdrop() {
    return Container(
      height: 340,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A7C59), Color(0xFF5D9B6D), Color(0xFF6BAE7A)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: 50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Pattern overlay
          Positioned.fill(
            child: CustomPaint(painter: _BackdropPatternPainter()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'HealthShare',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Welcome message
          const Text(
            'Welcome Back! 👋',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How are you feeling today?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A7C59), Color(0xFF5D9B6D)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A7C59).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickAccessCard(
                title: _lastAccessedGroup?['name'] ?? 'Join a Group',
                subtitle: 'Connect with others',
                icon: Icons.group_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A7C59), Color(0xFF6BAE7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () {
                  if (_lastAccessedGroup != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => GroupDetailsScreen(
                              groupId: _lastAccessedGroup!['id'],
                              groupName: _lastAccessedGroup!['name'] ?? 'Group',
                              groupData: _lastAccessedGroup!,
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No group joined yet'),
                        behavior: SnackBarBehavior.floating,
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
                    _lastAccessedOrganization?['name'] ?? 'Join Organization',
                subtitle: 'Medical facilities',
                icon: Icons.local_hospital_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B9C9C), Color(0xFF5EC1C1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () {
                  if (_lastAccessedOrganization != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => DoctorsScreen(
                              orgId: _lastAccessedOrganization!['id'],
                              orgName:
                                  _lastAccessedOrganization!['name'] ??
                                  'Organization',
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No organization joined yet'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _QuickAccessCard(
          title: 'Upload Medical Files',
          subtitle: 'Share your health records securely',
          icon: Icons.cloud_upload_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isFullWidth: true,
          onTap: () {
            Navigator.pushNamed(context, '/files');
          },
        ),
      ],
    );
  }

  Widget _buildDoctorsSection() {
    if (_assignedDoctors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4A7C59).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                size: 48,
                color: Color(0xFF4A7C59),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No doctors assigned yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your assigned doctors will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children:
          _assignedDoctors
              .map(
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
              )
              .toList(),
    );
  }
}

class _BackdropPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.03)
          ..style = PaintingStyle.fill;

    // Draw subtle pattern dots
    for (var i = 0; i < 15; i++) {
      for (var j = 0; j < 8; j++) {
        canvas.drawCircle(Offset(i * 40.0, j * 40.0), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickAccessCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        height: widget.isFullWidth ? 110 : 150,
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.gradient.colors.first.withOpacity(0.3),
              blurRadius: _isPressed ? 10 : 15,
              offset: Offset(0, _isPressed ? 4 : 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child:
                  widget.isFullWidth
                      ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 18,
                          ),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 1,
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A7C59), Color(0xFF6BAE7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A7C59).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. $doctorName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (department != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A7C59).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        department,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A7C59),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          organizationName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A7C59).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: const Color(0xFF4A7C59),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
