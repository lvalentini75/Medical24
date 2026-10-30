import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class M24Colors extends ThemeExtension<M24Colors> {
  const M24Colors({required this.bg, required this.surface, required this.surfaceAlt, required this.surfaceMuted, required this.border, required this.divider, required this.ink, required this.inkSecondary, required this.inkMuted, required this.primary, required this.primaryHover, required this.primaryPressed, required this.primaryTint, required this.primarySoft, required this.primaryInk, required this.chart, required this.success, required this.successTint, required this.successInk, required this.info, required this.infoTint, required this.infoInk, required this.warning, required this.warningTint, required this.warningInk, required this.danger, required this.dangerTint, required this.dangerInk, required this.neutral, required this.neutralTint, required this.indigo, required this.indigoTint, required this.avatarBg, required this.overlay, required this.focusRing});

  static const Color white = Color(0xFFFFFFFF);
  static const M24Colors light = M24Colors(
    bg: Color(0xFFF8F8F6), surface: white, surfaceAlt: Color(0xFFF3F5F7), surfaceMuted: Color(0xFFEFF2F5), border: Color(0xFFE6E9EE), divider: Color(0xFFEEF0F3), ink: Color(0xFF0B1B33), inkSecondary: Color(0xFF4F5B7A), inkMuted: Color(0xFF6B7590), primary: Color(0xFF007F88), primaryHover: Color(0xFF00737B), primaryPressed: Color(0xFF006770), primaryTint: Color(0xFFE4F4F4), primarySoft: Color(0xFFE1F6F7), primaryInk: Color(0xFF005E62), chart: Color(0xFF0A949A), success: Color(0xFF0F9B8E), successTint: Color(0xFFE8F7F4), successInk: Color(0xFF00565C), info: Color(0xFF0B66E6), infoTint: Color(0xFFE6F1FE), infoInk: Color(0xFF0047C2), warning: Color(0xFFE9700C), warningTint: Color(0xFFFEF1E3), warningInk: Color(0xFFB9400A), danger: Color(0xFFDC2F1A), dangerTint: Color(0xFFFDEDEA), dangerInk: Color(0xFFB3200C), neutral: Color(0xFF3B4A6B), neutralTint: Color(0xFFEDEEF2), indigo: Color(0xFF4F46E5), indigoTint: Color(0xFFEEEBFF), avatarBg: Color(0xFFE5E6EA), overlay: Color(0x660B1B33), focusRing: Color(0x66007F88),
  );
  static const M24Colors dark = M24Colors(
    bg: Color(0xFF0F1621), surface: Color(0xFF161F2E), surfaceAlt: Color(0xFF1C2637), surfaceMuted: Color(0xFF1A2334), border: Color(0xFF263143), divider: Color(0xFF212B3C), ink: Color(0xFFF3F5F8), inkSecondary: Color(0xFFAEB7C8), inkMuted: Color(0xFF8792A8), primary: Color(0xFF2AA7AE), primaryHover: Color(0xFF23979E), primaryPressed: Color(0xFF1C858C), primaryTint: Color(0x292AA7AE), primarySoft: Color(0x382AA7AE), primaryInk: Color(0xFF9ADFE3), chart: Color(0xFF2AA7AE), success: Color(0xFF0F9B8E), successTint: Color(0x2E0F9B8E), successInk: Color(0xFF0F9B8E), info: Color(0xFF0B66E6), infoTint: Color(0x2E0B66E6), infoInk: Color(0xFF0B66E6), warning: Color(0xFFE9700C), warningTint: Color(0x2EE9700C), warningInk: Color(0xFFE9700C), danger: Color(0xFFDC2F1A), dangerTint: Color(0x2EDC2F1A), dangerInk: Color(0xFFDC2F1A), neutral: Color(0xFFAEB7C8), neutralTint: Color(0x2EAEB7C8), indigo: Color(0xFF4F46E5), indigoTint: Color(0x2E4F46E5), avatarBg: Color(0xFF263143), overlay: Color(0x990B1B33), focusRing: Color(0x662AA7AE),
  );

  final Color bg, surface, surfaceAlt, surfaceMuted, border, divider, ink, inkSecondary, inkMuted, primary, primaryHover, primaryPressed, primaryTint, primarySoft, primaryInk, chart, success, successTint, successInk, info, infoTint, infoInk, warning, warningTint, warningInk, danger, dangerTint, dangerInk, neutral, neutralTint, indigo, indigoTint, avatarBg, overlay, focusRing;

  @override
  M24Colors copyWith() => this;
  @override
  M24Colors lerp(covariant M24Colors? other, double t) => other == null ? this : M24Colors(
    bg: Color.lerp(bg, other.bg, t)!, surface: Color.lerp(surface, other.surface, t)!, surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!, surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!, border: Color.lerp(border, other.border, t)!, divider: Color.lerp(divider, other.divider, t)!, ink: Color.lerp(ink, other.ink, t)!, inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!, inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!, primary: Color.lerp(primary, other.primary, t)!, primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!, primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!, primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!, primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!, primaryInk: Color.lerp(primaryInk, other.primaryInk, t)!, chart: Color.lerp(chart, other.chart, t)!, success: Color.lerp(success, other.success, t)!, successTint: Color.lerp(successTint, other.successTint, t)!, successInk: Color.lerp(successInk, other.successInk, t)!, info: Color.lerp(info, other.info, t)!, infoTint: Color.lerp(infoTint, other.infoTint, t)!, infoInk: Color.lerp(infoInk, other.infoInk, t)!, warning: Color.lerp(warning, other.warning, t)!, warningTint: Color.lerp(warningTint, other.warningTint, t)!, warningInk: Color.lerp(warningInk, other.warningInk, t)!, danger: Color.lerp(danger, other.danger, t)!, dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!, dangerInk: Color.lerp(dangerInk, other.dangerInk, t)!, neutral: Color.lerp(neutral, other.neutral, t)!, neutralTint: Color.lerp(neutralTint, other.neutralTint, t)!, indigo: Color.lerp(indigo, other.indigo, t)!, indigoTint: Color.lerp(indigoTint, other.indigoTint, t)!, avatarBg: Color.lerp(avatarBg, other.avatarBg, t)!, overlay: Color.lerp(overlay, other.overlay, t)!, focusRing: Color.lerp(focusRing, other.focusRing, t)!,
  );
}

