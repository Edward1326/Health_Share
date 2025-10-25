import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;
  final String organizationId;

  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    required this.organizationId,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _fadeController;
  late AnimationController _headerController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerScaleAnimation;

  // Doctor data
  Map<String, dynamic>? _doctorData;
  Map<String, dynamic>? _personData;
  bool _isLoading = true;
  String? _errorMessage;

  // Design tokens matching ProfileScreen
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

    _loadDoctorData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _headerController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔍 Loading doctor data for ID: ${widget.doctorId}');

      // Fetch doctor data with user and person information
      final doctorResponse =
          await _supabase
              .from('Organization_User')
              .select('''
            *,
            User!inner(
              id,
              email,
              Person!inner(
                id,
                first_name,
                middle_name,
                last_name,
                contact_number,
                address,
                sex,
                image
              )
            )
          ''')
              .eq('id', widget.doctorId)
              .eq('organization_id', widget.organizationId)
              .single();

      print('✅ Doctor data loaded successfully');

      if (mounted) {
        setState(() {
          _doctorData = doctorResponse;
          _personData = doctorResponse['User']['Person'];
          _isLoading = false;
        });

        _headerController.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        _fadeController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        _staggerController.forward();
      }
    } catch (e) {
      print('❌ Error loading doctor data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading doctor profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getFullName() {
    if (_personData == null) return 'Loading...';

    final firstName = _personData!['first_name'] ?? '';
    final middleName = _personData!['middle_name'] ?? '';
    final lastName = _personData!['last_name'] ?? '';

    return [
      firstName,
      middleName,
      lastName,
    ].where((name) => name.isNotEmpty).join(' ');
  }

  String _getInitials() {
    if (_personData == null) return 'D';
    final firstName = _personData!['first_name'] ?? '';
    final lastName = _personData!['last_name'] ?? '';

    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0];
    if (lastName.isNotEmpty) initials += lastName[0];

    return initials.toUpperCase();
  }

  String _getUserEmail() {
    return _doctorData?['User']?['email'] ?? 'No email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F0E3), // soft light green top
                  Colors.white, // white bottom
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _primaryColor.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _primaryColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Doctor Profile',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
        ],
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
      onRefresh: _loadDoctorData,
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
                        title: 'Professional Information',
                        icon: Icons.medical_services_outlined,
                        items: [
                          _InfoItem(
                            'Department',
                            _doctorData!['department'] ?? 'Not specified',
                          ),
                          _InfoItem('Full Name', 'Dr. ${_getFullName()}'),
                          _InfoItem('Email', _getUserEmail()),
                          _InfoItem(
                            'Contact',
                            _personData!['contact_number'] ?? 'Not provided',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStaggeredCard(
                      1,
                      _buildInfoSection(
                        title: 'Personal Information',
                        icon: Icons.person_outline_rounded,
                        items: [
                          _InfoItem(
                            'Address',
                            _personData!['address'] ?? 'Not provided',
                          ),
                          _InfoItem(
                            'Sex',
                            _personData!['sex'] ?? 'Not provided',
                          ),
                        ],
                      ),
                    ),
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
            'Loading doctor profile...',
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
              onPressed: _loadDoctorData,
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

  Widget _buildProfileHeader() {
    final imageUrl = _personData?['image'];
    final hasValidImage =
        imageUrl != null && imageUrl.toString().trim().isNotEmpty;

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
                    if (hasValidImage)
                      Container(
                        width: 140,
                        height: 140,
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
                      'Dr. ${_getFullName()}',
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
                            Icons.medical_services_rounded,
                            size: 14,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _doctorData?['department'] ?? 'General Medicine',
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
      width: 140,
      height: 140,
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
                _buildInfoRow(items[index].label, items[index].value),
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

  Widget _buildInfoRow(String label, String value) {
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
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem(this.label, this.value);
}
