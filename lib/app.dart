import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'core/themes/app_theme.dart';
import 'core/themes/color_schemes.dart';
import 'core/themes/theme_state.dart';
import 'features/onboarding/splash_screen.dart';
import 'shared/services/app_settings.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.themeMode.addListener(_onChanged);
    _settings.textScale.addListener(_onChanged);
    _settings.colorSchemeId.addListener(_onChanged);
    _settings.language.addListener(_onChanged);
  }

  Locale _resolveLocale() {
    return const Locale('en');
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _settings.themeMode.removeListener(_onChanged);
    _settings.textScale.removeListener(_onChanged);
    _settings.colorSchemeId.removeListener(_onChanged);
    _settings.language.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preset = ColorSchemes.getById(_settings.colorSchemeId.value);
    final lightScheme = preset.generateScheme(Brightness.light);
    final darkScheme = preset.generateScheme(Brightness.dark);
    ThemeStateManager.instance.updateColors(
      primary: lightScheme.primary,
      accent: lightScheme.secondary,
    );

    final mq = MediaQuery.maybeOf(context)
        ?? MediaQueryData.fromView(View.of(context));
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(_settings.textScale.value),
      ),
      child: MaterialApp(
        title: 'iSign',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(lightScheme),
        darkTheme: AppTheme.dark(darkScheme),
        themeMode: _settings.themeMode.value,
        locale: _resolveLocale(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    );
  }
}
