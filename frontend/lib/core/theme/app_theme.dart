/// AURIXA Application Theme — "Aurixa Nebula"
/// Light, color-forward theme. Page background carries real brand color
/// (periwinkle/slate-blue), surfaces use a subtle blue tint — never pure
/// white. One fixed theme. No dark/light toggle.
library;

import 'package:flutter/material.dart';

class AppTheme {
  // ==========================================================================
  // BACKGROUND LAYERS — Option F1 (locked)
  // ==========================================================================
  /// Page background — saturated periwinkle/slate-blue. Carries real brand
  /// color so cards have something to visually lift off of.
  static const Color bgBase = Color(0xFFB7C2EF);

  /// Card / panel surfaces — a whisper of blue, NOT pure white.
  static const Color bgSurface = Color(0xFFEEF1FC);

  /// Sidebar surface — subtle tint, distinct from card surface.
  static const Color sidebarSurface = Color(0xFFE3E8FA);

  /// Elevated surfaces — modals, dropdowns, popovers.
  static const Color bgElevated = Color(0xFFFFFFFF);

  static const Color borderColor = Color(0xFFC7D0EE);

  // ==========================================================================
  // BRAND GRADIENT — "Aurixa Nebula" (blue → indigo → purple)
  // Used everywhere it fits: buttons, active states, hero banners, score
  // elements, splash screen.
  // ==========================================================================
  static const Color brandBlue = Color(0xFF3B5FE0);
  static const Color brandIndigo = Color(0xFF7B5CE8);
  static const Color brandPurple = Color(0xFFA855E8);

  /// Primary alias — kept for backward compatibility with existing widgets
  /// that reference AppTheme.primary / primaryLight.
  static const Color primary = brandBlue;
  static const Color primaryLight = brandIndigo;
  static const Color primaryDark = Color(0xFF2A4FCB);

  static const List<Color> brandGradient = [brandBlue, brandIndigo, brandPurple];

  // ==========================================================================
  // SEMANTIC / STATUS COLORS — tuned, not stock Material colors. Kept
  // functionally standard (green=good, red=danger) for scannability, but
  // shifted to share DNA with the brand palette.
  // ==========================================================================
  static const Color success = Color(0xFF3DCB8F);
  static const Color warning = Color(0xFFF0A857);
  static const Color danger = Color(0xFFF1567A);
  static const Color info = Color(0xFF5CA8F5);

  // ==========================================================================
  // TEXT COLORS
  // ==========================================================================
  static const Color textPrimary = Color(0xFF161B3D);
  static const Color textSecondary = Color(0xFF4F5A8C);
  static const Color textMuted = Color(0xFF7882B0);
  static const Color textPlaceholder = Color(0xFF9AA3CC);

  // ==========================================================================
  // MODULE-SPECIFIC ACCENTS — used as the default hover-glow color per
  // module. Individual cards may override with a status color (see
  // GlowColor helpers in hover_widgets.dart).
  // ==========================================================================
  static const Color subVault = brandBlue;
  static const Color behaviorLens = brandPurple;
  static const Color riskRadar = danger;
  static const Color velocityEngine = brandIndigo;
  static const Color scoreCore = success;
  static const Color recommendations = brandPurple;
  static const Color wallet = brandBlue;
  static const Color auditTrail = brandIndigo;
  static const Color profileAccent = brandIndigo;  // ← ADD THIS

  // ==========================================================================
  // BORDER RADIUS
  // ==========================================================================
  static const double radiusCards = 16.0;
  static const double radiusInputs = 12.0;
  static const double radiusBadges = 8.0;
  static const double radiusButtons = 10.0;

  // ==========================================================================
  // SIDEBAR
  // ==========================================================================
  static const double sidebarExpandedWidth = 240.0;
  static const double sidebarCollapsedWidth = 64.0;
  static const Color sidebarBackground = sidebarSurface;

