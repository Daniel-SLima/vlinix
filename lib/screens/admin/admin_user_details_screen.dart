import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/theme/app_colors.dart';

class AdminUserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailsScreen({super.key, required this.user});

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  bool _isLoading = true;

  int _totalClients = 0;
  int _totalAppointments = 0;
  double _totalRevenue = 0.0;
  bool _isActive = true; // --- NOVA VARIÁVEL DO INTERRUPTOR ---

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadUserMetrics();
  }

  // --- FUNÇÃO PARA LIGAR/DESLIGAR O USUÁRIO ---
  Future<void> _toggleUserStatus() async {
    final supabase = AppBackend.client;
    final userId = widget.user['id'];
    final newStatus = !_isActive; // Inverte o status atual

    // Mostra um aviso carregando
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus ? 'Reativando usuário...' : 'Suspendendo usuário...',
        ),
      ),
    );

    try {
      await supabase
          .from('profiles')
          .update({'is_active': newStatus})
          .eq('id', userId);

      setState(() {
        _isActive = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Usuário reativado com sucesso!'
                  : 'Usuário suspenso!',
            ),
            backgroundColor: newStatus ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao mudar status do usuário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar status.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyQuickFilter(String type) {
    final now = DateTime.now();
    setState(() {
      if (type == 'all') {
        _startDate = null;
        _endDate = null;
      } else if (type == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == '7days') {
        _startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (type == 'month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }
    });
    _loadUserMetrics();
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Filtrar Período do Usuário',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.all_inclusive,
                    color: AppColors.primary,
                  ),
                  title: const Text('Todo o período'),
                  onTap: () {
                    Navigator.pop(context);
                    _applyQuickFilter('all');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.today, color: AppColors.primary),
                  title: const Text('Hoje'),
                  onTap: () {
                    Navigator.pop(context);
                    _applyQuickFilter('today');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.view_week,
                    color: AppColors.primary,
                  ),
                  title: const Text('Últimos 7 dias'),
                  onTap: () {
                    Navigator.pop(context);
                    _applyQuickFilter('7days');
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                  ),
                  title: const Text('Este mês'),
                  onTap: () {
                    Navigator.pop(context);
                    _applyQuickFilter('month');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.date_range,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Data personalizada...',
                    style: TextStyle(color: AppColors.accent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDateRange();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
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

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
        _loadUserMetrics();
      });
    }
  }

  void _clearDateFilter() {
    _applyQuickFilter('all');
  }

  Future<void> _loadUserMetrics() async {
    setState(() => _isLoading = true);
    final supabase = AppBackend.client;
    final userId = widget.user['id'];

    try {
      // Busca o status atualizado do usuário
      final profileData = await supabase
          .from('profiles')
          .select('is_active')
          .eq('id', userId)
          .maybeSingle();

      final clientsData = await supabase
          .from('clients')
          .select('id')
          .eq('user_id', userId);

      var appointmentsQuery = supabase
          .from('appointments')
          .select(
            'id, tip_amount, appointment_services(price), services(price)',
          )
          .eq('user_id', userId)
          .eq('status', 'concluido');

      var allAppointmentsQuery = supabase
          .from('appointments')
          .select('id')
          .eq('user_id', userId);

      if (_startDate != null && _endDate != null) {
        appointmentsQuery = appointmentsQuery
            .gte('start_time', _startDate!.toUtc().toIso8601String())
            .lte('start_time', _endDate!.toUtc().toIso8601String());

        allAppointmentsQuery = allAppointmentsQuery
            .gte('start_time', _startDate!.toUtc().toIso8601String())
            .lte('start_time', _endDate!.toUtc().toIso8601String());
      }

      final appointmentsData = await appointmentsQuery;
      final allAppointments = await allAppointmentsQuery;

      double rev = 0.0;
      for (var apt in appointmentsData) {
        double aptTotal = 0.0;
        if (apt['appointment_services'] != null &&
            (apt['appointment_services'] as List).isNotEmpty) {
          for (var srv in apt['appointment_services']) {
            aptTotal += (srv['price'] ?? 0.0);
          }
        } else if (apt['services'] != null) {
          aptTotal += (apt['services']['price'] ?? 0.0);
        }
        double tip = (apt['tip_amount'] ?? 0.0).toDouble();
        rev += (aptTotal + tip);
      }

      if (mounted) {
        setState(() {
          _isActive =
              profileData?['is_active'] ?? true; // Atualiza o interruptor
          _totalClients = clientsData.length;
          _totalRevenue = rev;
          _totalAppointments = allAppointments.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar métricas do usuário: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['full_name'] ?? 'Usuário sem nome';
    final email = widget.user['email'] ?? 'Sem email';
    final dateStr = widget.user['created_at'];
    String memberSince = 'Data desconhecida';

    if (dateStr != null) {
      final date = DateTime.parse(dateStr).toLocal();
      memberSince = DateFormat('dd/MM/yyyy').format(date);
    }

    String dateLabel = 'Histórico Total';
    if (_startDate != null && _endDate != null) {
      final startStr = DateFormat('dd/MM/yyyy').format(_startDate!);
      final endStr = DateFormat('dd/MM/yyyy').format(_endDate!);
      dateLabel = startStr == endStr ? startStr : '$startStr até $endStr';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalhes do Usuário'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- CABEÇALHO DO PERFIL COM SINAL DE SUSPENSO ---
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _isActive
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: _isActive ? AppColors.accent : Colors.red,
                        ),
                      ),
                      if (!_isActive)
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.block,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isActive ? AppColors.primary : Colors.red,
                      decoration: _isActive
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Membro desde: $memberSince',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- BOTÃO DE FILTRO DE DATA ---
                  GestureDetector(
                    onTap: _showFilterMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            color: AppColors.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_startDate != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _clearDateFilter,
                              child: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 18,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- CARTÕES DE MÉTRICAS ---
                  Row(
                    children: [
                      _buildMetricCard(
                        'Faturamento',
                        _formatCurrency(_totalRevenue),
                        Icons.attach_money,
                        AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      _buildMetricCard(
                        'Serviços',
                        _totalAppointments.toString(),
                        Icons.calendar_today,
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetricCard(
                        'Clientes Salvos',
                        _totalClients.toString(),
                        Icons.people,
                        Colors.purple,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Container()),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- O BOTÃO VERMELHO DE CONTROLE ---
                  const Divider(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isActive
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        foregroundColor: _isActive ? Colors.red : Colors.green,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isActive
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                      ),
                      icon: Icon(
                        _isActive ? Icons.block : Icons.check_circle_outline,
                      ),
                      label: Text(
                        _isActive ? 'Suspender Usuário' : 'Reativar Usuário',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        // Janela de confirmação dupla para evitar acidentes
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              _isActive
                                  ? 'Suspender conta?'
                                  : 'Reativar conta?',
                            ),
                            content: Text(
                              _isActive
                                  ? 'Este usuário será deslogado imediatamente e não poderá acessar o aplicativo até que você o reative.'
                                  : 'Este usuário terá o acesso restaurado ao aplicativo.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isActive
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _toggleUserStatus(); // Executa a função
                                },
                                child: Text(
                                  _isActive
                                      ? 'Sim, Suspender'
                                      : 'Sim, Reativar',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
