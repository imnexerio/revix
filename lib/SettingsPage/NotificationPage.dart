import 'package:flutter/material.dart';

void showNotificationSettingsBottomSheet(BuildContext context) {
  final screenSize = MediaQuery.of(context).size;
  final _formKey = GlobalKey<FormState>();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return Container(
        height: screenSize.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 40,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notifications',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                      SizedBox(height: 30),
                      _buildNotificationOption(
                        context,
                        'Push Notifications',
                        'Get notified about important updates',
                        Icons.notifications_outlined,
                        false,
                      ),
                      Divider(height: 32),
                      _buildNotificationOption(
                        context,
                        'Email Notifications',
                        'Receive updates via email',
                        Icons.email_outlined,
                        false,
                      ),
                      Divider(height: 32),
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
            ),
          ],
        ),
      );
    },
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
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
      SizedBox(width: 16),
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