  // ==========================================================================
  // WINDOW
  // ==========================================================================
  static const double minWindowWidth = 1280.0;
  static const double minWindowHeight = 800.0;
  static const Color titleBarBackground = Color(0xFF0E1024);

  // Splash / auth window sizing (small, centered, chrome-less)
  static const double splashWindowWidth = 560.0;
  static const double splashWindowHeight = 440.0;
  static const double authWindowWidth = 920.0;
  static const double authWindowHeight = 440.0;

  // Splash-specific dark panel colors (the splash/brand panel intentionally
  // stays dark to make the gradient sweep + glow read clearly — see
  // splash_screen.dart and login_screen.dart brand panel).
  static const Color splashBgStart = Color(0xFF0B0D24);
  static const Color splashBgEnd = Color(0xFF161A3D);

  // ==========================================================================
  // BACKWARD-COMPAT ALIASES — Phase 1 only touched theme + auth screens.
  // Phases 2-11 (Dashboard, SubVault, BehaviorLens, VelocityEngine,
  // RiskRadar, Recommendations, Score History, Profile, Wallet, Audit)
  // still reference these old field names. Keeping them mapped into the
  // new F1 palette means the WHOLE app compiles and runs after Phase 1,
  // not just the auth flow — each alias gets removed as its owning
  // screen is migrated in a later phase.
  // ==========================================================================

  /// Old name for the page/scaffold background. Maps to the new bgBase.
  static const Color bgCanvas = bgBase;

  /// Old secondary brand accent — used in a handful of older screens for
  /// non-gradient violet highlights. Maps to brandIndigo.
  static const Color violet = brandIndigo;

  /// Old cyan accent — used sparingly (VelocityEngine). Maps to a cool
  /// blue that still fits the Nebula palette rather than reintroducing an
  /// unrelated hue.
  static const Color cyan = Color(0xFF4DC8E8);

  // ==========================================================================
  // LOGO GRADIENT — kept name for compatibility with existing references.
  // ==========================================================================
  static const List<Color> logoGradient = brandGradient;

  // ==========================================================================
  // HOVER / ANIMATION TIMING — shared constants so every screen uses the
  // exact same feel (see core/widgets/hover_widgets.dart).
  // ==========================================================================
  static const Duration hoverDuration = Duration(milliseconds: 170);
  static const Duration entranceDuration = Duration(milliseconds: 280);
  static const Duration entranceStagger = Duration(milliseconds: 45);

  /// Hover zoom scale for large cards (stat cards, list cards) — capped so
  /// dense grids don't collide.
  static const double hoverScaleLarge = 1.08;

  /// Hover zoom scale for tall, content-dense list cards that still want
  /// a real zoom — just gentler than hoverScaleLarge. Use HoverSize.subtle
  /// (not a one-off override) wherever a card type needs toning down;
  /// e.g. SubVault's subscription cards. Noticeable, not aggressive.
  static const double hoverScaleSubtle = 1.045;

  /// Hover zoom scale for small items (icon badges, status badges, list rows).
  static const double hoverScaleSmall = 1.10;

  // ==========================================================================
  // THEME DATA
  // ==========================================================================
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Scaffold background
      scaffoldBackgroundColor: bgBase,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: brandBlue,
        primaryContainer: bgElevated,
        secondary: brandPurple,
        secondaryContainer: bgSurface,
        surface: bgSurface,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),

      // Typography
      fontFamily: 'Segoe UI',

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: bgBase,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // Card Theme — M3 requires CardThemeData (not CardTheme)
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCards),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputs),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputs),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputs),
          borderSide: const BorderSide(color: brandBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputs),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textPlaceholder),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButtons),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandBlue,
          side: const BorderSide(color: brandBlue),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButtons),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brandIndigo),
      ),

      // Dialog Theme — M3 requires DialogThemeData (not DialogTheme)
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCards),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(fontSize: 14, color: textSecondary),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
    );
  }
}