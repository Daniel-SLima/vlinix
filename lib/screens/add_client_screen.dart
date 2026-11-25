import 'package:vlinix/data/app_backend.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // --- CONTROLES DE ENDEREÇO ---
  final _zipController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();

  // Variavel para o Dropdown de Estados
  String? _selectedStateAbbr;

  bool _isLoading = false;
  bool _isSearchingZip = false;

  // --- MAPA DOS ESTADOS (Sigla -> Nome Extenso) ---
  final Map<String, String> _usStatesMap = {
    'AL': 'Alabama',
    'AK': 'Alaska',
    'AZ': 'Arizona',
    'AR': 'Arkansas',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DE': 'Delaware',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'IA': 'Iowa',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'ME': 'Maine',
    'MD': 'Maryland',
    'MA': 'Massachusetts',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MS': 'Mississippi',
    'MO': 'Missouri',
    'MT': 'Montana',
    'NE': 'Nebraska',
    'NV': 'Nevada',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NY': 'New York',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VT': 'Vermont',
    'VA': 'Virginia',
    'WA': 'Washington',
    'WV': 'West Virginia',
    'WI': 'Wisconsin',
    'WY': 'Wyoming',
  };

  // --- MÁSCARA FIXA PARA OS EUA ---
  final maskUS = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    if (widget.clientToEdit != null) {
      _nameController.text = widget.clientToEdit!['full_name'] ?? '';
      _phoneController.text = widget.clientToEdit!['phone'] ?? '';
      _emailController.text = widget.clientToEdit!['email'] ?? '';
      _streetController.text = widget.clientToEdit!['address'] ?? '';
    }
  }

  // --- BUSCA AUTOMÁTICA DE ZIPCODE (APENAS EUA) ---
  Future<void> _searchZipCode() async {
    if (AppBackend.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Na demonstração, preencha um endereço fictício manualmente.',
          ),
        ),
      );
      return;
    }
    final zip = _zipController.text.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    if (zip.isEmpty) return;

    setState(() => _isSearchingZip = true);

    try {
      final res = await http.get(
        Uri.parse('https://api.zippopotam.us/us/$zip'),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final places = data['places'] as List;
        if (places.isNotEmpty) {
          setState(() {
            _cityController.text = places[0]['place name'] ?? '';

            // Pega a sigla do estado e verifica se existe no nosso mapa
            String stateAbbr = (places[0]['state abbreviation'] ?? '')
                .toString()
                .toUpperCase();

            if (_usStatesMap.containsKey(stateAbbr)) {
              _selectedStateAbbr = stateAbbr;
            }
          });
        }
      } else {
        if (mounted) {
          final lang = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.msgZipcodeNotFound,
              ), // <-- CHAVE TRADUZIDA AQUI
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar Zipcode: $e');
    } finally {
      setState(() => _isSearchingZip = false);
    }
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final lang = AppLocalizations.of(context)!;

    try {
      final supabase = AppBackend.client;

      String rawPhone = _phoneController.text.trim();
      String fullPhone = rawPhone.isNotEmpty ? '+1 $rawPhone' : '';

      List<String> addressParts = [];
      if (_streetController.text.isNotEmpty) {
        addressParts.add(_streetController.text.trim());
      }
      if (_cityController.text.isNotEmpty) {
        String cityState = _cityController.text.trim();
        if (_selectedStateAbbr != null) {
          cityState += ', $_selectedStateAbbr';
        }
        addressParts.add(cityState);
      }
      if (_zipController.text.isNotEmpty) {
        addressParts.add(_zipController.text.trim());
      }

      final finalAddress = addressParts.join(' | ');

      final data = {
        'full_name': _nameController.text.trim(),
        'phone': fullPhone,
        'email': _emailController.text.trim(),
        'address': finalAddress,
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.labelProfileInfo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: lang.labelName,
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? lang.msgEmptyName
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [maskUS],
                      decoration: InputDecoration(
                        labelText: lang.labelPhone,
                        prefixIcon: const Icon(Icons.phone),
                        prefixText: '+1 ',
                        hintText: maskUS.getMask(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: lang.labelEmail,
                        prefixIcon: const Icon(Icons.email),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(),
                    ),

                    Text(
                      lang.labelAddress,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _zipController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText:
                            lang.labelZipcode, // <-- CHAVE TRADUZIDA AQUI
                        prefixIcon: const Icon(
                          Icons.markunread_mailbox_outlined,
                        ),
                        suffixIcon: _isSearchingZip
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.search,
                                  color: AppColors.accent,
                                ),
                                onPressed: _searchZipCode,
                              ),
                      ),
                      onFieldSubmitted: (_) => _searchZipCode(),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _streetController,
                      decoration: InputDecoration(
                        labelText: lang.labelStreet, // <-- CHAVE TRADUZIDA AQUI
                        hintText: 'e.g., 1234 Main St',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: InputDecoration(
                              labelText: lang.labelCity,
                              prefixIcon: const Icon(Icons.location_city),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedStateAbbr,
                            decoration: InputDecoration(
                              labelText: lang.labelState,
                            ),
                            items: _usStatesMap.keys.map((String abbr) {
                              return DropdownMenuItem<String>(
                                value: abbr,
                                child: Text(
                                  _usStatesMap[abbr]!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedStateAbbr = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

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
