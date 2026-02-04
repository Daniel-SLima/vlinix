import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class AllVehiclesScreen extends StatefulWidget {
  const AllVehiclesScreen({super.key});

  @override
  State<AllVehiclesScreen> createState() => _AllVehiclesScreenState();
}

class _AllVehiclesScreenState extends State<AllVehiclesScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';

  // Lista de clientes para o Dropdown (Criar Carro) e para a Pesquisa
  List<Map<String, dynamic>> _clients = [];

  final _vehiclesStream = Supabase.instance.client
      .from('vehicles')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  @override
  void initState() {
    super.initState();
    _fetchClients(); // Carrega clientes ao abrir a tela
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
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

  // --- CRUD ---

  Future<void> _createOrUpdateVehicle({
    int? id,
    required int clientId,
    required String model,
    required String plate,
    required String color,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = {
      'user_id': userId,
      'client_id': clientId,
      'model': model,
      'plate': plate,
      'color': color,
    };

    if (id == null) {
      await Supabase.instance.client.from('vehicles').insert(data);
    } else {
      await Supabase.instance.client.from('vehicles').update(data).eq('id', id);
    }
  }

  Future<void> _deleteVehicle(int id) async {
    try {
      await Supabase.instance.client.from('vehicles').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir veículo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDialog({Map<String, dynamic>? vehicle}) {
    final lang = AppLocalizations.of(context)!;
    final modelCtrl = TextEditingController(text: vehicle?['model']);
    final plateCtrl = TextEditingController(text: vehicle?['plate']);
    final colorCtrl = TextEditingController(text: vehicle?['color']);

    // Se for edição, pega o dono atual. Se for novo, nulo.
    int? selectedClientId = vehicle?['client_id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder para atualizar o Dropdown se precisar
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              vehicle == null ? 'Novo Veículo' : lang.titleEditVehicle,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dropdown de Clientes (Obrigatório)
                  DropdownButtonFormField<int>(
                    value: selectedClientId,
                    decoration: InputDecoration(
                      labelText: lang.labelClient,
                      border: const OutlineInputBorder(),
                    ),
                    items: _clients.map((c) {
                      return DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['full_name']),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setStateDialog(() => selectedClientId = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: modelCtrl,
                    decoration: InputDecoration(labelText: lang.labelModel),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: plateCtrl,
                    decoration: InputDecoration(labelText: lang.labelPlate),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: colorCtrl,
                    decoration: InputDecoration(labelText: lang.labelColor),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.btnCancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (modelCtrl.text.isNotEmpty && selectedClientId != null) {
                    await _createOrUpdateVehicle(
                      id: vehicle?['id'],
                      clientId: selectedClientId!,
                      model: modelCtrl.text,
                      plate: plateCtrl.text,
                      color: colorCtrl.text,
                    );
                    if (mounted) Navigator.pop(ctx);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Selecione um cliente e preencha o modelo.',
                        ),
                      ),
                    );
                  }
                },
                child: Text(lang.btnSave),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper para achar nome do dono pelo ID
  String _getOwnerName(int clientId) {
    final client = _clients.firstWhere(
      (c) => c['id'] == clientId,
      orElse: () => {'full_name': ''},
    );
    return client['full_name'];
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.titleAllVehicles),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      // --- FAB PARA CRIAR CARRO ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // --- BARRA DE PESQUISA ---
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Pesquisar Veículo',
                hintText: 'Modelo, placa ou dono...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // --- LISTA ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _vehiclesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final allVehicles = snapshot.data!;

                // Lógica de Filtro Poderosa
                final vehicles = allVehicles.where((v) {
                  if (_searchText.isEmpty) return true;

                  final model = (v['model'] ?? '').toString().toLowerCase();
                  final plate = (v['plate'] ?? '').toString().toLowerCase();
                  // Procura o nome do dono na nossa lista carregada
                  final ownerName = _getOwnerName(v['client_id']).toLowerCase();

                  return model.contains(_searchText) ||
                      plate.contains(_searchText) ||
                      ownerName.contains(_searchText);
                }).toList();

                if (vehicles.isEmpty)
                  return Center(child: Text(lang.msgNoVehicles));

                return ListView.builder(
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    final ownerName = _getOwnerName(vehicle['client_id']);

                    return ListTile(
                      leading: const Icon(
                        Icons.directions_car,
                        color: Colors.blue,
                      ),
                      title: Text(
                        '${vehicle['model']} - ${vehicle['plate']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${lang.labelColor}: ${vehicle['color']}'),
                          Text(
                            '${lang.labelOwner}: $ownerName',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showDialog(vehicle: vehicle),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteVehicle(vehicle['id']),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
