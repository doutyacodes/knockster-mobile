import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 48,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),

                    // Success Animation
                    Column(
                      children: [
                        // Animated Success Icon
                        Container(
                          width: 120,
                          height: 120,
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
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 70,
                            color: colorScheme.onPrimary,
                          ),
                        ).animate()
                          .scale(
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          )
                          .then()
                          .shake(
                            duration: 400.ms,
                            hz: 2,
                          ),

                        const SizedBox(height: 40),

                        // Success Message
                        Text(
                          'All Set!',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(
                          duration: 600.ms,
                          delay: 400.ms,
                        ).slideY(
                          begin: 0.3,
                          end: 0,
                          duration: 600.ms,
                          delay: 400.ms,
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Your alert schedule has been saved successfully',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(
                          duration: 600.ms,
                          delay: 600.ms,
                        ),

                        const SizedBox(height: 50),

                        // Info Cards
                        _InfoCard(
                          icon: Icons.notifications_active_rounded,
                          title: 'Alerts Enabled',
                          description: 'You\'ll receive notifications at your scheduled times',
                          colorScheme: colorScheme,
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 800.ms,
                        ).slideX(
                          begin: -0.2,
                          end: 0,
                          duration: 500.ms,
                          delay: 800.ms,
                        ),

                        const SizedBox(height: 16),

                        _InfoCard(
                          icon: Icons.calendar_today_rounded,
                          title: 'Schedule Active',
                          description: 'Alerts will repeat on your selected days',
                          colorScheme: colorScheme,
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 1000.ms,
                        ).slideX(
                          begin: -0.2,
                          end: 0,
                          duration: 500.ms,
                          delay: 1000.ms,
                        ),

                        const SizedBox(height: 16),

                        _InfoCard(
                          icon: Icons.settings_rounded,
                          title: 'Easy to Modify',
                          description: 'Change your schedule anytime from settings',
                          colorScheme: colorScheme,
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 1200.ms,
                        ).slideX(
                          begin: -0.2,
                          end: 0,
                          duration: 500.ms,
                          delay: 1200.ms,
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Action Buttons
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              context.go('/home');
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Go to Dashboard'),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 1400.ms,
                        ).scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                          duration: 500.ms,
                          delay: 1400.ms,
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              context.go('/schedule');
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Edit Schedule',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: 500.ms,
                          delay: 1500.ms,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Info Card Widget
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.2),
                  colorScheme.secondary.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
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
