import 'package:flutter/material.dart';
import 'package:health_share/components/navbar_main.dart';
import 'package:health_share/screens/profile/change_password.dart';
import 'package:health_share/screens/profile/edit_profile.dart';
import 'package:health_share/services/auth_services/auth_gate.dart';
import 'package:health_share/services/auth_services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _fadeController;
  late AnimationController _headerController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerScaleAnimation;

  int _selectedIndex = 4;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  // Design tokens matching OrgDetailsScreen
  static const Color _primaryColor = Color(0xFF416240);
  static const Color _accentColor = Color(0xFFA3B18A);
  static const Color _bg = Color(0xFFF8FAF8);
  static const Color _card = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _headerSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _headerScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
    );

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final response =
          await _supabase
              .from('Person')
              .select('*')
              .eq('auth_user_id', user.id)
              .single();

      if (mounted) {
        setState(() {
          _userData = response;
          _isLoading = false;
        });

        _headerController.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        _fadeController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        _staggerController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _headerController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  String _getFullName() {
    if (_userData == null) return 'Loading...';
    final firstName = _userData!['first_name'] ?? '';
    final middleName = _userData!['middle_name'] ?? '';
    final lastName = _userData!['last_name'] ?? '';
    return [
      firstName,
      middleName,
      lastName,
    ].where((n) => n.isNotEmpty).join(' ');
  }

  String _getInitials() {
    if (_userData == null) return '?';
    final firstName = _userData!['first_name'] ?? '';
    final lastName = _userData!['last_name'] ?? '';
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0];
    if (lastName.isNotEmpty) initials += lastName[0];
    return initials.toUpperCase();
  }

  String _getUserEmail() {
    return _supabase.auth.currentUser?.email ?? 'No email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 320,
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
              children: [_buildAppBar(context), Expanded(child: _buildBody())],
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_userData != null)
            _buildIconButton(
              icon: Icons.edit_outlined,
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => EditProfileScreen(userData: _userData!),
                  ),
                );
                if (result == true) {
                  _loadUserData();
                }
              },
            ),
          const SizedBox(width: 12),
          _buildIconButton(icon: Icons.refresh_rounded, onTap: _loadUserData),
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

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildStaggeredCard(
                      0,
                      _buildInfoSection(
                        title: 'Personal Information',
                        icon: Icons.person_outline_rounded,
                        items: [
                          _InfoItem('Full Name', _getFullName()),
                          _InfoItem('Email', _getUserEmail()),
                          _InfoItem(
                            'Contact',
                            _userData!['contact_number'] ?? 'Not provided',
                          ),
                          _InfoItem(
                            'Address',
                            _userData!['address'] ?? 'Not provided',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStaggeredCard(
                      1,
                      _buildInfoSection(
                        title: 'Medical Information',
                        icon: Icons.medical_information_outlined,
                        items: [
                          _InfoItem(
                            'Blood Type',
                            _userData!['blood_type'] ?? 'Not provided',
                          ),
                          _InfoItem('Sex', _userData!['sex'] ?? 'Not provided'),
                          _InfoItem(
                            'Allergies',
                            _formatArrayValue(_userData!['allergies']),
                          ),
                          _InfoItem(
                            'Medical Conditions',
                            _formatArrayValue(_userData!['medical_conditions']),
                          ),
                          _InfoItem(
                            'Disabilities',
                            _formatArrayValue(_userData!['disabilities']),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStaggeredCard(2, _buildActionSection()),
                    const SizedBox(height: 20),
                    _buildStaggeredCard(3, _buildLogoutButton()),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaggeredCard(int index, Widget child) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final progress = (_staggerController.value - (index * 0.1)).clamp(
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
      child: child,
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
            'Loading profile...',
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

  Widget _buildProfileHeader() {
    final imageUrl = _userData?['image'];

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
            borderRadius: BorderRadius.circular(24),
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
                    borderRadius: BorderRadius.circular(24),
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
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    if (imageUrl != null && imageUrl.toString().isNotEmpty)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _primaryColor.withOpacity(0.12),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    _buildFallbackAvatar(),
                          ),
                        ),
                      )
                    else
                      _buildFallbackAvatar(),
                    const SizedBox(height: 20),
                    Text(
                      _getFullName(),
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.email_rounded,
                            size: 14,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _getUserEmail(),
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
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
          const SizedBox(height: 20),
          ...List.generate(
            items.length,
            (index) => Column(
              children: [
                _buildInfoItem(items[index].label, items[index].value),
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

  Widget _buildInfoItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _formatArrayValue(dynamic values) {
    if (values == null) return 'Not provided';
    if (values is List && values.isNotEmpty) return values.join(', ');
    if (values is String && values.isNotEmpty) return values;
    return 'Not provided';
  }

  Widget _buildActionSection() {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Update your account security',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _showLogoutDialog,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.red,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.15),
                    Colors.red.withOpacity(0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 15,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: _primaryColor.withOpacity(0.3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Retry',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: _card,
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from your account?',
            style: TextStyle(
              fontSize: 15,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: _textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthGate()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.error_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Error signing out: $e',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem(this.label, this.value);
}
