import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CheckinAlertScreen extends StatefulWidget {
  final int checkinId;
  final String label;
  final String scheduledTime;

  const CheckinAlertScreen({
    super.key,
    required this.checkinId,
    required this.label,
    required this.scheduledTime,
  });

  @override
  State<CheckinAlertScreen> createState() => _CheckinAlertScreenState();
}

class _CheckinAlertScreenState extends State<CheckinAlertScreen> {
  String _pin = '';
  bool _isVerifying = false;
  final int _maxPinLength = 6;

  void _onNumberTap(String number) {
    if (_pin.length < _maxPinLength) {
      setState(() {
        _pin += number;
      });

      // Auto-submit when PIN is 4-6 digits
      if (_pin.length >= 4) {
        // Optional: Auto-verify after a short delay
        // _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin = '';
    });
  }

  Future<void> _verifyPin() async {
    if (_pin.length < 4) {
      _showError('PIN must be at least 4 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/checkins/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checkin_id': widget.checkinId,
          'pin': _pin,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSuccess();
      } else {
        final error = jsonDecode(response.body);
        _showError(error['message'] ?? 'Invalid PIN. Please try again.');
        setState(() {
          _pin = '';
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Cannot connect to server. Please check if backend is running.');
        setState(() {
          _pin = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 50,
                color: Colors.green.shade700,
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(
              'Check-in Successful',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your safety has been confirmed',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              child: Text('Done'),
            ),
          ),
        ],
      ),
    );
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

  Future<void> _onSnooze() async {
    try {
      await http.put(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/checkins/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checkin_id': widget.checkinId,
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in snoozed for 5 minutes'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in snoozed locally (server offline)'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 24 : 48,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded),
                    onPressed: () => context.go('/home'),
                  ),
                  TextButton.icon(
                    onPressed: _onSnooze,
                    icon: Icon(Icons.snooze, size: 18),
                    label: Text('Snooze'),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              // Alert Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.2),
                      colorScheme.secondary.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 50,
                  color: colorScheme.primary,
                ),
              ).animate().scale(
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Safety Check-in Required',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                '${widget.label} • ${widget.scheduledTime}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

              const SizedBox(height: 8),

              Text(
                'Enter your PIN to confirm you are safe',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

              const SizedBox(height: 40),

              // PIN Display
              _PinDisplay(
                pin: _pin,
                maxLength: _maxPinLength,
                colorScheme: colorScheme,
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms),

              const SizedBox(height: 40),

              // Numeric Keypad
              _NumericKeypad(
                onNumberTap: _onNumberTap,
                onBackspace: _onBackspace,
                onClear: _onClear,
                colorScheme: colorScheme,
                enabled: !_isVerifying,
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying || _pin.length < 4 ? null : _verifyPin,
                  child: _isVerifying
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
                            Icon(Icons.check_circle_outline, size: 24),
                            const SizedBox(width: 12),
                            Text('Confirm Safety'),
                          ],
                        ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 800.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// PIN Display Widget
class _PinDisplay extends StatelessWidget {
  final String pin;
  final int maxLength;
  final ColorScheme colorScheme;

  const _PinDisplay({
    required this.pin,
    required this.maxLength,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        maxLength,
        (index) => Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < pin.length
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: index < pin.length
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        )
            .animate(key: ValueKey('$index-${index < pin.length}'))
            .scale(duration: 200.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

// Numeric Keypad Widget
class _NumericKeypad extends StatelessWidget {
  final Function(String) onNumberTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final ColorScheme colorScheme;
  final bool enabled;

  const _NumericKeypad({
    required this.onNumberTap,
    required this.onBackspace,
    required this.onClear,
    required this.colorScheme,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: '1',
              onTap: () => onNumberTap('1'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              text: '2',
              onTap: () => onNumberTap('2'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              text: '3',
              onTap: () => onNumberTap('3'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: '4',
              onTap: () => onNumberTap('4'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              text: '5',
              onTap: () => onNumberTap('5'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              text: '6',
              onTap: () => onNumberTap('6'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              text: '7',
              onTap: () => onNumberTap('7'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              text: '8',
              onTap: () => onNumberTap('8'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              text: '9',
              onTap: () => onNumberTap('9'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 4: Clear, 0, Backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(
              icon: Icons.clear,
              onTap: onClear,
              colorScheme: colorScheme,
              enabled: enabled,
              isAction: true,
            ),
            _KeypadButton(
              text: '0',
              onTap: () => onNumberTap('0'),
              colorScheme: colorScheme,
              enabled: enabled,
            ),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              colorScheme: colorScheme,
              enabled: enabled,
              isAction: true,
            ),
          ],
        ),
      ],
    );
  }
}

// Keypad Button Widget
class _KeypadButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool enabled;
  final bool isAction;

  const _KeypadButton({
    this.text,
    this.icon,
    required this.onTap,
    required this.colorScheme,
    this.enabled = true,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: enabled
                ? (isAction
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primaryContainer)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        size: 28,
                        color: enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                      )
                    : Text(
                        text ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}