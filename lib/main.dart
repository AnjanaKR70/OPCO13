import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/permission_service.dart';
import 'services/issues_service.dart';
import 'services/home_stats_service.dart';
import 'services/localization_service.dart';

import 'services/background_service.dart';
import 'services/intent_service.dart';
import 'overlay_main.dart'; // Ensure entry point is compiled

@pragma("vm:entry-point")
void overlayMain() {
  runOverlay();
}

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Fire and forget background/intent initialization so they don't block the UI
  initializeBackgroundService().catchError((e) {
    debugPrint('[SCAMUNDO_STARTUP] Failed to initialize background service: $e');
  });
  
  try {
    IntentService.initialize();
  } catch (e) {
    debugPrint('[SCAMUNDO_STARTUP] Failed to initialize IntentService: $e');
  }

  runApp(const ScamundoApp());
}

class ScamundoApp extends StatelessWidget {
  const ScamundoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => IssuesService()),
        ChangeNotifierProvider(create: (_) => PermissionState()),
        ChangeNotifierProvider(create: (_) => HomeStatsService()),
      ],
      child: MaterialApp(
        navigatorKey: globalNavigatorKey,
        title: 'Scamundo',
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
