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
  // Dados do Banco
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _allServices = []; // Lista completa disponível
  List<Map<String, dynamic>> _clientVehicles = [];

  // Seleções do Usuário
  int? _selectedClientId;
  int? _selectedVehicleId;

  // --- LISTA DE SERVIÇOS SELECIONADOS (NOVO) ---
  List<Map<String, dynamic>> _selectedServices = [];

  // Data e Hora
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Configura data/hora
    if (widget.appointmentToEdit != null) {
      final startTime = DateTime.parse(
        widget.appointmentToEdit!['start_time'],
      ).toLocal();
      _selectedDate = startTime;
      _selectedTime = TimeOfDay.fromDateTime(startTime);

      _selectedClientId = widget.appointmentToEdit!['client_id'];
      _selectedVehicleId = widget.appointmentToEdit!['vehicle_id'];
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }

    _fetchInitialData();
  }

  // Carrega Dados Iniciais
  Future<void> _fetchInitialData() async {
    final supabase = Supabase.instance.client;

    try {
      // 1. Clientes (Só quem tem veículo)
      final clientsData = await supabase
          .from('clients')
          .select('*, vehicles!inner(id)')
          .order('full_name');

      // 2. Serviços Disponíveis
      final servicesData = await supabase
          .from('services')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(clientsData);
          _allServices = List<Map<String, dynamic>>.from(servicesData);
        });

        // Se estiver editando, carrega veículos
        if (_selectedClientId != null) {
          _fetchVehicles(_selectedClientId!);
        }

        // --- LÓGICA DE EDIÇÃO (LEGADO VS NOVO) ---
        if (widget.appointmentToEdit != null) {
          // A. Verifica se já existem itens na tabela nova (appointment_services)
          final itemsData = await supabase
              .from('appointment_services')
              .select('service_id, services(*)') // Join para pegar detalhes
              .eq('appointment_id', widget.appointmentToEdit!['id']);

          if (itemsData.isNotEmpty) {
            setState(() {
              _selectedServices = List<Map<String, dynamic>>.from(
                itemsData.map((item) => item['services']),
              );
            });
          }
          // B. Fallback: Se não achar na nova, verifica se tem ID antigo na tabela appointments
          else if (widget.appointmentToEdit!['service_id'] != null) {
            final legacyId = widget.appointmentToEdit!['service_id'];
            final legacyService = _allServices.firstWhere(
              (s) => s['id'] == legacyId,
              orElse: () => {},
            );
            if (legacyService.isNotEmpty) {
              setState(() {
                _selectedServices.add(legacyService);
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro init: $e');
    }
  }

  // Carrega Veículos
  Future<void> _fetchVehicles(int clientId) async {
    final vehiclesData = await Supabase.instance.client
        .from('vehicles')
        .select()
        .eq('client_id', clientId);

    if (mounted) {
      setState(() {
        _clientVehicles = List<Map<String, dynamic>>.from(vehiclesData);

        // Seleção Automática (Se só tiver 1)
        if (_clientVehicles.length == 1) {
          _selectedVehicleId = _clientVehicles.first['id'];
        } else {
          if (_selectedVehicleId != null) {
            final exists = _clientVehicles.any(
              (v) => v['id'] == _selectedVehicleId,
            );
            if (!exists) {
              _selectedVehicleId = null;
            }
          }
        }
      });
    }
  }

  // --- UI: DIALOG DE SELEÇÃO MÚLTIPLA ---
  void _showMultiSelectServices() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Selecione os Serviços'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allServices.length,
                  itemBuilder: (context, index) {
                    final service = _allServices[index];
                    final isSelected = _selectedServices.any(
                      (s) => s['id'] == service['id'],
                    );

                    return CheckboxListTile(
                      title: Text(service['name']),
                      subtitle: Text('R\$ ${service['price']}'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            _selectedServices.add(service);
                          } else {
                            _selectedServices.removeWhere(
                              (s) => s['id'] == service['id'],
                            );
                          }
                        });
                        // Atualiza a tela de trás (AddAppointmentScreen) para recalcular total
                        this.setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _totalPrice {
    return _selectedServices.fold(
      0.0,
      (sum, item) => sum + (item['price'] ?? 0),
    );
  }

  // --- GOOGLE CALENDAR ---
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
      debugPrint('Erro Google: $e');
    }
    return null;
  }

  // --- SALVAR ---
  Future<void> _save() async {
    if (_selectedClientId == null || _selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione Cliente e Veículo!')),
      );
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um serviço!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // 1. Datas
      final finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final endTime = finalDateTime.add(const Duration(hours: 1));

      // 2. Textos
      final clientName = _clients.firstWhere(
        (c) => c['id'] == _selectedClientId,
      )['full_name'];
      final servicesNames = _selectedServices.map((s) => s['name']).join(' + ');

      final googleTitle = 'Vlinix: $servicesNames - $clientName';
      final googleDesc = 'Serviços: $servicesNames\nTotal: R\$ $_totalPrice';

      // 3. Google Calendar (Somente Criação por enquanto para simplificar)
      String? googleEventId;
      if (widget.appointmentToEdit == null) {
        googleEventId = await _createGoogleEvent(
          title: googleTitle,
          description: googleDesc,
          startTime: finalDateTime,
          endTime: endTime,
        );
      }

      // 4. Salvar Agendamento (PAI)
      int appointmentId;

      if (widget.appointmentToEdit == null) {
        // Create
        final response = await supabase
            .from('appointments')
            .insert({
              'user_id': userId,
              'client_id': _selectedClientId,
              'vehicle_id': _selectedVehicleId,
              'start_time': finalDateTime.toUtc().toIso8601String(),
              'status': 'pendente',
              'google_event_id': googleEventId,
              // 'service_id' agora fica NULL
            })
            .select()
            .single();

        appointmentId = response['id'];
      } else {
        // Update
        appointmentId = widget.appointmentToEdit!['id'];
        await supabase
            .from('appointments')
            .update({
              'client_id': _selectedClientId,
              'vehicle_id': _selectedVehicleId,
              'start_time': finalDateTime.toUtc().toIso8601String(),
            })
            .eq('id', appointmentId);

        // Remove vínculos antigos para regravar (estratégia segura de update)
        await supabase
            .from('appointment_services')
            .delete()
            .eq('appointment_id', appointmentId);
      }

      // 5. Salvar Itens (FILHOS)
      final List<Map<String, dynamic>> servicesToInsert = _selectedServices.map(
        (service) {
          return {
            'user_id': userId,
            'appointment_id': appointmentId,
            'service_id': service['id'],
            'price': service['price'],
          };
        },
      ).toList();

      if (servicesToInsert.isNotEmpty) {
        await supabase.from('appointment_services').insert(servicesToInsert);
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
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.titleEditClient : lang.btnNew),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: isLargeScreen ? Colors.grey[100] : Colors.white,

      body: _clients.isEmpty || _allServices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Container(
                    width: isLargeScreen ? 500 : double.infinity,
                    padding: isLargeScreen
                        ? const EdgeInsets.all(32)
                        : EdgeInsets.zero,
                    decoration: isLargeScreen
                        ? BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                                _selectedVehicleId = null;
                              });
                              _fetchVehicles(value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Veículo
                        DropdownButtonFormField<int>(
                          value: _selectedVehicleId,
                          decoration: InputDecoration(
                            labelText: lang.labelVehicle,
                            border: const OutlineInputBorder(),
                          ),
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
                              : (value) =>
                                    setState(() => _selectedVehicleId = value),
                          hint: _selectedClientId == null
                              ? const Text('Selecione um cliente primeiro')
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // --- CAMPO DE SERVIÇOS (MULTI-SELECT) ---
                        InkWell(
                          onTap: _showMultiSelectServices,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Serviços',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: _selectedServices.isEmpty
                                ? const Text(
                                    'Selecione os serviços...',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                : Wrap(
                                    spacing: 8.0,
                                    children: _selectedServices.map((s) {
                                      return Chip(
                                        label: Text(s['name']),
                                        backgroundColor: Colors.blue[50],
                                        deleteIcon: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedServices.remove(s);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                        // Total
                        if (_selectedServices.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Total Estimado: R\$ $_totalPrice',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Data e Hora
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_selectedDate),
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
                              elevation: isLargeScreen ? 2 : 1,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    isEditing
                                        ? lang.btnUpdate.toUpperCase()
                                        : lang.btnSchedule.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
