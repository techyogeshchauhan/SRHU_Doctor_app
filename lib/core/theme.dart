import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clinical meaning of a result. Colour is always paired with an icon and
/// text so it is never the only signal.
enum Tone {
  /// Improving / no action needed.
  success(Icons.check_circle_outline),

  /// Act or monitor (start support, due soon).
  warning(Icons.error_outline),

  /// Specific treatment indicated (surfactant, ROP treatment).
  treat(Icons.medical_services_outlined),

  /// Failure / urgent referral / overdue.
  danger(Icons.warning_amber_rounded),

  /// Information or pending input.
  info(Icons.info_outline);

  const Tone(this.icon);
  final IconData icon;

  /// Background color with high visibility on light theme.
  Color background([Brightness? _]) => switch (this) {
        Tone.success => const Color(0xFFDCFCE7),
        Tone.warning => const Color(0xFFFEF3C7),
        Tone.treat => const Color(0xFFE0E7FF),
        Tone.danger => const Color(0xFFFEE2E2),
        Tone.info => const Color(0xFFE0F2FE),
      };

  /// Foreground/text color meeting WCAG AA contrast (≥ 4.5:1) on [background].
  Color foreground([Brightness? _]) => switch (this) {
        Tone.success => const Color(0xFF14532D),
        Tone.warning => const Color(0xFF854D0E),
        Tone.treat => const Color(0xFF1E40AF),
        Tone.danger => const Color(0xFF991B1B),
        Tone.info => const Color(0xFF075985),
      };
}

class AppTheme {
  /// Dominant blue sampled from assets/images/logo212.png (#1D3C71)
  static const sampledLogoBlue = Color(0xFF1D3C71);

  /// Navy for headings and app bar text (#0B2A5B)
  static const primaryNavy = Color(0xFF0B2A5B);

  /// Primary blue for buttons, links, active states (#1F5FBF)
  static const primaryBlue = Color(0xFF1F5FBF);

  /// Mid blue for secondary accents (#4C86D9)
  static const midBlue = Color(0xFF4C86D9);

  /// Soft blue tint for card backgrounds, chips, pill tabs (#EAF2FF)
  static const tint = Color(0xFFEAF2FF);

  /// Surface white (#FFFFFF)
  static const surfaceWhite = Color(0xFFFFFFFF);

  /// Clean light page background (#F7FAFF)
  static const scaffoldBg = Color(0xFFF7FAFF);

  /// High-contrast body text (#1B2430)
  static const bodyText = Color(0xFF1B2430);

  /// Muted text (#5B6B7F)
  static const mutedText = Color(0xFF5B6B7F);

  /// Thin divider / border (#DCE6F5)
  static const dividerColor = Color(0xFFDCE6F5);
  static const borderColor = Color(0xFFDCE6F5);

  /// RD and ROP are told apart only by blue shades
  static const accentRd = primaryBlue;
  static const accentRop = midBlue;

  /// Backward-compatibility alias
  static const primaryTeal = primaryBlue;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      secondary: midBlue,
      tertiary: primaryNavy,
      surface: surfaceWhite,
      brightness: Brightness.light,
    );

    const poppinsFallback = ['Inter', 'sans-serif'];
    const interFallback = ['Poppins', 'sans-serif'];

    final textTheme = Typography.blackMountainView.copyWith(
      // Landing title: 28 sp Poppins Bold
      headlineLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primaryNavy,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primaryNavy,
      ),
      // Screen titles: 22 sp Poppins SemiBold
      headlineSmall: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primaryNavy,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primaryNavy,
      ),
      // Card titles: 16 sp Poppins SemiBold
      titleMedium: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryNavy,
      ),
      titleSmall: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryNavy,
      ),
      // Body: 14-15 sp Inter Regular with 1.4 line height
      bodyLarge: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: interFallback,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: bodyText,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: interFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: bodyText,
      ),
      // Small/disclaimer text: 12 sp Inter
      bodySmall: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: interFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: mutedText,
      ),
      // Buttons & Labels: Poppins SemiBold for buttons
      labelLarge: const TextStyle(
        fontFamily: 'Poppins',
        fontFamilyFallback: poppinsFallback,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: interFallback,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: mutedText,
      ),
      labelSmall: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: interFallback,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: mutedText,
      ),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Poppins', 'sans-serif'],
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: primaryNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontFamilyFallback: poppinsFallback,
          color: primaryNavy,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontFamilyFallback: poppinsFallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: dividerColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontFamilyFallback: poppinsFallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontFamilyFallback: poppinsFallback,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: mutedText,
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: mutedText),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
        backgroundColor: tint,
        labelStyle: const TextStyle(
          color: primaryNavy,
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        minLeadingWidth: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
    );
  }
}
