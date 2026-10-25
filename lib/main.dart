import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/inventory_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/main_navigation_shell.dart';
import 'presentation/screens/login_screen.dart';
import 'core/services/notification_service.dart';
import 'core/services/mongodb_sync_service.dart';
import 'core/services/cloud_auth_service.dart';
import 'core/services/benaa_ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await NotificationService.init();
    } catch (_) {}
  }
  try {
    await MongoDbSyncService.initialize();
  } catch (_) {}
  try {
    await CloudAuthService.initialize();
  } catch (_) {}
  try {
    await BenaaAiService().initialize();
  } catch (_) {}
  runApp(const BenaaInventoryApp());
}

class BenaaInventoryApp extends StatelessWidget {
  const BenaaInventoryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp(
            title: 'Benaa Inventory System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,

            // --- Full RTL Arabic Locale Configuration ---
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            home: Directionality(
              textDirection: TextDirection.rtl,
              child: CloudAuthService.isLoggedIn
                  ? const MainNavigationShell()
                  : const LoginScreen(),
            ),
          );
        },
      ),
    );
  }
}
