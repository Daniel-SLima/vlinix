import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class AddClientScreen extends StatefulWidget {
  final Map<String, dynamic>? clientToEdit;

  const AddClientScreen({super.key, this.clientToEdit});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Padrão inicial: EUA (+1)
  String _selectedCountryCode = '+1';
  bool _isLoading = false;

  // Lista de Países (Mercado Norte-Americano + Brasil)
  final List<Map<String, String>> _countryCodes = [
    {'code': '+1', 'flag': '🇺🇸', 'label': 'USA (+1)', 'value': 'US+1'},
    {'code': '+1', 'flag': '🇨🇦', 'label': 'CAN (+1)', 'value': 'CA+1'},
    {'code': '+52', 'flag': '🇲🇽', 'label': 'MEX (+52)', 'value': 'MX+52'},
    {'code': '+55', 'flag': '🇧🇷', 'label': 'BRA (+55)', 'value': 'BR+55'},
  ];

  String _selectedDropdownValue = 'US+1';

  @override
  void initState() {
    super.initState();
    if (widget.clientToEdit != null) {
      _nameController.text = widget.clientToEdit!['full_name'];
      _emailController.text = widget.clientToEdit!['email'] ?? '';

      String fullPhone = widget.clientToEdit!['phone'] ?? '';
      _extractCountryCode(fullPhone);
    }
  }

  void _extractCountryCode(String phone) {
    bool found = false;
    for (var country in _countryCodes) {
      if (phone.startsWith(country['code']!)) {
        setState(() {
          _selectedCountryCode = country['code']!;
          _selectedDropdownValue = country['value']!;
          _phoneController.text = phone
              .substring(country['code']!.length)
              .trim();
        });
        found = true;
        break;
      }
    }
    if (!found) {
      _phoneController.text = phone;
    }
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return true;
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phoneRaw = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('O nome é obrigatório.')));
      return;
    }

    if (email.isNotEmpty && !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-mail inválido. Verifique o formato.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final cleanPhone = phoneRaw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final fullPhone = cleanPhone.isNotEmpty
          ? '$_selectedCountryCode$cleanPhone'
          : '';

      final data = {
        'user_id': userId,
        'full_name': name,
        'phone': fullPhone,
        'email': email,
      };

      if (widget.clientToEdit == null) {
        await Supabase.instance.client.from('clients').insert(data);
      } else {
        await Supabase.instance.client
            .from('clients')
            .update(data)
            .eq('id', widget.clientToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
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
    final isEditing = widget.clientToEdit != null;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    // Altura padrão do Material Design para Inputs
    const double inputHeight = 56.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.titleEditClient : lang.titleNewClient),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: isLargeScreen ? Colors.grey[100] : Colors.white,

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
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lang.labelName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- SELETOR DE PAÍS + TELEFONE (Visual Unificado) ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown de País
                      Container(
                        height: inputHeight, // Altura fixa igual ao TextField
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey,
                          ), // Mesma cor da borda padrão
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDropdownValue,
                            icon: const Icon(Icons.arrow_drop_down),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16, // Tamanho de fonte padrão do input
                            ),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedDropdownValue = newValue!;
                                _selectedCountryCode = _countryCodes.firstWhere(
                                  (c) => c['value'] == newValue,
                                )['code']!;
                              });
                            },
                            items: _countryCodes.map((country) {
                              return DropdownMenuItem(
                                value: country['value'],
                                child: Row(
                                  children: [
                                    Text(
                                      country['flag']!,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      country['code']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      // Campo de Número (Grudado na direita)
                      Expanded(
                        child: SizedBox(
                          height: inputHeight, // Garante altura igual
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            // Remove o padding vertical padrão para alinhar o texto
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              labelText: lang.labelPhone,
                              prefixIcon: null,
                              // Remove a borda esquerda para "grudar" no dropdown
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(4),
                                  bottomRight: Radius.circular(4),
                                ),
                                borderSide: BorderSide(
                                  color: Color(0xFF1E88E5),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: lang.labelEmail,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email),
                      hintText: 'cliente@email.com',
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        elevation: isLargeScreen ? 2 : 1,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              lang.btnSave.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
