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
  TimeOfDay? _alertTime1;
  TimeOfDay? _alertTime2;
  final Set<int> _selectedDays = {};

  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    // Set default times
    _alertTime1 = const TimeOfDay(hour: 9, minute: 0);
    _alertTime2 = const TimeOfDay(hour: 18, minute: 0);
  }

  Future<void> _selectTime(BuildContext context, bool isFirstTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isFirstTime
          ? (_alertTime1 ?? TimeOfDay.now())
          : (_alertTime2 ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFirstTime) {
          _alertTime1 = picked;
        } else {
          _alertTime2 = picked;
        }
      });
    }
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      if (_selectedDays.contains(dayIndex)) {
        _selectedDays.remove(dayIndex);
      } else {
        _selectedDays.add(dayIndex);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_selectedDays.isEmpty) {
      _showError('Please select at least one day');
      return;
    }

    try {
      // Get user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        _showError('User not logged in. Please login again.');
        return;
      }

      // Convert day indices to day names expected by backend
      final dayNamesMap = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final activeDays = _selectedDays.map((index) => dayNamesMap[index]).toList();

      // Create schedule for first alert time
      if (_alertTime1 != null) {
        final time1 = '${_alertTime1!.hour.toString().padLeft(2, '0')}:${_alertTime1!.minute.toString().padLeft(2, '0')}:00';

        await http.post(
          Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/schedule/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'label': 'Morning Check-in',
            'time': time1,
            'active_days': activeDays,
          }),
        );
      }

      // Create schedule for second alert time
      if (_alertTime2 != null) {
        final time2 = '${_alertTime2!.hour.toString().padLeft(2, '0')}:${_alertTime2!.minute.toString().padLeft(2, '0')}:00';

        final response = await http.post(
          Uri.parse('https://knockster-safety.vercel.app/api/mobile-api/schedule/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'label': 'Evening Check-in',
            'time': time2,
            'active_days': activeDays,
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          context.go('/success');
        } else {
          final error = jsonDecode(response.body);
          _showError(error['message'] ?? 'Failed to save schedule');
        }
      } else {
        if (mounted) {
          context.go('/success');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Cannot connect to server. Please check if backend is running.');
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

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select Time';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Alerts'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
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
              // Header Section
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
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
                      Icons.schedule_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ).animate().scale(
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Set Your Alert Times',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

                  const SizedBox(height: 8),

                  Text(
                    'Choose two times per day and select active days',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                ],
              ),

              const SizedBox(height: 40),

              // Time Pickers Section
              _TimePickerCard(
                title: 'First Alert Time',
                subtitle: 'Morning reminder',
                time: _alertTime1,
                timeString: _formatTime(_alertTime1),
                icon: Icons.wb_sunny_rounded,
                onTap: () => _selectTime(context, true),
                colorScheme: colorScheme,
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideX(
                begin: -0.1,
                end: 0,
                duration: 500.ms,
                delay: 400.ms,
              ),

              const SizedBox(height: 20),

              _TimePickerCard(
                title: 'Second Alert Time',
                subtitle: 'Evening reminder',
                time: _alertTime2,
                timeString: _formatTime(_alertTime2),
                icon: Icons.nightlight_round,
                onTap: () => _selectTime(context, false),
                colorScheme: colorScheme,
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideX(
                begin: -0.1,
                end: 0,
                duration: 500.ms,
                delay: 500.ms,
              ),

              const SizedBox(height: 40),

              // Days Selection Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Days',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 600.ms),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(
                      7,
                      (index) => _DayChip(
                        day: _dayNames[index],
                        isSelected: _selectedDays.contains(index),
                        onTap: () => _toggleDay(index),
                        colorScheme: colorScheme,
                      ).animate().fadeIn(
                        duration: 400.ms,
                        delay: (700 + (index * 50)).ms,
                      ).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 400.ms,
                        delay: (700 + (index * 50)).ms,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 24),
                      const SizedBox(width: 12),
                      Text('Save Schedule'),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 1100.ms).scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                duration: 500.ms,
                delay: 1100.ms,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Time Picker Card Widget
class _TimePickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final TimeOfDay? time;
  final String timeString;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _TimePickerCard({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.timeString,
    required this.icon,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
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
                  icon,
                  color: colorScheme.primary,
                  size: 28,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeString,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
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

// Day Chip Widget
class _DayChip extends StatelessWidget {
  final String day;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
