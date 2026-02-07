import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AddClientScreen extends StatefulWidget {
  final Map<String, dynamic>? clientToEdit;

  const AddClientScreen({super.key, this.clientToEdit});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  // Estado para controlar qual país está selecionado (Padrão: BR)
  String _selectedCountry = 'BR';

  // --- DEFINIÇÃO DAS MÁSCARAS ---
  final maskBR = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final maskUS = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final maskMX = MaskTextInputFormatter(
    mask: '(##) #### ####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Getter para pegar a máscara atual baseada na seleção
  MaskTextInputFormatter get _currentMask {
    switch (_selectedCountry) {
      case 'US':
        return maskUS;
      case 'MX':
        return maskMX;
      default:
        return maskBR;
    }
  }

  // Getter para o prefixo (ajuda visual)
  String get _countryPrefix {
    switch (_selectedCountry) {
      case 'US':
        return '+1 ';
      case 'MX':
        return '+52 ';
      default:
        return '+55 ';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.clientToEdit != null) {
      _nameController.text = widget.clientToEdit!['full_name'] ?? '';
      _phoneController.text = widget.clientToEdit!['phone'] ?? '';
      _emailController.text = widget.clientToEdit!['email'] ?? '';
      _addressController.text = widget.clientToEdit!['address'] ?? '';

      // Tenta "adivinhar" o país pelo tamanho do número se estiver editando,
      // mas o ideal seria salvar o código do país no banco separado.
      // Por simplicidade, mantemos BR como padrão na edição se não for óbvio.
    }
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final lang = AppLocalizations.of(context)!;

    try {
      final supabase = Supabase.instance.client;

      // Opcional: Salvar o prefixo junto? Ex: "+55 (11) 9..."
      // Por enquanto salvamos o que está no campo formatado.
      final fullPhone = _phoneController.text.trim();

      final data = {
        'full_name': _nameController.text.trim(),
        'phone': fullPhone,
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
      };

      if (widget.clientToEdit == null) {
        await supabase.from('clients').insert(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.msgClientCreated),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await supabase
            .from('clients')
            .update(data)
            .eq('id', widget.clientToEdit!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.msgClientUpdated),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.clientToEdit != null;
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? lang.titleEditClient : lang.titleNewClient),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // NOME
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: lang.labelName,
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Informe o nome'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // --- SELETOR DE PAÍS E TELEFONE ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dropdown de País
                        Container(
                          height: 56, // Altura padrão do input
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCountry,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCountry = newValue!;
                                  _phoneController
                                      .clear(); // Limpa ao trocar para evitar conflito de máscara
                                });
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'BR',
                                  child: Text('🇧🇷 BR'),
                                ),
                                DropdownMenuItem(
                                  value: 'US',
                                  child: Text('🇺🇸 US'),
                                ),
                                DropdownMenuItem(
                                  value: 'MX',
                                  child: Text('🇲🇽 MX'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Campo de Telefone (Muda conforme seleção)
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              _currentMask,
                            ], // Aplica a máscara selecionada
                            decoration: InputDecoration(
                              labelText: lang.labelPhone,
                              prefixIcon: const Icon(Icons.phone),
                              prefixText:
                                  _countryPrefix, // Mostra +55, +1, etc.
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: _currentMask
                                  .getMask(), // Mostra o formato esperado (##) ...
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    // EMAIL
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: lang.labelEmail,
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ENDEREÇO
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: lang.labelAddress,
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // BOTÃO SALVAR
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveClient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
