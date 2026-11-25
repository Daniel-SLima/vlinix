import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

typedef DemoRow = Map<String, dynamic>;

/// Local adapter for the query operations used by the existing Vlinix screens.
/// There is no HTTP client, remote database, credential, or network fallback.
class DemoStore {
  static const storageKey = 'vlinix:public-demo:v1';
  static const userId = 'vlinix-fictional-detailer';
  final DemoAuth auth = DemoAuth();
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Map<String, List<DemoRow>> _tables = {};
  bool persistentStorageAvailable = true;

  DemoStore() {
    reset(persist: false);
    if (kIsWeb) {
      try {
        final raw = html.window.localStorage[storageKey];
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          if (decoded['version'] == 1 && decoded['tables'] is Map) {
            final saved = Map<String, dynamic>.from(decoded['tables']);
            if (_tables.keys.every((key) => saved[key] is List)) {
              _tables = saved.map(
                (key, value) => MapEntry(
                  key,
                  (value as List).map((row) => DemoRow.from(row)).toList(),
                ),
              );
            }
          }
        }
      } catch (_) {
        // A stale or unavailable browser store must not prevent exploration.
        persistentStorageAvailable = false;
      }
    }
  }

  LocalQuery from(String table) {
    if (!_tables.containsKey(table)) {
      throw StateError('Tabela indisponível nesta demonstração: $table');
    }
    return LocalQuery(this, table);
  }

  void reset({bool persist = true, DateTime? now}) {
    final reference = now ?? DateTime.now();
    String date(int offset, int hour) => DateTime(
      reference.year,
      reference.month,
      (offset < 0 && reference.day + offset < 1) ? 1 : reference.day + offset,
      hour,
    ).toUtc().toIso8601String();
    final created = reference.toUtc().toIso8601String();
    _tables = {
      'profiles': [
        {
          'id': userId,
          'full_name': 'Alex Demo',
          'email': 'demo@vlinix.example',
          'is_active': true,
        },
      ],
      'global_announcements': <DemoRow>[],
      'clients': [
        {
          'id': 1,
          'user_id': userId,
          'full_name': 'Marina Exemplo',
          'phone': '+1 (202) 555-0101',
          'email': 'marina@example.com',
          'address': 'Rua Exemplo, 100 | Cidade Fictícia',
          'created_at': created,
        },
        {
          'id': 2,
          'user_id': userId,
          'full_name': 'Rafael Demonstração',
          'phone': '+1 (202) 555-0102',
          'email': 'rafael@example.com',
          'address': 'Avenida Modelo, 200 | Cidade Fictícia',
          'created_at': created,
        },
        {
          'id': 3,
          'user_id': userId,
          'full_name': 'Oficina Horizonte (fictícia)',
          'phone': '+1 (202) 555-0103',
          'email': 'oficina@example.com',
          'address': 'Alameda Demonstração, 300 | Cidade Fictícia',
          'created_at': created,
        },
      ],
      'vehicles': [
        {
          'id': 1,
          'user_id': userId,
          'client_id': 1,
          'model': 'Sedã Exemplo',
          'category': 'Sedan',
          'color': 'Prata',
          'created_at': created,
        },
        {
          'id': 2,
          'user_id': userId,
          'client_id': 2,
          'model': 'SUV Demonstração',
          'category': 'SUV',
          'color': 'Preto',
          'created_at': created,
        },
        {
          'id': 3,
          'user_id': userId,
          'client_id': 3,
          'model': 'Sedã Modelo',
          'category': 'Sedan',
          'color': 'Branco',
          'created_at': created,
        },
      ],
      'services': [
        {
          'id': 1,
          'user_id': userId,
          'name': 'Lavagem técnica',
          'price': 120.0,
          'created_at': created,
        },
        {
          'id': 2,
          'user_id': userId,
          'name': 'Higienização interna',
          'price': 320.0,
          'created_at': created,
        },
        {
          'id': 3,
          'user_id': userId,
          'name': 'Polimento comercial',
          'price': 680.0,
          'created_at': created,
        },
        {
          'id': 4,
          'user_id': userId,
          'name': 'Proteção de pintura',
          'price': 180.0,
          'created_at': created,
        },
      ],
      'appointments': [
        {
          'id': 1,
          'user_id': userId,
          'client_id': 1,
          'vehicle_id': 1,
          'start_time': date(0, 10),
          'status': 'pendente',
          'payment_method': null,
          'tip_amount': 0.0,
          'google_event_id': null,
        },
        {
          'id': 2,
          'user_id': userId,
          'client_id': 2,
          'vehicle_id': 2,
          'start_time': date(0, 15),
          'status': 'em_andamento',
          'payment_method': null,
          'tip_amount': 0.0,
          'google_event_id': null,
        },
        {
          'id': 3,
          'user_id': userId,
          'client_id': 3,
          'vehicle_id': 3,
          'start_time': date(1, 14),
          'status': 'pendente',
          'payment_method': null,
          'tip_amount': 0.0,
          'google_event_id': null,
        },
        {
          'id': 4,
          'user_id': userId,
          'client_id': 1,
          'vehicle_id': 1,
          'start_time': date(-2, 9),
          'status': 'concluido',
          'payment_method': 'dinheiro',
          'tip_amount': 20.0,
          'google_event_id': null,
        },
        {
          'id': 5,
          'user_id': userId,
          'client_id': 2,
          'vehicle_id': 2,
          'start_time': date(-4, 11),
          'status': 'concluido',
          'payment_method': 'cartao',
          'tip_amount': 0.0,
          'google_event_id': null,
        },
      ],
      'appointment_services': [
        {
          'id': 1,
          'user_id': userId,
          'appointment_id': 1,
          'service_id': 1,
          'price': 120.0,
          'completed': false,
        },
        {
          'id': 2,
          'user_id': userId,
          'appointment_id': 2,
          'service_id': 2,
          'price': 320.0,
          'completed': false,
        },
        {
          'id': 3,
          'user_id': userId,
          'appointment_id': 3,
          'service_id': 3,
          'price': 680.0,
          'completed': false,
        },
        {
          'id': 4,
          'user_id': userId,
          'appointment_id': 4,
          'service_id': 1,
          'price': 120.0,
          'completed': true,
        },
        {
          'id': 5,
          'user_id': userId,
          'appointment_id': 4,
          'service_id': 4,
          'price': 180.0,
          'completed': true,
        },
        {
          'id': 6,
          'user_id': userId,
          'appointment_id': 5,
          'service_id': 2,
          'price': 320.0,
          'completed': true,
        },
      ],
      'expenses': [
        {
          'id': 1,
          'user_id': userId,
          'description': 'Produtos de limpeza (exemplo)',
          'amount': 110.0,
          'date': date(-2, 12),
        },
        {
          'id': 2,
          'user_id': userId,
          'description': 'Material de consumo (exemplo)',
          'amount': 95.0,
          'date': date(-3, 12),
        },
      ],
    };
    if (persist) _persist();
  }

  DemoRow? _find(String table, dynamic id) {
    for (final row in _tables[table]!) {
      if (row['id'] == id) return DemoRow.from(row);
    }
    return null;
  }

  DemoRow _joined(String table, DemoRow source, String selection) {
    final row = DemoRow.from(source);
    if (table == 'clients' && selection.contains('vehicles(')) {
      row['vehicles'] = _tables['vehicles']!
          .where((vehicle) => vehicle['client_id'] == row['id'])
          .map(DemoRow.from)
          .toList();
    }
    if (table == 'appointments') {
      if (selection.contains('clients('))
        row['clients'] = _find('clients', row['client_id']);
      if (selection.contains('vehicles('))
        row['vehicles'] = _find('vehicles', row['vehicle_id']);
      if (selection.contains('services('))
        row['services'] = _find('services', row['service_id']);
      if (selection.contains('appointment_services(')) {
        row['appointment_services'] = _tables['appointment_services']!
            .where((item) => item['appointment_id'] == row['id'])
            .map((item) => _joined('appointment_services', item, 'services(*)'))
            .toList();
      }
    }
    if (table == 'appointment_services' && selection.contains('services(')) {
      row['services'] = _find('services', row['service_id']);
    }
    return row;
  }

  void _validate(String table, DemoRow row) {
    void requiredText(String key) {
      if ((row[key] ?? '').toString().trim().isEmpty)
        throw StateError('Preencha o campo $key.');
    }

    void positive(String key) {
      final value = row[key];
      if (value is! num || !value.isFinite || value < 0)
        throw StateError('O valor deve ser um número não negativo.');
    }

    if (table == 'clients') requiredText('full_name');
    if (table == 'services') {
      requiredText('name');
      positive('price');
    }
    if (table == 'expenses') {
      requiredText('description');
      positive('amount');
    }
    if (table == 'vehicles') {
      requiredText('model');
      if (_find('clients', row['client_id']) == null)
        throw StateError('Cliente não encontrado.');
    }
    if (table == 'appointments') {
      final vehicle = _find('vehicles', row['vehicle_id']);
      if (_find('clients', row['client_id']) == null ||
          vehicle == null ||
          vehicle['client_id'] != row['client_id']) {
        throw StateError('Escolha um veículo pertencente ao cliente.');
      }
      if (![
        'pendente',
        'em_andamento',
        'concluido',
        'cancelado',
      ].contains(row['status']))
        throw StateError('Status inválido.');
      if (DateTime.tryParse(row['start_time']?.toString() ?? '') == null)
        throw StateError('Data inválida.');
      positive('tip_amount');
    }
    if (table == 'appointment_services') {
      if (_find('appointments', row['appointment_id']) == null ||
          _find('services', row['service_id']) == null) {
        throw StateError('Agendamento ou serviço não encontrado.');
      }
      positive('price');
    }
  }

  void _delete(String table, List<DemoRow> rows) {
    final ids = rows.map((row) => row['id']).toSet();
    if (table == 'services' &&
        _tables['appointment_services']!.any(
          (row) => ids.contains(row['service_id']),
        )) {
      throw StateError(
        'Este serviço está vinculado a agendamentos. Edite-o ou remova os agendamentos primeiro.',
      );
    }
    if (table == 'clients') {
      _delete(
        'vehicles',
        _tables['vehicles']!
            .where((row) => ids.contains(row['client_id']))
            .toList(),
      );
    }
    if (table == 'vehicles') {
      _delete(
        'appointments',
        _tables['appointments']!
            .where((row) => ids.contains(row['vehicle_id']))
            .toList(),
      );
    }
    if (table == 'appointments') {
      _tables['appointment_services']!.removeWhere(
        (row) => ids.contains(row['appointment_id']),
      );
    }
    _tables[table]!.removeWhere((row) => ids.contains(row['id']));
  }

  void _persist() {
    if (kIsWeb) {
      try {
        html.window.localStorage[storageKey] = jsonEncode({
          'version': 1,
          'tables': _tables,
        });
      } catch (_) {
        persistentStorageAvailable = false;
      }
    }
    _changes.add(null);
  }
}

