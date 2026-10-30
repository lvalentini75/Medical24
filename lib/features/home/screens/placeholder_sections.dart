import 'package:flutter/material.dart';

import '../../../core/widgets/app_state_views.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Sections whose modules arrive in the next prompts. They are honest empty
/// states: no mock data, no fake content.
class HealthSectionScreen extends StatelessWidget {
  const HealthSectionScreen({super.key});

  @override
  Widget build(BuildContext context) => SectionPage(
        title: context.l10n.t('healthTitle'),
        showDisclaimer: true,
        child: AppEmptyView(
          icon: Icons.monitor_heart_outlined,
          body: context.l10n.t('healthEmptyBody'),
        ),
      );
}

class ArchiveSectionScreen extends StatelessWidget {
  const ArchiveSectionScreen({super.key});

  @override
  Widget build(BuildContext context) => SectionPage(
        title: context.l10n.t('archiveTitle'),
        child: AppEmptyView(
          icon: Icons.folder_open_outlined,
          body: context.l10n.t('archiveEmptyBody'),
        ),
      );
}

class TreatmentsSectionScreen extends StatelessWidget {
  const TreatmentsSectionScreen({super.key});

  @override
  Widget build(BuildContext context) => SectionPage(
        title: context.l10n.t('treatmentsTitle'),
        showDisclaimer: true,
        child: AppEmptyView(
          icon: Icons.healing_outlined,
          body: context.l10n.t('treatmentsEmptyBody'),
        ),
      );
}

class DoctorSectionScreen extends StatelessWidget {
  const DoctorSectionScreen({super.key});

  @override
  Widget build(BuildContext context) => SectionPage(
        title: context.l10n.t('doctorTitle'),
        showDisclaimer: true,
        child: AppEmptyView(
          icon: Icons.medical_information_outlined,
          body: context.l10n.t('doctorEmptyBody'),
        ),
      );
}
