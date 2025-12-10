import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = true;
  List<ScheduleTiming> _existingTimings = [];
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadExistingTimings();
  }

  Future<void> _loadExistingTimings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id');

      if (_userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/schedule/user/$_userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final timings = data['data']['timings'] as List;

        setState(() {
          _existingTimings = timings.map((t) => ScheduleTiming.fromJson(t)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTiming(int timingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Schedule'),
        content: Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _userId != null) {
      try {
        final response = await http.delete(
          Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/schedule/user/$_userId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'timing_id': timingId}),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          _showSuccess('Schedule deleted successfully');
          _loadExistingTimings(); // Reload
        } else {
          _showError('Failed to delete schedule');
        }
      } catch (e) {
        if (mounted) {
          _showError('Cannot connect to server');
        }
      }
    }
  }

  void _showAddEditDialog({ScheduleTiming? existingTiming}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditTimingDialog(
        userId: _userId!,
        existingTiming: existingTiming,
        onSaved: () {
          _loadExistingTimings();
          Navigator.pop(context);
        },
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      appBar: AppBar(
        title: Text('Manage Schedules'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadExistingTimings,
                child: _existingTimings.isEmpty
                    ? _EmptyState(
                        colorScheme: colorScheme,
                        onAddPressed: () => _showAddEditDialog(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 20 : 48,
                          vertical: 24,
                        ),
                        itemCount: _existingTimings.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Schedules',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Manage your safety check-in timings',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                SizedBox(height: 24),
                              ],
                            );
                          }

                          final timing = _existingTimings[index - 1];
                          return _TimingCard(
                            timing: timing,
                            colorScheme: colorScheme,
                            onEdit: () => _showAddEditDialog(existingTiming: timing),
                            onDelete: () => _deleteTiming(timing.id),
                          ).animate().fadeIn(
                            duration: 400.ms,
                            delay: (index * 100).ms,
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: !_isLoading && _userId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(),
              icon: Icon(Icons.add_rounded),
              label: Text('Add Schedule'),
            ).animate().scale(duration: 400.ms)
          : null,
    );
  }
}

// Empty State Widget
class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onAddPressed;

  const _EmptyState({
    required this.colorScheme,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
            SizedBox(height: 24),
            Text(
              'No Schedules Yet',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Create your first safety check-in schedule',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAddPressed,
              icon: Icon(Icons.add_rounded),
              label: Text('Add Schedule'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Timing Card Widget
class _TimingCard extends StatelessWidget {
  final ScheduleTiming timing;
  final ColorScheme colorScheme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimingCard({
    required this.timing,
    required this.colorScheme,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }

  String _formatDays(List<String> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains('saturday') && !days.contains('sunday')) {
      return 'Weekdays';
    }
    final shortNames = {
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };
    return days.map((d) => shortNames[d.toLowerCase()] ?? d).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.2),
                        colorScheme.secondary.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timing.label,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatTime(timing.time),
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: 8),
                  Text(
                    _formatDays(timing.activeDays),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add/Edit Timing Dialog
class _AddEditTimingDialog extends StatefulWidget {
  final int userId;
  final ScheduleTiming? existingTiming;
  final VoidCallback onSaved;

  const _AddEditTimingDialog({
    required this.userId,
    this.existingTiming,
    required this.onSaved,
  });

  @override
  State<_AddEditTimingDialog> createState() => _AddEditTimingDialogState();
}

class _AddEditTimingDialogState extends State<_AddEditTimingDialog> {
  final _labelController = TextEditingController();
  TimeOfDay? _selectedTime;
  final Set<int> _selectedDays = {};
  bool _isSaving = false;

  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _dayNamesMap = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  @override
  void initState() {
    super.initState();
    if (widget.existingTiming != null) {
      _labelController.text = widget.existingTiming!.label;

      // Parse time
      final timeParts = widget.existingTiming!.time.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );

      // Parse days
      for (var day in widget.existingTiming!.activeDays) {
        final index = _dayNamesMap.indexOf(day.toLowerCase());
        if (index >= 0) {
          _selectedDays.add(index);
        }
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _toggleDay(int index) {
    setState(() {
      if (_selectedDays.contains(index)) {
        _selectedDays.remove(index);
      } else {
        _selectedDays.add(index);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_labelController.text.trim().isEmpty) {
      _showError('Please enter a label');
      return;
    }

    if (_selectedTime == null) {
      _showError('Please select a time');
      return;
    }

    if (_selectedDays.isEmpty) {
      _showError('Please select at least one day');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final time = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      final activeDays = _selectedDays.map((i) => _dayNamesMap[i]).toList();

      http.Response response;

      if (widget.existingTiming != null) {
        // Update existing
        response = await http.put(
          Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/schedule/user/${widget.userId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'timing_id': widget.existingTiming!.id,
            'label': _labelController.text.trim(),
            'time': time,
            'active_days': activeDays,
          }),
        );
      } else {
        // Create new
        response = await http.post(
          Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/schedule/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': widget.userId,
            'label': _labelController.text.trim(),
            'time': time,
            'active_days': activeDays,
          }),
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSaved();
      } else {
        final error = jsonDecode(response.body);
        _showError(error['message'] ?? 'Failed to save schedule');
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Cannot connect to server');
        setState(() {
          _isSaving = false;
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
      ),
    );
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingTiming != null ? 'Edit Schedule' : 'Add Schedule',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),

              // Label Field
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g., Morning Check-in',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              SizedBox(height: 20),

              // Time Picker
              InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: colorScheme.primary),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _formatTime(_selectedTime),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Days Selection
              Text(
                'Active Days',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final isSelected = _selectedDays.contains(index);
                  return InkWell(
                    onTap: () => _toggleDay(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dayNames[index],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Save'),
                    ),
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

// Data Model
class ScheduleTiming {
  final int id;
  final String label;
  final String time;
  final List<String> activeDays;

  ScheduleTiming({
    required this.id,
    required this.label,
    required this.time,
    required this.activeDays,
  });

  factory ScheduleTiming.fromJson(Map<String, dynamic> json) {
    return ScheduleTiming(
      id: json['id'],
      label: json['label'] ?? 'Check-in',
      time: json['time'] ?? '',
      activeDays: (json['active_days'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
