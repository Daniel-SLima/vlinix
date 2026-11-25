import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';

class AddVehicleScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicleToEdit;
  // --- MUDANÇA: ADICIONAMOS O CLIENTE PRÉ-SELECIONADO ---
  final int? preSelectedClientId;

  const AddVehicleScreen({
    super.key,
    this.vehicleToEdit,
    this.preSelectedClientId,
  });

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();

  int? _selectedClientId;
  String? _selectedCategory;
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = false;

  final List<String> _vehicleSizes = [
    'Sedan',
    'SUV',
    'Large SUV',
    'Truck',
    'Minivan',
  ];

  final List<String> _vehicleModels = [
    'Ford F-150',
    'Chevrolet Silverado',
    'Ram 1500',
    'Toyota RAV4',
    'Toyota Camry',
    'Toyota Corolla',
    'Honda CR-V',
    'Honda Civic',
    'Nissan Rogue',
    'Jeep Grand Cherokee',
    'Tesla Model Y',
    'Tesla Model 3',
    'BMW 3 Series',
    'BMW X5',
    'Mercedes-Benz C-Class',
    'Mercedes-Benz GLE',
    'Lexus RX',
    'Audi Q5',
    'Porsche Macan',
    'Land Rover Range Rover',
  ];

  @override
  void initState() {
    super.initState();

    // --- MUDANÇA: SE RECEBER UM CLIENTE, JÁ SALVA ELE NO ESTADO ---
    if (widget.preSelectedClientId != null) {
      _selectedClientId = widget.preSelectedClientId;
    }

    _fetchClients();

    if (widget.vehicleToEdit != null) {
      _modelController.text = widget.vehicleToEdit!['model'] ?? '';
      _colorController.text = widget.vehicleToEdit!['color'] ?? '';
      _selectedClientId = widget.vehicleToEdit!['client_id'];
      _selectedCategory = widget.vehicleToEdit!['category'];
    }
  }

  Future<void> _fetchClients() async {
    final data = await AppBackend.client
        .from('clients')
        .select()
        .order('full_name');

    if (mounted) {
      setState(() {
        _clients = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  Future<void> _save() async {
    final lang = AppLocalizations.of(context)!;

    if (_modelController.text.isEmpty ||
        _selectedClientId == null ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(lang.msgErrorSaveVehicle)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = AppBackend.client.auth.currentUser!.id;
      final data = {
        'user_id': userId,
        'client_id': _selectedClientId,
        'category': _selectedCategory,
        'model': _modelController.text.trim(),
        'color': _colorController.text.trim(),
      };

      if (widget.vehicleToEdit == null) {
        await AppBackend.client.from('vehicles').insert(data);
      } else {
        await AppBackend.client
            .from('vehicles')
            .update(data)
            .eq('id', widget.vehicleToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgVehicleSaved),
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
    final isEditing = widget.vehicleToEdit != null;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    // --- MUDANÇA: Verifica se a tela foi abierta por um cliente específico ---
    final isFromClientProfile = widget.preSelectedClientId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.titleEditVehicle : lang.titleNewVehicle),
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body:
          _clients.isEmpty &&
              !isFromClientProfile // Pequeno ajuste de loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
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
                            Icons.directions_car_filled,
                            size: 60,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // --- MUDANÇA: ESCONDE O DROPDOWN SE VEIO DO PERFIL DO CLIENTE ---
                        if (!isFromClientProfile) ...[
                          DropdownButtonFormField<int>(
                            value: _selectedClientId,
                            decoration: InputDecoration(
                              labelText: lang.labelClient,
                              prefixIcon: const Icon(Icons.person),
                            ),
                            items: _clients.map((c) {
                              return DropdownMenuItem(
                                value: c['id'] as int,
                                child: Text(c['full_name']),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedClientId = val),
                          ),
                          const SizedBox(height: 16),
                        ],

                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: lang.labelCategory,
                            prefixIcon: const Icon(Icons.category),
                          ),
                          items: _vehicleSizes.map((size) {
                            return DropdownMenuItem(
                              value: size,
                              child: Text(size),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategory = val),
                        ),
                        const SizedBox(height: 16),

                        Autocomplete<String>(
                          initialValue: TextEditingValue(
                            text: _modelController.text,
                          ),
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return _vehicleModels.where((String option) {
                              return option.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              );
                            });
                          },
                          onSelected: (String selection) {
                            _modelController.text = selection;
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (val) =>
                                      _modelController.text = val,
                                  decoration: InputDecoration(
                                    labelText: lang.labelModel,
                                    prefixIcon: const Icon(
                                      Icons.directions_car,
                                    ),
                                    hintText: lang.hintModelExample,
                                  ),
                                );
                              },
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _colorController,
                          decoration: InputDecoration(
                            labelText: lang.labelColor,
                            prefixIcon: const Icon(Icons.color_lens),
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
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
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
