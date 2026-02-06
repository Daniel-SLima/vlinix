import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart'; // <--- IMPORTANTE

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

  @override
  void initState() {
    super.initState();
    // Se veio um serviço para editar, preenche os campos
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

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preencha todos os campos')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final double price = double.parse(
        _priceController.text.replaceAll(',', '.'),
      );

      final data = {
        'user_id': userId,
        'name': _nameController.text.trim(),
        'price': price,
      };

      if (widget.serviceToEdit == null) {
        // Criar Novo
        await Supabase.instance.client.from('services').insert(data);
      } else {
        // Editar Existente
        await Supabase.instance.client
            .from('services')
            .update(data)
            .eq('id', widget.serviceToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serviço salvo com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context); // Volta para a lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Serviço' : lang.btnNew),
        centerTitle: true,
        // Theme cuida das cores
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
                children: [
                  if (isLargeScreen) ...[
                    const Icon(
                      Icons.local_offer,
                      size: 60,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Campo Nome
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lang.labelService,
                      prefixIcon: const Icon(Icons.build_circle_outlined),
                      // Theme cuida das bordas
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo Preço
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço (R\$)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botão Salvar
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
