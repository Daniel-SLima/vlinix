import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/screens/login_screen.dart';
import 'admin_user_details_screen.dart';

import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  double _totalPlatformRevenue = 0.0;
  List<Map<String, dynamic>> _usersList = [];

  DateTime? _startDate;
  DateTime? _endDate;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  final _announcementController = TextEditingController();
  bool _isAnnouncementActive = false;
  bool _isSavingAnnouncement = false;

  @override
  void initState() {
    super.initState();
    _loadPlatformData();
    _loadAnnouncement();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncement() async {
    try {
      final data = await AppBackend.client
          .from('global_announcements')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _announcementController.text = data['message'] ?? '';
          _isAnnouncementActive = data['is_active'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar aviso: $e');
    }
  }

  Future<void> _updateAnnouncement(bool isActive) async {
    setState(() => _isSavingAnnouncement = true);
    try {
      await AppBackend.client
          .from('global_announcements')
          .update({
            'message': _announcementController.text.trim(),
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1)
          .select();

      if (mounted) {
        setState(() {
          _isAnnouncementActive = isActive;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? 'Aviso ATIVADO para todos os clientes!'
                  : 'Aviso desativado.',
            ),
            backgroundColor: isActive ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar aviso: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar aviso.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingAnnouncement = false);
    }
  }

  // --- NOVA FUNÇÃO AUXILIAR PARA PEGAR O NOME DO PERÍODO ---
  String _getDateLabel() {
    if (_startDate != null && _endDate != null) {
      final startStr = DateFormat('dd/MM/yyyy').format(_startDate!);
      final endStr = DateFormat('dd/MM/yyyy').format(_endDate!);
      return startStr == endStr ? startStr : '$startStr até $endStr';
    }
    return 'Histórico Total (Todo o período)';
  }

  Future<void> _exportAdminReport() async {
    setState(() => _isLoading = true);

    try {
      var excel = Excel.createExcel();

      Sheet sheet1 = excel['Resumo Geral'];
      excel.setDefaultSheet('Resumo Geral');

      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      sheet1.appendRow([
        TextCellValue('RELATÓRIO ADMINISTRATIVO - VLINIX'),
        TextCellValue(''),
      ]);
      sheet1.appendRow([
        TextCellValue('Data de Geração:'),
        TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
      ]);
      // --- ADICIONADO: INFORMAÇÃO DO PERÍODO NO EXCEL ---
      sheet1.appendRow([
        TextCellValue('Período Selecionado:'),
        TextCellValue(_getDateLabel()),
      ]);
      sheet1.appendRow([TextCellValue('')]);

      sheet1.appendRow([TextCellValue('Métrica'), TextCellValue('Valor')]);
      sheet1.appendRow([
        TextCellValue('Faturamento no Período'),
        TextCellValue(_formatCurrency(_totalPlatformRevenue)),
      ]);
      sheet1.appendRow([
        TextCellValue('Total de Usuários Cadastrados'),
        IntCellValue(_totalUsers),
      ]);

      sheet1
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
      );

      Sheet sheet2 = excel['Lista de Usuários'];
      sheet2.appendRow([
        TextCellValue('Nome Completo'),
        TextCellValue('E-mail'),
        TextCellValue('Data de Cadastro'),
        TextCellValue('Carteira Total (Qtd. Clientes)'), // Mantido total
        TextCellValue('Serviços no Período'), // NOVO: Agendamentos feitos
        TextCellValue('Faturamento no Período'),
        TextCellValue('Status'),
      ]);

      for (var user in _usersList) {
        final createdAt = user['created_at'] != null
            ? DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.parse(user['created_at']))
            : 'N/A';

        sheet2.appendRow([
          TextCellValue(user['full_name'] ?? 'N/A'),
          TextCellValue(user['email'] ?? 'N/A'),
          TextCellValue(createdAt),
          IntCellValue(user['total_clients'] ?? 0), // Carteira total
          IntCellValue(
            user['appointments_in_period'] ?? 0,
          ), // NOVO: Serviços do período
          TextCellValue(_formatCurrency(user['total_revenue'] ?? 0.0)),
          TextCellValue((user['is_active'] ?? true) ? 'ATIVO' : 'SUSPENSO'),
        ]);
      }

      final fileBytes = excel.encode();

      if (fileBytes != null) {
        final xFile = XFile.fromData(
          Uint8List.fromList(fileBytes),
          name: 'Relatorio_Vlinix.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );

        await Share.shareXFiles([
          xFile,
        ], text: 'Relatório Administrativo V-Linix');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relatório gerado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao exportar Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar planilha. Verifique os logs.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    _loadPlatformData();
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
                    'Filtrar Faturamento',
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
        _loadPlatformData();
      });
    }
  }

  void _clearDateFilter() {
    _applyQuickFilter('all');
  }

  Future<void> _loadPlatformData() async {
    setState(() => _isLoading = true);
    final supabase = AppBackend.client;

    try {
      final profilesData = await supabase
          .from('profiles')
          .select()
          .order('full_name');

      // Esta busca NÃO TEM FILTRO, pega a carteira total de clientes
      final clientsData = await supabase.from('clients').select('user_id');

      var query = supabase
          .from('appointments')
          .select(
            'user_id, tip_amount, appointment_services(price), services(price)',
          )
          .eq('status', 'concluido');

      if (_startDate != null && _endDate != null) {
        query = query
            .gte('start_time', _startDate!.toUtc().toIso8601String())
            .lte('start_time', _endDate!.toUtc().toIso8601String());
      }

      // Esta busca TEM FILTRO, pega só o dinheiro e agendamentos do período
      final appointmentsData = await query;

      Map<String, double> revenuePerUser = {};
      Map<String, int> appointmentsPerUser = {}; // NOVO: Conta agendamentos

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

        double finalVal = aptTotal + tip;
        String uid = apt['user_id'].toString();

        revenuePerUser[uid] = (revenuePerUser[uid] ?? 0.0) + finalVal;
        appointmentsPerUser[uid] = (appointmentsPerUser[uid] ?? 0) + 1; // NOVO
      }

      // Conta o tamanho da carteira total (sem filtro)
      Map<String, int> clientsPerUser = {};
      for (var c in clientsData) {
        String uid = c['user_id'].toString();
        clientsPerUser[uid] = (clientsPerUser[uid] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          final adminEmails = [
            'theniels.lima@gmail.com',
            'daniel.admin@admin.com',
          ];

          _usersList = profilesData
              .where((user) => !adminEmails.contains(user['email']))
              .map((user) {
                String uid = user['id'].toString();
                return {
                  ...user,
                  'total_revenue': revenuePerUser[uid] ?? 0.0,
                  'appointments_in_period':
                      appointmentsPerUser[uid] ?? 0, // NOVO
                  'total_clients': clientsPerUser[uid] ?? 0, // MANTIDO
                };
              })
              .toList();

          double realPlatformRevenue = 0.0;
          for (var user in _usersList) {
            realPlatformRevenue += (user['total_revenue'] as double);
          }

          _totalUsers = _usersList.length;
          _totalPlatformRevenue = realPlatformRevenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro Admin Dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AppBackend.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  }

  @override
  Widget build(BuildContext context) {
    String dateLabel = _getDateLabel();

    final filteredUsers = _usersList.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Painel VIP - Vlinix'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view, color: AppColors.accent),
            onPressed: _exportAdminReport,
            tooltip: 'Exportar Relatório Excel',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadPlatformData();
                await _loadAnnouncement();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A1A1A), AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'FATURAMENTO DA PLATAFORMA',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCurrency(_totalPlatformRevenue),
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _showFilterMenu,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white24),
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
                                      color: Colors.white,
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
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.business_center,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_totalUsers Usuários Cadastrados',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Row(
                      children: [
                        Icon(Icons.campaign, color: Colors.orange, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Aviso Global',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _announcementController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Digite o aviso para todos os clientes...',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Switch(
                                    value: _isAnnouncementActive,
                                    activeColor: Colors.orange,
                                    onChanged: _isSavingAnnouncement
                                        ? null
                                        : (val) {
                                            _updateAnnouncement(val);
                                          },
                                  ),
                                  Text(
                                    _isAnnouncementActive
                                        ? 'Aviso LIGADO'
                                        : 'Aviso DESLIGADO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isAnnouncementActive
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                icon: _isSavingAnnouncement
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save, size: 18),
                                label: const Text(
                                  'Salvar Texto',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: _isSavingAnnouncement
                                    ? null
                                    : () => _updateAnnouncement(
                                        _isAnnouncementActive,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Usuários Cadastrados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filteredUsers.length}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome ou e-mail...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    FocusScope.of(context).unfocus();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (filteredUsers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nenhum usuário encontrado.',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final name = user['full_name'] ?? 'Usuário sem nome';
                          final isActive = user['is_active'] ?? true;

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                child: Icon(
                                  isActive ? Icons.person : Icons.block,
                                  color: isActive
                                      ? AppColors.accent
                                      : Colors.red,
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                  color: isActive ? Colors.black : Colors.red,
                                ),
                              ),
                              // --- ADICIONADO: MOSTRA A CARTEIRA E OS SERVIÇOS FEITOS NO SUBTÍTULO ---
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['email'] ?? 'Sem e-mail cadastrado',
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${user['total_clients']} clientes na base',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${user['appointments_in_period']} lavagens no período',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatCurrency(
                                      user['total_revenue'] ?? 0.0,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminUserDetailsScreen(user: user),
                                  ),
                                ).then((_) => _loadPlatformData());
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
