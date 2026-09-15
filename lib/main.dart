import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/clinic_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  final authProvider = AuthProvider();
  await authProvider.init();
  runApp(MyApp(
    themeProvider: themeProvider,
    authProvider: authProvider,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
  });

  final ThemeProvider themeProvider;
  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, theme, auth, _) {
          final MaterialApp app = MaterialApp(
            title: AppConstants.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.mode,
            home: auth.isAuthenticated
                ? const MainNavigationScreen()
                : const LoginScreen(),
          );

          if (!auth.isAuthenticated) return app;

          return ChangeNotifierProvider<ClinicProvider>(
            create: (_) => ClinicProvider(
              currentUserId: auth.currentUser?.id,
            )..initialize(),
            child: app,
          );
        },
      ),
    );
  }
}