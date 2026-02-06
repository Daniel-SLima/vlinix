import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/main.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';

import 'add_client_screen.dart';
import 'add_vehicle_screen.dart';
import 'add_appointment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _todayAppointmentsCount = 0;
  List<Map<String, dynamic>> _todayAppointments = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();

      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      const selectQuery = '''
        *,
        clients(full_name),
        vehicles(model, plate),
        services(name),
        appointment_services(price, services(name))
      ''';

      // 1. Busca Agendamentos de HOJE
      final todayData = await supabase
          .from('appointments')
          .select(selectQuery)
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay)
          .order('start_time', ascending: true);

      // 2. Busca PRÓXIMOS Agendamentos
      final upcomingData = await supabase
          .from('appointments')
          .select(selectQuery)
          .gt('start_time', endOfDay)
          .order('start_time', ascending: true);

      if (mounted) {
        setState(() {
          _todayAppointments = List<Map<String, dynamic>>.from(todayData);
          _todayAppointmentsCount = _todayAppointments.length;
          _upcomingAppointments = List<Map<String, dynamic>>.from(upcomingData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro Dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(
    int id,
    String newStatus, {
    String? paymentMethod,
  }) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      if (newStatus == 'concluido') {
        updateData['payment_method'] = paymentMethod;
      } else {
        updateData['payment_method'] = null;
      }

      await Supabase.instance.client
          .from('appointments')
          .update(updateData)
          .eq('id', id);

      await _loadDashboardData();

      if (mounted) {
        final lang = AppLocalizations.of(context)!;
        bool isCompleted = newStatus == 'concluido';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCompleted ? '${lang.statusDone} ✅' : '${lang.statusPending} 🟠',
            ),
            backgroundColor: isCompleted ? AppColors.success : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showPaymentDialog(int appointmentId) {
    final lang = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: Text(lang.dialogPaymentTitle),
          children: [
            _buildPaymentOption(
              ctx,
              appointmentId,
              lang.paymentCash,
              Icons.money,
              Colors.green,
            ),
            _buildPaymentOption(
              ctx,
              appointmentId,
              lang.paymentCard,
              Icons.credit_card,
              Colors.blue,
            ),
            _buildPaymentOption(
              ctx,
              appointmentId,
              lang.paymentPlan,
              Icons.calendar_today,
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  SimpleDialogOption _buildPaymentOption(
    BuildContext ctx,
    int id,
    String label,
    IconData icon,
    Color color,
  ) {
    return SimpleDialogOption(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
      onPressed: () {
        Navigator.pop(ctx);
        _updateStatus(id, 'concluido', paymentMethod: label);
      },
    );
  }

  String _formatTime(String isoString) {
    return DateFormat('HH:mm').format(DateTime.parse(isoString).toLocal());
  }

  Map<String, dynamic> _processAppointmentData(Map<String, dynamic> apt) {
    String serviceNames = '';
    double totalPrice = 0.0;

    if (apt['appointment_services'] != null &&
        (apt['appointment_services'] as List).isNotEmpty) {
      final items = apt['appointment_services'] as List;
      serviceNames = items.map((i) => i['services']['name']).join(', ');
      totalPrice = items.fold(0.0, (sum, i) => sum + (i['price'] ?? 0.0));
    } else if (apt['services'] != null) {
      serviceNames = apt['services']['name'];
    } else {
      serviceNames = 'Serviço não identificado';
    }

    return {
      'clientName': apt['clients'] != null
          ? apt['clients']['full_name']
          : 'Desconhecido',
      'vehicleInfo': apt['vehicles'] != null
          ? "${apt['vehicles']['model']} (${apt['vehicles']['plate']})"
          : 'Carro?',
      'serviceNames': serviceNames,
      'totalPrice': totalPrice,
      'isCompleted': apt['status'] == 'concluido',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final String displayName =
        currentUser?.userMetadata?['full_name'] ?? 'Usuário';
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo_symbol.png',
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(lang.appTitle),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String langCode) =>
                MyApp.setLocale(context, Locale(langCode)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pt', child: Text('🇧🇷 Português')),
              PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
              PopupMenuItem(value: 'es', child: Text('🇪🇸 Español')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),

      floatingActionButton: _buildFab(),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Olá, $displayName",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons.today,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${lang.agendaToday} ($_todayAppointmentsCount)",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildAppointmentList(
                      _todayAppointments,
                      isToday: true,
                      emptyMsg: lang.agendaEmptyToday,
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.agendaUpcoming,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildAppointmentList(
                      _upcomingAppointments,
                      isToday: false,
                      emptyMsg: lang.agendaEmptyUpcoming,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFab() {
    final lang = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      offset: const Offset(0, -200),
      tooltip: lang.btnNew,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      onSelected: (value) {
        Widget screen;
        if (value == 'cliente')
          screen = const AddClientScreen();
        else if (value == 'carro')
          screen = const AddVehicleScreen();
        else
          screen = const AddAppointmentScreen();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ).then((_) => _loadDashboardData());
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'cliente',
          child: Row(
            children: [
              const Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(lang.titleNewClient),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'carro',
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(lang.titleNewVehicle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'agendamento',
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(lang.titleNewAppointment),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentList(
    List<Map<String, dynamic>> list, {
    required bool isToday,
    required String emptyMsg,
  }) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              isToday ? Icons.check_circle_outline : Icons.event_busy,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final apt = list[index];
        final data = _processAppointmentData(apt);

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.accent.withOpacity(0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(apt['start_time']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppColors.primary : Colors.grey[700],
                    ),
                  ),
                  if (!isToday)
                    Text(
                      DateFormat(
                        'dd/MM',
                      ).format(DateTime.parse(apt['start_time']).toLocal()),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
            title: Text(
              data['clientName'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${data['vehicleInfo']}",
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
                if (data['serviceNames'].toString().isNotEmpty)
                  Text(
                    "${data['serviceNames']}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (data['totalPrice'] > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "R\$ ${data['totalPrice'].toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                data['isCompleted']
                    ? Icons.check_circle
                    : Icons.pending_outlined,
                color: data['isCompleted'] ? AppColors.success : Colors.orange,
                size: 28,
              ),
              tooltip: data['isCompleted'] ? 'Reabrir' : 'Concluir',
              onPressed: () {
                final lang = AppLocalizations.of(context)!;
                if (data['isCompleted']) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('${lang.statusPending}?'),
                      content: const Text('Deseja voltar para pendente?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            lang.btnCancel,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(apt['id'], 'pendente');
                          },
                          child: Text(lang.statusPending),
                        ),
                      ],
                    ),
                  );
                } else {
                  _showPaymentDialog(apt['id']);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
