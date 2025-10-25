import 'package:flutter/material.dart';
import 'package:health_share/screens/login/login.dart';
import 'package:health_share/screens/registration/email_verification.dart';
import 'package:health_share/screens/home/home.dart';
import 'package:health_share/services/auth_services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final authService = AuthService();

  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Consistent color scheme with LoginScreen
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailLower = email.toLowerCase();
    return emailLower.contains('@gmail.com') ||
        emailLower.contains('@yahoo.com');
  }

  bool _isValidPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s-]'), '');
    return cleanPhone.length == 11 && RegExp(r'^\d{11}$').hasMatch(cleanPhone);
  }

  bool _isStrongPassword(String password) {
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final isLengthValid = password.length >= 8;

    return hasUppercase &&
        hasLowercase &&
        hasNumbers &&
        hasSpecialChar &&
        isLengthValid;
  }

  String _getPasswordErrorMessage(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return '';
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

  void register() async {
    if (_isLoading) return;

    if (_emailController.text.trim().isEmpty ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      _showSnackBar(
        'Please fill in all required fields',
        Icons.warning_amber_rounded,
        Colors.orange[700]!,
      );
      return;
    }

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_isValidEmail(email)) {
      _showSnackBar(
        'Email must be from @gmail.com or @yahoo.com',
        Icons.error_outline_rounded,
        Colors.red[700]!,
      );
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      _showSnackBar(
        'Phone number must be exactly 11 digits',
        Icons.error_outline_rounded,
        Colors.red[700]!,
      );
      return;
    }

    if (!_isStrongPassword(password)) {
      final errorMessage = _getPasswordErrorMessage(password);
      _showSnackBar(
        errorMessage,
        Icons.error_outline_rounded,
        Colors.red[700]!,
      );
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar(
        'Passwords do not match',
        Icons.error_outline_rounded,
        Colors.red[700]!,
      );
      return;
    }

    setState(() => _isLoading = true);

    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    try {
      await authService.signUpWithEmailOnly(email, password);

      if (mounted) {
        setState(() => _isLoading = false);

        _showSnackBar(
          'Check your email for OTP',
          Icons.check_circle_rounded,
          _primaryColor,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EmailVerificationScreen(
                    email: email,
                    firstName: firstName,
                    middleName: middleName,
                    lastName: lastName,
                    phone: phone,
                  ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'Error: $e',
          Icons.error_outline_rounded,
          Colors.red[700]!,
        );
      }
    }
  }

  void _signUpWithGoogle() async {
    if (_isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);

    try {
      final authResponse = await authService.signInWithGoogle();

      if (authResponse.user != null && mounted) {
        _showSnackBar(
          'Registration successful!',
          Icons.check_circle_rounded,
          _primaryColor,
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e.toString().contains('cancelled')
              ? 'Sign-Up cancelled'
              : 'Google Sign-Up failed',
          Icons.error_outline_rounded,
          Colors.red[700]!,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Subtle background gradient
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildHeader(),
                      ),
                      const SizedBox(height: 36),
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildRegisterCard(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
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
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Health Share',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _textPrimary,
            letterSpacing: -0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Create your account',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
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
                borderRadius: BorderRadius.circular(28),
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
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputField(
                  label: 'Email Address',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  hint: 'your.email@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
                _buildInputField(
                  label: 'First Name',
                  controller: _firstNameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter first name',
                ),
                const SizedBox(height: 18),
                _buildInputField(
                  label: 'Middle Name',
                  controller: _middleNameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter middle name',
                  isOptional: true,
                ),
                const SizedBox(height: 18),
                _buildInputField(
                  label: 'Last Name',
                  controller: _lastNameController,
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter last name',
                ),
                const SizedBox(height: 18),
                _buildInputField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  hint: '09123456789',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 18),
                _buildPasswordField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onToggle:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 12),
                _buildPasswordStrengthIndicator(),
                const SizedBox(height: 18),
                _buildPasswordField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  onToggle:
                      () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                ),
                const SizedBox(height: 32),
                _buildRegisterButton(),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildGoogleButton(),
                const SizedBox(height: 28),
                _buildLoginPrompt(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              if (isOptional)
                Text(
                  ' (Optional)',
                  style: TextStyle(
                    fontSize: 12,
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
            style: const TextStyle(
              fontSize: 15,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: _primaryColor, size: 20),
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: _textSecondary.withOpacity(0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: 0.2,
            ),
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
            obscureText: obscureText,
            onChanged: (value) => setState(() {}),
            style: const TextStyle(
              fontSize: 15,
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textSecondary.withOpacity(0.6),
                  size: 20,
                ),
              ),
              hintText: 'Enter your password',
              hintStyle: TextStyle(
                color: _textSecondary.withOpacity(0.5),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    final hasLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    // Only show if user has started typing
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: _primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Password Requirements',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRequirementCheck('At least 8 characters', hasLength),
          _buildRequirementCheck('One uppercase letter (A-Z)', hasUppercase),
          _buildRequirementCheck('One lowercase letter (a-z)', hasLowercase),
          _buildRequirementCheck('One number (0-9)', hasNumbers),
          _buildRequirementCheck(
            'One special character (!@#\$%^&*)',
            hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCheck(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? _primaryColor : _textSecondary.withOpacity(0.2),
              border: Border.all(
                color: isMet ? _primaryColor : _textSecondary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                isMet ? Icons.check : Icons.close,
                size: 11,
                color: isMet ? Colors.white : _textSecondary.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 13,
                color: isMet ? _primaryColor : _textSecondary,
                fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Container(
      width: double.infinity,
      height: 56,
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
        onPressed: _isLoading || _isGoogleLoading ? null : register,
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
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, _primaryColor.withOpacity(0.15)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor.withOpacity(0.15), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading || _isGoogleLoading ? null : _signUpWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: _textPrimary,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child:
            _isGoogleLoading
                ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _primaryColor,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/assets/google_logo.png',
                      height: 22,
                      width: 22,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: Text(
              'Login',
              style: TextStyle(
                color: _primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
