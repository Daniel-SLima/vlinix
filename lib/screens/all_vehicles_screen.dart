import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class AllVehiclesScreen extends StatefulWidget {
  const AllVehiclesScreen({super.key});

  @override
  State<AllVehiclesScreen> createState() => _AllVehiclesScreenState();
}

class _AllVehiclesScreenState extends State<AllVehiclesScreen> {
  final _vehiclesStream = Supabase.instance.client
      .from('vehicles')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Future<void> _updateVehicle(
    int id,
    String model,
    String plate,
    String color,
  ) async {
    await Supabase.instance.client
        .from('vehicles')
        .update({'model': model, 'plate': plate, 'color': color})
        .eq('id', id);
  }

  Future<void> _deleteVehicle(int id) async {
    try {
      await Supabase.instance.client.from('vehicles').delete().eq('id', id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.msgErrorDeleteVehicle),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  void _showEditDialog(Map<String, dynamic> vehicle) {
    final lang = AppLocalizations.of(context)!;
    final modelCtrl = TextEditingController(text: vehicle['model']);
    final plateCtrl = TextEditingController(text: vehicle['plate']);
    final colorCtrl = TextEditingController(text: vehicle['color']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.titleEditVehicle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.btnCancel),
          ),
          ElevatedButton(
            onPressed: () {
              _updateVehicle(
                vehicle['id'],
                modelCtrl.text,
                plateCtrl.text,
                colorCtrl.text,
              );
              Navigator.pop(ctx);
            },
            child: Text(lang.btnSave),
          ),
        ],
      ),
    );
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _vehiclesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final vehicles = snapshot.data!;
          if (vehicles.isEmpty) return Center(child: Text(lang.msgNoVehicles));

          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return FutureBuilder(
                future: Supabase.instance.client
                    .from('clients')
                    .select('full_name')
                    .eq('id', vehicle['client_id'])
                    .single(),
                builder: (ctx, ownerSnapshot) {
                  if (!ownerSnapshot.hasData)
                    return const LinearProgressIndicator();
                  final owner = ownerSnapshot.data!;
                  final ownerName = owner['full_name'] ?? 'Desconhecido';

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
                          onPressed: () => _showEditDialog(vehicle),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(lang.dialogDeleteTitle),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(lang.btnCancel),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _deleteVehicle(vehicle['id']);
                                      Navigator.pop(ctx);
                                    },
                                    child: Text(
                                      lang.btnDelete,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
