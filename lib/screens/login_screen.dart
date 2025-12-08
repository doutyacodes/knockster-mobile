import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ FIXED: Correct API response structure
        final userData = data['data'];
        final user = userData['user'];
        final profile = userData['profile'];
        final organizations = userData['organizations'] as List;
        final needsPinSetup = userData['needs_pin_setup'] ?? false;

        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', user['id']);
        await prefs.setString('email', user['email']);
        if (profile != null) {
          await prefs.setString('full_name', profile['full_name'] ?? '');
          await prefs.setString('phone', profile['phone'] ?? '');
        }

        // Save org_id for admins
        if (organizations.isNotEmpty) {
          await prefs.setInt('org_id', organizations.first['org_id']);
        }

        // Register device token for push notifications
        try {
          final notificationService = FirebaseNotificationService();
          final deviceType = Platform.isAndroid ? 'android' : 'ios';
          await notificationService.registerDeviceToken(user['id'], deviceType);
          print('✅ Device token registered for user ${user['id']}');
        } catch (e) {
          print('⚠️ Failed to register device token: $e');
          // Don't block login if token registration fails
        }

        // Check if user is admin (has org_admin or super_admin role)
        bool isAdmin = organizations.any((org) =>
          org['role_name'] == 'org_admin' ||
          org['role_name'] == 'super_admin' ||
          org['role_name'] == 'moderator'
        );

        // Subscribe to organization topics for admins
        if (isAdmin && organizations.isNotEmpty) {
          try {
            final notificationService = FirebaseNotificationService();
            final orgId = organizations.first['org_id'];
            await notificationService.subscribeToTopic('org_${orgId}_alerts');
            print('✅ Subscribed to admin alerts for org $orgId');
          } catch (e) {
            print('⚠️ Failed to subscribe to admin topics: $e');
          }
        }

        // Navigate based on user type and setup status
        if (isAdmin) {
          // Admin users go to admin dashboard
          context.go('/admin/dashboard');
        } else {
          // Regular users - check if they need PIN setup
          if (needsPinSetup) {
            context.go('/pin-setup');
          } else {
            context.go('/home');
          }
        }
      } else {
        final error = jsonDecode(response.body);
        _showError(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (mounted) {
        _showError('Cannot connect to server. Please check if backend is running.\nError: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 24 : 48,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),

                      // Logo & Title Section
                      Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 50,
                              color: colorScheme.onPrimary,
                            ),
                          ).animate().scale(
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          ),

                          const SizedBox(height: 24),

                          Text(
                            'Knockster',
                            style: GoogleFonts.inter(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 200.ms,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Stay Safe, Stay Connected',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 400.ms,
                          ),
                        ],
                      ),

                      const SizedBox(height: 60),

                      // Login Form
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: colorScheme.primary,
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 600.ms,
                          ).slideX(
                            begin: -0.2,
                            end: 0,
                            duration: 600.ms,
                            delay: 600.ms,
                          ),

                          const SizedBox(height: 20),

                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !_isLoading,
                            onSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: colorScheme.primary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 700.ms,
                          ).slideX(
                            begin: -0.2,
                            end: 0,
                            duration: 600.ms,
                            delay: 700.ms,
                          ),

                          const SizedBox(height: 12),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // TODO: Add forgot password logic
                              },
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.inter(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 800.ms,
                          ),

                          const SizedBox(height: 32),

                          // Login Button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          colorScheme.onPrimary,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('Sign In'),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                            ),
                          ).animate().fadeIn(
                            duration: 600.ms,
                            delay: 900.ms,
                          ).scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                            duration: 600.ms,
                            delay: 900.ms,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.inter(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // TODO: Navigate to sign up screen
                            },
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.inter(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(
                        duration: 600.ms,
                        delay: 1000.ms,
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 