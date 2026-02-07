import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';
import 'package:vlinix/screens/add_expense_screen.dart'; // <--- Importe a tela nova

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _isLoading = true;

  // Totais
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _netBalance = 0.0;

  // Lista unificada (Receitas + Despesas)
  List<Map<String, dynamic>> _records = [];

  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + monthsToAdd,
        1,
      );
      _loadFinanceData();
    });
  }

  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _loadFinanceData();
    });
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);

    final startOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    ).toUtc().toIso8601String();

    final endOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
      23,
      59,
      59,
    ).toUtc().toIso8601String();

    final supabase = Supabase.instance.client;

    try {
      // ---------------------------------------------
      // 1. BUSCAR RECEITAS (Appointments)
      // ---------------------------------------------
      var queryRevenue = supabase
          .from('appointments')
          .select('''
            start_time, 
            payment_method, 
            clients(full_name), 
            appointment_services(price, services(name)), 
            services(name, price) 
            ''')
          .eq('status', 'concluido')
          .gte('start_time', startOfMonth)
          .lte('start_time', endOfMonth);

      if (_selectedFilter != 'Todos') {
        queryRevenue = queryRevenue.eq('payment_method', _selectedFilter);
      }

      final revenueData = await queryRevenue;

      // ---------------------------------------------
      // 2. BUSCAR DESPESAS (Expenses)
      // ---------------------------------------------
      // O RLS no Supabase garante que só vem dados do usuário logado
      final expensesData = await supabase
          .from('expenses')
          .select()
          .gte('date', startOfMonth)
          .lte('date', endOfMonth);

      // ---------------------------------------------
      // 3. PROCESSAMENTO E UNIÃO
      // ---------------------------------------------
      double revenueTotal = 0.0;
      double expenseTotal = 0.0;
      final List<Map<String, dynamic>> combinedList = [];

      // A. Processar Receitas
      for (var item in revenueData) {
        double appointmentTotal = 0.0;
        String serviceNames = '';

        if (item['appointment_services'] != null &&
            (item['appointment_services'] as List).isNotEmpty) {
          final items = item['appointment_services'] as List;
          appointmentTotal = items.fold(
            0.0,
            (sum, i) => sum + (i['price'] ?? 0.0),
          );
          serviceNames = items.map((i) => i['services']['name']).join(', ');
        } else if (item['services'] != null) {
          final s = item['services'];
          appointmentTotal = (s['price'] is int)
              ? (s['price'] as int).toDouble()
              : (s['price'] as double? ?? 0.0);
          serviceNames = s['name'];
        } else {
          serviceNames = 'Serviço desconhecido';
        }

        revenueTotal += appointmentTotal;

        combinedList.add({
          'type': 'income',
          'date': item['start_time'],
          'title': serviceNames,
          'subtitle': item['clients'] != null
              ? item['clients']['full_name']
              : 'Cliente?',
          'value': appointmentTotal,
          'method': item['payment_method'],
        });
      }

      // B. Processar Despesas
      for (var item in expensesData) {
        final double val = (item['amount'] is int)
            ? (item['amount'] as int).toDouble()
            : (item['amount'] as double);
        expenseTotal += val;

        // Se o filtro for 'Todos', mostra despesas. Se for filtro de Pagamento (ex: Cartão),
        // geralmente despesas não entram, a não ser que você adicione coluna de pagamento nas despesas.
        // Aqui vou mostrar despesas apenas se filtro for 'Todos'.
        if (_selectedFilter == 'Todos') {
          combinedList.add({
            'type': 'expense',
            'date': item['date'],
            'title': item['description'] ?? 'Despesa',
            'subtitle': 'Despesa Operacional',
            'value': val,
            'method': 'N/A',
          });
        }
      }

      // Ordenar por data (mais recente primeiro)
      combinedList.sort(
        (a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
      );

      if (mounted) {
        setState(() {
          _totalRevenue = revenueTotal;
          _totalExpenses = expenseTotal;
          _netBalance = revenueTotal - expenseTotal;
          _records = combinedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro Financeiro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    final locale = Localizations.localeOf(context).languageCode;
    final symbol = locale == 'pt' ? 'R\$' : '\$';
    return NumberFormat.currency(locale: locale, symbol: symbol).format(value);
  }

  String _formatDate(String isoString) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat(
      'dd/MM',
      locale,
    ).format(DateTime.parse(isoString).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),
        title: Text(lang.financeTitle),
        centerTitle: true,
      ),

      // BOTÃO DE ADICIONAR DESPESA
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_add_expense',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) {
            _loadFinanceData(); // Atualiza a lista ao voltar
          }
        },
        backgroundColor: AppColors.error, // Vermelho
        child: const Icon(Icons.remove, color: Colors.white),
      ),

      body: Column(
        children: [
          // 1. SELETOR DE MÊS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat(
                      'MMMM yyyy',
                      locale,
                    ).format(_selectedDate).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // 2. FILTROS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Todos', lang.filterAll),
                const SizedBox(width: 8),
                _buildFilterChip('Dinheiro', lang.paymentCash),
                const SizedBox(width: 8),
                _buildFilterChip('Cartão', lang.paymentCard),
                const SizedBox(width: 8),
                _buildFilterChip('Plano Mensal', lang.paymentPlan),
              ],
            ),
          ),

          // 3. CARD DE RESUMO FINANCEIRO
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C2C2C), AppColors.primary],
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
                  "SALDO LÍQUIDO",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoading
                    ? const CircularProgressIndicator(color: AppColors.accent)
                    : Text(
                        _formatCurrency(_netBalance),
                        style: TextStyle(
                          color: _netBalance >= 0
                              ? AppColors.accent
                              : AppColors.error,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 16),
                // Mini resumo Entrada vs Saída
                if (!_isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            color: Colors.green,
                            size: 16,
                          ),
                          Text(
                            _formatCurrency(_totalRevenue),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 20, color: Colors.white24),
                      Column(
                        children: [
                          const Icon(
                            Icons.arrow_downward,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          Text(
                            _formatCurrency(_totalExpenses),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 4. LISTA DE TRANSAÇÕES
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        Text(
                          lang.financeEmpty,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _records[index];
                      final isExpense = item['type'] == 'expense';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            // Box da Data
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatDate(item['date']).split('/')[0],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isExpense
                                          ? AppColors.error
                                          : AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(item['date']).split('/')[1],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Detalhes
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['subtitle'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Valor
                            Text(
                              "${isExpense ? '-' : ''}${_formatCurrency(item['value'])}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isExpense
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String internalValue, String displayLabel) {
    final isSelected = _selectedFilter == internalValue;
    return FilterChip(
      label: Text(displayLabel),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) _changeFilter(internalValue);
      },
      selectedColor: AppColors.accent,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
    );
  }
}
