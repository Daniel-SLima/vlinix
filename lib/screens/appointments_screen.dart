import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';

import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart'; // Adicionado para debugPrint

// IMPORT NECESSÁRIO PARA TRADUÇÃO:
import 'package:vlinix/l10n/app_localizations.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _appointmentsStream = Supabase.instance.client
      .from('appointments')
      .stream(primaryKey: ['id'])
      .order('start_time', ascending: true);

  List<Map<String, dynamic>> _clients = [];

  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();

    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    final clientsData = await Supabase.instance.client
        .from('clients')
        .select()
        .order('full_name');

    final servicesData = await Supabase.instance.client
        .from('services')
        .select()
        .order('name');

    if (mounted) {
      setState(() {
        _clients = List<Map<String, dynamic>>.from(clientsData);

        _services = List<Map<String, dynamic>>.from(servicesData);
      });
    }
  }

  // ==============================================================================

  // FUNÇÕES DO GOOGLE CALENDAR

  // ==============================================================================

  Future<String?> _getSessionToken() async {
    final session = Supabase.instance.client.auth.currentSession;

    return session?.providerToken;
  }

  // 1. CRIAR EVENTO NO GOOGLE (Retorna o ID do Google)

  Future<String?> _createGoogleEvent({
    required String title,

    required String description,

    required DateTime startTime,

    required DateTime endTime,
  }) async {
    final token = await _getSessionToken();

    if (token == null) return null;

    final event = {
      'summary': title,

      'description': description,

      'start': {
        'dateTime': startTime.toIso8601String(),

        'timeZone': 'America/Sao_Paulo',
      },

      'end': {
        'dateTime': endTime.toIso8601String(),

        'timeZone': 'America/Sao_Paulo',
      },
    };

    try {
      final response = await http.post(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events',
        ),

        headers: {
          'Authorization': 'Bearer $token',

          'Content-Type': 'application/json',
        },

        body: jsonEncode(event),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        return json['id']; // <--- Pega o ID que o Google criou!
      }
    } catch (e) {
      debugPrint('Erro Create Google: $e');
    }

    return null;
  }

  // 2. ATUALIZAR EVENTO NO GOOGLE

  Future<void> _updateGoogleEvent({
    required String googleEventId,

    required String title,

    required String description,

    required DateTime startTime,

    required DateTime endTime,
  }) async {
    final token = await _getSessionToken();

    if (token == null) return;

    final event = {
      'summary': title,

      'description': description,

      'start': {
        'dateTime': startTime.toIso8601String(),

        'timeZone': 'America/Sao_Paulo',
      },

      'end': {
        'dateTime': endTime.toIso8601String(),

        'timeZone': 'America/Sao_Paulo',
      },
    };

    try {
      await http.put(
        // Usa PUT para atualizar
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events/$googleEventId',
        ),

        headers: {
          'Authorization': 'Bearer $token',

          'Content-Type': 'application/json',
        },

        body: jsonEncode(event),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.msgGoogleUpdated),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro Update Google: $e');
    }
  }

  // 3. APAGAR EVENTO NO GOOGLE

  Future<void> _deleteGoogleEvent(String googleEventId) async {
    final token = await _getSessionToken();

    if (token == null) return;

    try {
      await http.delete(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events/$googleEventId',
        ),

        headers: {'Authorization': 'Bearer $token'},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.msgGoogleDeleted),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro Delete Google: $e');
    }
  }

  // ==============================================================================

  // LÓGICA DO APP (SUPABASE + UI)

  // ==============================================================================

  Future<void> _deleteAppointment(int id, String? googleEventId) async {
    try {
      // 1. Apaga do Google se tiver ID

      if (googleEventId != null && googleEventId.isNotEmpty) {
        await _deleteGoogleEvent(googleEventId);
      }

      // 2. Apaga do Supabase

      await Supabase.instance.client.from('appointments').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),

            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAppointmentDialog({Map<String, dynamic>? appointmentToEdit}) {
    final lang = AppLocalizations.of(context)!;

    int? selectedClientId = appointmentToEdit?['client_id'];

    int? selectedVehicleId = appointmentToEdit?['vehicle_id'];

    int? selectedServiceId = appointmentToEdit?['service_id'];

    String? currentGoogleId =
        appointmentToEdit?['google_event_id']; // ID DO GOOGLE

    DateTime initialDate = appointmentToEdit != null
        ? DateTime.parse(appointmentToEdit['start_time']).toLocal()
        : DateTime.now();

    DateTime selectedDate = initialDate;

    TimeOfDay selectedTime = TimeOfDay.fromDateTime(initialDate);

    List<Map<String, dynamic>> clientVehicles = [];

    // Carrega veículos se estiver editando

    if (appointmentToEdit != null && selectedClientId != null) {
      Supabase.instance.client
          .from('vehicles')
          .select()
          .eq('client_id', selectedClientId)
          .then((data) {
            if (mounted) {
              // Atualiza a lista mas não rebuilda tudo, o StatefulBuilder cuida disso se chamar dentro
            }
          });
    }

    showDialog(
      context: context,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Gambiarra de carregamento

            if (appointmentToEdit != null &&
                clientVehicles.isEmpty &&
                selectedClientId != null) {
              Supabase.instance.client
                  .from('vehicles')
                  .select()
                  .eq('client_id', selectedClientId!)
                  .then((data) {
                    if (mounted) {
                      setStateDialog(
                        () => clientVehicles = List<Map<String, dynamic>>.from(
                          data,
                        ),
                      );
                    }
                  });
            }

            return AlertDialog(
              title: Text(
                appointmentToEdit == null
                    ? lang
                          .btnNew // "Novo"
                    : lang.titleEditClient, // "Editar..." (Reutilizando ou crie "Editar Agendamento" no arb se preferir)
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    DropdownButtonFormField<int>(
                      initialValue:
                          selectedClientId, // Alterado de value para initialValue

                      decoration: InputDecoration(
                        labelText: lang.labelClient, // "Cliente"

                        border: const OutlineInputBorder(),
                      ),

                      items: _clients
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as int,

                              child: Text(c['full_name']),
                            ),
                          )
                          .toList(),

                      onChanged: (value) async {
                        if (value != null) {
                          final vehiclesData = await Supabase.instance.client
                              .from('vehicles')
                              .select()
                              .eq('client_id', value);

                          setStateDialog(() {
                            selectedClientId = value;

                            selectedVehicleId = null;

                            clientVehicles = List<Map<String, dynamic>>.from(
                              vehiclesData,
                            );
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      initialValue:
                          selectedVehicleId, // Alterado de value para initialValue

                      decoration: InputDecoration(
                        labelText: lang.labelVehicle, // "Veículo"

                        border: const OutlineInputBorder(),
                      ),

                      items: clientVehicles
                          .map(
                            (v) => DropdownMenuItem(
                              value: v['id'] as int,

                              child: Text('${v['model']} (${v['plate']})'),
                            ),
                          )
                          .toList(),

                      onChanged: (value) =>
                          setStateDialog(() => selectedVehicleId = value),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<int>(
                      initialValue:
                          selectedServiceId, // Alterado de value para initialValue

                      decoration: InputDecoration(
                        labelText: lang.labelService, // "Serviço"

                        border: const OutlineInputBorder(),
                      ),

                      items: _services
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as int,

                              child: Text('${s['name']} (R\$ ${s['price']})'),
                            ),
                          )
                          .toList(),

                      onChanged: (value) =>
                          setStateDialog(() => selectedServiceId = value),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),

                            label: Text(
                              DateFormat('dd/MM/yyyy').format(selectedDate),
                            ),

                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,

                                initialDate: selectedDate,

                                firstDate: DateTime(2020),

                                lastDate: DateTime(2030),
                              );

                              if (date != null) {
                                setStateDialog(() => selectedDate = date);
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),

                            label: Text(selectedTime.format(context)),

                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,

                                initialTime: selectedTime,
                              );

                              if (time != null) {
                                setStateDialog(() => selectedTime = time);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),

                  child: Text(lang.btnCancel),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (selectedClientId != null &&
                        selectedVehicleId != null &&
                        selectedServiceId != null) {
                      final finalDateTime = DateTime(
                        selectedDate.year,

                        selectedDate.month,

                        selectedDate.day,

                        selectedTime.hour,

                        selectedTime.minute,
                      );

                      final endTime = finalDateTime.add(
                        const Duration(hours: 1),
                      );

                      // Infos para o Google

                      final clientName = _clients.firstWhere(
                        (c) => c['id'] == selectedClientId,
                      )['full_name'];

                      final serviceName = _services.firstWhere(
                        (s) => s['id'] == selectedServiceId,
                      )['name'];

                      final googleTitle = 'Vlinix: $serviceName - $clientName';

                      final googleDesc = 'Agendamento App Vlinix';

                      if (appointmentToEdit == null) {
                        // --- PROCESSO DE CRIAÇÃO ---

                        // 1. Cria no Google primeiro para pegar o ID

                        String? newGoogleId = await _createGoogleEvent(
                          title: googleTitle,

                          description: googleDesc,

                          startTime: finalDateTime,

                          endTime: endTime,
                        );

                        // 2. Salva no Supabase COM o ID do Google

                        await Supabase.instance.client
                            .from('appointments')
                            .insert({
                              'client_id': selectedClientId,

                              'vehicle_id': selectedVehicleId,

                              'service_id': selectedServiceId,

                              'start_time': finalDateTime
                                  .toUtc()
                                  .toIso8601String(),

                              'status': 'pendente',

                              'google_event_id':
                                  newGoogleId, // <--- SALVA O ID AQUI
                            });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Agendado e Sincronizado!'),
                            ),
                          );
                        }
                      } else {
                        // --- PROCESSO DE EDIÇÃO ---

                        // 1. Atualiza no Supabase

                        await Supabase.instance.client
                            .from('appointments')
                            .update({
                              'client_id': selectedClientId,

                              'vehicle_id': selectedVehicleId,

                              'service_id': selectedServiceId,

                              'start_time': finalDateTime
                                  .toUtc()
                                  .toIso8601String(),
                            })
                            .eq('id', appointmentToEdit['id']);

                        // 2. Atualiza no Google (se tiver ID)

                        if (currentGoogleId != null &&
                            currentGoogleId.isNotEmpty) {
                          await _updateGoogleEvent(
                            googleEventId: currentGoogleId,

                            title: googleTitle,

                            description: googleDesc,

                            startTime: finalDateTime,

                            endTime: endTime,
                          );
                        } else {
                          // Se não tinha ID (foi criado antes dessa atualização), cria um novo evento agora

                          String? newId = await _createGoogleEvent(
                            title: googleTitle,

                            description: googleDesc,

                            startTime: finalDateTime,

                            endTime: endTime,
                          );

                          // Atualiza o banco com o novo ID

                          if (newId != null) {
                            await Supabase.instance.client
                                .from('appointments')
                                .update({'google_event_id': newId})
                                .eq('id', appointmentToEdit['id']);
                          }
                        }
                      }

                      if (mounted) Navigator.pop(context);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preencha tudo!')),
                        );
                      }
                    }
                  },

                  child: Text(
                    appointmentToEdit == null
                        ? lang.btnSchedule
                        : lang.btnUpdate, // "Agendar" ou "Salvar"
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String isoString) {
    return DateFormat(
      'dd/MM HH:mm',
    ).format(DateTime.parse(isoString).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.menuAgenda), // "Agenda"

        backgroundColor: const Color(0xFF1E88E5),

        foregroundColor: Colors.white,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAppointmentDialog(),

        label: Text(lang.btnNew), // "Novo"

        icon: const Icon(Icons.add),

        backgroundColor: const Color(0xFF1E88E5),

        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _appointmentsStream,

        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final appointments = snapshot.data!;

          if (appointments.isEmpty)
            return Center(
              child: Text(lang.agendaEmptyUpcoming),
            ); // "Sem agendamentos"

          return ListView.builder(
            itemCount: appointments.length,

            itemBuilder: (context, index) {
              final apt = appointments[index];

              return FutureBuilder(
                future: Future.wait([
                  Supabase.instance.client
                      .from('clients')
                      .select()
                      .eq('id', apt['client_id'])
                      .single(),

                  Supabase.instance.client
                      .from('vehicles')
                      .select()
                      .eq('id', apt['vehicle_id'])
                      .single(),

                  Supabase.instance.client
                      .from('services')
                      .select()
                      .eq('id', apt['service_id'])
                      .single(),
                ]),

                builder: (context, AsyncSnapshot<List<dynamic>> detailsSnapshot) {
                  if (!detailsSnapshot.hasData)
                    return const LinearProgressIndicator();

                  final client = detailsSnapshot.data![0];

                  final vehicle = detailsSnapshot.data![1];

                  final service = detailsSnapshot.data![2];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: apt['status'] == 'pendente'
                            ? Colors.orange
                            : Colors.green,

                        child: const Icon(
                          Icons.calendar_today,

                          color: Colors.white,

                          size: 18,
                        ),
                      ),

                      title: Text(
                        client['full_name'],

                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text('${vehicle['model']} - ${service['name']}'),

                          Text(
                            _formatDate(apt['start_time']),

                            style: TextStyle(
                              color: Colors.blue.shade800,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),

                            onPressed: () =>
                                _showAppointmentDialog(appointmentToEdit: apt),
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),

                            onPressed: () {
                              showDialog(
                                context: context,

                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    lang.dialogDeleteTitle,
                                  ), // "Excluir?"

                                  content: const Text(
                                    'Isso apagará do app e do Google Agenda.',
                                  ),

                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),

                                      child: Text(lang.btnCancel),
                                    ),

                                    TextButton(
                                      onPressed: () {
                                        _deleteAppointment(
                                          apt['id'],

                                          apt['google_event_id'],
                                        ); // Passa o ID do Google

                                        Navigator.pop(ctx);
                                      },

                                      child: Text(
                                        lang.btnDelete, // "Excluir"

                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
