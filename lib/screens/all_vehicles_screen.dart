import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';
import 'add_vehicle_screen.dart';

class AllVehiclesScreen extends StatefulWidget {
  const AllVehiclesScreen({super.key});

  @override
  State<AllVehiclesScreen> createState() => _AllVehiclesScreenState();
}

class _AllVehiclesScreenState extends State<AllVehiclesScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';
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

  Future<void> _deleteVehicle(int id) async {
    final lang = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Veículo?'),
        content: Text(lang.dialogDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.btnCancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.btnDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('vehicles').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veículo excluído com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir veículo.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _navigateToAddEdit({Map<String, dynamic>? vehicle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(vehicleToEdit: vehicle),
      ),
    ).then((_) {
      _fetchClients();
    });
  }

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),
        title: Text(lang.titleAllVehicles),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_vehicles', // Hero Tag Única
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: lang.hintSearchVehicle, // Traduzido
                hintText: lang.hintSearchGeneric, // Traduzido
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                    color: AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _vehiclesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allVehicles = snapshot.data!;
                final vehicles = allVehicles.where((v) {
                  if (_searchText.isEmpty) return true;
                  final model = (v['model'] ?? '').toString().toLowerCase();
                  final plate = (v['plate'] ?? '').toString().toLowerCase();
                  final ownerName = _getOwnerName(v['client_id']).toLowerCase();
                  return model.contains(_searchText) ||
                      plate.contains(_searchText) ||
                      ownerName.contains(_searchText);
                }).toList();

                if (vehicles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          lang.msgNoVehicles,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    final ownerName = _getOwnerName(vehicle['client_id']);

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          '${vehicle['model']} - ${vehicle['plate']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${lang.labelColor}: ${vehicle['color']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 12,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ownerName.isNotEmpty ? ownerName : 'Sem dono',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _navigateToAddEdit(vehicle: vehicle);
                            } else if (value == 'delete') {
                              _deleteVehicle(vehicle['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.edit,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(lang.btnEdit),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(lang.btnDelete),
                                ],
                              ),
                            ),
                          ],
                        ),
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
