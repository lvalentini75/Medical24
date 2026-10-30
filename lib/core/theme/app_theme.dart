import 'package:flutter/material.dart';

/// "Calm Health" design tokens for Medical 24.
/// Colours are defined once here and referenced everywhere else.
class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFF7F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF111418);
  static const Color textSecondary = Color(0xFF5B6470);
  static const Color accent = Color(0xFF0E7C86);
  static const Color statusGreen = Color(0xFF1E9E6A);
  static const Color statusAmber = Color(0xFFD98A0B);
  static const Color statusRed = Color(0xFFD64545);
  static const Color neutralGrey = Color(0xFFA3ABB4);
  static const Color border = Color(0x0F111418);

  // Dark mode uses the same tokens on inverted surfaces.
  static const Color darkBackground = Color(0xFF0E1114);
  static const Color darkSurface = Color(0xFF171B20);
  static const Color darkText = Color(0xFFF2F4F6);
  static const Color darkTextSecondary = Color(0xFFA3ABB4);
  static const Color darkBorder = Color(0x1FFFFFFF);
}

/// Spacing scale.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
}

/// Corner radii.
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double card = 20;
  static const double pill = 999;
}

/// Adaptive breakpoints: phone / tablet / full HD desktop.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double tablet = 600;
  static const double desktop = 1200;
  static const double maxContentWidth = 1440;
  static const double sideMenuWidth = 260;

  static bool isPhone(double width) => width < tablet;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}

ThemeData _buildTheme({required Brightness brightness}) {
  final bool isDark = brightness == Brightness.dark;
  final Color background =
      isDark ? AppColors.darkBackground : AppColors.background;
  final Color surface = isDark ? AppColors.darkSurface : AppColors.surface;
  final Color onSurface = isDark ? AppColors.darkText : AppColors.text;
  final Color secondary =
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  final Color border = isDark ? AppColors.darkBorder : AppColors.border;

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: surface,
    onSurface: onSurface,
    error: AppColors.statusRed,
  );

  final TextTheme base = (isDark ? ThemeData.dark() : ThemeData.light())
      .textTheme
      .apply(fontFamily: 'Inter', bodyColor: onSurface, displayColor: onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    textTheme: base.copyWith(
      bodySmall: base.bodySmall?.copyWith(color: secondary),
      labelMedium: base.labelMedium?.copyWith(color: secondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      labelStyle: TextStyle(color: secondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        minimumSize: const Size(0, 52),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accent.withValues(alpha: 0.12),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: IconThemeData(color: secondary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      iconColor: secondary,
    ),
  );
}

ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);
ThemeData get darkTheme => _buildTheme(brightness: Brightness.dark);
