import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Adicionado para debugPrint
// IMPORT NECESSÁRIO PARA TRADUÇÃO:
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
  String _selectedFilter =
      'Todos'; // Opções internas: Todos, Dinheiro, Cartão, Plano Mensal

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

  // --- AQUI ESTÁ A CORREÇÃO DO ERRO DE ORDEM (.eq) ---
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
      // 1. Monta a query BASE (Sem ordenar ainda)
      var query = Supabase.instance.client
          .from('appointments')
          .select(
            'start_time, payment_method, services(name, price), clients(full_name), vehicles(model, plate)',
          )
          .eq('status', 'concluido')
          .gte('start_time', startOfMonth)
          .lte('start_time', endOfMonth);

      // 2. Aplica o filtro de pagamento (se não for "Todos")
      if (_selectedFilter != 'Todos') {
        query = query.eq('payment_method', _selectedFilter);
      }

      // 3. AGORA sim ordenamos e buscamos os dados
      final data = await query.order('start_time', ascending: false);

      double total = 0;
      final List<Map<String, dynamic>> tempList = [];

      for (var item in data) {
        final service = item['services'];
        final price = (service['price'] is int)
            ? (service['price'] as int).toDouble()
            : (service['price'] as double? ?? 0.0);

        total += price;
        tempList.add(item);
      }

      if (mounted) {
        setState(() {
          _totalRevenue = total;
          _records = tempList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro Financeiro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double value) {
    // Usa o locale do contexto para formatar (R$ ou $)
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
        title: Text(lang.financeTitle), // "Controle Financeiro" traduzido
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
                    locale, // Locale dinâmico
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

          // 2. FILTROS DE PAGAMENTO
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Passamos o VALOR INTERNO (para lógica) e o LABEL TRADUZIDO (para exibir)
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
                  color: Colors.grey.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  lang.financeTotal, // "Faturamento Total"
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

          // 4. LISTA
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
                          lang.financeEmpty, // "Nenhum registro..."
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
                      final serviceName = item['services']['name'];
                      final clientName = item['clients']['full_name'];
                      final paymentMethod =
                          item['payment_method'] ?? 'Não inf.';
                      final price = (item['services']['price'] is int)
                          ? (item['services']['price'] as int).toDouble()
                          : (item['services']['price'] as double? ?? 0.0);

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
                          serviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text(clientName),
                            const SizedBox(width: 5),
                            const Text(
                              '•',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 5),
                            _getPaymentIcon(paymentMethod),
                            const SizedBox(width: 4),
                            Text(
                              paymentMethod,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          _formatCurrency(price),
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
