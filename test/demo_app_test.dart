import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vlinix/data/app_backend.dart';
import 'package:vlinix/main.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  testWidgets(
    'demo opens the original agenda and main screens without authentication',
    (tester) async {
      expect(
        AppBackend.isDemo,
        isTrue,
        reason: 'Run with --dart-define=DEMO_MODE=true',
      );
      AppBackend.demo.reset(persist: false);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorar demonstração'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Marina Exemplo'), findsWidgets);

      for (final label in ['Clientes', 'Serviços', 'Financeiro', 'Agenda']) {
        final navigation = find.text(label);
        expect(navigation, findsWidgets);
        await tester.tap(navigation.last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }

      await tester.tap(find.text('Restaurar exemplo').first);
      await tester.pumpAndSettle();
      expect(find.text('Restaurar demonstração?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restaurar exemplo'));
      await tester.pumpAndSettle();
      expect(find.text('Explorar demonstração'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('demo introduction fits a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Explorar demonstração'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
