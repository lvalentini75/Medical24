import 'package:flutter/material.dart';
import 'package:medical24/core/ui/tokens.dart';

enum M24ButtonVariant { primary, secondary, outline, outlinePrimary, tertiary, destructiveOutline, warning }
enum M24ButtonSize { small, medium, large }

class M24Button extends StatelessWidget {
  const M24Button({super.key, required this.label, required this.onPressed, this.icon, this.variant = M24ButtonVariant.primary, this.size = M24ButtonSize.medium, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final M24ButtonVariant variant;
  final M24ButtonSize size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final M24Colors c = context.m24.colors;
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final double height = size == M24ButtonSize.small ? 36 : size == M24ButtonSize.large ? 56 : desktop ? 44 : 48;
    final Widget content = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      if (loading) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: variant == M24ButtonVariant.primary || variant == M24ButtonVariant.warning ? M24Colors.white : c.primary)) else if (icon != null) Icon(icon, size: 20),
      if (loading || icon != null) const SizedBox(width: 8), Text(label),
    ]);
    final ButtonStyle style = ButtonStyle(minimumSize: MaterialStatePropertyAll(Size(size == M24ButtonSize.large ? double.infinity : 44, height)), padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)), shape: MaterialStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), textStyle: MaterialStatePropertyAll(context.m24.text.button), foregroundColor: MaterialStateProperty.resolveWith((s) => onPressed == null ? c.ink.withValues(alpha: .4) : _foreground(c)), backgroundColor: MaterialStateProperty.resolveWith((s) => onPressed == null ? _background(c).withValues(alpha: .4) : s.contains(MaterialState.pressed) ? _pressed(c) : s.contains(MaterialState.hovered) || s.contains(MaterialState.focused) ? _hover(c) : _background(c)), side: MaterialStatePropertyAll(_side(c)));
    return TextButton(onPressed: loading ? null : onPressed, style: style, child: content);
  }

  Color _foreground(M24Colors c) => switch (variant) { M24ButtonVariant.primary || M24ButtonVariant.warning => M24Colors.white, M24ButtonVariant.secondary => c.primaryInk, M24ButtonVariant.outline => c.ink, M24ButtonVariant.outlinePrimary || M24ButtonVariant.tertiary => c.primary, M24ButtonVariant.destructiveOutline => c.danger };
  Color _background(M24Colors c) => switch (variant) { M24ButtonVariant.primary => c.primary, M24ButtonVariant.secondary => c.primaryTint, M24ButtonVariant.destructiveOutline => c.dangerTint, M24ButtonVariant.warning => c.warning, _ => c.surface.withValues(alpha: variant == M24ButtonVariant.tertiary ? 0 : 1) };
  Color _hover(M24Colors c) => switch (variant) { M24ButtonVariant.primary => c.primaryHover, M24ButtonVariant.warning => c.warningInk, M24ButtonVariant.secondary || M24ButtonVariant.outlinePrimary || M24ButtonVariant.tertiary => c.primarySoft, M24ButtonVariant.destructiveOutline => c.dangerTint, _ => c.surfaceAlt };
  Color _pressed(M24Colors c) => variant == M24ButtonVariant.primary ? c.primaryPressed : _hover(c);
  BorderSide _side(M24Colors c) => switch (variant) { M24ButtonVariant.outline => BorderSide(color: c.border), M24ButtonVariant.outlinePrimary => BorderSide(color: c.primary), M24ButtonVariant.destructiveOutline => BorderSide(color: c.danger), _ => BorderSide.none };
}

enum M24IconButtonVariant { plain, tinted }

class M24IconButton extends StatelessWidget {
  const M24IconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.variant = M24IconButtonVariant.plain, this.selected = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final M24IconButtonVariant variant;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    final M24Colors c = context.m24.colors;
    return IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon, size: 20), color: selected ? c.primary : variant == M24IconButtonVariant.tinted ? c.info : c.inkSecondary, style: ButtonStyle(fixedSize: MaterialStatePropertyAll(Size.square(desktop ? 36 : 40)), backgroundColor: MaterialStateProperty.resolveWith((s) => selected ? c.primaryTint : variant == M24IconButtonVariant.tinted ? c.infoTint : s.contains(MaterialState.hovered) || s.contains(MaterialState.focused) || s.contains(MaterialState.pressed) ? c.surfaceAlt : c.surface.withValues(alpha: 0)), shape: const MaterialStatePropertyAll(CircleBorder())));
  }
}