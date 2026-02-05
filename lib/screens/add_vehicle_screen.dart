import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class AddVehicleScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicleToEdit;

  const AddVehicleScreen({super.key, this.vehicleToEdit});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();

  int? _selectedClientId;
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();

    if (widget.vehicleToEdit != null) {
      _modelController.text = widget.vehicleToEdit!['model'];
      _plateController.text = widget.vehicleToEdit!['plate'];
      _colorController.text = widget.vehicleToEdit!['color'];
      _selectedClientId = widget.vehicleToEdit!['client_id'];
    }
  }

  Future<void> _fetchClients() async {
    final data = await Supabase.instance.client
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
    if (_modelController.text.isEmpty || _selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um cliente e preencha o modelo.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = {
        'user_id': userId,
        'client_id': _selectedClientId,
        'model': _modelController.text.trim(),
        'plate': _plateController.text.trim(),
        'color': _colorController.text.trim(),
      };

      if (widget.vehicleToEdit == null) {
        // Criar
        await Supabase.instance.client.from('vehicles').insert(data);
      } else {
        // Editar
        await Supabase.instance.client
            .from('vehicles')
            .update(data)
            .eq('id', widget.vehicleToEdit!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veículo salvo com sucesso!'),
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
    final isEditing = widget.vehicleToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? lang.titleEditVehicle : 'Novo Veículo'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: _clients.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedClientId,
                    decoration: InputDecoration(
                      labelText: lang.labelClient,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    items: _clients.map((c) {
                      return DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['full_name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedClientId = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: lang.labelModel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _plateController,
                    decoration: InputDecoration(
                      labelText: lang.labelPlate,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.pin),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _colorController,
                    decoration: InputDecoration(
                      labelText: lang.labelColor,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.color_lens),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(lang.btnSave.toUpperCase()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