class DemoAuth {
  final User currentUser = User(
    id: DemoStore.userId,
    appMetadata: const {},
    userMetadata: const {'full_name': 'Alex Demo'},
    aud: 'demo',
    email: 'demo@vlinix.example',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
  Session? get currentSession => null;
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();
}

class LocalQuery implements Future<dynamic> {
  final DemoStore store;
  final String table;
  final List<bool Function(DemoRow)> _filters = [];
  String _operation = 'read';
  String _selection = '*';
  String? _order;
  bool _ascending = true;
  bool _single = false;
  bool _nullable = false;
  dynamic _data;
  Future<dynamic>? _result;

  LocalQuery(this.store, this.table);
  LocalQuery select([String columns = '*']) {
    _selection = columns;
    return this;
  }

  LocalQuery insert(dynamic data) {
    _operation = 'insert';
    _data = data;
    return this;
  }

  LocalQuery update(Map<String, dynamic> data) {
    _operation = 'update';
    _data = data;
    return this;
  }

  LocalQuery delete() {
    _operation = 'delete';
    return this;
  }

  LocalQuery eq(String key, dynamic value) {
    _filters.add((row) => row[key] == value);
    return this;
  }

  LocalQuery inFilter(String key, List<dynamic> values) {
    _filters.add((row) => values.contains(row[key]));
    return this;
  }

