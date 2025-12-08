import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _safePinController = TextEditingController();
  final _dangerPinController = TextEditingController();
  final _confirmSafePinController = TextEditingController();
  final _confirmDangerPinController = TextEditingController();

  bool _obscureSafePin = true;
  bool _obscureDangerPin = true;
  bool _obscureConfirmSafe = true;
  bool _obscureConfirmDanger = true;

  int _currentStep = 0; // 0: safe PIN, 1: danger PIN

  @override
  void dispose() {
    _safePinController.dispose();
    _dangerPinController.dispose();
    _confirmSafePinController.dispose();
    _confirmDangerPinController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_currentStep == 0) {
      // Validate safe PIN
      if (_safePinController.text.isEmpty) {
        _showError('Please enter a safe PIN');
        return;
      }

      if (_safePinController.text.length < 4 ||
          _safePinController.text.length > 6) {
        _showError('PIN must be 4-6 digits');
        return;
      }

      if (!RegExp(r'^\d+$').hasMatch(_safePinController.text)) {
        _showError('PIN must contain only numbers');
        return;
      }

      if (_safePinController.text != _confirmSafePinController.text) {
        _showError('PINs do not match');
        return;
      }

      // Move to danger PIN step
      setState(() {
        _currentStep = 1;
      });
    } else {
      // Validate danger PIN
      if (_dangerPinController.text.isEmpty) {
        _showError('Please enter a danger PIN');
        return;
      }

      if (_dangerPinController.text.length < 4 ||
          _dangerPinController.text.length > 6) {
        _showError('PIN must be 4-6 digits');
        return;
      }

      if (!RegExp(r'^\d+$').hasMatch(_dangerPinController.text)) {
        _showError('PIN must contain only numbers');
        return;
      }

      if (_dangerPinController.text != _confirmDangerPinController.text) {
        _showError('PINs do not match');
        return;
      }

      if (_safePinController.text == _dangerPinController.text) {
        _showError('Safe and Danger PINs must be different');
        return;
      }

      _savePins();
    }
  }

  Future<void> _savePins() async {
    try {
      // Get user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        _showError('User not logged in. Please login again.');
        return;
      }

      final response = await http.post(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/pins/setup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'safe_pin': _safePinController.text,
          'danger_pin': _dangerPinController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        context.go('/schedule');
      } else {
        final error = jsonDecode(response.body);
        _showError(error['message'] ?? 'Failed to save PINs');
      }
    } catch (e) {
      if (mounted) {
        _showError(
          'Cannot connect to server. Please check if backend is running.',
        );
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
      ),
    );
  }

  Widget _buildSafePinSection() {
    return Column(
      key: const ValueKey(0),
      children: [
        TextField(
          controller: _safePinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: _obscureSafePin,
          decoration: InputDecoration(
            labelText: 'Safe PIN',
            hintText: 'Enter 4-6 digit PIN',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.green.shade700),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSafePin
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureSafePin = !_obscureSafePin;
                });
              },
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmSafePinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: _obscureConfirmSafe,
          decoration: InputDecoration(
            labelText: 'Confirm Safe PIN',
            hintText: 'Re-enter PIN',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.green.shade700),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmSafe
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmSafe = !_obscureConfirmSafe;
                });
              },
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildDangerPinSection() {
    return Column(
      key: const ValueKey(1),
      children: [
        TextField(
          controller: _dangerPinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: _obscureDangerPin,
          decoration: InputDecoration(
            labelText: 'Danger PIN',
            hintText: 'Enter 4-6 digit PIN (different from Safe PIN)',
            prefixIcon: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureDangerPin
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureDangerPin = !_obscureDangerPin;
                });
              },
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmDangerPinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: _obscureConfirmDanger,
          decoration: InputDecoration(
            labelText: 'Confirm Danger PIN',
            hintText: 'Re-enter PIN',
            prefixIcon: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmDanger
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmDanger = !_obscureConfirmDanger;
                });
              },
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Security PINs'),
        leading: _currentStep == 1
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 24 : 48,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Indicator
              _ProgressIndicator(
                currentStep: _currentStep,
                colorScheme: colorScheme,
              ),

              const SizedBox(height: 40),

              // Header Section
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _currentStep == 0
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          _currentStep == 0
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _currentStep == 0
                          ? Icons.shield_outlined
                          : Icons.warning_amber_rounded,
                      size: 40,
                      color: _currentStep == 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _currentStep == 0 ? 'Set Safe PIN' : 'Set Danger PIN',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _currentStep == 0
                        ? 'This PIN confirms you are safe during check-ins'
                        : 'This PIN silently alerts admins if you are in danger',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Info Card
              _InfoCard(
                icon: _currentStep == 0
                    ? Icons.check_circle_outline
                    : Icons.emergency,
                title: _currentStep == 0
                    ? 'Safe PIN Usage'
                    : 'Danger PIN Usage',
                description: _currentStep == 0
                    ? 'Enter this PIN when everything is okay. This confirms your safety to the system.'
                    : 'Enter this PIN if you\'re in danger. The app will look normal but secretly alert admins.',
                colorScheme: colorScheme,
                color: _currentStep == 0 ? Colors.green : Colors.red,
              ),

              const SizedBox(height: 32),

              // PIN Input Section with AnimatedSwitcher
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: (_currentStep == 0)
                    ? _buildSafePinSection()
                    : _buildDangerPinSection(),
              ),

              const SizedBox(height: 40),

              // Continue Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_currentStep == 0 ? 'Continue' : 'Complete Setup'),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 900.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Progress Indicator Widget
class _ProgressIndicator extends StatelessWidget {
  final int currentStep;
  final ColorScheme colorScheme;

  const _ProgressIndicator({
    required this.currentStep,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: currentStep >= 0
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: currentStep >= 1
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

// Info Card Widget
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
