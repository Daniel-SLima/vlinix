import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vlinix/data/app_backend.dart';
import 'package:vlinix/main.dart';
import 'package:vlinix/screens/add_client_screen.dart';
import 'package:vlinix/screens/add_vehicle_screen.dart';
import 'package:vlinix/screens/add_service_screen.dart';
import 'package:vlinix/screens/add_expense_screen.dart';
import 'package:vlinix/screens/add_appointment_screen.dart';
import 'package:vlinix/screens/client_details_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    // Use the shipped font so layout assertions measure real glyph widths.
    final fonts = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await fonts.load();
  });
  for (final size in [const Size(360, 800), const Size(390, 844)]) {
    testWidgets('main screens fit ${size.width.toInt()}px phone width', (
      tester,
    ) async {
      AppBackend.demo.reset(persist: false);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Welcome');
      await tester.ensureVisible(find.text('Explorar demonstração'));
      await tester.tap(find.text('Explorar demonstração'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Agenda');
      for (final label in ['Clientes', 'Serviços', 'Financeiro', 'Agenda']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.tap(find.text('Restaurar exemplo').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Reset dialog');
    });
    testWidgets('forms fit ${size.width.toInt()}px phone width', (
      tester,
    ) async {
      AppBackend.demo.reset(persist: false);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final client = await AppBackend.demo
          .from('clients')
          .select()
          .eq('id', 1)
          .single();
      for (final screen in <Widget>[
        const AddClientScreen(),
        const AddVehicleScreen(),
        const AddServiceScreen(),
        const AddExpenseScreen(),
        const AddAppointmentScreen(),
        ClientDetailsScreen(clientData: client),
      ]) {
        navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: screen.runtimeType.toString(),
        );
        navigator.pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
