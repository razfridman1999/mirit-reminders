import 'package:flutter/material.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          _sectionHeader('התראות'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('הרשאות התראות'),
            subtitle: const Text('בדוק ואפשר התראות במכשיר'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('פתח הגדרות המכשיר כדי לאפשר התראות'),
                ),
              );
            },
          ),
          _sectionHeader('אודות'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('יומן תזכורות'),
            subtitle: Text('גרסה 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('פותח עבור מירית פרידמן'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
}
