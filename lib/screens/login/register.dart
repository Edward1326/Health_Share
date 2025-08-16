import 'package:flutter/material.dart';
import 'package:health_share/screens/login/login.dart';
import 'package:health_share/services/auth_services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

bool _isLoading = false;

class _RegisterScreenState extends State<RegisterScreen> {
  final authService = AuthService();

  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void register() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await authService.signUpWithEmailPassword(
        email,
        password,
        firstName,
        middleName,
        lastName,
        phone,
      );

      Navigator.pop(context);
      setState(() => _isLoading = false);

      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      Navigator.popUntil(context, (route) => route.isFirst);
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign up',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Social Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SocialIconButton(icon: Icons.g_mobiledata),
                const SizedBox(width: 20),
                _SocialIconButton(icon: Icons.facebook),
                const SizedBox(width: 20),
                _SocialIconButton(icon: Icons.apple),
              ],
            ),
            const SizedBox(height: 16),
            const Center(child: Text('Or, Register with an Email')),
            const SizedBox(height: 24),

            // Email ID
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email_outlined, color: Colors.teal),
                hintText: 'Email ID',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // First Name
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: Colors.teal),
                hintText: 'First Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Middle Name
            TextField(
              controller: _middleNameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: Colors.teal),
                hintText: 'Middle Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Last Name
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: Colors.teal),
                hintText: 'Last Name',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Number
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined, color: Colors.teal),
                hintText: 'Phone Number',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.security_outlined, color: Colors.teal),
                hintText: 'Password',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.security_outlined, color: Colors.teal),
                hintText: 'Confirm Password',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Signup Button
            ElevatedButton(
              onPressed: _isLoading ? null : register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Signup', style: TextStyle(fontSize: 18)),
            ),
            const Spacer(),

            // Already signed up? Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already Signed up? '),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;

  const _SocialIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey.shade200,
      child: Icon(icon, color: Colors.black, size: 28),
    );
  }
}
