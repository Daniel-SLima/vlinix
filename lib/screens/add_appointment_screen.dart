import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:vlinix/l10n/app_localizations.dart';

class AddAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic>? appointmentToEdit;

  const AddAppointmentScreen({super.key, this.appointmentToEdit});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  // Dados dos Dropdowns
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _clientVehicles = [];

  // Seleções
  int? _selectedClientId;
  int? _selectedVehicleId;
  int? _selectedServiceId;

  // Data e Hora
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Configura data/hora inicial
    if (widget.appointmentToEdit != null) {
      final startTime = DateTime.parse(
        widget.appointmentToEdit!['start_time'],
      ).toLocal();
      _selectedDate = startTime;
      _selectedTime = TimeOfDay.fromDateTime(startTime);

      _selectedClientId = widget.appointmentToEdit!['client_id'];
      _selectedVehicleId = widget.appointmentToEdit!['vehicle_id'];
      _selectedServiceId = widget.appointmentToEdit!['service_id'];
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    _fetchInitialData();
  }

  // Carrega Clientes e Serviços
  Future<void> _fetchInitialData() async {
    final supabase = Supabase.instance.client;

    final clientsData = await supabase
        .from('clients')
        .select()
        .order('full_name');
    final servicesData = await supabase.from('services').select().order('name');

    if (mounted) {
      setState(() {
        _clients = List<Map<String, dynamic>>.from(clientsData);
        _services = List<Map<String, dynamic>>.from(servicesData);
      });

      // Se estiver editando, precisamos carregar os veículos do cliente selecionado
      if (_selectedClientId != null) {
        _fetchVehicles(_selectedClientId!);
      }
    }
  }

  // Carrega Veículos quando escolhe um Cliente
  Future<void> _fetchVehicles(int clientId) async {
    final vehiclesData = await Supabase.instance.client
        .from('vehicles')
        .select()
        .eq('client_id', clientId);

    if (mounted) {
      setState(() {
        _clientVehicles = List<Map<String, dynamic>>.from(vehiclesData);
        // Se o veículo selecionado não pertencer mais a lista (trocou de cliente), limpa
        if (_clientVehicles.every((v) => v['id'] != _selectedVehicleId)) {
          _selectedVehicleId = null;
        }
      });
    }
  }

  // --- LÓGICA DO GOOGLE CALENDAR (Create/Update) ---

  Future<String?> _getSessionToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.providerToken;
  }

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
        return json['id'];
      }
    } catch (e) {
      debugPrint('Erro Create Google: $e');
    }
    return null;
  }

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
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events/$googleEventId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(event),
      );
    } catch (e) {
      debugPrint('Erro Update Google: $e');
    }
  }

  // --- SALVAR ---

  Future<void> _save() async {
    if (_selectedClientId == null ||
        _selectedVehicleId == null ||
        _selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Preparar Datas
      final finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final endTime = finalDateTime.add(const Duration(hours: 1));

      // 2. Dados para o Google
      final clientName = _clients.firstWhere(
        (c) => c['id'] == _selectedClientId,
      )['full_name'];
      final serviceName = _services.firstWhere(
        (s) => s['id'] == _selectedServiceId,
      )['name'];
      final googleTitle = 'Vlinix: $serviceName - $clientName';
      final googleDesc = 'Agendamento App Vlinix';

      // 3. Lógica Principal
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      if (widget.appointmentToEdit == null) {
        // --- CRIAÇÃO ---

        // A. Cria no Google
        String? newGoogleId = await _createGoogleEvent(
          title: googleTitle,
          description: googleDesc,
          startTime: finalDateTime,
          endTime: endTime,
        );

        // B. Salva no Banco
        await supabase.from('appointments').insert({
          'user_id': userId,
          'client_id': _selectedClientId,
          'vehicle_id': _selectedVehicleId,
          'service_id': _selectedServiceId,
          'start_time': finalDateTime.toUtc().toIso8601String(),
          'status': 'pendente',
          'google_event_id': newGoogleId,
        });
      } else {
        // --- EDIÇÃO ---

        // A. Atualiza no Banco
        await supabase
            .from('appointments')
            .update({
              'client_id': _selectedClientId,
              'vehicle_id': _selectedVehicleId,
              'service_id': _selectedServiceId,
              'start_time': finalDateTime.toUtc().toIso8601String(),
            })
            .eq('id', widget.appointmentToEdit!['id']);

        // B. Atualiza no Google
        String? currentGoogleId = widget.appointmentToEdit!['google_event_id'];

        if (currentGoogleId != null && currentGoogleId.isNotEmpty) {
          await _updateGoogleEvent(
            googleEventId: currentGoogleId,
            title: googleTitle,
            description: googleDesc,
            startTime: finalDateTime,
            endTime: endTime,
          );
        } else {
          // Se não tinha evento, cria um
          String? newId = await _createGoogleEvent(
            title: googleTitle,
            description: googleDesc,
            startTime: finalDateTime,
            endTime: endTime,
          );
          if (newId != null) {
            await supabase
                .from('appointments')
                .update({'google_event_id': newId})
                .eq('id', widget.appointmentToEdit!['id']);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final isEditing = widget.appointmentToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? lang.titleEditClient : lang.btnNew,
        ), // Reutilizando strings existentes
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: _clients.isEmpty || _services.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Cliente
                  DropdownButtonFormField<int>(
                    value: _selectedClientId,
                    decoration: InputDecoration(
                      labelText: lang.labelClient,
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedClientId = value;
                          _selectedVehicleId =
                              null; // Reseta veículo ao trocar cliente
                        });
                        _fetchVehicles(value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Veículo (Depende do Cliente)
                  DropdownButtonFormField<int>(
                    value: _selectedVehicleId,
                    decoration: InputDecoration(
                      labelText: lang.labelVehicle,
                      border: const OutlineInputBorder(),
                    ),
                    // Se não tiver cliente selecionado ou não tiver veículos, mostra lista vazia ou desabilita
                    items: _clientVehicles
                        .map(
                          (v) => DropdownMenuItem(
                            value: v['id'] as int,
                            child: Text('${v['model']} (${v['plate']})'),
                          ),
                        )
                        .toList(),
                    onChanged: _selectedClientId == null
                        ? null
                        : (value) => setState(() => _selectedVehicleId = value),
                    hint: _selectedClientId == null
                        ? const Text('Selecione um cliente primeiro')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Serviço
                  DropdownButtonFormField<int>(
                    value: _selectedServiceId,
                    decoration: InputDecoration(
                      labelText: lang.labelService,
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
                        setState(() => _selectedServiceId = value),
                  ),
                  const SizedBox(height: 24),

                  // Data e Hora
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null)
                              setState(() => _selectedDate = date);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(_selectedTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (time != null)
                              setState(() => _selectedTime = time);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEditing
                                  ? lang.btnUpdate.toUpperCase()
                                  : lang.btnSchedule.toUpperCase(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
