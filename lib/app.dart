import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/navigation/main_screen.dart';
import 'package:mirit_reminders/core/theme/app_theme.dart';
import 'package:mirit_reminders/features/onboarding/onboarding_screen.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:mirit_reminders/features/settings/presentation/providers/settings_provider.dart';
import 'package:mirit_reminders/features/widget/widget_update_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key, this.showOnboarding = false});

  /// If true, the app starts with the onboarding flow before showing
  /// MainScreen. Decided at startup based on SharedPreferences.
  final bool showOnboarding;

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(upcomingRemindersProvider, (_, next) {
      next.whenData(WidgetUpdateService.update);
    });
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.flutterThemeMode,
      debugShowCheckedModeBanner: false,
      locale: const Locale('he', 'IL'),
      supportedLocales: const [
        Locale('he', 'IL'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(settings.textScale)),
          child: child!,
        );
      },
      home: _showOnboarding
          ? OnboardingScreen(
              onFinished: () => setState(() => _showOnboarding = false),
            )
          : const MainScreen(),
    );
  }
}
