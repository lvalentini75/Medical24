import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/features/admin/data/admin_models.dart';
import 'package:medical24/features/admin/screens/admin_screen.dart';
import 'package:medical24/features/admin/widgets/admin_widgets.dart';
import 'package:medical24/features/admin/widgets/admin_governance_widgets.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('admin guard allows admins', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminTestApp(child: AdminAccessGate(isAdmin: AsyncData<bool>(true), child: Text('ADMIN-CONTENT'))));
    expect(find.text('ADMIN-CONTENT'), findsOneWidget);
  });

  testWidgets('admin guard shows 403 to non admins', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminTestApp(child: AdminAccessGate(isAdmin: AsyncData<bool>(false), child: Text('ADMIN-CONTENT'))));
    expect(find.textContaining('403'), findsOneWidget);
    expect(find.text('ADMIN-CONTENT'), findsNothing);
  });

  testWidgets('overview tiles render fake data', (WidgetTester tester) async {
    final AdminOverviewData data = AdminOverviewData(usersTotal: 120, usersActive7d: 18, usersActive30d: 60, documents: 450, extractions: const <String, int>{'ok': 30, 'failed': 2, 'review': 4}, costToday: const <String, int>{'explain': 1250000}, costMonth: const <String, int>{'explain': 5000000}, errors: const <String, int>{'timeout': 3}, tasks: const <AdminTaskState>[AdminTaskState(id: 'explain', enabled: true)]);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(AdminTestApp(child: SingleChildScrollView(child: AdminOverviewContent(data: data))));
    expect(find.text('120'), findsOneWidget);
    expect(find.text('450'), findsOneWidget);
    expect(find.text('\$1.2500'), findsOneWidget);
  });

  testWidgets('task form blocks invalid tokens and non-object JSON', (WidgetTester tester) async {
    int saves = 0;
    const AdminAiTask task = AdminAiTask(id: 'explain', description: 'Explain', model: 'model-a', fallbackModel: 'model-a', enabledFallback: false, dailyBudgetMicroUsd: 1000000, spentToday: 0, maxOutputTokens: 100, enabled: true, budgetAction: 'alert', requiresSecondApproval: false, requestOptions: <String, dynamic>{});
    const List<AdminAiModel> models = <AdminAiModel>[AdminAiModel(id: 'model-a', provider: 'anthropic', displayName: 'Model A', status: 'active')];
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    await tester.pumpWidget(AdminTestApp(child: SingleChildScrollView(child: AdminTaskForm(task: task, models: models, onSave: (patch) async => saves++))));
    await tester.enterText(find.byKey(const Key('adminTaskMaxTokens')), '0');
    await tester.enterText(find.byKey(const Key('adminTaskJson')), '[]');
    await tester.tap(find.text('Salva'));
    await tester.pump();
    expect(find.text('Inserisci un numero maggiore di zero.'), findsOneWidget);
    expect(find.text('Il JSON deve essere un oggetto.'), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('maintenance switch requires confirmation', (WidgetTester tester) async {
    bool? changed;
    await tester.pumpWidget(AdminTestApp(child: AdminMaintenanceControl(enabled: false, onChanged: (value) async => changed = value)));
    await tester.tap(find.byKey(const Key('adminMaintenanceSwitch')));
    await tester.pumpAndSettle();
    expect(changed, isNull);
    await tester.tap(find.byKey(const Key('adminMaintenanceConfirm')));
    await tester.pumpAndSettle();
    expect(changed, isTrue);
  });

  testWidgets('prompt actions follow prompt status', (WidgetTester tester) async {
    const AdminPrompt draft = AdminPrompt(id: '1', taskId: 'explain', version: '2', status: 'draft', systemPrompt: '', userTemplate: '', toolSchema: <String, dynamic>{});
    await tester.pumpWidget(const AdminTestApp(child: AdminPromptActions(prompt: draft)));
    expect(find.text('Approva'), findsOneWidget);
    expect(find.text('Esegui test'), findsOneWidget);
    expect(find.text('Attiva'), findsOneWidget);
  });

  testWidgets('dry run renders three fake cases', (WidgetTester tester) async {
    const cases = <AdminDryRunCase>[AdminDryRunCase(name: 'biomarker', text: 'A', filterPassed: true, closingPresent: true), AdminDryRunCase(name: 'organ', text: 'B', filterPassed: true, closingPresent: true), AdminDryRunCase(name: 'risk', text: 'C', filterPassed: false, closingPresent: false)];
    await tester.pumpWidget(const AdminTestApp(child: AdminDryRunResults(cases: cases)));
    expect(find.byType(AdminDryRunResults), findsOneWidget);
    expect(find.text('biomarker'), findsOneWidget);
    expect(find.text('organ'), findsOneWidget);
    expect(find.text('risk'), findsOneWidget);
  });

  testWidgets('usage chart renders fake usage', (WidgetTester tester) async {
    final rows = <AdminUsageRow>[AdminUsageRow(day: DateTime(2026, 1, 1), task: 'explain', model: 'model', calls: 4, ok: 3, errors: 1, cached: 2, tokensIn: 10, tokensCached: 2, tokensOut: 5, costMicroUsd: 120000, latencyAvg: 100, latencyP95: 180)];
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(AdminTestApp(child: SingleChildScrollView(child: AdminUsageCharts(rows: rows))));
    expect(find.byKey(const Key('adminUsageCharts')), findsOneWidget);
    expect(find.text('explain'), findsOneWidget);
  });

  testWidgets('event pagination moves to next page', (WidgetTester tester) async {
    int page = 0;
    await tester.pumpWidget(AdminTestApp(child: AdminPagination(page: 0, hasNext: true, onPageChanged: (value) => page = value)));
    await tester.tap(find.text('Successiva'));
    expect(page, 1);
  });
}

class AdminTestApp extends StatelessWidget {
  const AdminTestApp({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ProviderScope(child: MaterialApp(theme: M24Theme.light, locale: const Locale('it'), localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, home: Scaffold(body: child)));
}