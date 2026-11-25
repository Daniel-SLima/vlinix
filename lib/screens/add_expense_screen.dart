import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? expenseToEdit;

  const AddExpenseScreen({super.key, this.expenseToEdit});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _otherDescController = TextEditingController();
  late DateTime _selectedDate;
  bool _isLoading = false;

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final String originalDesc = widget.expenseToEdit!['description'];

      // Lista das categorias padrão
      final List<String> standardCategories = [
        'water',
        'energy',
        'gas',
        'products',
        'food',
        'rent',
        'others',
      ];

      // Se a descrição do banco não for uma das chaves padrão, significa que foi digitado algo customizado
      if (!standardCategories.contains(originalDesc)) {
        _selectedCategory = 'others';
        _otherDescController.text = originalDesc;
      } else {
        _selectedCategory = originalDesc;
      }

      _amountController.text = widget.expenseToEdit!['amount'].toString();
      _selectedDate = DateTime.parse(widget.expenseToEdit!['date']).toLocal();
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _otherDescController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    final lang = AppLocalizations.of(context)!;

    // Validação
    if (_selectedCategory == null || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.msgFillAllFields)));
      return;
    }
    if (_selectedCategory == 'others' &&
        _otherDescController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.msgFillAllFields)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = AppBackend.client.auth.currentUser!.id;
      final double amount = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );

      final safeDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        12,
      );

      final String dateStr = safeDate.toIso8601String();

      // Se for 'others', salvamos o texto digitado. Se não, salvamos a chave.
      final String finalDescription = _selectedCategory == 'others'
          ? _otherDescController.text.trim()
          : _selectedCategory!;

      final data = {
        'user_id': userId,
        'description': finalDescription,
        'amount': amount,
        'date': dateStr,
      };

      if (widget.expenseToEdit == null) {
        await AppBackend.client.from('expenses').insert(data);
      } else {
        await AppBackend.client
            .from('expenses')
            .update(data)
            .eq('id', widget.expenseToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgExpenseSaved),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorGeneric(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final isEditing = widget.expenseToEdit != null;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final currencySymbol = lang.localeName == 'pt' ? 'R\$' : '\$';

    final List<String> categories = [
      'water',
      'energy',
      'gas',
      'products',
      'food',
      'rent',
      'others',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.btnEdit : lang.titleNewExpense),
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Container(
              width: isLargeScreen ? 500 : double.infinity,
              padding: isLargeScreen
                  ? const EdgeInsets.all(32)
                  : EdgeInsets.zero,
              decoration: isLargeScreen
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: lang.labelDescription,
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: categories.map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(_translateCategory(key, lang)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  ),

                  // --- CAMPO EXTRA SE 'OTHERS' FOR SELECIONADO ---
                  if (_selectedCategory == 'others') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otherDescController,
                      decoration: InputDecoration(
                        labelText: lang
                            .labelWhichExpense, // --- TRADUÇÃO APLICADA AQUI ---
                        prefixIcon: const Icon(Icons.edit),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '${lang.labelPrice} ($currencySymbol)',
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        lang.labelDate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.error,
                                    onPrimary: Colors.white,
                                    onSurface: AppColors.primary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today, color: AppColors.error),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEditing
                                  ? lang.btnUpdate.toUpperCase()
                                  : lang.btnAddExpense,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
