import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/treatments/providers/treatments_providers.dart';
import 'package:medical24/features/treatments/widgets/treatment_widgets.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class TreatmentFavoritesScreen extends ConsumerWidget {
  const TreatmentFavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionPage(title: context.l10n.t('treatmentsFavorites'), showDisclaimer: true, child: ref.watch(favoriteTreatmentsProvider).when(loading: () => const AppLoadingView(), error: (_, __) => AppErrorView(message: context.l10n.t('treatmentsLoadError'), onRetry: () => ref.invalidate(favoriteTreatmentsProvider)), data: (items) { if (items.isEmpty) return M24EmptyState(icon: M24Icons.favorite, title: context.l10n.t('treatmentsFavoritesEmpty'), message: context.l10n.t('treatmentsFavoritesEmptyBody'), actionLabel: context.l10n.t('treatmentsSeeAll'), onAction: () => context.go(AppRoutes.treatments)); final int columns = MediaQuery.sizeOf(context).width >= 1200 ? 3 : 1; return GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: columns == 1 ? .8 : .62), itemCount: items.length, itemBuilder: (_, index) => TreatmentCard(treatment: items[index], onRemoveFavorite: () async { await ref.read(treatmentsRepositoryProvider).toggleFavorite(items[index].id); ref.invalidate(favoriteTreatmentsProvider); })); }));
}