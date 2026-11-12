import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/items_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/session_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/working_day_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/app_theme.dart';

class KitagawaInventoryApp extends StatelessWidget {
  const KitagawaInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ItemsProvider()),
        ChangeNotifierProvider(create: (_) => WorkingDayProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
      ],
      child: MaterialApp(
        title: 'Kitagawa Stock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // Light only: the logo asset has an opaque white background, so a
        // dark surface would render it as a white block. See AppColors.
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
