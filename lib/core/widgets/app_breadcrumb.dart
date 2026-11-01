import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/widgets/navigation.dart';
import 'package:medical24/features/archive/providers/archive_providers.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class AppBreadcrumbItem {
  const AppBreadcrumbItem(this.label, this.route);
  final String label;
  final String? route;
}

/// Desktop route breadcrumb with labels resolved from live providers.
class AppBreadcrumb extends ConsumerWidget {
  const AppBreadcrumb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter? router = GoRouter.maybeOf(context);
    final String path = router?.routerDelegate.currentConfiguration.uri.path ?? AppRoutes.home;
    final List<AppBreadcrumbItem> items = <AppBreadcrumbItem>[AppBreadcrumbItem(context.l10n.t('navHealthSpace'), AppRoutes.home)];
    if (path.startsWith('/health')) {
      items.add(AppBreadcrumbItem(context.l10n.t('navHealth'), AppRoutes.health));
      items.add(AppBreadcrumbItem(context.l10n.t('healthValuesTitle'), path == AppRoutes.health ? null : AppRoutes.health));
      if (path == AppRoutes.healthValueNew) items.add(AppBreadcrumbItem(context.l10n.t('healthManualTitle'), null));
      if (path.startsWith('/health/values/') && path != AppRoutes.healthValueNew) {
        final String code = Uri.decodeComponent(path.split('/').last);
        final String language = Localizations.localeOf(context).languageCode;
        final String label = ref.watch(healthCatalogProvider).value?.where((item) => item.code == code).firstOrNull?.name(language) ?? code;
        items.add(AppBreadcrumbItem(label, null));
      }
    } else if (path.startsWith('/archive')) {
      items.add(AppBreadcrumbItem(context.l10n.t('navArchive'), path == AppRoutes.archive ? null : AppRoutes.archive));
      final RegExpMatch? match = RegExp(r'^/archive/document/([^/]+)').firstMatch(path);
      if (match != null) {
        final String id = match.group(1)!;
        final document = ref.watch(archiveDocumentProvider(id)).value;
        items.add(AppBreadcrumbItem(document == null || document.title.isEmpty ? context.l10n.t('archiveDocumentDetail') : document.title, null));
      }
    } else if (path.startsWith('/admin')) {
      items.add(AppBreadcrumbItem(context.l10n.adminGovernment, AppRoutes.adminOverview));
      final String section = path.startsWith(AppRoutes.adminAi)
          ? context.l10n.adminAiTasks
          : path.startsWith(AppRoutes.adminSettings)
              ? context.l10n.adminSettings
              : context.l10n.adminOverview;
      items.add(AppBreadcrumbItem(section, null));
    } else {
      items.add(AppBreadcrumbItem(context.l10n.t(path == '/' ? 'navHome' : 'appTitle'), null));
    }
    return Semantics(label: context.l10n.t('breadcrumbLabel'), child: M24Breadcrumb(segments: items.map((AppBreadcrumbItem item) => item.label).toList()));
  }
}