import 'package:flutter/material.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/features/settings/presentation/screens/settings_screen.dart';

class RemindersPlaceholderScreen extends StatelessWidget {
  const RemindersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.reminders)),
      body: const Center(child: Text('בפיתוח...')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_placeholder',
        onPressed: null,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CalendarPlaceholderScreen extends StatelessWidget {
  const CalendarPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.calendar)),
      body: const Center(child: Text('בפיתוח...')),
    );
  }
}

class CategoriesPlaceholderScreen extends StatelessWidget {
  const CategoriesPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.categories)),
      body: const Center(child: Text('בפיתוח...')),
    );
  }
}

class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}
