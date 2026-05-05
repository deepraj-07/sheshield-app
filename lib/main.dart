import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/app_env.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
import 'providers/app_state.dart';
import 'providers/auth_provider.dart';
import 'services/firebase_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env (local dev only).
  // This is intentionally silent on failure — .env is not required in
  // release builds. All AppEnv getters have safe hardcoded fallbacks.
  await AppEnv.load();

  // Set system UI overlays style
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations (portrait only)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.i('Firebase initialized successfully');

    // Development-time verification of Firestore access.
    // This is intentionally lightweight and only writes in debug builds.
    await FirebaseService().smokeTest();
  } catch (e, stackTrace) {
    AppLogger.e('Firebase initialization failed', e, stackTrace);
  }

  runApp(const SheShieldApp());
}

/// Root widget for SheShield app
/// Handles all global configuration, providers, and routing
class SheShieldApp extends StatelessWidget {
  const SheShieldApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // ========== GLOBAL PROVIDERS ==========
      // Order matters: auth_provider must be initialized first
      providers: [
        // Central app state
        ChangeNotifierProvider(
          create: (_) => AppState(),
          lazy: false,
        ),
        // Authentication provider (depends on AppState)
        ChangeNotifierProxyProvider<AppState, AuthProvider>(
          create: (_) => AuthProvider(),
          update: (_, appState, authProvider) {
            authProvider?.appState = appState;
            return authProvider ?? AuthProvider();
          },
          lazy: false,
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            // ========== APP CONFIGURATION ==========
            title: 'SheShield',
            debugShowCheckedModeBanner: false,

            // ========== THEME ==========
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,

            // ========== HOME & ROUTING ==========
            home: const SplashScreen(),

            // Named routes can be added here for complex navigation
            // onGenerateRoute: _onGenerateRoute,

            // ========== GLOBAL NAVIGATION OBSERVER (for logging) ==========
            navigatorObservers: [
              _LoggingNavigatorObserver(),
            ],

            // ========== LOCALIZATION (future) ==========
            // supportedLocales: [Locale('en')],
            // localizationsDelegates: [GlobalMaterialLocalizations.delegate],
          );
        },
      ),
    );
  }
}

/// Custom NavigatorObserver for logging navigation events
class _LoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    AppLogger.d('Pushed: ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    AppLogger.d('Popped: ${route.settings.name}');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    AppLogger.d(
        'Replaced: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}');
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    AppLogger.d('Removed: ${route.settings.name}');
  }
}
