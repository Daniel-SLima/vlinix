import 'package:flutter_test/flutter_test.dart';
import 'package:vlinix/data/demo_store.dart';

void main() {
  late DemoStore store;
  setUp(() {
    store = DemoStore();
    store.reset(persist: false, now: DateTime(2026, 11, 25, 12));
  });

  test('fixtures expose joined agenda and completed revenue', () async {
    final completed = await store
        .from('appointments')
        .select(
          'clients(full_name), vehicles(model), appointment_services(price, services(name))',
        )
        .eq('status', 'concluido');
    expect(completed, hasLength(2));
    expect(completed.first['clients']['full_name'], 'Marina Exemplo');
    var revenue = 0.0;
    for (final appointment in completed) {
      for (final item in appointment['appointment_services']) {
        expect(item['services']['name'], isNotEmpty);
        revenue += (item['price'] as num).toDouble();
      }
      revenue += (appointment['tip_amount'] as num).toDouble();
    }
    expect(revenue, 640);
  });

  test(
    'client, vehicle, appointment, checklist and financial status form a local flow',
    () async {
      final client = await store
          .from('clients')
          .insert({
            'full_name': 'Cliente de teste',
            'email': 'test@example.com',
          })
          .select()
          .single();
      final vehicle = await store
          .from('vehicles')
          .insert({
            'client_id': client['id'],
            'model': 'Veículo fictício',
            'category': 'Sedan',
          })
          .select()
          .single();
      final appointment = await store
          .from('appointments')
          .insert({
            'client_id': client['id'],
            'vehicle_id': vehicle['id'],
            'start_time': DateTime(2026, 11, 26, 10).toUtc().toIso8601String(),
          })
          .select()
          .single();
      final item = await store
          .from('appointment_services')
          .insert({
            'appointment_id': appointment['id'],
            'service_id': 1,
            'price': 120.0,
          })
          .select()
          .single();
      await store
          .from('appointment_services')
          .update({'completed': true})
          .eq('id', item['id']);
      await store
          .from('appointments')
          .update({
            'status': 'concluido',
            'payment_method': 'cartao',
            'tip_amount': 10.0,
          })
          .eq('id', appointment['id']);
      final found = await store
          .from('appointments')
          .select(
            'clients(full_name), appointment_services(price, completed, services(name))',
          )
          .gte('start_time', '2026-11-26T00:00:00.000Z')
          .lte('start_time', '2026-11-26T23:59:59.000Z')
          .inFilter('payment_method', ['cartao'])
          .single();
      expect(found['id'], appointment['id']);
      expect(found['appointment_services'].single['completed'], true);
      expect(found['clients']['full_name'], 'Cliente de teste');
      await store.from('clients').delete().eq('id', client['id']);
      expect(
        await store.from('vehicles').select().eq('client_id', client['id']),
        isEmpty,
      );
      expect(
        await store.from('appointments').select().eq('id', appointment['id']),
        isEmpty,
      );
      expect(
        await store
            .from('appointment_services')
            .select()
            .eq('appointment_id', appointment['id']),
        isEmpty,
      );
    },
  );

  test(
    'invalid money and mismatched vehicle are rejected without partial writes',
    () async {
      await expectLater(
        store.from('services').insert({'name': 'Inválido', 'price': -1}),
        throwsStateError,
      );
      expect(await store.from('services').select(), hasLength(4));
      await expectLater(
        store.from('appointments').insert({
          'client_id': 1,
          'vehicle_id': 2,
          'start_time': '2026-11-25T15:00:00Z',
        }),
        throwsStateError,
      );
      expect(await store.from('appointments').select(), hasLength(5));
      await expectLater(
        store.from('services').delete().eq('id', 1),
        throwsStateError,
      );
      expect(await store.from('services').select().eq('id', 1), hasLength(1));
    },
  );

  test(
    'service stream updates after CRUD and reset restores fixtures',
    () async {
      final events = store
          .from('services')
          .stream(primaryKey: ['id'])
          .order('name')
          .take(2)
          .toList();
      await Future<void>.delayed(Duration.zero);
      await store.from('services').insert({
        'name': 'Serviço fictício novo',
        'price': 45.0,
      });
      final emissions = await events;
      expect(emissions[0], hasLength(4));
      expect(emissions[1], hasLength(5));
      store.reset(persist: false, now: DateTime(2026, 11, 25, 12));
      expect(await store.from('services').select(), hasLength(4));
    },
  );
}
