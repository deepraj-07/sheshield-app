import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Material 3 theme configuration for SheShield app.
/// Provides consistent design tokens across the entire app.
class AppTheme {
  /// Light theme for SheShield (default)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // ========== COLOR SCHEME ==========
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.info,
        onSecondary: AppColors.textOnPrimary,
        secondaryContainer: AppColors.infoLight,
        onSecondaryContainer: AppColors.info,
        tertiary: AppColors.warning,
        onTertiary: AppColors.textOnPrimary,
        tertiaryContainer: AppColors.warningLight,
        onTertiaryContainer: AppColors.warning,
        error: AppColors.danger,
        onError: AppColors.textOnDanger,
        errorContainer: AppColors.dangerLight,
        onErrorContainer: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceAlt,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        scrim: AppColors.overlay,
      ),

      // ========== BACKGROUND & SCAFFOLD ==========
      scaffoldBackgroundColor: AppColors.background,

      // ========== APP BAR ==========
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      ),

      // ========== BUTTONS ==========
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: _labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ========== INPUT FIELDS ==========
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderActive, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
        hintStyle: _bodyMedium.copyWith(color: AppColors.textTertiary),
        labelStyle: _bodyMedium.copyWith(color: AppColors.textSecondary),
        errorStyle: _bodySmall.copyWith(color: AppColors.danger),
      ),

      // ========== CARDS & CONTAINERS ==========
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),

      // ========== DIALOGS ==========
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: _bodyMedium,
        titleTextStyle: _titleMedium,
      ),

      // ========== BOTTOM SHEET ==========
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ========== SNACKBAR ==========
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: _bodyMedium.copyWith(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 8,
      ),

      // ========== FLOATING ACTION BUTTON ==========
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ========== TAB BAR ==========
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: _labelMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: _labelMedium.copyWith(fontWeight: FontWeight.w500),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),

      // ========== DIVIDER ==========
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 16,
      ),

      // ========== NAVIGATION BOTTOM ==========
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 16,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      // ========== TEXT STYLES ==========
      textTheme: TextTheme(
        displayLarge: _displayLarge,
        displayMedium: _displayMedium,
        displaySmall: _displaySmall,
        headlineLarge: _headlineLarge,
        headlineMedium: _headlineMedium,
        headlineSmall: _headlineSmall,
        titleLarge: _titleLarge,
        titleMedium: _titleMedium,
        titleSmall: _titleSmall,
        bodyLarge: _bodyLarge,
        bodyMedium: _bodyMedium,
        bodySmall: _bodySmall,
        labelLarge: _labelLarge,
        labelMedium: _labelMedium,
        labelSmall: _labelSmall,
      ),

      // ========== ICONS ==========
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),

      // ========== OTHERS ==========
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.safeDark;
          }
          return AppColors.divider;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.safeLight;
          }
          return AppColors.surfaceDim;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surface;
        }),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: AppColors.primary, width: 2);
          }
          return const BorderSide(color: AppColors.border, width: 1.5);
        }),
      ),
    );
  }

  /// Dark theme for SheShield (optional future implementation)
  static ThemeData get darkTheme {
    const darkBackground = Color(0xFF120B22);
    const darkSurface = Color(0xFF1B102E);
    const darkSurfaceAlt = Color(0xFF26163F);
    const darkSurfaceDim = Color(0xFF3B2A5D);
    const darkPrimaryText = Color(0xFFF8FAFC);
    const darkSecondaryText = Color(0xFFCBD5E1);
    const darkTertiaryText = Color(0xFF94A3B8);
    const darkBorder = Color(0xFF46315F);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: darkPrimaryText,
        secondary: AppColors.infoLight,
        onSecondary: AppColors.textOnPrimary,
        secondaryContainer: const Color(0xFF31245B),
        onSecondaryContainer: darkPrimaryText,
        tertiary: AppColors.warningLight,
        onTertiary: darkPrimaryText,
        tertiaryContainer: const Color(0xFF5A3A13),
        onTertiaryContainer: darkPrimaryText,
        error: AppColors.dangerLight,
        onError: AppColors.textOnPrimary,
        errorContainer: const Color(0xFF5E1D23),
        onErrorContainer: darkPrimaryText,
        surface: darkSurface,
        onSurface: darkPrimaryText,
        surfaceContainerHighest: darkSurfaceAlt,
        outline: darkBorder,
        outlineVariant: darkSurfaceDim,
        scrim: AppColors.overlay,
      ),

      scaffoldBackgroundColor: darkBackground,

      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _titleLarge,
        iconTheme: IconThemeData(color: darkPrimaryText, size: 24),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textOnPrimary),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: darkSurface,
          foregroundColor: darkPrimaryText,
          side: const BorderSide(color: darkBorder, width: 1.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _labelLarge.copyWith(fontWeight: FontWeight.w600, color: darkPrimaryText),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primaryLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: _labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryLight),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerLight, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dangerLight, width: 2),
        ),
        hintStyle: _bodyMedium.copyWith(color: darkTertiaryText),
        labelStyle: _bodyMedium.copyWith(color: darkSecondaryText),
        errorStyle: _bodySmall.copyWith(color: AppColors.dangerLight),
      ),

      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: _bodyMedium.copyWith(color: darkPrimaryText),
        titleTextStyle: _titleMedium.copyWith(color: darkPrimaryText),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkSurface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkPrimaryText,
        contentTextStyle: _bodyMedium.copyWith(color: darkSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 8,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryLight,
        unselectedLabelColor: darkSecondaryText,
        labelStyle: _labelMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryLight),
        unselectedLabelStyle: _labelMedium.copyWith(fontWeight: FontWeight.w500, color: darkSecondaryText),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primaryLight, width: 3),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 16,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: darkSecondaryText,
        elevation: 16,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      textTheme: TextTheme(
        displayLarge: _displayLarge.copyWith(color: darkPrimaryText),
        displayMedium: _displayMedium.copyWith(color: darkPrimaryText),
        displaySmall: _displaySmall.copyWith(color: darkPrimaryText),
        headlineLarge: _headlineLarge.copyWith(color: darkPrimaryText),
        headlineMedium: _headlineMedium.copyWith(color: darkPrimaryText),
        headlineSmall: _headlineSmall.copyWith(color: darkPrimaryText),
        titleLarge: _titleLarge.copyWith(color: darkPrimaryText),
        titleMedium: _titleMedium.copyWith(color: darkPrimaryText),
        titleSmall: _titleSmall.copyWith(color: darkPrimaryText),
        bodyLarge: _bodyLarge.copyWith(color: darkPrimaryText),
        bodyMedium: _bodyMedium.copyWith(color: darkSecondaryText),
        bodySmall: _bodySmall.copyWith(color: darkTertiaryText),
        labelLarge: _labelLarge.copyWith(color: darkPrimaryText),
        labelMedium: _labelMedium.copyWith(color: darkSecondaryText),
        labelSmall: _labelSmall.copyWith(color: darkTertiaryText),
      ),

      iconTheme: const IconThemeData(color: darkPrimaryText, size: 24),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return darkBorder;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDark;
          }
          return darkSurfaceDim;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return darkSurface;
        }),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: AppColors.primaryLight, width: 2);
          }
          return const BorderSide(color: darkBorder, width: 1.5);
        }),
      ),
    );
  }

  // ========== TEXT STYLES ==========
  static const TextStyle _displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.29,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.33,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    fontFamily: 'Inter',
    color: AppColors.textSecondary,
  );

  static const TextStyle _labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
    fontFamily: 'Inter',
    color: AppColors.textPrimary,
  );

  static const TextStyle _labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
    fontFamily: 'Inter',
    color: AppColors.textSecondary,
  );
}
