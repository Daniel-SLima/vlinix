import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';

class AddServiceScreen extends StatefulWidget {
  final Map<String, dynamic>? serviceToEdit;

  const AddServiceScreen({super.key, this.serviceToEdit});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;

  // --- TEMPLATES RÁPIDOS ---
  final List<Map<String, dynamic>> _quickTemplates = [
    {'name': 'Lavagem Simples', 'price': '30.00'},
    {'name': 'Lavagem Completa', 'price': '60.00'},
    {'name': 'Polimento', 'price': '150.00'},
    {'name': 'Higienização Interna', 'price': '100.00'},
    {'name': 'Vitrificação', 'price': '400.00'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.serviceToEdit != null) {
      _nameController.text = widget.serviceToEdit!['name'];
      _priceController.text = widget.serviceToEdit!['price'].toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _applyTemplate(String name, String price) {
    setState(() {
      _nameController.text = name;
      _priceController.text = price;
    });

    final lang = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.msgTemplateApplied(name)),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _save() async {
    final lang = AppLocalizations.of(context)!;

    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.msgFillAllFields)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = AppBackend.client.auth.currentUser!.id;
      final double price = double.parse(
        _priceController.text.replaceAll(',', '.'),
      );

      final data = {
        'user_id': userId,
        'name': _nameController.text.trim(),
        'price': price,
      };

      if (widget.serviceToEdit == null) {
        await AppBackend.client.from('services').insert(data);
      } else {
        await AppBackend.client
            .from('services')
            .update(data)
            .eq('id', widget.serviceToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.msgServiceSaved, // <--- CORREÇÃO AQUI
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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
    final isEditing = widget.serviceToEdit != null;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final currencySymbol = lang.localeName == 'pt' ? 'R\$' : '\$';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.btnEdit : lang.btnNew),
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
                  if (isLargeScreen) ...[
                    const Center(
                      child: Icon(
                        Icons.local_offer,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (!isEditing) ...[
                    Text(
                      lang.titleQuickTemplates,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _quickTemplates.map((template) {
                        return ActionChip(
                          backgroundColor: AppColors.accent.withValues(
                            alpha: 0.1,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          label: Text(
                            template['name'],
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => _applyTemplate(
                            template['name'],
                            template['price'],
                          ),
                        );
                      }).toList(),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(),
                    ),
                  ],
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lang.labelService,
                      prefixIcon: const Icon(Icons.build_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '${lang.labelPrice} ($currencySymbol)',
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              lang.btnSave.toUpperCase(),
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
