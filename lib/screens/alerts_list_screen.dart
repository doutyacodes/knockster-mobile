import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlertsListScreen extends StatefulWidget {
  const AlertsListScreen({super.key});

  @override
  State<AlertsListScreen> createState() => _AlertsListScreenState();
}

class _AlertsListScreenState extends State<AlertsListScreen> {
  bool _isLoading = true;
  List<AlertItem> _allAlerts = [];
  List<AlertItem> _filteredAlerts = [];
  String _selectedFilter = 'all'; // all, critical, high, medium, low
  String _selectedStatus = 'active'; // active, resolved, all

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get org_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final orgId = prefs.getInt('org_id') ?? 1;

      final response = await http.get(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/alerts/active/$orgId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        setState(() {
          _allAlerts = (data['alerts'] as List?)
              ?.map((item) => AlertItem(
                    id: item['alert_id'] ?? 0,
                    userName: item['user_name'] ?? 'Unknown',
                    userPhone: item['user_phone'] ?? '',
                    userPhoto: item['user_profile_pic'],
                    alertType: item['alert_type'] ?? 'no_response_after_snooze',
                    priority: item['priority'] ?? 'medium',
                    status: item['alert_status'] ?? 'pending',
                    sentAt: DateTime.tryParse(item['alert_sent_at'] ?? '') ?? DateTime.now(),
                    checkinDate: item['checkin_date'] ?? '',
                    scheduledTime: item['scheduled_time'] ?? '',
                  ))
              .toList() ?? [];
          _filterAlerts();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load alerts');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allAlerts = [];
          _filterAlerts();
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

  void _filterAlerts() {
    setState(() {
      _filteredAlerts = _allAlerts.where((alert) {
        // Filter by priority
        bool matchesPriority = _selectedFilter == 'all' || 
                               alert.priority == _selectedFilter;
        
        // Filter by status
        bool matchesStatus = _selectedStatus == 'all' ||
                            (_selectedStatus == 'active' && 
                             alert.status != 'resolved' && 
                             alert.status != 'false_alarm') ||
                            (_selectedStatus == 'resolved' && 
                             (alert.status == 'resolved' || 
                              alert.status == 'false_alarm'));
        
        return matchesPriority && matchesStatus;
      }).toList();
      
      // Sort by priority and time
      _filteredAlerts.sort((a, b) {
        final priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
        final priorityCompare = (priorityOrder[a.priority] ?? 99)
            .compareTo(priorityOrder[b.priority] ?? 99);
        if (priorityCompare != 0) return priorityCompare;
        return b.sentAt.compareTo(a.sentAt);
      });
    });
  }

  Future<void> _refresh() async {
    await _loadAlerts();
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} mins ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Active Alerts'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
          IconButton(
            icon: Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: Column(
                children: [
                  // Filter Chips
                  _FilterChips(
                    selectedFilter: _selectedFilter,
                    selectedStatus: _selectedStatus,
                    onFilterChanged: (filter) {
                      setState(() {
                        _selectedFilter = filter;
                        _filterAlerts();
                      });
                    },
                    onStatusChanged: (status) {
                      setState(() {
                        _selectedStatus = status;
                        _filterAlerts();
                      });
                    },
                    colorScheme: colorScheme,
                  ).animate().fadeIn(duration: 300.ms),

                  // Alert Count
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 20 : 48,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_filteredAlerts.length} ${_filteredAlerts.length == 1 ? "Alert" : "Alerts"}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Alerts List
                  Expanded(
                    child: _filteredAlerts.isEmpty
                        ? _EmptyState(
                            colorScheme: colorScheme,
                            filter: _selectedFilter,
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 20 : 48,
                            ),
                            itemCount: _filteredAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = _filteredAlerts[index];
                              return _AlertListCard(
                                alert: alert,
                                colorScheme: colorScheme,
                                timeAgo: _getTimeAgo(alert.sentAt),
                                onTap: () {
                                  context.push('/admin/alert-detail/${alert.id}');
                                },
                              ).animate().fadeIn(
                                duration: 400.ms,
                                delay: (index * 50).ms,
                              ).slideX(
                                begin: -0.1,
                                end: 0,
                                duration: 400.ms,
                                delay: (index * 50).ms,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        selectedFilter: _selectedFilter,
        selectedStatus: _selectedStatus,
        onFilterChanged: (filter) {
          setState(() {
            _selectedFilter = filter;
            _filterAlerts();
          });
          Navigator.pop(context);
        },
        onStatusChanged: (status) {
          setState(() {
            _selectedStatus = status;
            _filterAlerts();
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

// Filter Chips Widget
class _FilterChips extends StatelessWidget {
  final String selectedFilter;
  final String selectedStatus;
  final Function(String) onFilterChanged;
  final Function(String) onStatusChanged;
  final ColorScheme colorScheme;

  const _FilterChips({
    required this.selectedFilter,
    required this.selectedStatus,
    required this.onFilterChanged,
    required this.onStatusChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: selectedFilter == 'all',
            color: colorScheme.primary,
            onTap: () => onFilterChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Critical',
            isSelected: selectedFilter == 'critical',
            color: Colors.red,
            onTap: () => onFilterChanged('critical'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'High',
            isSelected: selectedFilter == 'high',
            color: Colors.orange,
            onTap: () => onFilterChanged('high'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Medium',
            isSelected: selectedFilter == 'medium',
            color: Colors.yellow.shade700,
            onTap: () => onFilterChanged('medium'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Low',
            isSelected: selectedFilter == 'low',
            color: Colors.blue,
            onTap: () => onFilterChanged('low'),
          ),
        ],
      ),
    );
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// Alert List Card Widget
class _AlertListCard extends StatelessWidget {
  final AlertItem alert;
  final ColorScheme colorScheme;
  final String timeAgo;
  final VoidCallback onTap;

  const _AlertListCard({
    required this.alert,
    required this.colorScheme,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color priorityColor = Colors.grey;
    if (alert.priority == 'critical') priorityColor = Colors.red;
    if (alert.priority == 'high') priorityColor = Colors.orange;
    if (alert.priority == 'medium') priorityColor = Colors.yellow.shade700;
    if (alert.priority == 'low') priorityColor = Colors.blue;

    IconData alertIcon = alert.alertType == 'danger_pin_entered'
        ? Icons.warning_amber_rounded
        : Icons.notifications_off;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // User Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: priorityColor.withValues(alpha: 0.1),
                    child: Text(
                      alert.userName[0].toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.userName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.userPhone,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: priorityColor),
                    ),
                    child: Text(
                      alert.priority.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Alert Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: priorityColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(alertIcon, color: priorityColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.alertType == 'danger_pin_entered'
                            ? '🚨 Danger PIN was entered'
                            : 'No response after 3 snooze attempts',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Footer Row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeAgo,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
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
  final String filter;

  const _EmptyState({
    required this.colorScheme,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            filter == 'all' ? 'No Active Alerts' : 'No $filter Alerts',
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

// Filter Bottom Sheet
class _FilterBottomSheet extends StatelessWidget {
  final String selectedFilter;
  final String selectedStatus;
  final Function(String) onFilterChanged;
  final Function(String) onStatusChanged;

  const _FilterBottomSheet({
    required this.selectedFilter,
    required this.selectedStatus,
    required this.onFilterChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Alerts',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Priority',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                isSelected: selectedFilter == 'all',
                color: Colors.grey,
                onTap: () => onFilterChanged('all'),
              ),
              _FilterChip(
                label: 'Critical',
                isSelected: selectedFilter == 'critical',
                color: Colors.red,
                onTap: () => onFilterChanged('critical'),
              ),
              _FilterChip(
                label: 'High',
                isSelected: selectedFilter == 'high',
                color: Colors.orange,
                onTap: () => onFilterChanged('high'),
              ),
              _FilterChip(
                label: 'Medium',
                isSelected: selectedFilter == 'medium',
                color: Colors.yellow.shade700,
                onTap: () => onFilterChanged('medium'),
              ),
              _FilterChip(
                label: 'Low',
                isSelected: selectedFilter == 'low',
                color: Colors.blue,
                onTap: () => onFilterChanged('low'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// Data Model
class AlertItem {
  final int id;
  final String userName;
  final String userPhone;
  final String? userPhoto;
  final String alertType;
  final String priority;
  final String status;
  final DateTime sentAt;
  final String checkinDate;
  final String scheduledTime;

  AlertItem({
    required this.id,
    required this.userName,
    required this.userPhone,
    this.userPhoto,
    required this.alertType,
    required this.priority,
    required this.status,
    required this.sentAt,
    required this.checkinDate,
    required this.scheduledTime,
  });
}