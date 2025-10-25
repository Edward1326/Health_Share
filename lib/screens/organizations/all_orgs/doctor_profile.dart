import 'dart:ui';
import 'package:flutter/material.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final String organizationName;

  const DoctorProfileScreen({
    super.key,
    required this.doctorData,
    required this.organizationName,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerScaleAnimation;

  // Design tokens - matching OrgDetailsScreen
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

    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  String _formatFullName() {
    final user = widget.doctorData['User'];
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

  String _getInitial() {
    final fullName = _formatFullName();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';
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
                Expanded(child: _buildContent()),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [_primaryColor, _accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
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
                          child: Center(
                            child: Text(
                              _getInitial(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
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
                                'Dr. ${_formatFullName()}',
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
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
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
                                      size: 14,
                                      color: _primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        widget.doctorData['department']
                                                ?.toString()
                                                .trim() ??
                                            'General',
                                        style: TextStyle(
                                          fontSize: 12,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 16,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.organizationName,
                              style: TextStyle(
                                fontSize: 13,
                                color: _primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
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

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactInfo(),
          const SizedBox(height: 16),
          _buildAdditionalInfo(),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    final user = widget.doctorData['User'];
    final email = user?['email'];

    final items = <Map<String, dynamic>>[];

    if (email != null) {
      items.add({
        'icon': Icons.email_outlined,
        'label': 'Email',
        'value': email,
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

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
                  Icons.contact_mail_outlined,
                  size: 22,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Contact Information',
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

  Widget _buildAdditionalInfo() {
    final user = widget.doctorData['User'];
    final person = user?['Person'];

    final items = <Map<String, dynamic>>[];

    final department =
        widget.doctorData['department']?.toString().trim() ?? 'General';
    items.add({
      'icon': Icons.local_hospital_outlined,
      'label': 'Department',
      'value': department,
    });

    if (person != null) {
      final firstName = person['first_name']?.toString().trim();
      final middleName = person['middle_name']?.toString().trim();
      final lastName = person['last_name']?.toString().trim();

      if (firstName != null && firstName.isNotEmpty) {
        items.add({
          'icon': Icons.person_outline,
          'label': 'First Name',
          'value': firstName,
        });
      }

      if (middleName != null && middleName.isNotEmpty) {
        items.add({
          'icon': Icons.person_outline,
          'label': 'Middle Name',
          'value': middleName,
        });
      }

      if (lastName != null && lastName.isNotEmpty) {
        items.add({
          'icon': Icons.person_outline,
          'label': 'Last Name',
          'value': lastName,
        });
      }
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
                  Icons.info_outline,
                  size: 22,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Professional Details',
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
}
