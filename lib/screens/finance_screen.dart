import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/l10n/app_localizations.dart';

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
      // 1. QUERY ATUALIZADA PARA SUPORTAR MÚLTIPLOS SERVIÇOS
      // Buscamos 'appointment_services' para pegar preços e nomes.
      var query = Supabase.instance.client
          .from('appointments')
          .select(
            '''
            start_time, 
            payment_method, 
            clients(full_name), 
            appointment_services(price, services(name)), 
            services(name, price) 
            ''',
            // Mantemos 'services' antigo como fallback para dados legados
          )
          .eq('status', 'concluido')
          .gte('start_time', startOfMonth)
          .lte('start_time', endOfMonth);

      // 2. Aplica o filtro de pagamento
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

        // LÓGICA DE CÁLCULO (HÍBRIDA: NOVO + LEGADO)

        // A. Tenta pegar da nova estrutura (Lista)
        if (item['appointment_services'] != null &&
            (item['appointment_services'] as List).isNotEmpty) {
          final items = item['appointment_services'] as List;

          // Soma preços
          appointmentTotal = items.fold(
            0.0,
            (sum, i) => sum + (i['price'] ?? 0.0),
          );

          // Concatena nomes (ex: "Lavagem, Cera")
          serviceNames = items.map((i) => i['services']['name']).join(', ');
        }
        // B. Fallback para estrutura antiga (Único)
        else if (item['services'] != null) {
          final s = item['services'];
          appointmentTotal = (s['price'] is int)
              ? (s['price'] as int).toDouble()
              : (s['price'] as double? ?? 0.0);
          serviceNames = s['name'];
        } else {
          serviceNames = 'Serviço desconhecido';
        }

        totalMonthRevenue += appointmentTotal;

        // Cria um objeto limpo para a lista visual
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
        return const Icon(Icons.credit_card, size: 16, color: Colors.blue);
      case 'Plano Mensal':
        return const Icon(Icons.calendar_today, size: 16, color: Colors.purple);
      default:
        return const Icon(Icons.help_outline, size: 16, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.financeTitle),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. SELETOR DE MÊS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat(
                    'MMMM yyyy',
                    locale,
                  ).format(_selectedDate).toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // 2. FILTROS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          // 3. PLACAR TOTAL
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade400],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  lang.financeTotal,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 5),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _formatCurrency(_totalRevenue),
                        style: const TextStyle(
                          color: Colors.white,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _records[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDate(item['start_time']),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        title: Text(
                          item['service_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text(item['client_name']),
                            const SizedBox(width: 5),
                            const Text(
                              '•',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 5),
                            _getPaymentIcon(item['payment_method']),
                            const SizedBox(width: 4),
                            Text(
                              item['payment_method'] ?? '?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          _formatCurrency(item['total_price']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
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
      selectedColor: Colors.green.shade200,
      checkmarkColor: Colors.green.shade900,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade900 : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
