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

  // Initialize Firebase — must succeed before runApp.
  // Guard against duplicate-app on hot restart: if Firebase is already
  // initialized (apps list is non-empty), reuse it instead of calling
  // initializeApp() again.
  bool firebaseReady = false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseReady = true;
    AppLogger.i('Firebase initialized successfully');

    // Smoke test is fire-and-forget — never block startup on it.
    FirebaseService().smokeTest().catchError((e) {
      AppLogger.w('Smoke test failed (non-fatal)', e);
    });
  } catch (e, stackTrace) {
    AppLogger.e('Firebase initialization failed', e, stackTrace);
  }

  runApp(SheShieldApp(firebaseReady: firebaseReady));
}

/// Root widget for SheShield app
/// Handles all global configuration, providers, and routing
class SheShieldApp extends StatelessWidget {
  final bool firebaseReady;

  const SheShieldApp({Key? key, required this.firebaseReady}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If Firebase failed to initialize, show a clear error screen instead
    // of crashing inside a provider constructor.
    if (!firebaseReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1a1a2e),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: Colors.white54, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Unable to connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase could not be initialized.\nCheck your internet connection and restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      // ========== GLOBAL PROVIDERS ==========
      // Order matters: auth_provider must be initialized first
      providers: [
        // Central app state
        ChangeNotifierProvider(
          create: (_) {
            final state = AppState();
            // Restore persisted theme on startup
            state.loadPersistedTheme();
            return state;
          },
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
