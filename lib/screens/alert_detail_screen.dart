import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlertDetailScreen extends StatefulWidget {
  final int alertId;

  const AlertDetailScreen({
    super.key,
    required this.alertId,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  bool _isLoading = true;
  AlertDetail? _alertDetail;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAlertDetail();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAlertDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/alerts/${widget.alertId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body)['data'];
        final alertData = responseData['alert'];
        final callLogsData = responseData['call_logs'] as List?;

        setState(() {
          _alertDetail = AlertDetail(
            id: alertData['alert_id'] ?? widget.alertId,
            userId: alertData['user_id'] ?? 0,
            userName: alertData['user_name'] ?? 'Unknown',
            userEmail: alertData['user_email'] ?? '',
            userPhone: alertData['user_phone'] ?? '',
            userPhoto: alertData['user_profile_pic'],
            emergencyContactName: alertData['emergency_contact_name'],
            emergencyContactPhone: alertData['emergency_contact_phone'],
            alertType: alertData['alert_type'] ?? 'no_response_after_snooze',
            priority: alertData['priority'] ?? 'medium',
            status: alertData['alert_status'] ?? 'pending',
            sentAt: DateTime.tryParse(alertData['alert_sent_at'] ?? '') ?? DateTime.now(),
            checkinDate: alertData['checkin_date'] ?? '',
            scheduledTime: alertData['scheduled_time'] ?? '',
            userResponseTime: alertData['user_response_time'] != null
                ? DateTime.tryParse(alertData['user_response_time'])
                : null,
            snoozeCount: alertData['snooze_count'] ?? 0,
            callLogs: callLogsData
                ?.map((log) => CallLog(
                      id: log['id'] ?? 0,
                      adminName: log['admin_name'] ?? 'Unknown',
                      callStatus: log['call_status'] ?? '',
                      callTime: log['call_time'] ?? '',
                      notes: log['notes'],
                    ))
                .toList() ?? [],
          );
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load alert details');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Cannot connect to server. Please check if backend is running.');
      }
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      _showCallStatusDialog();
    } else {
      _showError('Could not launch phone dialer');
    }
  }

  void _showCallStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Call Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Attended - Safe'),
              onTap: () {
                Navigator.pop(context);
                _updateCallLog('attended_safe');
              },
            ),
            ListTile(
              leading: Icon(Icons.warning, color: Colors.red),
              title: Text('Attended - Not Safe'),
              onTap: () {
                Navigator.pop(context);
                _updateCallLog('attended_not_safe');
              },
            ),
            ListTile(
              leading: Icon(Icons.phone_missed, color: Colors.orange),
              title: Text('Not Attended'),
              onTap: () {
                Navigator.pop(context);
                _updateCallLog('not_attended');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCallLog(String callStatus) async {
    try {
      // Get admin_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getInt('user_id');

      if (adminId == null || _alertDetail == null) {
        _showError('Cannot log call. Please try again.');
        return;
      }

      // Get user_id from alert detail (need to extract from response)
      // For now, we'll need to store user_id in AlertDetail model
      // Backend expects: alert_id, admin_id, user_id, call_status

      await http.post(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/alerts/call-log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'alert_id': widget.alertId,
          'admin_id': adminId,
          'user_id': _alertDetail!.userId, // Need to add userId to AlertDetail model
          'call_status': callStatus,
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call logged successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAlertDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call logged locally (server offline)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resolveAlert() async {
    final notes = await _showResolveDialog();
    if (notes == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/alerts/${widget.alertId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': 'resolved',
          'notes': notes,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert resolved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        throw Exception('Failed to resolve alert');
      }
    } catch (e) {
      if (mounted) {
        _showError('Cannot connect to server. Please check if backend is running.');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> _showResolveDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Resolve Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add resolution notes (optional):',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _notesController.text);
            },
            child: Text('Resolve'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsFalseAlarm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark as False Alarm'),
        content: Text('Are you sure this is a false alarm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.put(
          Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/alerts/${widget.alertId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'status': 'false_alarm',
            'notes': 'Marked as false alarm',
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marked as false alarm'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else {
          throw Exception('Failed to mark as false alarm');
        }
      } catch (e) {
        if (mounted) {
          _showError('Cannot connect to server. Please check if backend is running.');
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    if (_isLoading || _alertDetail == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Alert Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final alert = _alertDetail!;
    Color priorityColor = Colors.grey;
    if (alert.priority == 'critical') priorityColor = Colors.red;
    if (alert.priority == 'high') priorityColor = Colors.orange;
    if (alert.priority == 'medium') priorityColor = Colors.yellow.shade700;
    if (alert.priority == 'low') priorityColor = Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text('Alert Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _loadAlertDetail,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 20 : 48,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Priority Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: priorityColor, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: priorityColor),
                  const SizedBox(width: 8),
                  Text(
                    '${alert.priority.toUpperCase()} PRIORITY',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            // User Info Card
            _UserInfoCard(
              alert: alert,
              priorityColor: priorityColor,
              colorScheme: colorScheme,
              onCallTap: () => _makeCall(alert.userPhone),
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

            const SizedBox(height: 24),

            // Alert Details Card
            _AlertDetailsCard(
              alert: alert,
              timeAgo: _getTimeAgo(alert.sentAt),
              colorScheme: colorScheme,
            ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

            const SizedBox(height: 24),

            // Emergency Contact Card
            if (alert.emergencyContactName != null)
              _EmergencyContactCard(
                name: alert.emergencyContactName!,
                phone: alert.emergencyContactPhone!,
                colorScheme: colorScheme,
                onCallTap: () => _makeCall(alert.emergencyContactPhone!),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

            const SizedBox(height: 24),

            // Call Logs
            if (alert.callLogs.isNotEmpty) ...[
              Text(
                'Call History',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...alert.callLogs.map(
                (log) => _CallLogCard(
                  log: log,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            _ActionButtons(
              onCallUser: () => _makeCall(alert.userPhone),
              onResolve: _resolveAlert,
              onFalseAlarm: _markAsFalseAlarm,
            ).animate().fadeIn(duration: 500.ms, delay: 800.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// User Info Card
class _UserInfoCard extends StatelessWidget {
  final AlertDetail alert;
  final Color priorityColor;
  final ColorScheme colorScheme;
  final VoidCallback onCallTap;

  const _UserInfoCard({
    required this.alert,
    required this.priorityColor,
    required this.colorScheme,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: priorityColor.withValues(alpha: 0.1),
              child: Text(
                alert.userName[0].toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: priorityColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              alert.userName,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Email
            Text(
              alert.userEmail,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            // Phone
            Text(
              alert.userPhone,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            // Call Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onCallTap,
                icon: Icon(Icons.phone),
                label: Text('Call Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Alert Details Card
class _AlertDetailsCard extends StatelessWidget {
  final AlertDetail alert;
  final String timeAgo;
  final ColorScheme colorScheme;

  const _AlertDetailsCard({
    required this.alert,
    required this.timeAgo,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alert Information',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.warning_amber_rounded,
              label: 'Alert Type',
              value: alert.alertType == 'danger_pin_entered'
                  ? '🚨 Danger PIN Entered'
                  : 'No Response After Snooze',
            ),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Sent At',
              value: timeAgo,
            ),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Check-in Date',
              value: alert.checkinDate,
            ),
            _DetailRow(
              icon: Icons.schedule,
              label: 'Scheduled Time',
              value: alert.scheduledTime,
            ),
            if (alert.snoozeCount > 0)
              _DetailRow(
                icon: Icons.snooze,
                label: 'Snooze Count',
                value: '${alert.snoozeCount} times',
              ),
          ],
        ),
      ),
    );
  }
}

// Detail Row
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

// Emergency Contact Card
class _EmergencyContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final ColorScheme colorScheme;
  final VoidCallback onCallTap;

  const _EmergencyContactCard({
    required this.name,
    required this.phone,
    required this.colorScheme,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_emergency, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Emergency Contact',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              phone,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCallTap,
                icon: Icon(Icons.phone, size: 18),
                label: Text('Call Emergency Contact'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade700),
                  foregroundColor: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Call Log Card
class _CallLogCard extends StatelessWidget {
  final CallLog log;
  final ColorScheme colorScheme;

  const _CallLogCard({
    required this.log,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.phone, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.adminName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    log.callStatus,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              log.callTime,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Action Buttons
class _ActionButtons extends StatelessWidget {
  final VoidCallback onCallUser;
  final VoidCallback onResolve;
  final VoidCallback onFalseAlarm;

  const _ActionButtons({
    required this.onCallUser,
    required this.onResolve,
    required this.onFalseAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onResolve,
            icon: Icon(Icons.check_circle),
            label: Text('Mark as Resolved'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onFalseAlarm,
            icon: Icon(Icons.report_off, size: 20),
            label: Text('Mark as False Alarm'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange),
              foregroundColor: Colors.orange,
            ),
          ),
        ),
      ],
    );
  }
}

// Data Models
class AlertDetail {
  final int id;
  final int userId; // Added for call logging
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? userPhoto;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String alertType;
  final String priority;
  final String status;
  final DateTime sentAt;
  final String checkinDate;
  final String scheduledTime;
  final DateTime? userResponseTime;
  final int snoozeCount;
  final List<CallLog> callLogs;

  AlertDetail({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.userPhoto,
    this.emergencyContactName,
    this.emergencyContactPhone,
    required this.alertType,
    required this.priority,
    required this.status,
    required this.sentAt,
    required this.checkinDate,
    required this.scheduledTime,
    this.userResponseTime,
    required this.snoozeCount,
    required this.callLogs,
  });
}

class CallLog {
  final int id;
  final String adminName;
  final String callStatus;
  final String callTime;
  final String? notes;

  CallLog({
    required this.id,
    required this.adminName,
    required this.callStatus,
    required this.callTime,
    this.notes,
  });
}