  LocalQuery gte(String key, dynamic value) {
    _filters.add((row) => _compare(row[key], value) >= 0);
    return this;
  }

  LocalQuery lte(String key, dynamic value) {
    _filters.add((row) => _compare(row[key], value) <= 0);
    return this;
  }

  LocalQuery gt(String key, dynamic value) {
    _filters.add((row) => _compare(row[key], value) > 0);
    return this;
  }

  LocalQuery order(String column, {bool ascending = true}) {
    _order = column;
    _ascending = ascending;
    return this;
  }

  LocalQuery single() {
    _single = true;
    return this;
  }

  LocalQuery maybeSingle() {
    _single = true;
    _nullable = true;
    return this;
  }

  LocalStreamQuery stream({required List<String> primaryKey}) =>
      LocalStreamQuery(this);

  static int _compare(dynamic a, dynamic b) {
    if (a is num && b is num) return a.compareTo(b);
    final da = DateTime.tryParse(a?.toString() ?? '');
    final db = DateTime.tryParse(b?.toString() ?? '');
    if (da != null && db != null) return da.compareTo(db);
    return (a?.toString() ?? '').compareTo(b?.toString() ?? '');
  }

  List<DemoRow> _read() {
    final rows = store._tables[table]!
        .where((row) => _filters.every((test) => test(row)))
        .toList();
    if (_order != null)
      rows.sort(
        (a, b) => _compare(a[_order], b[_order]) * (_ascending ? 1 : -1),
      );
    return rows;
  }

