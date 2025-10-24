import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/company_provider.dart';
import '../core/enums/user_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(1.0), // Prevent text scaling issues
        ),
        child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000B58), // Deep navy blue
              Color(0xFF35BF8C), // Bright green
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Title Section
                const Text(
                  'HR Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Users are managed by your company administrator',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 60),

                // Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Username Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                              letterSpacing: 0.0,
                              height: 1.25,
                              fontFamily: 'Roboto',
                              decoration: TextDecoration.none,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Username',
                            hintStyle: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.0,
                              fontFamily: 'Roboto',
                            ),
                              prefixIcon: Icon(
                                Icons.person_outlined,
                                color: Color(0xFF000B58),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Password Field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                              letterSpacing: 0.0,
                              height: 1.25,
                              fontFamily: 'Roboto',
                              decoration: TextDecoration.none,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.0,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outlined,
                                color: Color(0xFF000B58),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF000B58),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Sign In Button
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  authProvider.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: authProvider.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Color(0xFF000B58),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Roboto',
                                        letterSpacing: 0.0,
                                        height: 1.2,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),

                      // Error Message
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          if (authProvider.error != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        authProvider.error!,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Help Text
                const Text(
                  'Need access? Contact your company administrator',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    print('=== LOGIN ATTEMPT START ===');
    print('Username: ${_usernameController.text.trim()}');

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    // Store provider references before async operations
    final authProvider = context.read<AuthProvider>();
    final companyProvider = context.read<CompanyProvider>();

    try {
      print('Calling authProvider.login...');
      final result = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      print('Login result - isSuccess: ${result.isSuccess}');
      print('Login result - companies: ${result.companies?.length ?? 0}');

      if (result.isSuccess && result.companies != null) {
        companyProvider.setAvailableCompanies(result.companies!);

        if (result.companies!.length == 1) {
          print('Single company found - navigating to dashboard');
          print('User role: ${result.companies!.first.userRole}');

          // Single company - go directly to dashboard
          await authProvider.setCurrentCompany(result.companies!.first);
          companyProvider.setCurrentCompany(result.companies!.first);

          // Check if context is still mounted before navigation
          if (mounted) {
            _navigateToDashboard(result.companies!.first.userRole);
          }
        } else {
          print('Multiple companies found - showing selection screen');
          // Multiple companies - show selection screen
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/company-selection',
              arguments: result.companies,
            );
          }
        }
      } else {
        print('Login failed - result.isSuccess: ${result.isSuccess}');
        print('Error message: ${result.errorMessage}');
      }
    } catch (e) {
      print('Exception during login: $e');
      _showErrorDialog('An error occurred: ${e.toString()}');
    }

    print('=== LOGIN ATTEMPT END ===');
  }

  void _navigateToDashboard(UserRole role) {
    switch (role) {
      case UserRole.employee:
        Navigator.pushReplacementNamed(context, '/employee-dashboard');
        break;
      case UserRole.hr:
        Navigator.pushReplacementNamed(context, '/hr-dashboard');
        break;
      case UserRole.manager:
        Navigator.pushReplacementNamed(context, '/manager-dashboard');
        break;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
