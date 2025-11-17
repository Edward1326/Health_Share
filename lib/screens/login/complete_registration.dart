import 'package:flutter/material.dart';
import 'package:health_share/screens/files/files_main.dart';
import 'package:health_share/services/auth_services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompleteRegistrationScreen extends StatefulWidget {
  final String email;

  const CompleteRegistrationScreen({super.key, required this.email});

  @override
  State<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState extends State<CompleteRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final authService = AuthService();
  final _supabase = Supabase.instance.client;

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Consistent color scheme matching other screens
  static const Color _primaryColor = Color(0xFF416240);
  static const Color _accentColor = Color(0xFFA3B18A);
  static const Color _bg = Color(0xFFF8FAF8);
  static const Color _card = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      } else if (mounted) {
        setState(() => _canResend = true);
      }
    });
  }

  void _handleOtpInput(String value, int index) {
    if (value.length == 1 && value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((c) => c.text).join();
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  void _verifyAndComplete() async {
    final otpCode = _getOtpCode();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (otpCode.length != 6) {
      _showSnackBar(
        'Please enter a valid 6-digit code',
        Icons.warning_amber_rounded,
        Colors.orange[700]!,
      );
      return;
    }

    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      _showSnackBar(
        'Please fill in all required fields',
        Icons.warning_amber_rounded,
        Colors.orange[700]!,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await authService.verifyOTPAndCreateProfile(
        widget.email,
        otpCode,
        firstName,
        middleName,
        lastName,
        phone,
      );

      // Wait and verify profile was created
      print('Waiting for profile creation to complete...');
      await Future.delayed(const Duration(milliseconds: 1000));

      final userId = authService.getCurrentUser()?.id;
      if (userId != null) {
        final profile =
            await _supabase
                .from('User')
                .select()
                .eq('id', userId)
                .maybeSingle();

        if (profile == null) {
          throw Exception('Profile creation failed. Please try again.');
        }

        print('✅ Profile verified to exist');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'Registration completed successfully!',
          Icons.check_circle_rounded,
          _primaryColor,
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const FilesScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          e.toString().contains('Invalid OTP')
              ? 'Invalid OTP code'
              : 'Verification failed. Please try again.',
          Icons.error_outline_rounded,
          Colors.red[700]!,
        );
      }
    }
  }

  void _resendOtp() async {
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });

    try {
      await authService.sendOTP(widget.email);
      _showSnackBar(
        'OTP resent successfully',
        Icons.check_circle_rounded,
        _primaryColor,
      );
      _startResendCountdown();
    } catch (e) {
      _showSnackBar(
        'Failed to resend OTP',
        Icons.error_outline_rounded,
        Colors.red[700]!,
      );
      setState(() => _canResend = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    final isMediumScreen = size.width >= 360 && size.width < 600;
    final isTablet = size.width >= 600;

    // Responsive padding
    final horizontalPadding = isTablet ? 48.0 : (isSmallScreen ? 16.0 : 24.0);
    final maxWidth = isTablet ? 550.0 : double.infinity;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Subtle background gradient matching other screens
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryColor.withOpacity(0.04),
                    _accentColor.withOpacity(0.02),
                    _bg,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: isSmallScreen ? 40 : 60),
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildHeader(isSmallScreen, isMediumScreen),
                          ),
                          SizedBox(height: isSmallScreen ? 30 : 50),
                          SlideTransition(
                            position: _slideAnimation,
                            child: _buildRegistrationCard(
                              isSmallScreen,
                              isMediumScreen,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen, bool isMediumScreen) {
    final iconSize = isSmallScreen ? 70.0 : 90.0;
    final iconInnerSize = isSmallScreen ? 35.0 : 42.0;
    final titleSize = isSmallScreen ? 24.0 : (isMediumScreen ? 28.0 : 32.0);
    final subtitleSize = isSmallScreen ? 14.0 : 16.0;

    return Column(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.app_registration_rounded,
            color: Colors.white,
            size: iconInnerSize,
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 24),
        Text(
          'Complete Registration',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            color: _textPrimary,
            letterSpacing: -0.8,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter code and your details',
          style: TextStyle(
            fontSize: subtitleSize,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard(bool isSmallScreen, bool isMediumScreen) {
    final cardPadding = isSmallScreen ? 20.0 : 28.0;
    final borderRadius = isSmallScreen ? 20.0 : 28.0;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _primaryColor.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _primaryColor.withOpacity(0.04),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primaryColor.withOpacity(0.015),
                    Colors.transparent,
                    _accentColor.withOpacity(0.01),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildEmailBadge(isSmallScreen),
                SizedBox(height: isSmallScreen ? 24 : 32),
                _buildOtpInputFields(isSmallScreen),
                SizedBox(height: isSmallScreen ? 16 : 20),
                _buildResendSection(isSmallScreen),
                SizedBox(height: isSmallScreen ? 24 : 32),
                _buildInputField(
                  label: 'First Name',
                  controller: _firstNameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter first name',
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 14 : 18),
                _buildInputField(
                  label: 'Middle Name',
                  controller: _middleNameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter middle name',
                  isOptional: true,
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 14 : 18),
                _buildInputField(
                  label: 'Last Name',
                  controller: _lastNameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter last name',
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 14 : 18),
                _buildInputField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  hint: '09123456789',
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 24 : 32),
                _buildCompleteButton(isSmallScreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailBadge(bool isSmallScreen) {
    final fontSize = isSmallScreen ? 13.0 : 14.0;
    final emailFontSize = isSmallScreen ? 13.0 : 15.0;
    final padding =
        isSmallScreen
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 16);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: isSmallScreen ? 16 : 18,
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Code sent to',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.email,
            style: TextStyle(
              fontSize: emailFontSize,
              fontWeight: FontWeight.w800,
              color: _primaryColor,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInputFields(bool isSmallScreen) {
    final size = MediaQuery.of(context).size;
    final availableWidth = size.width - (isSmallScreen ? 72 : 104);
    final spacing = isSmallScreen ? 6.0 : 8.0;
    final totalSpacing = spacing * 5;
    final boxWidth = ((availableWidth - totalSpacing) / 6).clamp(40.0, 52.0);
    final boxHeight = isSmallScreen ? 52.0 : 58.0;
    final fontSize = isSmallScreen ? 20.0 : 24.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        6,
        (index) => Flexible(
          child: Container(
            width: boxWidth,
            height: boxHeight,
            margin: EdgeInsets.symmetric(horizontal: spacing / 2),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _otpControllers[index].text.isNotEmpty
                        ? _primaryColor
                        : _primaryColor.withOpacity(0.12),
                width: _otpControllers[index].text.isNotEmpty ? 2 : 1.5,
              ),
              boxShadow:
                  _otpControllers[index].text.isNotEmpty
                      ? [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : [],
            ),
            child: TextField(
              controller: _otpControllers[index],
              focusNode: _otpFocusNodes[index],
              onChanged: (value) {
                setState(() {});
                _handleOtpInput(value, index);
              },
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: _primaryColor,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection(bool isSmallScreen) {
    final textSize = isSmallScreen ? 13.0 : 14.0;
    final buttonPadding =
        isSmallScreen
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final minButtonSize =
        isSmallScreen ? const Size(120, 40) : const Size(140, 44);

    return Column(
      children: [
        Text(
          "Didn't receive the code?",
          style: TextStyle(
            color: _textSecondary,
            fontSize: textSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color:
                _canResend
                    ? _primaryColor.withOpacity(0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  _canResend
                      ? _primaryColor.withOpacity(0.2)
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: TextButton(
            onPressed: _canResend ? _resendOtp : null,
            style: TextButton.styleFrom(
              padding: buttonPadding,
              minimumSize: minButtonSize,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canResend)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: isSmallScreen ? 16 : 18,
                      color: _primaryColor,
                    ),
                  ),
                Flexible(
                  child: Text(
                    _canResend
                        ? 'Resend Code'
                        : 'Resend in ${_resendCountdown}s',
                    style: TextStyle(
                      color: _canResend ? _primaryColor : _textSecondary,
                      fontSize: textSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isSmallScreen,
    TextInputType? keyboardType,
    bool isOptional = false,
    int? maxLength,
  }) {
    final labelSize = isSmallScreen ? 13.0 : 14.0;
    final inputSize = isSmallScreen ? 14.0 : 15.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final verticalPadding = isSmallScreen ? 14.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              if (isOptional)
                Text(
                  ' (Optional)',
                  style: TextStyle(
                    fontSize: labelSize - 1,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _primaryColor.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: TextStyle(
              fontSize: inputSize,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: _primaryColor, size: iconSize),
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: _textSecondary.withOpacity(0.5),
                fontSize: inputSize,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: verticalPadding,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteButton(bool isSmallScreen) {
    final buttonHeight = isSmallScreen ? 52.0 : 56.0;
    final fontSize = isSmallScreen ? 15.0 : 16.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;

    return Container(
      width: double.infinity,
      height: buttonHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyAndComplete,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Complete Registration',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_outline_rounded, size: iconSize),
                  ],
                ),
      ),
    );
  }
}
