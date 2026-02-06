import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart'; // <--- IMPORTANTE

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _isLoading = true;
  double _totalRevenue = 0.0;
  List<Map<String, dynamic>> _records = [];

  // Controle do Filtro e Data
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

    try {
      // 1. QUERY ATUALIZADA
      var query = Supabase.instance.client
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

      // 2. Aplica o filtro
      if (_selectedFilter != 'Todos') {
        query = query.eq('payment_method', _selectedFilter);
      }

      // 3. Ordena e busca
      final data = await query.order('start_time', ascending: false);

      double totalMonthRevenue = 0;
      final List<Map<String, dynamic>> processedList = [];

      for (var item in data) {
        double appointmentTotal = 0.0;
        String serviceNames = '';

        // LÓGICA DE CÁLCULO
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

        totalMonthRevenue += appointmentTotal;

        processedList.add({
          'start_time': item['start_time'],
          'client_name': item['clients'] != null
              ? item['clients']['full_name']
              : 'Cliente?',
          'service_name': serviceNames,
          'total_price': appointmentTotal,
          'payment_method': item['payment_method'],
        });
      }

      if (mounted) {
        setState(() {
          _totalRevenue = totalMonthRevenue;
          _records = processedList;
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

  Widget _getPaymentIcon(String? method) {
    switch (method) {
      case 'Dinheiro':
        return const Icon(Icons.money, size: 16, color: Colors.green);
      case 'Cartão':
        return const Icon(
          Icons.credit_card,
          size: 16,
          color: AppColors.primary,
        );
      case 'Plano Mensal':
        return const Icon(
          Icons.calendar_today,
          size: 16,
          color: AppColors.accent,
        );
      default:
        return const Icon(Icons.help_outline, size: 16, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lang.financeTitle),
        centerTitle: true,
        // Theme cuida das cores (Chumbo)
      ),
      body: Column(
        children: [
          // 1. SELETOR DE MÊS (Estilo limpo)
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

          // 3. PLACAR TOTAL ("Black Card" Premium)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              // Gradiente Chumbo Escuro -> Chumbo Claro
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
                Text(
                  lang.financeTotal.toUpperCase(),
                  style: const TextStyle(
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
                        _formatCurrency(_totalRevenue),
                        style: const TextStyle(
                          color: AppColors.accent, // Dourado!
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
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

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            // Data Box
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
                                    _formatDate(
                                      item['start_time'],
                                    ).split('/')[0], // Dia
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(
                                      item['start_time'],
                                    ).split('/')[1], // Mês
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
                                    item['service_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        item['client_name'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _getPaymentIcon(item['payment_method']),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Valor
                            Text(
                              _formatCurrency(item['total_price']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors
                                    .success, // Verde para dinheiro entrando
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
      // Dourado quando selecionado, Cinza claro quando não
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
