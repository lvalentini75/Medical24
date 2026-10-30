import 'package:flutter/material.dart';
import 'package:medical24/core/ui/tokens.dart';

class M24Theme {
  const M24Theme._();
  static ThemeData get light => _build(Brightness.light, M24Colors.light);
  static ThemeData get dark => _build(Brightness.dark, M24Colors.dark);

  static ThemeData _build(Brightness brightness, M24Colors colors) {
    final M24TextStyles text = M24TextStyles.create(colors, desktop: false);
    final ColorScheme scheme = ColorScheme(
      brightness: brightness, primary: colors.primary, onPrimary: M24Colors.white, secondary: colors.info, onSecondary: M24Colors.white, error: colors.danger, onError: M24Colors.white, surface: colors.surface, onSurface: colors.ink, surfaceContainerHighest: colors.surfaceAlt, outline: colors.border, outlineVariant: colors.divider, shadow: colors.overlay, scrim: colors.overlay, inverseSurface: colors.ink, onInverseSurface: colors.surface, inversePrimary: colors.primaryInk,
    );
    final TextTheme textTheme = TextTheme(displayLarge: text.display, headlineLarge: text.h1, headlineMedium: text.h2, headlineSmall: text.h3, titleLarge: text.title, bodyLarge: text.body, bodyMedium: text.bodySmall, labelLarge: text.button, labelMedium: text.label, bodySmall: text.caption);
    MaterialStateProperty<Color?> overlay(Color hover, Color pressed) => MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) return pressed;
      if (states.contains(MaterialState.hovered) || states.contains(MaterialState.focused)) return hover;
      return null;
    });
    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final OutlineInputBorder inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.border));
    return ThemeData(
      useMaterial3: true, brightness: brightness, fontFamily: 'Inter', colorScheme: scheme, scaffoldBackgroundColor: colors.bg, canvasColor: colors.bg, textTheme: textTheme, extensions: <ThemeExtension<dynamic>>[colors, text],
      focusColor: colors.focusRing, hoverColor: colors.surfaceAlt, splashColor: colors.primaryTint,
      cardTheme: CardThemeData(color: colors.surface, surfaceTintColor: colors.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: colors.border))),
      chipTheme: ChipThemeData(backgroundColor: colors.surface, selectedColor: colors.primaryTint, disabledColor: colors.surfaceMuted, side: BorderSide(color: colors.border), shape: const StadiumBorder(), labelStyle: text.label, secondaryLabelStyle: text.label.copyWith(color: colors.primaryInk), padding: const EdgeInsets.symmetric(horizontal: 10)),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(minimumSize: const MaterialStatePropertyAll(Size(0, 48)), shape: MaterialStatePropertyAll(buttonShape), textStyle: MaterialStatePropertyAll(text.button), foregroundColor: const MaterialStatePropertyAll(M24Colors.white), backgroundColor: MaterialStateProperty.resolveWith((states) { if (states.contains(MaterialState.disabled)) return colors.primary.withValues(alpha: .4); if (states.contains(MaterialState.pressed)) return colors.primaryPressed; if (states.contains(MaterialState.hovered)) return colors.primaryHover; return colors.primary; }), overlayColor: overlay(colors.primaryHover, colors.primaryPressed))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(minimumSize: const MaterialStatePropertyAll(Size(0, 48)), shape: MaterialStatePropertyAll(buttonShape), textStyle: MaterialStatePropertyAll(text.button), foregroundColor: MaterialStatePropertyAll(colors.ink), side: MaterialStatePropertyAll(BorderSide(color: colors.border)), overlayColor: overlay(colors.surfaceAlt, colors.primaryTint))),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(minimumSize: const MaterialStatePropertyAll(Size(44, 44)), shape: MaterialStatePropertyAll(buttonShape), textStyle: MaterialStatePropertyAll(text.button), foregroundColor: MaterialStatePropertyAll(colors.info), overlayColor: overlay(colors.infoTint, colors.primaryTint))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: colors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), hintStyle: text.body.copyWith(color: colors.inkMuted), labelStyle: text.bodySmall, border: inputBorder, enabledBorder: inputBorder, disabledBorder: inputBorder.copyWith(borderSide: BorderSide(color: colors.border.withValues(alpha: .4))), focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: colors.primary, width: 2)), errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: colors.danger))),
      navigationBarTheme: NavigationBarThemeData(height: 64, backgroundColor: colors.surface, surfaceTintColor: colors.surface, indicatorColor: colors.primarySoft, labelTextStyle: MaterialStateProperty.resolveWith((s) => text.navLabel.copyWith(color: s.contains(MaterialState.selected) ? colors.primary : colors.inkSecondary)), iconTheme: MaterialStateProperty.resolveWith((s) => IconThemeData(color: s.contains(MaterialState.selected) ? colors.primary : colors.inkSecondary, size: 24))),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: colors.surface, indicatorColor: colors.primarySoft, selectedIconTheme: IconThemeData(color: colors.primary, size: 24), unselectedIconTheme: IconThemeData(color: colors.inkSecondary, size: 24), selectedLabelTextStyle: text.navLabel.copyWith(color: colors.primary), unselectedLabelTextStyle: text.navLabel),
      segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(minimumSize: const MaterialStatePropertyAll(Size(44, 44)), shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), side: MaterialStatePropertyAll(BorderSide(color: colors.border)), textStyle: MaterialStatePropertyAll(text.label), foregroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? colors.primaryInk : colors.ink), backgroundColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? colors.primaryTint : colors.surface))),
      tabBarTheme: TabBarThemeData(labelColor: colors.primary, unselectedLabelColor: colors.inkSecondary, labelStyle: text.label, unselectedLabelStyle: text.label, indicatorColor: colors.primary, indicatorSize: TabBarIndicatorSize.label, dividerColor: colors.divider),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(backgroundColor: colors.bg, foregroundColor: colors.ink, surfaceTintColor: colors.bg, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleTextStyle: text.h3),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: colors.surface, surfaceTintColor: colors.surface, modalBarrierColor: colors.overlay, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      snackBarTheme: SnackBarThemeData(backgroundColor: colors.ink, contentTextStyle: text.bodySmall.copyWith(color: colors.surface), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      dialogTheme: DialogThemeData(backgroundColor: colors.surface, surfaceTintColor: colors.surface, titleTextStyle: text.h2, contentTextStyle: text.body, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    );
  }
}