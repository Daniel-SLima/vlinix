import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
// import 'package:vlinix/services/google_calendar_service.dart'; // <--- COMENTADO

import 'add_client_screen.dart';
import 'add_service_screen.dart';
import 'add_vehicle_screen.dart';

class AddAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic>? appointmentToEdit;

  const AddAppointmentScreen({super.key, this.appointmentToEdit});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _clientVehicles = [];

  int? _selectedClientId;
  int? _selectedVehicleId;
  List<Map<String, dynamic>> _selectedServices = [];

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  bool _isLoading = false;
  bool _isFetchingInitialData = true;

  bool _hasClients = false;
  bool _hasVehicles = false;
  bool _hasServices = false;

  @override
  void initState() {
    super.initState();
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
    setState(() => _isFetchingInitialData = true);

    final supabase = AppBackend.client;
    try {
      final clientsData = await supabase
          .from('clients')
          .select('*, vehicles(id)')
          .order('full_name');

      final servicesData = await supabase
          .from('services')
          .select()
          .order('name');

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(clientsData);
          _allServices = List<Map<String, dynamic>>.from(servicesData);

          _hasClients = _clients.isNotEmpty;
          _hasVehicles = _clients.any(
            (c) => c['vehicles'] != null && (c['vehicles'] as List).isNotEmpty,
          );
          _hasServices = _allServices.isNotEmpty;

          _isFetchingInitialData = false;
        });

        if (_selectedClientId != null) {
          _fetchVehicles(_selectedClientId!);
        }

        if (widget.appointmentToEdit != null) {
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
        }
      }
    } catch (e) {
      debugPrint('Erro init: $e');
      if (mounted) {
        setState(() => _isFetchingInitialData = false);
      }
    }
  }

  Future<void> _fetchVehicles(int clientId) async {
    final vehiclesData = await AppBackend.client
        .from('vehicles')
        .select()
        .eq('client_id', clientId)
        .order('model');

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
            if (!exists) _selectedVehicleId = null;
          }
        }
      });
    }
  }

  void _showMultiSelectServices() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final lang = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: isLargeScreen ? 500 : null,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.labelSelectServices,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _allServices.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
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
                              '${NumberFormat.simpleCurrency(name: '').currencySymbol} ${service['price']}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            activeColor: AppColors.accent,
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
                              this.setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
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
      final supabase = AppBackend.client;
      final userId = supabase.auth.currentUser!.id;

      final finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // COMENTADO: As variáveis abaixo eram usadas pro Google Calendar
      // final endTime = finalDateTime.add(const Duration(hours: 1));
      // final clientName = _clients.firstWhere((c) => c['id'] == _selectedClientId)['full_name'];
      // final servicesNames = _selectedServices.map((s) => s['name']).join(' + ');
      // final googleTitle = 'Vlinix: $servicesNames - $clientName';
      // final googleDesc = 'Serviços: $servicesNames\nTotal: ${NumberFormat.simpleCurrency(name: '').currencySymbol} $_totalPrice';

      String? googleEventId;

      /* --- GOOGLE CALENDAR COMENTADO ---
      if (widget.appointmentToEdit == null) {
        googleEventId = await GoogleCalendarService.instance.insertEvent(
          title: googleTitle,
          description: googleDesc,
          startTime: finalDateTime,
          endTime: endTime,
        );
      }
      ----------------------------------- */

      int appointmentId;

      if (widget.appointmentToEdit == null) {
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
        appointmentId = widget.appointmentToEdit!['id'];
        await supabase
            .from('appointments')
            .update({
              'client_id': _selectedClientId,
              'vehicle_id': _selectedVehicleId,
              'start_time': finalDateTime.toUtc().toIso8601String(),
            })
            .eq('id', appointmentId);

        await supabase
            .from('appointment_services')
            .delete()
            .eq('appointment_id', appointmentId);
      }

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
          SnackBar(
            content: Text(lang.msgAppointmentSaved),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorGeneric(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    Widget screen,
  ) {
    return SizedBox(
      width: 250,
      height: 45,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          ).then((_) => _fetchInitialData());
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final lang = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 80,
              color: Colors.orange.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              lang.msgAlmostThere,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lang.msgNeedClientAndService,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            if (!_hasClients) ...[
              _buildActionButton(
                lang.btnRegisterClient,
                Icons.person_add,
                AppColors.primary,
                const AddClientScreen(),
              ),
              const SizedBox(height: 16),
            ],
            if (_hasClients && !_hasVehicles) ...[
              _buildActionButton(
                lang.btnRegisterVehicle,
                Icons.directions_car,
                AppColors.primary,
                const AddVehicleScreen(),
              ),
              const SizedBox(height: 16),
            ],
            if (!_hasServices) ...[
              _buildActionButton(
                lang.btnRegisterService,
                Icons.design_services,
                AppColors.accent,
                const AddServiceScreen(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final isEditing = widget.appointmentToEdit != null;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.titleEditClient : lang.btnNew),
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body: _isFetchingInitialData
          ? const Center(child: CircularProgressIndicator())
          : (!_hasClients || !_hasVehicles || !_hasServices)
          ? _buildEmptyState()
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
                        DropdownButtonFormField<int>(
                          value: _selectedClientId,
                          decoration: InputDecoration(
                            labelText: lang.labelClient,
                            prefixIcon: const Icon(Icons.person),
                          ),
                          items: _clients
                              .where(
                                (c) =>
                                    c['vehicles'] != null &&
                                    (c['vehicles'] as List).isNotEmpty,
                              )
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedVehicleId,
                                decoration: InputDecoration(
                                  labelText: lang.labelVehicle,
                                  prefixIcon: const Icon(Icons.directions_car),
                                ),
                                items: _clientVehicles
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v['id'] as int,
                                        child: Text(
                                          '${v['model']} - ${v['category'] ?? lang.labelCategoryNoCategory}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _selectedClientId == null
                                    ? null
                                    : (value) => setState(
                                        () => _selectedVehicleId = value,
                                      ),
                                hint: _selectedClientId == null
                                    ? Text(lang.msgSelectClientFirst)
                                    : null,
                              ),
                            ),
                            if (_selectedClientId != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  tooltip: lang
                                      .tooltipAddNewVehicle, // <-- TRADUZIDO AQUI
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddVehicleScreen(
                                          preSelectedClientId:
                                              _selectedClientId,
                                        ),
                                      ),
                                    ).then((_) {
                                      _fetchVehicles(_selectedClientId!);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        InkWell(
                          onTap: _showMultiSelectServices,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: lang.labelService,
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
                                        backgroundColor: AppColors.accent
                                            .withOpacity(0.1),
                                        labelStyle: const TextStyle(
                                          color: AppColors.primary,
                                        ),
                                        deleteIcon: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: AppColors.primary,
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
                        if (_selectedServices.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${lang.labelEstimatedTotal}: ${NumberFormat.simpleCurrency(name: '').currencySymbol} ${_totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.calendar_today,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_selectedDate),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: AppColors.primary,
                                            onPrimary: Colors.white,
                                            onSurface: AppColors.primary,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (date != null)
                                    setState(() => _selectedDate = date);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.access_time,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  _selectedTime.format(context),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: AppColors.primary,
                                            onPrimary: Colors.white,
                                            onSurface: AppColors.primary,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (time != null)
                                    setState(() => _selectedTime = time);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
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
                                      letterSpacing: 1,
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
