import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'add_vehicle_screen.dart'; // IMPORTANTE: Importe a nova tela

class AllVehiclesScreen extends StatefulWidget {
  const AllVehiclesScreen({super.key});

  @override
  State<AllVehiclesScreen> createState() => _AllVehiclesScreenState();
}

class _AllVehiclesScreenState extends State<AllVehiclesScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';

  // Lista de clientes necessária para a BUSCA por nome do dono
  List<Map<String, dynamic>> _clients = [];

  final _vehiclesStream = Supabase.instance.client
      .from('vehicles')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  @override
  void initState() {
    super.initState();
    _fetchClients();
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

  // --- DELETE ---
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

  // Navegação para a tela de Adicionar/Editar
  void _navigateToAddEdit({Map<String, dynamic>? vehicle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(vehicleToEdit: vehicle),
      ),
    ).then((_) {
      // Quando volta, recarrega os clientes caso algum nome tenha mudado (opcional, mas boa prática)
      _fetchClients();
    });
  }

  // Helper para achar nome do dono pelo ID (Usado na Busca e na Lista)
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
      // --- FAB Redireciona para tela nova ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEdit(),
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

                // Lógica de Filtro
                final vehicles = allVehicles.where((v) {
                  if (_searchText.isEmpty) return true;

                  final model = (v['model'] ?? '').toString().toLowerCase();
                  final plate = (v['plate'] ?? '').toString().toLowerCase();
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
                            onPressed: () =>
                                _navigateToAddEdit(vehicle: vehicle),
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
