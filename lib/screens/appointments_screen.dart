import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'add_appointment_screen.dart'; // IMPORTANTE: Importe a nova tela

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
  // Mantemos aqui pois deletar acontece na lista
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
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro Delete Google: $e');
    }
  }

  // --- APP DELETE ---
  Future<void> _deleteAppointment(int id, String? googleEventId) async {
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
            backgroundColor: Colors.red,
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
      appBar: AppBar(
        title: Text(lang.menuAgenda),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        label: Text(lang.btnNew),
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
            return Center(child: Text(lang.agendaEmptyUpcoming));

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
                                _navigateToAddEdit(appointment: apt),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(lang.dialogDeleteTitle),
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
                                        );
                                        Navigator.pop(ctx);
                                      },
                                      child: Text(
                                        lang.btnDelete,
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
