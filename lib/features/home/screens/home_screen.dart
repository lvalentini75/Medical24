import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:medical24/core/errors/app_failure.dart';
import 'package:medical24/core/models/user_profile.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/widgets/app_state_views.dart';
import 'package:medical24/features/archive/widgets/add_document_sheet.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';
import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/features/home/providers/home_providers.dart';
import 'package:medical24/features/home/widgets/home_dashboard.dart';

/// Home reads the real profile from Supabase: no mock data.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) ref.invalidate(homeSnapshotProvider); }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<UserProfile?> profile = ref.watch(myProfileProvider);
    final String language = Localizations.localeOf(context).languageCode;
    final AsyncValue<HomeSnapshot> snapshot = ref.watch(homeSnapshotProvider);

    return profile.when(
      loading: () => const AppLoadingView(),
      error: (Object e, StackTrace _) => AppErrorView(
        message: AppFailure.from(e, where: 'home').localized(language),
        onRetry: () => ref.read(myProfileProvider.notifier).refreshProfile(),
      ),
      data: (UserProfile? data) {
        final String? name = data?.firstName;
        final bool desktop = MediaQuery.sizeOf(context).width >= 1200;
        final int hour = DateTime.now().hour;
        final String greetingKey = desktop ? (hour < 12 ? 'homeGreetingMorning' : hour < 18 ? 'homeGreetingAfternoon' : 'homeGreetingEvening') : 'homeGreeting';
        final String title = name == null ? l10n.t(desktop ? 'homeGreetingDesktopNoName' : 'homeGreetingNoName') : l10n.t(greetingKey, args: <String, String>{'name': name});
        final HomeSnapshot? current = snapshot.hasValue ? snapshot.requireValue : null;
        final DateTime? updatedAt = current?.values.isNotEmpty == true ? current!.values.first.effectiveAt : current?.latestDocument?.createdAt;
        return SectionPage(
          title: title,
          subtitle: desktop && updatedAt != null ? l10n.t('homeUpdatedAt', args: <String, String>{'date': DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(updatedAt)}) : l10n.t('homeHealthSpace'),
          action: M24Button(label: l10n.t(desktop ? 'homeUploadReport' : 'homeUpload'), icon: M24Icons.upload, onPressed: () => AddDocumentSheet.show(context)),
          showDisclaimer: false,
          child: snapshot.when(loading: () => const AppLoadingView(), error: (Object error, StackTrace _) => AppErrorView(message: AppFailure.from(error, where: 'home_snapshot').localized(language), onRetry: () => ref.invalidate(homeSnapshotProvider)), data: (HomeSnapshot value) => RefreshIndicator(onRefresh: () async { ref.invalidate(homeSnapshotProvider); await ref.read(homeSnapshotProvider.future); }, child: HomeDashboard(snapshot: value))),
        );
      },
    );
  }
}

