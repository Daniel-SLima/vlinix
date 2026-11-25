import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/services/device_calendar_service.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';
import 'add_appointment_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _appointmentsStream = AppBackend.client
      .from('appointments')
      .stream(primaryKey: ['id'])
      .order('start_time', ascending: true);

  // --- APP DELETE ---
  Future<void> _deleteAppointment(int id) async {
    final lang = AppLocalizations.of(context)!; // Trazido para cá

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.dialogDeleteAppointmentTitle), // NOVA CHAVE
        content: Text(lang.dialogDeleteAppointmentContent), // NOVA CHAVE
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.btnCancel,
              style: const TextStyle(color: Colors.grey),
            ), // Usando chave existente
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.btnDelete), // Usando chave existente
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AppBackend.client.from('appointments').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.msgErrorGeneric(e.toString()),
            ), // CHAVE RECENTE DA ETAPA ANTERIOR
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openInDeviceCalendar(
    Map<String, dynamic> apt,
    Map<String, dynamic> client,
    Map<String, dynamic> vehicle,
    List<dynamic> appointmentServices,
  ) async {
    final lang = AppLocalizations.of(context)!;
    final startTime = DateTime.parse(apt['start_time']).toLocal();
    final endTime = apt['end_time'] != null
        ? DateTime.parse(apt['end_time']).toLocal()
        : startTime.add(const Duration(hours: 1));

    final services = appointmentServices
        .map((item) => item['services']?['name'])
        .whereType<String>()
        .join(', ');
    final title = 'Vlinix: ${services.isEmpty ? lang.menuServicos : services}';
    final vehicleLabel = [
      vehicle['brand'],
      vehicle['model'],
      vehicle['color'],
    ].whereType<String>().where((item) => item.isNotEmpty).join(' ');

    final ok = await DeviceCalendarService.openCalendarInvite(
      title: title,
      description: 'Cliente: ${client['full_name']}\nVeiculo: $vehicleLabel',
      startTime: startTime,
      endTime: endTime,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Arquivo de calendario gerado.'
              : 'Nao foi possivel abrir o calendario neste dispositivo.',
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _navigateToAddEdit({Map<String, dynamic>? appointment}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddAppointmentScreen(appointmentToEdit: appointment),
      ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // --- 1. AVATAR ---
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),

        title: Text(lang.menuAgenda),
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        label: Text(
          lang.btnNew,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _appointmentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Trocado para usar chave
            return Center(
              child: Text(lang.msgErrorGeneric(snapshot.error.toString())),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data!;

          if (appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    lang.agendaEmptyUpcoming,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final apt = appointments[index];

              return FutureBuilder(
                future: Future.wait([
                  AppBackend.client
                      .from('clients')
                      .select()
                      .eq('id', apt['client_id'])
                      .single(),
                  AppBackend.client
                      .from('vehicles')
                      .select()
                      .eq('id', apt['vehicle_id'])
                      .single(),
                  AppBackend.client
                      .from('appointment_services')
                      .select('price, services(name)')
                      .eq('appointment_id', apt['id']),
                ]),
                builder:
                    (context, AsyncSnapshot<List<dynamic>> detailsSnapshot) {
                      if (!detailsSnapshot.hasData) {
                        return Card(
                          child: ListTile(
                            leading: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                            title: Text(lang.msgLoading), // NOVA CHAVE
                          ),
                        );
                      }

                      final client = detailsSnapshot.data![0];
                      final vehicle = detailsSnapshot.data![1];
                      final appointmentServices =
                          detailsSnapshot.data![2] as List<dynamic>;
                      final servicesLabel = appointmentServices
                          .map((item) => item['services']?['name'])
                          .whereType<String>()
                          .join(', ');
                      final bool isPending = apt['status'] == 'pendente';

                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.orange.withOpacity(0.1)
                                  : AppColors.success.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              color: isPending
                                  ? Colors.orange
                                  : AppColors.success,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            client['full_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('${vehicle['model']} - $servicesLabel'),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(apt['start_time']),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _navigateToAddEdit(appointment: apt);
                              } else if (value == 'calendar') {
                                _openInDeviceCalendar(
                                  apt,
                                  client,
                                  vehicle,
                                  appointmentServices,
                                );
                              } else if (value == 'delete') {
                                _deleteAppointment(apt['id']);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'calendar',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_available,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Abrir no calendario'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.edit,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      lang.btnEdit,
                                    ), // Usando chave existente
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      lang.btnDelete,
                                    ), // Usando chave existente
                                  ],
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
        },
      ),
    );
  }
}
