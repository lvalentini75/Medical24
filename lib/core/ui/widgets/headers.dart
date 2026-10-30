import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/branding.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';

class M24AppHeader extends StatelessWidget {
  const M24AppHeader({super.key, required this.initials, required this.bellTooltip, required this.avatarTooltip, this.hasUnreadAlerts = false, this.onBellPressed, this.onAvatarPressed});
  final String initials;
  final String bellTooltip, avatarTooltip;
  final bool hasUnreadAlerts;
  final VoidCallback? onBellPressed, onAvatarPressed;
  @override
  Widget build(BuildContext context) => SizedBox(height: 56, child: Row(children: <Widget>[const M24Logo(), const Spacer(), Badge(isLabelVisible: hasUnreadAlerts, backgroundColor: context.m24.colors.warning, smallSize: 8, child: M24IconButton(icon: M24Icons.bell, tooltip: bellTooltip, onPressed: onBellPressed)), const SizedBox(width: 8), Tooltip(message: avatarTooltip, child: M24Avatar(initials: initials, onPressed: onAvatarPressed))]));
}

class M24DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const M24DetailAppBar({super.key, required this.title, required this.backTooltip, this.parentTitle, this.onBack});
  final String title;
  final String backTooltip;
  final String? parentTitle;
  final VoidCallback? onBack;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(leading: M24IconButton(icon: M24Icons.chevronLeft, tooltip: backTooltip, onPressed: onBack), title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[Text(title, style: context.m24.text.h3), if (parentTitle != null) Text(parentTitle!, style: context.m24.text.caption.copyWith(color: context.m24.colors.inkSecondary))]));
}

class M24PageHeader extends StatelessWidget {
  const M24PageHeader({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final Widget copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.h1), if (subtitle != null) ...<Widget>[const SizedBox(height: 4), Text(subtitle!, style: context.m24.text.bodySmall)]]);
    if (action == null) return copy;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[Expanded(child: copy), const SizedBox(width: 16), action!]);
  }
}

class M24SectionHeader extends StatelessWidget {
  const M24SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: <Widget>[Expanded(child: Text(title, style: context.m24.text.h2)), if (actionLabel != null) TextButton(onPressed: onAction, child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Text(actionLabel!), const SizedBox(width: 4), const Icon(M24Icons.chevronRight, size: 16)]))]);
}