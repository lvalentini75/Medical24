import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/features/settings/data/settings_privacy_repository.dart';
import 'package:medical24/features/settings/screens/export_data_screen.dart';
import 'package:medical24/features/settings/widgets/delete_account_dialog.dart';
import 'package:medical24/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('wrong localized confirmation keeps delete disabled', (WidgetTester tester) async {
    await tester.pumpWidget(_TestApp(home: DeleteAccountDialog(onDelete: _deleted)));
    await tester.tap(find.byKey(const Key('delete-continue')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('delete-confirmation-field')), 'NO');
    await tester.pump();
    final FilledButton button = tester.widget(find.byKey(const Key('delete-confirm')));
    expect(button.onPressed, isNull);
  });

  testWidgets('correct localized word sends the fixed DELETE confirmation', (WidgetTester tester) async {
    String? function;
    Map<String, dynamic>? body;
    final SupabaseSettingsPrivacyRepository repository = SupabaseSettingsPrivacyRepository(invoker: (String name, Map<String, dynamic> payload) async {
      function = name;
      body = payload;
      return <String, dynamic>{'deleted': true, 'files_removed': 3, 'purge_at': '2026-12-17T09:00:00Z'};
    });
    await tester.pumpWidget(_TestApp(home: DeleteAccountDialog(onDelete: repository.deleteAccount)));
    await tester.tap(find.byKey(const Key('delete-continue')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('delete-confirmation-field')), 'elimina');
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();
    expect(function, 'delete-account');
    expect(body, <String, dynamic>{'confirm': 'DELETE'});
  });

  testWidgets('ready export shows expiry and download action', (WidgetTester tester) async {
    final DataExportState ready = DataExportState(status: 'ready', expiresAt: DateTime.utc(2026, 12, 1, 12), bytes: 2048, fileCount: 4, url: 'https://example.test/export.zip');
    await tester.pumpWidget(_TestApp(home: ExportDataScreen(onBack: () {}, repository: const _FakePrivacyRepository(), initialExport: ready, loadOnStart: false)));
    expect(find.textContaining('1 dic 2026'), findsOneWidget);
    expect(find.byKey(const Key('export-download')), findsOneWidget);
  });
}

Future<DeleteAccountResult> _deleted() async => DeleteAccountResult(purgeAt: DateTime.utc(2026, 12, 17), filesRemoved: 0);

class _FakePrivacyRepository implements SettingsPrivacyRepository {
  const _FakePrivacyRepository();
  @override Future<DataExportState?> latestExport() async => null;
  @override Future<DataExportState> requestExport() => throw UnimplementedError();
  @override Future<DeleteAccountResult> deleteAccount() => throw UnimplementedError();
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('it'),
    theme: M24Theme.light,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  );
}