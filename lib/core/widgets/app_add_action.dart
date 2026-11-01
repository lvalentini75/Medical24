import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/navigation.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

enum AppAddAction { report, value, symptom }

Future<void> openAppAddAction(BuildContext context) async {
  final AppAddAction? action;
  if (MediaQuery.sizeOf(context).width < 600) {
    action = await showModalBottomSheet<AppAddAction>(context: context, useSafeArea: true, builder: (BuildContext sheetContext) => const AppAddActionSheet());
  } else {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final Offset origin = box.localToGlobal(Offset.zero);
    action = await showGeneralDialog<AppAddAction>(context: context, barrierDismissible: true, barrierLabel: context.l10n.t('commonClose'), barrierColor: Colors.transparent, pageBuilder: (BuildContext menuContext, Animation<double> _, Animation<double> __) => AppAddAnchoredMenu(origin: Offset(origin.dx, origin.dy + box.size.height)));
  }
  if (!context.mounted || action == null) return;
  if (action == AppAddAction.report) {
    await AddDocumentSheet.show(context);
  } else if (action == AppAddAction.value) {
    context.push(AppRoutes.healthValueNew);
  } else {
    context.push(AppRoutes.symptomNew);
  }
}

/// Shared add action used by the rail and desktop side menu.
class AppAddActionButton extends StatelessWidget {
  const AppAddActionButton({super.key, this.extended = false});
  final bool extended;

  @override
  Widget build(BuildContext context) => extended
      ? M24Button(label: context.l10n.t('commonAdd'), icon: M24Icons.plus, onPressed: () => openAppAddAction(context))
      : M24IconButton(icon: M24Icons.plus, tooltip: context.l10n.t('commonAdd'), onPressed: () => openAppAddAction(context));
}

/// Prominent 56 pt add control shared by the phone bar and tablet rail.
class AppAddFloatingButton extends StatelessWidget {
  const AppAddFloatingButton({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(message: context.l10n.t('commonAdd'), child: Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: <BoxShadow>[BoxShadow(color: context.m24.colors.accent.withValues(alpha: .30), blurRadius: 24, offset: const Offset(0, 8))]),
    child: FilledButton(
      onPressed: () => openAppAddAction(context),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll<Size>(Size(56, 56)),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
        backgroundColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed)) return Color.lerp(context.m24.colors.accent, Colors.black, .08)!;
          return context.m24.colors.accent;
        }),
      ),
      child: Icon(M24Icons.plus, size: 28, color: context.m24.colors.onAccent),
    ),
  ));
}

class AppAddActionSheet extends StatelessWidget {
  const AppAddActionSheet({super.key});

  @override
  Widget build(BuildContext context) => M24Sheet(items: <M24SheetItem>[
    M24SheetItem(icon: M24Icons.upload, label: context.l10n.t('addUploadReport'), onTap: () => context.pop(AppAddAction.report)),
    M24SheetItem(icon: M24Icons.manualValue, label: context.l10n.t('addManualValue'), onTap: () => context.pop(AppAddAction.value)),
    M24SheetItem(icon: M24Icons.symptoms, label: context.l10n.t('addSymptom'), onTap: () => context.pop(AppAddAction.symptom)),
  ]);
}

/// Anchored desktop/tablet presentation of the shared add sheet.
class AppAddAnchoredMenu extends StatelessWidget {
  const AppAddAnchoredMenu({super.key, required this.origin});
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double left = origin.dx.clamp(16, screen.width - 296).toDouble();
    final double top = origin.dy.clamp(16, screen.height - 220).toDouble();
    return Stack(children: <Widget>[Positioned(left: left, top: top, width: 280, child: Material(color: Colors.transparent, child: M24Sheet(items: <M24SheetItem>[
      M24SheetItem(icon: M24Icons.upload, label: context.l10n.t('addUploadReport'), onTap: () => context.pop(AppAddAction.report)),
      M24SheetItem(icon: M24Icons.manualValue, label: context.l10n.t('addManualValue'), onTap: () => context.pop(AppAddAction.value)),
      M24SheetItem(icon: M24Icons.symptoms, label: context.l10n.t('addSymptom'), onTap: () => context.pop(AppAddAction.symptom)),
    ])))]);
  }
}