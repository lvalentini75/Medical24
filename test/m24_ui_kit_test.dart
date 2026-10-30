import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/m24_theme.dart';
import 'package:medical24/core/ui/widgets/widgets.dart';

void main() {
  const List<Size> breakpoints = <Size>[Size(390, 844), Size(834, 1194), Size(1920, 1080)];

  for (final Size size in breakpoints) {
    testWidgets('core components build at ${size.width}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: M24Theme.light, home: Scaffold(body: SingleChildScrollView(child: Column(children: <Widget>[
        const M24PageHeader(title: 'Archivio', subtitle: '12 documenti'),
        const M24ListRow(icon: M24Icons.archive, title: 'Esami del sangue', subtitle: '20 ott 2026 - Esami'),
        const Wrap(children: <Widget>[
          M24StatusPill(label: 'Archiviato', variant: M24StatusPillVariant.info), M24StatusPill(label: 'Analizzato', variant: M24StatusPillVariant.success), M24StatusPill(label: 'Da verificare', variant: M24StatusPillVariant.warning), M24StatusPill(label: 'Critico', variant: M24StatusPillVariant.danger), M24StatusPill(label: 'Caricato', variant: M24StatusPillVariant.neutral),
        ]),
        Wrap(children: <Widget>[
          M24Button(label: 'Primary', onPressed: () {}), M24Button(label: 'Secondary', variant: M24ButtonVariant.secondary, onPressed: () {}), M24Button(label: 'Outline', variant: M24ButtonVariant.outline, onPressed: () {}), M24Button(label: 'Tertiary', variant: M24ButtonVariant.tertiary, onPressed: () {}), M24Button(label: 'Destructive', variant: M24ButtonVariant.destructiveOutline, onPressed: () {}), M24Button(label: 'Warning', variant: M24ButtonVariant.warning, onPressed: () {}),
        ]),
      ])))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  test('feature and legacy core widgets contain no Material Icons', () {
    final List<File> files = <String>['lib/features', 'lib/core/widgets'].expand((root) => Directory(root).listSync(recursive: true).whereType<File>()).where((file) => file.path.endsWith('.dart')).toList();
    final List<String> offenders = files.where((file) => RegExp(r'\bIcons\.').hasMatch(file.readAsStringSync())).map((file) => file.path).toList();
    expect(offenders, isEmpty, reason: 'Expected to fail until existing screens are migrated to M24Icons: ${offenders.join(', ')}');
  });
}