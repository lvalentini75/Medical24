import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/ui/widgets/headers.dart';

/// App bar for detail routes, with a safe fallback for directly opened URLs.
class DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailAppBar({super.key, required this.title, required this.parentLabel, required this.parentRoute});

  final String title;
  final String parentLabel;
  final String parentRoute;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) => M24DetailAppBar(title: title, backTooltip: parentLabel, parentTitle: parentLabel, onBack: () => context.canPop() ? context.pop() : context.go(parentRoute));
}