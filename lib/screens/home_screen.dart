import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<CheckIn> _todayCheckins = [];
  CheckInStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadTodayCheckins();
  }

  Future<void> _loadTodayCheckins() async {
    try {
      // Get user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/checkins/today/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          _todayCheckins = (data['checkins'] as List?)
              ?.map((item) => CheckIn(
                    id: item['id'] ?? 0,
                    label: item['timing_label'] ?? 'Check-in',
                    scheduledTime: item['scheduled_time'] ?? '',
                    status: item['status'] ?? 'pending',
                    responseTime: item['user_response_time'],
                  ))
              .toList() ?? [];

          _stats = CheckInStats(
            total: data['stats']?['total'] ?? 0,
            completed: data['stats']?['completed'] ?? 0,
            pending: data['stats']?['pending'] ?? 0,
            missed: data['stats']?['missed'] ?? 0,
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load check-ins');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _todayCheckins = [];
          _stats = CheckInStats(total: 0, completed: 0, pending: 0, missed: 0);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot connect to server. Using offline mode.'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    await _loadTodayCheckins();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Safety Check-ins'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 48,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Section
                    _WelcomeCard(
                      colorScheme: colorScheme,
                    ).animate().fadeIn(duration: 500.ms),

                    const SizedBox(height: 24),

                    // Stats Cards
                    if (_stats != null)
                      _StatsSection(
                        stats: _stats!,
                        colorScheme: colorScheme,
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                    const SizedBox(height: 32),

                    // Today's Check-ins Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Check-ins',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Navigate to history
                          },
                          icon: Icon(Icons.history, size: 18),
                          label: Text('View All'),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                    const SizedBox(height: 16),

                    // Check-in List
                    if (_todayCheckins.isEmpty)
                      _EmptyState(colorScheme: colorScheme)
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 600.ms)
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _todayCheckins.length,
                        itemBuilder: (context, index) {
                          final checkin = _todayCheckins[index];
                          return _CheckInCard(
                            checkin: checkin,
                            colorScheme: colorScheme,
                            onTap: () {
                              if (checkin.status == 'pending') {
                                // Navigate to check-in alert screen
                                context.push('/checkin-alert', extra: checkin);
                              }
                            },
                          ).animate().fadeIn(
                            duration: 500.ms,
                            delay: (600 + (index * 100)).ms,
                          ).slideX(
                            begin: -0.1,
                            end: 0,
                            duration: 500.ms,
                            delay: (600 + (index * 100)).ms,
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/schedule');
        },
        icon: Icon(Icons.schedule_rounded),
        label: Text('Manage Schedule'),
      ).animate().scale(duration: 500.ms, delay: 1000.ms),
    );
  }
}

// Welcome Card Widget
class _WelcomeCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _WelcomeCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    IconData icon = Icons.wb_sunny_rounded;

    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      icon = Icons.wb_sunny_outlined;
    } else if (hour >= 17) {
      greeting = 'Good Evening';
      icon = Icons.nightlight_round;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stay safe today!',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

// Stats Section Widget
class _StatsSection extends StatelessWidget {
  final CheckInStats stats;
  final ColorScheme colorScheme;

  const _StatsSection({
    required this.stats,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: stats.completed.toString(),
            color: Colors.green,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.pending_outlined,
            label: 'Pending',
            value: stats.pending.toString(),
            color: Colors.orange,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.cancel_outlined,
            label: 'Missed',
            value: stats.missed.toString(),
            color: Colors.red,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme colorScheme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
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
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// Check-in Card Widget
class _CheckInCard extends StatelessWidget {
  final CheckIn checkin;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _CheckInCard({
    required this.checkin,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = checkin.status == 'pending' || checkin.status == 'snoozed';
    final isCompleted = checkin.status == 'acknowledged_safe';
    final isMissed = checkin.status == 'escalated_no_response';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.info_outline;
    String statusText = 'Unknown';

    if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_outlined;
      statusText = 'Pending';
    } else if (isCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completed';
    } else if (isMissed) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Missed';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isPending ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Time Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkin.label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheduled: ${checkin.scheduledTime}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (checkin.responseTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Completed: ${checkin.responseTime}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
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
}

// Empty State Widget
class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No check-ins scheduled today',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your day off!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// Data Models
class CheckIn {
  final int id;
  final String label;
  final String scheduledTime;
  final String status;
  final String? responseTime;

  CheckIn({
    required this.id,
    required this.label,
    required this.scheduledTime,
    required this.status,
    this.responseTime,
  });
}

class CheckInStats {
  final int total;
  final int completed;
  final int pending;
  final int missed;

  CheckInStats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.missed,
  });
}