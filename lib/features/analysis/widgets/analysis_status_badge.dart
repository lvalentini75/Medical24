import 'package:flutter/material.dart';

import 'package:medical24/core/models/observation.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Realtime extraction state shown in the archive without relying on color alone.
class AnalysisStatusBadge extends StatelessWidget {
  const AnalysisStatusBadge({super.key, required this.extraction});

  final Extraction extraction;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (extraction.status) {
      ExtractionStatus.done => (AppColors.statusGreen, Icons.check_circle_outline),
      ExtractionStatus.needsReview => (AppColors.statusAmber, Icons.fact_check_outlined),
      ExtractionStatus.failed => (AppColors.statusRed, Icons.error_outline),
      _ => (AppColors.accent, Icons.hourglass_top_outlined),
    };
    final String label = switch (extraction.status) {
      ExtractionStatus.needsReview => context.l10n.t('analysisReviewBadge', args: <String, String>{'count': '${extraction.valuesToReview}'}),
      ExtractionStatus.done when extraction.valuesTotal == 0 && extraction.failureReason == 'skipped_not_lab' => context.l10n.t('analysisStatusSkipped'),
      ExtractionStatus.done when extraction.valuesTotal == 0 => context.l10n.t('analysisStatusNoValues'),
      _ => context.l10n.t('analysisStatus_${extraction.status.value}'),
    };
    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}