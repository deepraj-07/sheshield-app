import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/logger.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'auth/login_screen.dart';

/// Splash screen that checks authentication state and routes to appropriate screen.
/// Shown on app startup for 2-3 seconds while checking auth status.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuthStateAndNavigate();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  Future<void> _checkAuthStateAndNavigate() async {
    try {
      AppLogger.i('SplashScreen: Starting auth check with 3-second timeout');
      
      // Wait for minimum splash duration with timeout (max 3 seconds)
      final checkAuthFuture = _performAuthCheck();
      await checkAuthFuture.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          AppLogger.w('SplashScreen: Auth check timeout reached, proceeding to login');
          return false; // Default to login on timeout
        },
      );

      if (!mounted) {
        AppLogger.d('SplashScreen: Widget unmounted, skipping navigation');
        return;
      }

      // Navigate to appropriate screen
      final authProvider = context.read<AuthProvider>();
      final isAuthenticated = authProvider.isAuthenticated;
      
      AppLogger.i('SplashScreen: Auth check complete - isAuthenticated: $isAuthenticated');
      
      if (isAuthenticated) {
        _navigateToHome();
      } else {
        _navigateToLogin();
      }
    } catch (e, stackTrace) {
      AppLogger.e('SplashScreen: Error during auth check', e, stackTrace);
      if (mounted) {
        AppLogger.i('SplashScreen: Error handler - navigating to login');
        _navigateToLogin();
      }
    }
  }

  Future<bool> _performAuthCheck() async {
    // Wait for minimum splash duration (2 seconds)
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  void _navigateToHome() {
    AppLogger.d('SplashScreen: Navigating to HomeScreen');
    if (!mounted) return;
    
    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      AppLogger.e('SplashScreen: Navigation to HomeScreen failed', e, StackTrace.current);
      // Fallback: navigate to login if home navigation fails
      if (mounted) _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    AppLogger.d('SplashScreen: Navigating to LoginScreen');
    if (!mounted) return;
    
    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      AppLogger.e('SplashScreen: Navigation to LoginScreen failed', e, StackTrace.current);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ========== LOGO ==========
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    size: 60,
                    color: AppColors.textOnPrimary,
                  ),
                ),

                const SizedBox(height: 32),

                // ========== APP NAME ==========
                Text(
                  'SheShield',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),

                const SizedBox(height: 8),

                // ========== TAGLINE ==========
                Text(
                  'Women\'s Safety First',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                ),

                const SizedBox(height: 64),

                // ========== LOADING INDICATOR ==========
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    strokeWidth: 3,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Initializing...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
