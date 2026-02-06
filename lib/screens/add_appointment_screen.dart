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
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _clientVehicles = [];

  // Seleções do Usuário
  int? _selectedClientId;
  int? _selectedVehicleId;

  // Lista de Serviços Selecionados
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

        if (_selectedClientId != null) {
          _fetchVehicles(_selectedClientId!);
        }

        // Lógica de Edição (Carregar serviços existentes)
        if (widget.appointmentToEdit != null) {
          // A. Busca na tabela nova
          final itemsData = await supabase
              .from('appointment_services')
              .select('service_id, services(*)')
              .eq('appointment_id', widget.appointmentToEdit!['id']);

          if (itemsData.isNotEmpty) {
            setState(() {
              _selectedServices = List<Map<String, dynamic>>.from(
                itemsData.map((item) => item['services']),
              );
            });
          }
          // B. Fallback (Legado)
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

  Future<void> _fetchVehicles(int clientId) async {
    final vehiclesData = await Supabase.instance.client
        .from('vehicles')
        .select()
        .eq('client_id', clientId);

    if (mounted) {
      setState(() {
        _clientVehicles = List<Map<String, dynamic>>.from(vehiclesData);

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

  // --- MUDANÇA AQUI: DIALOG RESPONSIVO ---
  void _showMultiSelectServices() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final lang = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Usamos Dialog + Container para controlar a largura exata
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                // AQUI ESTÁ O SEGREDO: Largura fixa no PC, ou ajustada no celular
                width: isLargeScreen ? 500 : null,
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height *
                      0.8, // Altura máx 80% da tela
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min, // Encolhe se tiver poucos itens
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      lang.labelSelectServices, // "Selecionar Serviços"
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lista Scrollável
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _allServices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final service = _allServices[index];
                          final isSelected = _selectedServices.any(
                            (s) => s['id'] == service['id'],
                          );

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              service['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'R\$ ${service['price']}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            activeColor: const Color(0xFF1E88E5),
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
                              this.setState(
                                () {},
                              ); // Atualiza tela de trás (Total)
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botão Fechar
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'OK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final lang = AppLocalizations.of(context)!;

    if (_selectedClientId == null || _selectedVehicleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.msgSelectClientVehicle)));
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.msgSelectService)));
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

      // 3. Google Calendar
      String? googleEventId;
      if (widget.appointmentToEdit == null) {
        googleEventId = await _createGoogleEvent(
          title: googleTitle,
          description: googleDesc,
          startTime: finalDateTime,
          endTime: endTime,
        );
      }

      // 4. Salvar Pai
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

        // Remove vínculos antigos
        await supabase
            .from('appointment_services')
            .delete()
            .eq('appointment_id', appointmentId);
      }

      // 5. Salvar Filhos
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

                        // --- CAMPO DE SERVIÇOS (CLICÁVEL) ---
                        InkWell(
                          onTap: _showMultiSelectServices,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: lang.labelService, // "Serviço"
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            child: _selectedServices.isEmpty
                                ? Text(
                                    lang.labelSelectServices,
                                    style: const TextStyle(color: Colors.grey),
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
                                '${lang.labelTotal}: R\$ $_totalPrice',
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
