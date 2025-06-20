import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  int _alarmDurationSeconds = 300; // Default 5 minutes (300 seconds)

  @override
  void initState() {
    super.initState();
    _loadAlarmDuration();
  }
  Future<void> _loadAlarmDuration() async {
    try {
      // Try to load from HomeWidget preferences first
      final duration = await HomeWidget.getWidgetData<int>('alarm_duration_seconds');
      if (duration != null) {
        setState(() {
          _alarmDurationSeconds = duration;
        });
        debugPrint('Loaded alarm duration from HomeWidget: ${duration}s');
        return;
      }
    } catch (e) {
      debugPrint('Failed to load from HomeWidget: $e');
    }
    
    // Fall back to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _alarmDurationSeconds = prefs.getInt('alarm_duration_seconds') ?? 300;
      });
      debugPrint('Loaded alarm duration from SharedPreferences: ${_alarmDurationSeconds}s');
    } catch (e) {
      debugPrint('Failed to load alarm duration: $e');
      setState(() {
        _alarmDurationSeconds = 300; // Default to 5 minutes
      });
    }
  }
  Future<void> _saveAlarmDuration(int seconds) async {
    try {
      // Save to HomeWidget preferences (which creates "HomeWidgetPreferences" on Android)
      await HomeWidget.saveWidgetData('alarm_duration_seconds', seconds);
      setState(() {
        _alarmDurationSeconds = seconds;
      });
      
      // Also save to regular SharedPreferences for consistency within Flutter
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('alarm_duration_seconds', seconds);
      
      debugPrint('Alarm duration saved: ${seconds}s');
    } catch (e) {
      debugPrint('Failed to save alarm duration: $e');
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,            children: [
              _buildAlarmDurationSetting(context),
              const Divider(height: 32),
              _buildNotificationOption(
                context,
                'Push Notifications',
                'Get notified about important updates',
                Icons.notifications_outlined,
                false,
              ),
              const Divider(height: 32),
              _buildNotificationOption(
                context,
                'Email Notifications',
                'Receive updates via email',
                Icons.email_outlined,
                false,
              ),
              const Divider(height: 32),
              _buildNotificationOption(
                context,
                'Marketing Communications',
                'Stay updated with our latest offers',
                Icons.campaign_outlined,
                false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationOption(
      BuildContext context,
      String title,
      String subtitle,
      IconData icon,
      bool initialValue,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: initialValue,
          onChanged: (value) {},
        ),
      ],
    );
  }

  Widget _buildAlarmDurationSetting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.timer_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alarm Duration',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'How long should alarms play before auto-stopping',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duration: ${_formatDuration(_alarmDurationSeconds)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Slider(
                value: _alarmDurationSeconds.toDouble(),
                min: 30.0, // 30 seconds minimum
                max: 300.0, // 5 minutes maximum
                divisions: 27, // 30s, 60s, 90s, 120s, 150s, 180s, 210s, 240s, 270s, 300s (every 10 seconds)
                label: _formatDuration(_alarmDurationSeconds),
                onChanged: (value) {
                  _saveAlarmDuration(value.round());
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '30s',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '5m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickDurationButton(context, 30, '30s'),
                  _buildQuickDurationButton(context, 60, '1m'),
                  _buildQuickDurationButton(context, 120, '2m'),
                  _buildQuickDurationButton(context, 180, '3m'),
                  _buildQuickDurationButton(context, 300, '5m'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDurationButton(BuildContext context, int seconds, String label) {
    final bool isSelected = _alarmDurationSeconds == seconds;
    return InkWell(
      onTap: () => _saveAlarmDuration(seconds),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${remainingSeconds}s';
      }
    }
  }
}