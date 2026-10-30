import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/models/consent_record.dart';
import 'package:medical24/core/theme/app_theme.dart';
import 'package:medical24/features/onboarding/widgets/consent_tile.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

void main() {
  testWidgets('consent tile shows version and toggles independently',
      (WidgetTester tester) async {
    bool value = false;

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      theme: lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => ConsentTile(
            title: 'Trattamento dei dati sanitari',
            body: 'Consenso esplicito art. 9.2.a GDPR.',
            version: ConsentVersions.healthData,
            required: true,
            value: value,
            onChanged: (bool v) => setState(() => value = v),
          ),
        ),
      ),
    ));

    expect(find.text('v${ConsentVersions.healthData}'), findsOneWidget);
    expect(find.text('Obbligatorio'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  test('consent types map to the Postgres enum values', () {
    expect(ConsentType.healthData.value, 'health_data');
    expect(ConsentType.aiProcessing.value, 'ai_processing');
    expect(ConsentType.fromValue('marketing'), ConsentType.marketing);
  });
}
