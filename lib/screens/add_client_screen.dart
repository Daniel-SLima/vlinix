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
  // Nota: O 'value' deve ser único para o Dropdown funcionar perfeitamente.
  // Como EUA e Canadá são +1, usamos um identificador único no value e tratamos depois.
  final List<Map<String, String>> _countryCodes = [
    {'code': '+1', 'flag': '🇺🇸', 'label': 'USA (+1)', 'value': 'US+1'},
    {'code': '+1', 'flag': '🇨🇦', 'label': 'CAN (+1)', 'value': 'CA+1'},
    {'code': '+52', 'flag': '🇲🇽', 'label': 'MEX (+52)', 'value': 'MX+52'},
    {'code': '+55', 'flag': '🇧🇷', 'label': 'BRA (+55)', 'value': 'BR+55'},
  ];

  // Variável para controlar a seleção única do dropdown (combinação País+Código)
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
    // Tenta encontrar o código na lista
    bool found = false;
    for (var country in _countryCodes) {
      if (phone.startsWith(country['code']!)) {
        setState(() {
          // Atualiza o código visual e o valor do dropdown
          _selectedCountryCode = country['code']!;
          _selectedDropdownValue = country['value']!;

          // Remove o código do início para mostrar só o número no campo de texto
          _phoneController.text = phone
              .substring(country['code']!.length)
              .trim();
        });
        found = true;
        break; // Para no primeiro que encontrar (EUA ganha de Canadá por ordem)
      }
    }
    // Se não achar (número antigo ou sem formato), mostra tudo no campo
    if (!found) {
      _phoneController.text = phone;
    }
  }

  // --- Validação de E-mail ---
  bool _isValidEmail(String email) {
    if (email.isEmpty) return true; // Opcional
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

      // Limpa caracteres especiais do telefone digitado pelo usuário
      final cleanPhone = phoneRaw.replaceAll(RegExp(r'[\s\-\(\)]'), '');

      // Junta DDI selecionado + Número limpo
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

                  // --- SELETOR DE PAÍS + TELEFONE ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown de País
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade500),
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
                            onChanged: (newValue) {
                              setState(() {
                                _selectedDropdownValue = newValue!;
                                // Encontra o código real baseado no valor selecionado (ex: pega '+1' de 'US+1')
                                _selectedCountryCode = _countryCodes.firstWhere(
                                  (c) => c['value'] == newValue,
                                )['code']!;
                              });
                            },
                            items: _countryCodes.map((country) {
                              return DropdownMenuItem(
                                value: country['value'], // Valor único
                                child: Text(
                                  "${country['flag']} ${country['code']}",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // Campo de Número
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: lang.labelPhone,
                            prefixIcon: null,
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
