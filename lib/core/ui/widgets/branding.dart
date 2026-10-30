import 'package:flutter/material.dart';
import 'package:medical24/core/ui/tokens.dart';

enum M24LogoType { mark, lockup }

class M24Logo extends StatelessWidget {
  const M24Logo({super.key, this.type = M24LogoType.lockup, this.height = 28});
  final M24LogoType type;
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(type == M24LogoType.mark ? 'assets/brand/logo_mark.png' : 'assets/brand/logo_lockup.png', height: height, fit: BoxFit.contain, semanticLabel: 'Medical 24');
}

class M24Avatar extends StatelessWidget {
  const M24Avatar({super.key, required this.initials, this.onPressed});
  final String initials;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
    return Semantics(button: onPressed != null, label: initials, child: InkWell(onTap: onPressed, customBorder: const CircleBorder(), focusColor: context.m24.colors.focusRing, child: CircleAvatar(radius: desktop ? 18 : 20, backgroundColor: context.m24.colors.avatarBg, child: Text(initials, style: context.m24.text.label.copyWith(fontWeight: FontWeight.w600, color: context.m24.colors.ink)))));
  }
}