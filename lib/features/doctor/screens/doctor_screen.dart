import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/doctor/widgets/doctor_widgets.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

class DoctorScreen extends StatelessWidget {
  const DoctorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Widget> cards = <Widget>[
      DoctorFeatureCard(icon: M24Icons.share, title: l10n.doctorShareTitle, body: l10n.doctorShareBody, onTap: () => context.push(AppRoutes.doctorShare)),
      DoctorFeatureCard(icon: M24Icons.history, title: l10n.doctorLinksTitle, body: l10n.doctorLinksBody, onTap: () => context.push(AppRoutes.doctorLinks)),
      DoctorFeatureCard(icon: M24Icons.help, title: l10n.doctorQuestionsTitle, body: l10n.doctorQuestionsBody, onTap: () => context.push(AppRoutes.doctorQuestions)),
      DoctorFeatureCard(icon: M24Icons.info, title: l10n.doctorEmergencyTitle, body: l10n.doctorEmergencyBody, onTap: () => context.push(AppRoutes.doctorEmergency)),
    ];
    return SectionPage(title: l10n.doctorTitle, subtitle: l10n.doctorSubtitle, action: M24Button(label: l10n.doctorDossierTitle, icon: M24Icons.document, variant: M24ButtonVariant.outlinePrimary, onPressed: () => context.push(AppRoutes.doctorDossier)), showDisclaimer: true, child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) { final int columns = constraints.maxWidth >= 900 ? 2 : 1; return GridView.builder(itemCount: cards.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 24, mainAxisSpacing: 12, mainAxisExtent: 132), itemBuilder: (_, int index) => cards[index]); }));
  }
}

class DoctorPlaceholderScreen extends StatelessWidget {
  const DoctorPlaceholderScreen({super.key, required this.title, required this.body});
  final String title, body;
  @override
  Widget build(BuildContext context) => SectionPage(title: title, showDisclaimer: true, child: AppEmptyView(icon: M24Icons.doctor, body: body));
}