@immutable
class M24TextStyles extends ThemeExtension<M24TextStyles> {
  const M24TextStyles({required this.display, required this.h1, required this.h2, required this.h3, required this.title, required this.body, required this.bodySmall, required this.label, required this.caption, required this.navLabel, required this.button, required this.stat});
  final TextStyle display, h1, h2, h3, title, body, bodySmall, label, caption, navLabel, button, stat;

  static M24TextStyles create(M24Colors colors, {required bool desktop}) {
    TextStyle style(double size, double height, FontWeight weight, Color color, {double? spacing}) => TextStyle(fontFamily: 'Inter', fontSize: size, height: height / size, fontWeight: weight, color: color, letterSpacing: spacing, fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);
    return M24TextStyles(
      display: style(desktop ? 32 : 36, desktop ? 36 : 40, FontWeight.w700, colors.ink, spacing: -0.64), h1: style(32, desktop ? 40 : 38, desktop ? FontWeight.w600 : FontWeight.w700, colors.ink, spacing: -0.64), h2: style(desktop ? 20 : 22, 28, FontWeight.w600, colors.ink), h3: style(18, desktop ? 26 : 24, FontWeight.w600, colors.ink), title: style(desktop ? 15 : 17, 22, FontWeight.w600, colors.ink), body: style(desktop ? 15 : 16, desktop ? 22 : 24, FontWeight.w400, colors.ink), bodySmall: style(desktop ? 14 : 15, desktop ? 20 : 22, FontWeight.w400, colors.inkSecondary), label: style(14, 20, FontWeight.w500, colors.ink), caption: style(13, 18, FontWeight.w400, colors.inkMuted), navLabel: style(desktop ? 15 : 12, desktop ? 20 : 16, FontWeight.w500, colors.inkSecondary), button: style(desktop ? 15 : 16, 20, FontWeight.w600, colors.ink), stat: style(28, 32, FontWeight.w700, colors.ink),
    );
  }

  @override
  M24TextStyles copyWith() => this;
  @override
  M24TextStyles lerp(covariant M24TextStyles? other, double t) => other == null ? this : M24TextStyles(display: TextStyle.lerp(display, other.display, t)!, h1: TextStyle.lerp(h1, other.h1, t)!, h2: TextStyle.lerp(h2, other.h2, t)!, h3: TextStyle.lerp(h3, other.h3, t)!, title: TextStyle.lerp(title, other.title, t)!, body: TextStyle.lerp(body, other.body, t)!, bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!, label: TextStyle.lerp(label, other.label, t)!, caption: TextStyle.lerp(caption, other.caption, t)!, navLabel: TextStyle.lerp(navLabel, other.navLabel, t)!, button: TextStyle.lerp(button, other.button, t)!, stat: TextStyle.lerp(stat, other.stat, t)!);
}

class M24Tokens {
  const M24Tokens(this.colors, this.text);
  final M24Colors colors;
  final M24TextStyles text;
}

extension M24BuildContext on BuildContext {
  M24Tokens get m24 {
    final ThemeData theme = Theme.of(this);
    final M24Colors colors = theme.extension<M24Colors>() ?? M24Colors.light;
    return M24Tokens(colors, M24TextStyles.create(colors, desktop: MediaQuery.sizeOf(this).width >= 1200));
  }
}