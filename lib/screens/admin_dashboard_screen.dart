import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  AlertStats? _stats;
  List<Alert> _recentAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Get org_id from SharedPreferences (saved during login)
      final prefs = await SharedPreferences.getInstance();
      // For now, use org_id = 1 as default. TODO: Save org_id during login
      final orgId = prefs.getInt('org_id') ?? 1;

      final response = await http.get(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/alerts/active/$orgId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          _stats = AlertStats(
            critical: data['stats']?['critical'] ?? 0,
            high: data['stats']?['high'] ?? 0,
            medium: data['stats']?['medium'] ?? 0,
            low: data['stats']?['low'] ?? 0,
            total: data['stats']?['total'] ?? 0,
          );

          // Get recent alerts (first 5 from the alerts list)
          _recentAlerts = (data['alerts'] as List?)
              ?.take(5)
              .map((item) => Alert(
                    id: item['alert_id'] ?? 0,
                    userName: item['user_name'] ?? 'Unknown',
                    userPhone: item['user_phone'] ?? '',
                    alertType: item['alert_type'] ?? 'no_response_after_snooze',
                    priority: item['priority'] ?? 'medium',
                    sentAt: item['alert_sent_at'] ?? '',
                    status: item['alert_status'] ?? 'pending',
                  ))
              .toList() ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load dashboard data');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stats = AlertStats(critical: 0, high: 0, medium: 0, low: 0, total: 0);
          _recentAlerts = [];
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
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      drawer: _AdminDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
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
                    _AdminWelcomeCard(
                      colorScheme: colorScheme,
                    ).animate().fadeIn(duration: 500.ms),

                    const SizedBox(height: 24),

                    // Alert Stats Grid
                    if (_stats != null)
                      _AlertStatsGrid(
                        stats: _stats!,
                        colorScheme: colorScheme,
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                    const SizedBox(height: 32),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.group_outlined,
                            label: 'Manage Users',
                            color: Colors.blue,
                            onTap: () {
                              // TODO: Navigate to user management
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.schedule_outlined,
                            label: 'View Schedules',
                            color: Colors.purple,
                            onTap: () {
                              // TODO: Navigate to schedules
                            },
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                    const SizedBox(height: 32),

                    // Recent Alerts Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Alerts',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.push('/admin/alerts');
                          },
                          child: Text('View All'),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

                    const SizedBox(height: 16),

                    // Alert List
                    if (_recentAlerts.isEmpty)
                      _EmptyState(colorScheme: colorScheme)
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentAlerts.length,
                        itemBuilder: (context, index) {
                          final alert = _recentAlerts[index];
                          return _AlertCard(
                            alert: alert,
                            colorScheme: colorScheme,
                            onTap: () {
                              context.push('/admin/alert-detail/${alert.id}');
                            },
                          ).animate().fadeIn(
                            duration: 500.ms,
                            delay: (800 + (index * 100)).ms,
                          ).slideX(
                            begin: -0.1,
                            end: 0,
                            duration: 500.ms,
                            delay: (800 + (index * 100)).ms,
                          );
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// Admin Welcome Card
class _AdminWelcomeCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _AdminWelcomeCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade700,
            Colors.deepPurple.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
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
              Icons.admin_panel_settings,
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
                  'Admin Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor & Manage Safety',
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

// Alert Stats Grid
class _AlertStatsGrid extends StatelessWidget {
  final AlertStats stats;
  final ColorScheme colorScheme;

  const _AlertStatsGrid({
    required this.stats,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'Critical',
          value: stats.critical.toString(),
          color: Colors.red,
          icon: Icons.warning_amber_rounded,
        ),
        _StatCard(
          label: 'High',
          value: stats.high.toString(),
          color: Colors.orange,
          icon: Icons.error_outline,
        ),
        _StatCard(
          label: 'Medium',
          value: stats.medium.toString(),
          color: Colors.yellow.shade700,
          icon: Icons.info_outline,
        ),
        _StatCard(
          label: 'Low',
          value: stats.low.toString(),
          color: Colors.blue,
          icon: Icons.notifications_outlined,
        ),
      ],
    );
  }
}

// Stat Card
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Quick Action Card
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Alert Card (same as before but simplified)
class _AlertCard extends StatelessWidget {
  final Alert alert;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _AlertCard({
    required this.alert,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color priorityColor = Colors.grey;
    if (alert.priority == 'critical') priorityColor = Colors.red;
    if (alert.priority == 'high') priorityColor = Colors.orange;
    if (alert.priority == 'medium') priorityColor = Colors.yellow.shade700;
    if (alert.priority == 'low') priorityColor = Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  alert.alertType == 'danger_pin_entered'
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_off,
                  color: priorityColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.userName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.alertType == 'danger_pin_entered'
                          ? '🚨 Danger PIN entered'
                          : 'No response after snooze',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.sentAt,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Empty State
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
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Alerts',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All employees are safe',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// Admin Drawer
class _AdminDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Admin Panel',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications_active),
            title: Text('Alerts'),
            onTap: () {
              Navigator.pop(context);
              context.push('/admin/alerts');
            },
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('User Management'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to user management
            },
          ),
          ListTile(
            leading: Icon(Icons.business),
            title: Text('Organization'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to organization
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to settings
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: () {
              // TODO: Logout
            },
          ),
        ],
      ),
    );
  }
}

// Data Models
class AlertStats {
  final int critical;
  final int high;
  final int medium;
  final int low;
  final int total;

  AlertStats({
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
    required this.total,
  });
}

class Alert {
  final int id;
  final String userName;
  final String userPhone;
  final String alertType;
  final String priority;
  final String sentAt;
  final String status;

  Alert({
    required this.id,
    required this.userName,
    required this.userPhone,
    required this.alertType,
    required this.priority,
    required this.sentAt,
    required this.status,
  });
}