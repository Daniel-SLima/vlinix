import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Adicionado para debugPrint

// --- NOVOS IMPORTS NECESSÁRIOS ---
import 'package:vlinix/main.dart'; // Para acessar MyApp.setLocale
import 'package:vlinix/l10n/app_localizations.dart'; // Para os textos traduzidos
// ---------------------------------

import 'login_screen.dart';
import 'clients_screen.dart';
import 'services_screen.dart';
import 'appointments_screen.dart';
import 'all_vehicles_screen.dart';
import 'finance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _user = Supabase.instance.client.auth.currentUser;

  // Variáveis
  int _totalClients = 0;
  int _totalVehicles = 0;
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
      // 1. Totais
      final clientsData = await supabase.from('clients').select('id');
      final vehiclesData = await supabase.from('vehicles').select('id');

      // Datas de Hoje
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

      // 2. Busca HOJE
      final todayData = await supabase
          .from('appointments')
          .select(
            '*, clients(full_name), vehicles(model, plate), services(name)',
          )
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay)
          .order('start_time', ascending: true);

      // 3. Busca PRÓXIMOS (Futuro) - Limite de 5
      final upcomingData = await supabase
          .from('appointments')
          .select(
            '*, clients(full_name), vehicles(model, plate), services(name)',
          )
          .gt('start_time', endOfDay)
          .order('start_time', ascending: true)
          .limit(5);

      if (mounted) {
        setState(() {
          _totalClients = (clientsData as List).length;
          _totalVehicles = (vehiclesData as List).length;
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

  // --- ALTERAR STATUS COM PAGAMENTO ---
  Future<void> _updateStatus(
    int id,
    String newStatus, {
    String? paymentMethod,
  }) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};

      // Se for concluir, salva o pagamento. Se for reabrir, limpa o pagamento.
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
              isCompleted
                  ? '${lang.statusDone} ($paymentMethod) ✅'
                  : '${lang.statusPending} 🟠',
            ),
            backgroundColor: isCompleted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- DIÁLOGO DE PAGAMENTO ---
  void _showPaymentDialog(int appointmentId, String serviceName) {
    final lang = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: Text(lang.dialogPaymentTitle), // "Forma de Pagamento"
          children: [
            SimpleDialogOption(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const Icon(Icons.money, color: Colors.green),
                  const SizedBox(width: 10),
                  Text(lang.paymentCash), // "Dinheiro"
                ],
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(
                  appointmentId,
                  'concluido',
                  paymentMethod: 'Dinheiro', // Mantém string original p/ banco
                );
              },
            ),
            SimpleDialogOption(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text(lang.paymentCard), // "Cartão"
                ],
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(
                  appointmentId,
                  'concluido',
                  paymentMethod: 'Cartão',
                );
              },
            ),
            SimpleDialogOption(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.purple),
                  const SizedBox(width: 10),
                  Text(lang.paymentPlan), // "Plano Mensal"
                ],
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(
                  appointmentId,
                  'concluido',
                  paymentMethod: 'Plano Mensal',
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
  }

  String _formatTime(String isoString) {
    return DateFormat('HH:mm').format(DateTime.parse(isoString).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = _user?.userMetadata?['full_name'] ?? 'Usuário';
    final String email = _user?.email ?? 'email@vlinix.com';
    final String? photoUrl = _user?.userMetadata?['avatar_url'];

    // Instância de tradução
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang.appTitle, // "Vlinix Dashboard"
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // --- NOVO BOTÃO DE LÍNGUAS ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String langCode) {
              MyApp.setLocale(context, Locale(langCode));
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'pt', child: Text('🇧🇷 Português')),
              const PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
              const PopupMenuItem(value: 'es', child: Text('🇪🇸 Español')),
            ],
          ),
          // -----------------------------
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),

      // --- AQUI ESTÁ A MUDANÇA SOLICITADA ---
      floatingActionButton: PopupMenuButton<String>(
        offset: const Offset(0, -200), // Faz o menu abrir "para cima" do botão
        tooltip: 'Criar Novo',
        // O "child" é o botão em si, desenhado como um FAB
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E88E5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
        onSelected: (value) {
          if (value == 'cliente') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientsScreen()),
            ).then((_) => _loadDashboardData());
          } else if (value == 'carro') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllVehiclesScreen()),
            ).then((_) => _loadDashboardData());
          } else if (value == 'agendamento') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
            ).then((_) => _loadDashboardData());
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'cliente',
            child: Row(
              children: [
                Icon(Icons.person_add, color: Colors.blue),
                SizedBox(width: 10),
                Text('Novo Cliente'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'carro',
            child: Row(
              children: [
                Icon(Icons.directions_car, color: Colors.orange),
                SizedBox(width: 10),
                Text('Novo Carro'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'agendamento',
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.green),
                SizedBox(width: 10),
                Text('Novo Agendamento'),
              ],
            ),
          ),
        ],
      ),

      // -------------------------------------
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E88E5)),
              accountName: Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(email),
              currentAccountPicture: CircleAvatar(
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null ? const Icon(Icons.person) : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Color(0xFF1E88E5)),
              title: Text(
                lang.menuOverview, // "Visão Geral"
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.monetization_on, color: Colors.green),
              title: Text(
                lang.menuFinance, // "Financeiro"
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FinanceScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(lang.menuAgenda), // "Agenda"
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentsScreen(),
                  ),
                ).then((_) => _loadDashboardData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(lang.menuClients), // "Clientes"
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientsScreen(),
                  ),
                ).then((_) => _loadDashboardData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(lang.menuVehicles), // "Veículos"
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllVehiclesScreen(),
                  ),
                ).then((_) => _loadDashboardData());
              },
            ),
            ListTile(
              leading: const Icon(Icons.price_change),
              title: Text(lang.menuServices), // "Serviços"
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServicesScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: Text(
                lang.menuLogout,
                style: const TextStyle(color: Colors.red),
              ), // "Sair"
              onTap: _signOut,
            ),
          ],
        ),
      ),

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
                    Row(
                      children: [
                        _buildInfoCard(
                          lang.dashboardClients, // "Clientes"
                          '$_totalClients',
                          Icons.people,
                          Colors.blue,
                        ),
                        const SizedBox(width: 10),
                        _buildInfoCard(
                          lang.dashboardVehicles, // "Veículos"
                          '$_totalVehicles',
                          Icons.directions_car,
                          Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        _buildInfoCard(
                          lang.dashboardToday, // "Hoje"
                          '$_todayAppointmentsCount',
                          Icons.calendar_today,
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text(
                      lang.agendaToday, // "Agenda de Hoje"
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAppointmentList(
                      _todayAppointments,
                      isToday: true,
                      emptyMsg: lang.agendaEmptyToday,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      lang.agendaUpcoming, // "Próximos Agendamentos"
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAppointmentList(
                      _upcomingAppointments,
                      isToday: false,
                      emptyMsg: lang.agendaEmptyUpcoming,
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
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
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              isToday ? Icons.check_circle_outline : Icons.event_busy,
              size: 40,
              color: Colors.grey,
            ),
            const SizedBox(height: 10),
            Text(
              emptyMsg, // "Tudo livre..." ou "Sem agendamentos..."
              style: const TextStyle(color: Colors.grey),
            ),
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
        final clientName = apt['clients'] != null
            ? apt['clients']['full_name']
            : 'Desconhecido';
        final vehicleInfo = apt['vehicles'] != null
            ? "${apt['vehicles']['model']} (${apt['vehicles']['plate']})"
            : 'Carro?';
        final serviceName = apt['services'] != null
            ? apt['services']['name']
            : 'Serviço?';
        final bool isCompleted = apt['status'] == 'concluido';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? Colors.blue.shade50 : Colors.grey.shade200,
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
                      color: isToday ? Colors.blue.shade800 : Colors.black87,
                    ),
                  ),
                  if (!isToday)
                    Text(
                      DateFormat(
                        'dd/MM',
                      ).format(DateTime.parse(apt['start_time']).toLocal()),
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
            title: Text(
              clientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("$vehicleInfo • $serviceName"),
            trailing: IconButton(
              icon: Icon(
                isCompleted ? Icons.check_circle : Icons.pending,
                color: isCompleted ? Colors.green : Colors.orange,
                size: 30,
              ),
              tooltip: isCompleted ? 'Reabrir Serviço' : 'Concluir Serviço',
              onPressed: () {
                final lang = AppLocalizations.of(context)!;
                if (isCompleted) {
                  // Se já está completo, pergunta se quer reabrir (volta para pendente)
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('${lang.statusPending}?'), // "Pendente?"
                      content: const Text(
                        'Deseja voltar o status para pendente?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(lang.btnCancel),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
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
                  // Se está pendente, abre o diálogo de pagamento
                  _showPaymentDialog(apt['id'], serviceName);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 5)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 5,
            ), // Alterado withOpacity para withValues
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
