import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';

enum M24BannerVariant { primary, info, warning }

class M24Banner extends StatelessWidget {
  const M24Banner({super.key, required this.title, required this.subtitle, this.variant = M24BannerVariant.warning, this.onTap});
  final String title, subtitle;
  final M24BannerVariant variant;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final (M24CardTint, M24IconTileVariant) styles = switch (variant) { M24BannerVariant.primary => (M24CardTint.primary, M24IconTileVariant.primary), M24BannerVariant.info => (M24CardTint.info, M24IconTileVariant.info), M24BannerVariant.warning => (M24CardTint.warning, M24IconTileVariant.warning) };
    return M24Card(tint: styles.$1, onTap: onTap, child: Row(children: <Widget>[M24IconTile(icon: variant == M24BannerVariant.warning ? M24Icons.review : M24Icons.info, variant: styles.$2), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.title), Text(subtitle, style: context.m24.text.bodySmall)])), Icon(M24Icons.chevronRight, size: 20, color: context.m24.colors.inkMuted)]));
  }
}

class M24Disclaimer extends StatelessWidget {
  const M24Disclaimer({super.key, this.phoneText = 'Informazioni da discutere con il medico.', this.desktopText = 'Le informazioni non sostituiscono il parere del medico.'});
  final String phoneText, desktopText;
  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: context.m24.colors.surfaceMuted, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: desktop ? MainAxisAlignment.center : MainAxisAlignment.start, children: <Widget>[Icon(M24Icons.info, size: 18, color: context.m24.colors.inkSecondary), const SizedBox(width: 8), Flexible(child: Text(desktop ? desktopText : phoneText, style: context.m24.text.caption.copyWith(color: context.m24.colors.inkSecondary)))]));
  }
}