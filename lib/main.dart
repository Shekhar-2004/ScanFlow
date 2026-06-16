import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanFlowApp());
}

class ScanFlowApp extends StatefulWidget {
  const ScanFlowApp({super.key});

  @override
  State<ScanFlowApp> createState() => _ScanFlowAppState();
}

class _ScanFlowAppState extends State<ScanFlowApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-create the router with the latest theme state
    final router = AppRouter.createRouter(
      onToggleTheme: _toggleTheme,
      isDarkMode: _themeMode == ThemeMode.dark,
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      routerConfig: router,
    );
  }
}