  dynamic _execute() {
    List<DemoRow> rows;
    if (_operation == 'insert') {
      final input = _data is List ? _data as List : [_data];
      var nextId =
          store._tables[table]!.fold<int>(
            0,
            (maxId, row) => row['id'] is int && row['id'] > maxId
                ? row['id'] as int
                : maxId,
          ) +
          1;
      rows = input
          .map(
            (item) => <String, dynamic>{
              'id': nextId++,
              'user_id': DemoStore.userId,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              if (table == 'appointment_services') 'completed': false,
              if (table == 'appointments') ...{
                'tip_amount': 0.0,
                'payment_method': null,
                'google_event_id': null,
                'status': 'pendente',
              },
              ...DemoRow.from(item),
            },
          )
          .toList();
      for (final row in rows) {
        store._validate(table, row);
      }
      store._tables[table]!.addAll(rows);
    } else {
      rows = _read();
      if (_operation == 'update') {
        for (final row in rows) {
          store._validate(table, {...row, ...DemoRow.from(_data)});
        }
        for (final row in rows) {
          row.addAll(DemoRow.from(_data));
        }
      } else if (_operation == 'delete') {
        store._delete(table, rows);
      }
    }
    if (_operation != 'read') store._persist();
    final result = rows
        .map((row) => store._joined(table, row, _selection))
        .toList();
    if (_single) {
      if (result.isEmpty && _nullable) return null;
      if (result.length != 1)
        throw StateError('Registro não encontrado ou ambíguo.');
      return result.single;
    }
    return result;
  }

  Future<dynamic> get _future => _result ??= Future<dynamic>.sync(_execute);
  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic) onValue, {
    Function? onError,
  }) => _future.then<R>(onValue, onError: onError);
  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);
  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);
  @override
  Future<dynamic> timeout(
    Duration timeLimit, {
    FutureOr<dynamic> Function()? onTimeout,
  }) => _future.timeout(timeLimit, onTimeout: onTimeout);
  @override
  Stream<dynamic> asStream() => _future.asStream();
}

class LocalStreamQuery extends Stream<List<DemoRow>> {
  final LocalQuery query;
  LocalStreamQuery(this.query);
  LocalStreamQuery order(String column, {bool ascending = true}) {
    query.order(column, ascending: ascending);
    return this;
  }

  Stream<List<DemoRow>> _watch() async* {
    yield query._read().map(DemoRow.from).toList();
    await for (final _ in query.store._changes.stream) {
      yield query._read().map(DemoRow.from).toList();
    }
  }

  @override
  StreamSubscription<List<DemoRow>> listen(
    void Function(List<DemoRow>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _watch().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
