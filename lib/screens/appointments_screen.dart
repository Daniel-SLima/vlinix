import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart'; // <--- IMPORTANTE
import 'add_appointment_screen.dart';

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

  // --- GOOGLE DELETE ---
  Future<String?> _getSessionToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.providerToken;
  }

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
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro Delete Google: $e');
    }
  }

  // --- APP DELETE ---
  Future<void> _deleteAppointment(int id, String? googleEventId) async {
    // Confirmação antes de apagar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Agendamento?'),
        content: const Text('Isso apagará do app e do Google Agenda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (googleEventId != null && googleEventId.isNotEmpty) {
        await _deleteGoogleEvent(googleEventId);
      }
      await Supabase.instance.client.from('appointments').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // --- NAVEGAÇÃO ---
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
        title: Text(lang.menuAgenda),
        centerTitle: true,
        // Theme cuida das cores (Chumbo)
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        label: Text(
          lang.btnNew,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.accent, // Dourado
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _appointmentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
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
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              80,
            ), // Espaço pro FAB
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final apt = appointments[index];

              // Mantemos o FutureBuilder pois a lógica original busca dados individuais
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
                builder:
                    (context, AsyncSnapshot<List<dynamic>> detailsSnapshot) {
                      if (!detailsSnapshot.hasData) {
                        // Placeholder enquanto carrega os detalhes
                        return const Card(
                          child: ListTile(
                            leading: CircularProgressIndicator(strokeWidth: 2),
                            title: Text("Carregando..."),
                          ),
                        );
                      }

                      final client = detailsSnapshot.data![0];
                      final vehicle = detailsSnapshot.data![1];
                      final service = detailsSnapshot.data![2];
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
                          // Indicador Visual de Status
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
                              Text('${vehicle['model']} - ${service['name']}'),
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
                              } else if (value == 'delete') {
                                _deleteAppointment(
                                  apt['id'],
                                  apt['google_event_id'],
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Excluir'),
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
