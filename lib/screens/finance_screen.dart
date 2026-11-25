import 'package:vlinix/data/app_backend.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';
import 'package:vlinix/screens/add_expense_screen.dart';
import 'package:universal_html/html.dart' as html;

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _isLoading = true;

  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _netBalance = 0.0;

  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _allAvailableServices = [];

  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedSpecificDay;
  String _selectedFilter = 'todos';

  @override
  void initState() {
    super.initState();
    _fetchServicesList();
    _loadFinanceData();
  }

  Future<void> _fetchServicesList() async {
    try {
      final res = await AppBackend.client
          .from('services')
          .select()
          .order('name');
      if (mounted) {
        setState(() {
          _allAvailableServices = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar serviços para o filtro: $e');
    }
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthsToAdd,
        1,
      );
      _selectedSpecificDay = null;
      _loadFinanceData();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedSpecificDay ?? _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _selectedSpecificDay = picked;
        _loadFinanceData();
      });
    }
  }

  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _loadFinanceData();
    });
  }

  void _showAdvancedFilterDialog() {
    final lang = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      lang.titleAdvancedFilters,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Divider(),

                  ListTile(
                    leading: const Icon(
                      Icons.all_inclusive,
                      color: AppColors.primary,
                    ),
                    title: Text(lang.filterAll),
                    selected: _selectedFilter == 'todos',
                    onTap: () {
                      Navigator.pop(context);
                      _changeFilter('todos');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.money_off,
                      color: AppColors.error,
                    ),
                    title: Text(lang.filterOnlyExpenses),
                    selected: _selectedFilter == 'despesas',
                    onTap: () {
                      Navigator.pop(context);
                      _changeFilter('despesas');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.volunteer_activism,
                      color: Colors.orange,
                    ),
                    title: Text(lang.filterOnlyTips),
                    selected: _selectedFilter == 'gorjetas',
                    onTap: () {
                      Navigator.pop(context);
                      _changeFilter('gorjetas');
                    },
                  ),

                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      lang.titleFilterByService,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                  ..._allAvailableServices.map((service) {
                    final String filterKey = 'servico_${service['id']}';
                    return ListTile(
                      leading: const Icon(
                        Icons.local_offer_outlined,
                        color: AppColors.accent,
                      ),
                      title: Text(service['name']),
                      selected: _selectedFilter == filterKey,
                      onTap: () {
                        Navigator.pop(context);
                        _changeFilter(filterKey);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateAppointmentStatus(
    int id,
    String newStatus, {
    String? paymentMethod,
  }) async {
    setState(() => _isLoading = true);
    final lang = AppLocalizations.of(context)!;
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      if (paymentMethod != null) {
        updateData['payment_method'] = paymentMethod;
      }

      if (newStatus == 'cancelado') {
        updateData['google_event_id'] = null;
      }

      await AppBackend.client
          .from('appointments')
          .update(updateData)
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'concluido'
                  ? lang.msgPaymentConfirmed
                  : lang.msgAppointmentCancelled,
            ),
            backgroundColor: newStatus == 'concluido'
                ? AppColors.success
                : Colors.grey,
          ),
        );
      }

      _loadFinanceData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorGeneric(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteExpense(int id) async {
    final lang = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.dialogDeleteExpenseTitle),
        content: Text(lang.dialogDeleteExpenseContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.btnCancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.btnDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await AppBackend.client.from('expenses').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgExpenseDeleted),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadFinanceData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorGeneric(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
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
              'dinheiro',
              Icons.money,
              Colors.green,
            ),
            _buildPaymentOption(
              ctx,
              appointmentId,
              lang.paymentCard,
              'cartao',
              Icons.credit_card,
              Colors.blue,
            ),
            _buildPaymentOption(
              ctx,
              appointmentId,
              lang.paymentPlan,
              'plano',
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
    String internalValue,
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
        _updateAppointmentStatus(id, 'concluido', paymentMethod: internalValue);
      },
    );
  }

  String _translateCategory(String categoryKey, AppLocalizations lang) {
    switch (categoryKey) {
      case 'water':
        return lang.expenseCatWater;
      case 'energy':
        return lang.expenseCatEnergy;
      case 'gas':
        return lang.expenseCatGas;
      case 'products':
        return lang.expenseCatProducts;
      case 'food':
        return lang.expenseCatFood;
      case 'rent':
        return lang.expenseCatRent;
      case 'others':
        return lang.expenseCatOthers;
      default:
        return categoryKey;
    }
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);

    String startTimeStr;
    String endTimeStr;

    if (_selectedSpecificDay != null) {
      startTimeStr = DateTime(
        _selectedSpecificDay!.year,
        _selectedSpecificDay!.month,
        _selectedSpecificDay!.day,
      ).toUtc().toIso8601String();
      endTimeStr = DateTime(
        _selectedSpecificDay!.year,
        _selectedSpecificDay!.month,
        _selectedSpecificDay!.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();
    } else {
      startTimeStr = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      ).toUtc().toIso8601String();
      endTimeStr = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      ).toUtc().toIso8601String();
    }

    final supabase = AppBackend.client;

    try {
      var queryRevenue = supabase
          .from('appointments')
          .select('''
            id,
            start_time, 
            status,
            payment_method, 
            tip_amount, 
            clients(full_name), 
            appointment_services(service_id, price, services(name)), 
            services(name, price) 
            ''')
          .gte('start_time', startTimeStr)
          .lte('start_time', endTimeStr);

      if (_selectedFilter == 'pendentes') {
        queryRevenue = queryRevenue.inFilter('status', const [
          'pendente',
          'em_andamento',
        ]);
      } else {
        queryRevenue = queryRevenue.eq('status', 'concluido');

        if (_selectedFilter == 'dinheiro') {
          queryRevenue = queryRevenue.inFilter('payment_method', [
            'dinheiro',
            'Dinheiro',
            'Cash',
            'Efectivo',
          ]);
        } else if (_selectedFilter == 'cartao') {
          queryRevenue = queryRevenue.inFilter('payment_method', [
            'cartao',
            'Cartão',
            'Card',
            'Tarjeta',
          ]);
        } else if (_selectedFilter == 'plano') {
          queryRevenue = queryRevenue.inFilter('payment_method', [
            'plano',
            'Plano Mensal',
            'Monthly Plan',
            'Plan Mensual',
          ]);
        }
      }

      final revenueData = await queryRevenue;

      List<dynamic> expensesData = [];
      if (_selectedFilter == 'todos' || _selectedFilter == 'despesas') {
        expensesData = await supabase
            .from('expenses')
            .select()
            .gte('date', startTimeStr)
            .lte('date', endTimeStr);
      }

      double revenueTotal = 0.0;
      double expenseTotal = 0.0;
      final List<Map<String, dynamic>> combinedList = [];

      bool isFilteringByService = _selectedFilter.startsWith('servico_');
      bool isFilteringByTips = _selectedFilter == 'gorjetas';
      bool isFilteringByExpenses = _selectedFilter == 'despesas';

      int? targetServiceId;
      if (isFilteringByService) {
        targetServiceId = int.parse(_selectedFilter.split('_')[1]);
      }

      for (var item in revenueData) {
        if (isFilteringByExpenses) break;

        double appointmentTotal = 0.0;
        String serviceNames = '';
        bool serviceMatchedFilter = false;

        if (item['appointment_services'] != null &&
            (item['appointment_services'] as List).isNotEmpty) {
          final items = item['appointment_services'] as List;

          if (isFilteringByService) {
            serviceMatchedFilter = items.any(
              (i) => i['service_id'] == targetServiceId,
            );
          }

          appointmentTotal = items.fold(
            0.0,
            (sum, i) => sum + (i['price'] ?? 0.0),
          );
          serviceNames = items.map((i) => i['services']['name']).join(', ');
        } else if (item['services'] != null) {
          appointmentTotal = (item['services']['price'] is int)
              ? (item['services']['price'] as int).toDouble()
              : (item['services']['price'] as double? ?? 0.0);
          serviceNames = item['services']['name'];
        }

        double tipAmount = 0.0;
        if (item['tip_amount'] != null) {
          tipAmount = (item['tip_amount'] is int)
              ? (item['tip_amount'] as int).toDouble()
              : (item['tip_amount'] as double);
        }

        if (isFilteringByTips && tipAmount <= 0) continue;
        if (isFilteringByService && !serviceMatchedFilter) continue;

        double displayValue = 0.0;
        if (isFilteringByTips) {
          displayValue = tipAmount;
          // Não tem como puxar do lang a menos que passemos o context aqui,
          // então vamos assumir que 'Tip' atende bem todos os idiomas visualmente,
          // ou usamos a tradução direta:
          // AQUI: Usaremos "Tip / Gorjeta" fixo pra facilitar a view
          serviceNames = 'Tip / Gorjeta';
        } else {
          displayValue = appointmentTotal + tipAmount;
        }

        revenueTotal += displayValue;

        final isPending =
            item['status'] == 'pendente' || item['status'] == 'em_andamento';

        combinedList.add({
          'id': item['id'],
          'type': isPending ? 'pending' : 'income',
          'date': item['start_time'],
          'title': serviceNames,
          'subtitle': item['clients'] != null
              ? item['clients']['full_name']
              : null,
          'value': displayValue,
          'tipAmount': isFilteringByTips ? 0.0 : tipAmount,
          'isPending': isPending,
          'rawMethod': item['payment_method'],
        });
      }

      for (var item in expensesData) {
        final double val = (item['amount'] is int)
            ? (item['amount'] as int).toDouble()
            : (item['amount'] as double);
        expenseTotal += val;

        combinedList.add({
          'id': item['id'],
          'type': 'expense',
          'date': item['date'],
          'titleRaw': item['description'],
          'value': val,
        });
      }

      combinedList.sort(
        (a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
      );

      if (mounted) {
        setState(() {
          _totalRevenue = revenueTotal;
          _totalExpenses = expenseTotal;

          if (_selectedFilter == 'todos') {
            _netBalance = revenueTotal - expenseTotal;
          } else if (_selectedFilter == 'despesas') {
            _netBalance = -expenseTotal;
          } else {
            _netBalance = revenueTotal;
          }

          _records = combinedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro Financeiro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    final lang = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final currencySymbol = locale == 'pt' ? 'R\$' : '\$';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.msgGeneratingExcel),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      var excel = Excel.createExcel();

      void populateSheet(String sheetName, String filterType) {
        Sheet sheet = excel[sheetName];

        CellStyle headerStyle = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.blue,
          horizontalAlign: HorizontalAlign.Center,
        );

        var headers = [
          lang.excelColDate,
          lang.excelColType,
          lang.excelColDesc,
          lang.excelColClient,
          lang.excelColMethod,
          '${lang.excelColTip} ($currencySymbol)',
          '${lang.excelColValue} ($currencySymbol)',
        ];

        for (var i = 0; i < headers.length; i++) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.value = TextCellValue(headers[i]);
          cell.cellStyle = headerStyle;
        }

        List<Map<String, dynamic>> filteredList = [];

        if (filterType == 'Todos') {
          filteredList = _records;
        } else if (filterType == 'A Receber') {
          filteredList = _records
              .where((item) => item['type'] == 'pending')
              .toList();
        } else if (filterType == 'Dinheiro') {
          filteredList = _records
              .where(
                (item) =>
                    item['type'] == 'income' &&
                    [
                      'dinheiro',
                      'Dinheiro',
                      'Cash',
                      'Efectivo',
                    ].contains(item['rawMethod']),
              )
              .toList();
        } else if (filterType == 'Cartão') {
          filteredList = _records
              .where(
                (item) =>
                    item['type'] == 'income' &&
                    [
                      'cartao',
                      'Cartão',
                      'Card',
                      'Tarjeta',
                    ].contains(item['rawMethod']),
              )
              .toList();
        } else if (filterType == 'Despesas') {
          filteredList = _records
              .where((item) => item['type'] == 'expense')
              .toList();
        }

        double totalSheetValue = 0.0;
        double totalTips = 0.0;

        for (int row = 0; row < filteredList.length; row++) {
          var item = filteredList[row];
          final isExpense = item['type'] == 'expense';
          final isPending = item['type'] == 'pending';

          String data = DateFormat(
            'dd/MM/yyyy',
            locale,
          ).format(DateTime.parse(item['date']).toLocal());
          String tipo = isExpense
              ? lang.excelTypeExpense
              : (isPending ? lang.excelTypePending : lang.excelTypeIncome);

          String titulo = isExpense
              ? _translateCategory(
                  (item['titleRaw'] ?? lang.labelExpenseTitle),
                  lang,
                )
              : item['title'];

          String subtitulo = isExpense
              ? lang.labelExpenseSubtitle
              : (item['subtitle'] ?? lang.labelUnknownClient);

          String metodo = '';
          if (isExpense) {
            metodo = '-';
          } else if (isPending) {
            metodo = lang.excelStatusWaiting;
          } else {
            final rawMethod = item['rawMethod'];
            if (rawMethod == null) {
              metodo = lang.labelWithoutRegistration;
            } else if ([
              'dinheiro',
              'Dinheiro',
              'Cash',
              'Efectivo',
            ].contains(rawMethod)) {
              metodo = lang.paymentCash;
            } else if ([
              'cartao',
              'Cartão',
              'Card',
              'Tarjeta',
            ].contains(rawMethod)) {
              metodo = lang.paymentCard;
            } else if ([
              'plano',
              'Plano Mensal',
              'Monthly Plan',
              'Plan Mensual',
            ].contains(rawMethod)) {
              metodo = lang.paymentPlan;
            } else {
              metodo = rawMethod;
            }
          }

          double valor = item['value'];
          double tipAmount = item['tipAmount'] ?? 0.0;
          double displayValue = isExpense ? -valor : valor;

          totalSheetValue += displayValue;
          totalTips += tipAmount;

          sheet.appendRow([
            TextCellValue(data),
            TextCellValue(tipo),
            TextCellValue(titulo),
            TextCellValue(subtitulo),
            TextCellValue(metodo),
            isExpense ? TextCellValue('-') : DoubleCellValue(tipAmount),
            DoubleCellValue(displayValue),
          ]);
        }

        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
        ]);

        CellStyle totalStyle = CellStyle(
          bold: true,
          fontColorHex: totalSheetValue >= 0
              ? ExcelColor.green
              : ExcelColor.red,
        );

        int totalRowIndex = filteredList.length + 2;

        var totalLabelCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRowIndex),
        );
        totalLabelCell.value = TextCellValue(lang.excelTotal);
        totalLabelCell.cellStyle = CellStyle(bold: true);

        if (filterType != 'Despesas') {
          var totalTipCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRowIndex),
          );
          totalTipCell.value = DoubleCellValue(totalTips);
          totalTipCell.cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.green,
          );
        }

        var totalValueCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRowIndex),
        );
        totalValueCell.value = DoubleCellValue(totalSheetValue);
        totalValueCell.cellStyle = totalStyle;
      }

      populateSheet(lang.excelSheetAll, 'Todos');
      populateSheet(lang.excelSheetReceivable, 'A Receber');
      populateSheet(lang.excelSheetCash, 'Dinheiro');
      populateSheet(lang.excelSheetCard, 'Cartão');
      populateSheet(lang.excelSheetExpenses, 'Despesas');

      if (excel.tables.keys.contains('Sheet1')) {
        excel.delete('Sheet1');
      }
      excel.setDefaultSheet(lang.excelSheetAll);

      String cleanTitle = lang.financeTitle.replaceAll(' ', '_');

      String dateStr = _selectedSpecificDay != null
          ? DateFormat('dd_MM_yyyy').format(_selectedSpecificDay!)
          : DateFormat('MM_yyyy').format(_selectedMonth);

      String filename = 'VLINIX_${cleanTitle}_$dateStr.xlsx';

      if (!kIsWeb) {
        Directory directory = await getApplicationDocumentsDirectory();
        String filePath = '${directory.path}/$filename';

        File file = File(filePath);
        final bytes = excel.encode();
        if (bytes != null) {
          await file.writeAsBytes(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(lang.msgExcelSaved(filename)),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        final bytes = excel.encode();
        if (bytes != null) {
          final blob = html.Blob(
            [bytes],
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          final url = html.Url.createObjectUrlFromBlob(blob);

          html.AnchorElement(href: url)
            ..setAttribute('download', filename)
            ..click();

          html.Url.revokeObjectUrl(url);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(lang.msgExcelDownloadStarted(filename)),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgExportError(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
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

  Color _getTypeColor(String type) {
    if (type == 'expense') return AppColors.error;
    if (type == 'pending') return Colors.orange;
    return AppColors.success;
  }

  String _getTopBannerText(AppLocalizations lang) {
    if (_selectedFilter == 'todos') return lang.labelNetBalance;
    if (_selectedFilter == 'pendentes') return lang.labelTotalReceivable;
    if (_selectedFilter == 'despesas') return lang.labelTotalExpenses;
    if (_selectedFilter == 'gorjetas') return lang.labelTotalTips;
    if (_selectedFilter == 'dinheiro')
      return lang.labelTotal(lang.paymentCash.toUpperCase());
    if (_selectedFilter == 'cartao')
      return lang.labelTotal(lang.paymentCard.toUpperCase());
    if (_selectedFilter == 'plano')
      return lang.labelTotal(lang.paymentPlan.toUpperCase());

    if (_selectedFilter.startsWith('servico_')) {
      final id = int.parse(_selectedFilter.split('_')[1]);
      final service = _allAvailableServices.firstWhere(
        (s) => s['id'] == id,
        orElse: () => {'name': 'Service'},
      );
      return lang.labelAppointmentsWith(service['name'].toUpperCase());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    String displayDateText;
    if (_selectedSpecificDay != null) {
      displayDateText = DateFormat(
        'dd/MM/yyyy',
        locale,
      ).format(_selectedSpecificDay!);
    } else {
      displayDateText = DateFormat(
        'MMMM yyyy',
        locale,
      ).format(_selectedMonth).toUpperCase();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),
        title: Text(lang.financeTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: lang.tooltipExportExcel,
            onPressed: _records.isEmpty ? null : _exportToExcel,
          ),
          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton:
          _selectedFilter == 'todos' || _selectedFilter == 'despesas'
          ? FloatingActionButton(
              heroTag: 'fab_expenses',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddExpenseScreen(),
                  ),
                );
                if (result == true) _loadFinanceData();
              },
              backgroundColor: AppColors.error,
              child: const Icon(Icons.remove, color: Colors.white),
            )
          : null,

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: AppColors.accent),
                  tooltip: lang.titleAdvancedFilters,
                  onPressed: _showAdvancedFilterDialog,
                ),

                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedSpecificDay != null
                            ? AppColors.accent
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayDateText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_selectedSpecificDay != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                      tooltip: lang.tooltipResetDate,
                      onPressed: () {
                        setState(() {
                          _selectedSpecificDay = null;
                          _loadFinanceData();
                        });
                      },
                    ),
                  )
                else
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

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('todos', lang.filterAll),
                const SizedBox(width: 8),
                _buildFilterChip('pendentes', lang.filterPending),
                const SizedBox(width: 8),
                _buildFilterChip('dinheiro', lang.paymentCash),
                const SizedBox(width: 8),
                _buildFilterChip('cartao', lang.paymentCard),
              ],
            ),
          ),

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
                Text(
                  _getTopBannerText(lang),
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
                        _formatCurrency(_netBalance),
                        style: TextStyle(
                          color: _selectedFilter == 'pendentes'
                              ? Colors.orange
                              : (_netBalance >= 0 ||
                                        _selectedFilter == 'despesas'
                                    ? AppColors.accent
                                    : AppColors.error),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                const SizedBox(height: 16),

                if (!_isLoading && _selectedFilter == 'todos')
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
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 85,
                    ),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _records[index];
                      final isExpense = item['type'] == 'expense';
                      final isPending = item['type'] == 'pending';
                      final valColor = _getTypeColor(item['type']);
                      final int? itemId = item['id'];
                      final double tipAmount = item['tipAmount'] ?? 0.0;

                      String displayTitle = '';
                      String displaySubtitle = '';
                      String displayMethod = '';

                      if (isExpense) {
                        displayTitle = _translateCategory(
                          (item['titleRaw'] ?? lang.labelExpenseTitle),
                          lang,
                        );
                        displaySubtitle = lang.labelExpenseSubtitle;
                        displayMethod = 'N/A';
                      } else {
                        displayTitle = item['title'];
                        displaySubtitle =
                            item['subtitle'] ?? lang.labelUnknownClient;

                        if (isPending) {
                          displayMethod = lang.statusAwaitingPayment;
                        } else {
                          final rawMethod = item['rawMethod'];
                          if (rawMethod == null) {
                            displayMethod = lang.labelWithoutRegistration;
                          } else if ([
                            'dinheiro',
                            'Dinheiro',
                            'Cash',
                            'Efectivo',
                          ].contains(rawMethod)) {
                            displayMethod = lang.paymentCash;
                          } else if ([
                            'cartao',
                            'Cartão',
                            'Card',
                            'Tarjeta',
                          ].contains(rawMethod)) {
                            displayMethod = lang.paymentCard;
                          } else if ([
                            'plano',
                            'Plano Mensal',
                            'Monthly Plan',
                            'Plan Mensual',
                          ].contains(rawMethod)) {
                            displayMethod = lang.paymentPlan;
                          } else {
                            displayMethod = rawMethod;
                          }
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
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
                                      color: valColor,
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPending
                                        ? '⏳ $displaySubtitle'
                                        : displaySubtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isPending
                                          ? Colors.orange.shade700
                                          : Colors.grey[600],
                                      fontWeight: isPending
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${isExpense ? '-' : (isPending ? '' : '+')}${_formatCurrency(item['value'])}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: valColor,
                                  ),
                                ),
                                if (displayMethod != 'N/A')
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (tipAmount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6.0,
                                          ),
                                          child: Text(
                                            '+ ${_formatCurrency(tipAmount)} 💰',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        displayMethod,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            if (isPending && itemId != null)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                onSelected: (value) {
                                  if (value == 'pay') {
                                    _showPaymentDialog(itemId);
                                  } else if (value == 'cancel') {
                                    _updateAppointmentStatus(
                                      itemId,
                                      'cancelado',
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'pay',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(lang.btnConfirmPayment),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.cancel,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(lang.btnCancelAppointment),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else if (isExpense && itemId != null)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteExpense(itemId);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.delete,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(lang.btnDelete),
                                      ],
                                    ),
                                  ),
                                ],
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
