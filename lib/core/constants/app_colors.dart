import 'package:flutter/material.dart';

/// Centralized color system for SheShield app.
/// NO hardcoded colors in UI files — use these constants exclusively.
class AppColors {
  // ========== PRIMARY PALETTE ==========
  /// Primary brand color: Purple
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF4C1D95);

  // ========== SEMANTIC COLORS ==========
  /// Safe/Success state
  static const Color safe = Color(0xFF22c55e);
  static const Color safeLight = Color(0xFFbbf7d0);
  static const Color safeDark = Color(0xFF16a34a);

  /// Danger/Emergency state
  static const Color danger = Color(0xFFef4444);
  static const Color dangerLight = Color(0xFFFecaca);
  static const Color dangerDark = Color(0xFFdc2626);

  /// Warning/Caution state
  static const Color warning = Color(0xFFf59e0b);
  static const Color warningLight = Color(0xFFfcd34d);
  static const Color warningDark = Color(0xFFd97706);

  /// Info/Neutral state
  static const Color info = Color(0xFF3b82f6);
  static const Color infoLight = Color(0xFFbfdbfe);
  static const Color infoDark = Color(0xFF1d4ed8);

  // ========== BACKGROUND & SURFACE ==========
  /// Main background color
  static const Color background = Color(0xFFF8F7FC);
  static const Color backgroundDark = Color(0xFF120B22);

  /// Surface color for cards, dialogs
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF2ECFF);
  static const Color surfaceDim = Color(0xFFE9DDFD);

  // ========== TEXT COLORS ==========
  /// Primary text color
  static const Color textPrimary = Color(0xFF1a1a2e);
  /// Secondary/muted text
  static const Color textSecondary = Color(0xFF64748b);
  /// Tertiary/disabled text
  static const Color textTertiary = Color(0xFFa0aec0);
  /// Text on primary (white)
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  /// Text on danger
  static const Color textOnDanger = Color(0xFFFFFFFF);

  // ========== DIVIDER & BORDER ==========
  /// Divider line color
  static const Color divider = Color(0xFFe2e8f0);
  /// Border color for inputs
  static const Color border = Color(0xFFcbd5e1);
  /// Border on focus/active
  static const Color borderActive = Color(0xFF7C3AED);

  // ========== OVERLAY & TRANSPARENCY ==========
  /// Semi-transparent overlay for modals
  static const Color overlay = Color(0x80000000);
  /// Light overlay for bottom sheets
  static const Color overlayLight = Color(0x40FFFFFF);

  // ========== DISABLE & SKELETON ==========
  /// Disabled state color
  static const Color disabled = Color(0xFFe2e8f0);
  /// Skeleton loading shimmer base
  static const Color skeleton = Color(0xFFf1f5f9);
  /// Skeleton loading shimmer highlight
  static const Color skeletonHighlight = Color(0xFFe2e8f0);

  // ========== GRADIENT COLORS ==========
  /// SOS button pulse gradient
  static const List<Color> sosPulseGradient = [
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
  ];

  /// Safe gradient (background card)
  static const List<Color> safeGradient = [
    Color(0xFF22c55e),
    Color(0xFF16a34a),
  ];

  /// Danger gradient (SOS alert)
  static const List<Color> dangerGradient = [
    Color(0xFFef4444),
    Color(0xFFdc2626),
  ];
}
