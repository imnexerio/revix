import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/platform_utils.dart';

class WidgetSettingsPage extends StatefulWidget {
  @override
  _WidgetSettingsPageState createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  static const platform = MethodChannel('com.imnexerio.revix/auto_refresh');
  int _alarmDurationSeconds = 60; // Default 1 minute (60 seconds)
  bool _autoRefreshEnabled = true; // Default enabled
  int _autoRefreshIntervalMinutes = 1440; // Default 24 hours (1440 minutes)

  @override
  void initState() {
    super.initState();
    // Initialize platform utils if not already done
    if (!PlatformUtils.instance.isInitialized) {
      PlatformUtils.init();
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final duration = prefs.getInt('alarm_duration_seconds');
      final autoRefreshEnabled = prefs.getBool('auto_refresh_enabled');
      final autoRefreshInterval = prefs.getInt('auto_refresh_interval_minutes');
      
      setState(() {
        _alarmDurationSeconds = duration ?? 60; // Default to 1 minute if null
        _autoRefreshEnabled = autoRefreshEnabled ?? true; // Default enabled
        _autoRefreshIntervalMinutes = autoRefreshInterval ?? 1440; // Default 24 hours
      });
      
      debugPrint('Loaded settings - Alarm: ${_alarmDurationSeconds}s, Auto-refresh: $_autoRefreshEnabled, Interval: ${_autoRefreshIntervalMinutes}m');
    } catch (e) {
      debugPrint('Failed to load settings: $e');
      setState(() {
        _alarmDurationSeconds = 60; // Default to 1 minute
        _autoRefreshEnabled = true;
        _autoRefreshIntervalMinutes = 1440; // Default 24 hours
      });
    }
  }

  Future<void> _saveAlarmDuration(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('alarm_duration_seconds', seconds);
      setState(() {
        _alarmDurationSeconds = seconds;
      });
      debugPrint('Alarm duration saved to SharedPreferences: ${seconds}s');
    } catch (e) {
      debugPrint('Failed to save alarm duration: $e');
    }
  }

  Future<void> _saveAutoRefreshSettings(bool enabled, int intervalMinutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_refresh_enabled', enabled);
      await prefs.setInt('auto_refresh_interval_minutes', intervalMinutes);
      
      setState(() {
        _autoRefreshEnabled = enabled;
        _autoRefreshIntervalMinutes = intervalMinutes;
      });
      
      debugPrint('Auto-refresh settings saved - Enabled: $enabled, Interval: ${intervalMinutes}m');
      
      // Update the native scheduling
      await _updateAutoRefreshSchedule();
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled 
              ? 'Auto-refresh enabled (${_formatRefreshInterval(intervalMinutes)})' 
              : 'Auto-refresh disabled'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save auto-refresh settings: $e');
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAutoRefreshSchedule() async {
    try {
      if (_autoRefreshEnabled) {
        debugPrint('Starting auto-refresh with interval: ${_autoRefreshIntervalMinutes}m');
        await platform.invokeMethod('startAutoRefresh', {
          'intervalMinutes': _autoRefreshIntervalMinutes,
        });
        debugPrint('Auto-refresh started successfully');
      } else {
        debugPrint('Stopping auto-refresh');
        await platform.invokeMethod('stopAutoRefresh');
        debugPrint('Auto-refresh stopped successfully');
      }
    } catch (e) {
      debugPrint('Error updating auto-refresh schedule: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating auto-refresh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlarmDurationSetting(context),
              const Divider(height: 32),
              _buildAutoRefreshSetting(context),
              const Divider(height: 32),
              _buildWidgetOption(
                context,
                'Show Missed Tasks',
                'Display missed tasks in widget',
                Icons.warning_amber_outlined,
                true,
              ),
              const Divider(height: 32),
              _buildWidgetOption(
                context,
                'Compact View',
                'Show more tasks in less space',
                Icons.view_compact_outlined,
                false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetOption(
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

  Widget _buildAutoRefreshSetting(BuildContext context) {
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
              child: Icon(Icons.refresh_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto Refresh',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Automatically refresh widget data at regular intervals',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _autoRefreshEnabled,
              onChanged: (value) {
                _saveAutoRefreshSettings(value, _autoRefreshIntervalMinutes);
              },
            ),
          ],
        ),
        if (_autoRefreshEnabled) ...[
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
                  'Refresh Interval: ${_formatRefreshInterval(_autoRefreshIntervalMinutes)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _getSliderValue(_autoRefreshIntervalMinutes).toDouble(),
                  min: 0.0, // 15 minutes
                  max: 8.0, // 24 hours (9 discrete steps: 0-8)
                  divisions: 8,
                  label: _formatRefreshInterval(_autoRefreshIntervalMinutes),
                  onChanged: (value) {
                    final newInterval = _getIntervalFromSliderValue(value.round());
                    _saveAutoRefreshSettings(_autoRefreshEnabled, newInterval);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '15m',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '24h',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildQuickIntervalButton(context, 15, '15m'),
                    _buildQuickIntervalButton(context, 30, '30m'),
                    _buildQuickIntervalButton(context, 60, '1h'),
                    _buildQuickIntervalButton(context, 120, '2h'),
                    _buildQuickIntervalButton(context, 240, '4h'),
                    _buildQuickIntervalButton(context, 360, '6h'),
                    _buildQuickIntervalButton(context, 480, '8h'),
                    _buildQuickIntervalButton(context, 720, '12h'),
                    _buildQuickIntervalButton(context, 1440, '24h'),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildQuickIntervalButton(BuildContext context, int minutes, String label) {
    final bool isSelected = _autoRefreshIntervalMinutes == minutes;
    return InkWell(
      onTap: () => _saveAutoRefreshSettings(_autoRefreshEnabled, minutes),
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

  String _formatRefreshInterval(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  // Convert minutes to slider value (0-8)
  int _getSliderValue(int minutes) {
    switch (minutes) {
      case 15: return 0;   // 15m
      case 30: return 1;   // 30m
      case 60: return 2;   // 1h
      case 120: return 3;  // 2h
      case 240: return 4;  // 4h
      case 360: return 5;  // 6h
      case 480: return 6;  // 8h
      case 720: return 7;  // 12h
      case 1440: return 8; // 24h
      default: return 8;   // Default to 24h
    }
  }

  // Convert slider value (0-8) to minutes
  int _getIntervalFromSliderValue(int sliderValue) {
    switch (sliderValue) {
      case 0: return 15;   // 15m
      case 1: return 30;   // 30m
      case 2: return 60;   // 1h
      case 3: return 120;  // 2h
      case 4: return 240;  // 4h
      case 5: return 360;  // 6h
      case 6: return 480;  // 8h
      case 7: return 720;  // 12h
      case 8: return 1440; // 24h
      default: return 1440; // Default to 24h
    }
  }
}
