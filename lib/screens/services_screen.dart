import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _stream = Supabase.instance.client
      .from('services')
      .stream(primaryKey: ['id'])
      .order('name');

  // --- Lógica de CRUD ---
  Future<void> _createOrUpdate(int? id, String name, double price) async {
    final data = {'name': name, 'price': price};
    if (id == null) {
      await Supabase.instance.client.from('services').insert(data);
    } else {
      await Supabase.instance.client.from('services').update(data).eq('id', id);
    }
  }

  Future<void> _delete(int id) async {
    try {
      await Supabase.instance.client.from('services').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Serviço em uso!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDialog({Map<String, dynamic>? service}) {
    final lang = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: service?['name']);
    final priceCtrl = TextEditingController(
      text: service?['price']?.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(service == null ? lang.btnNew : 'Editar Serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: lang.labelService),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Preço (R\$)'),
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
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                _createOrUpdate(
                  service?['id'],
                  nameCtrl.text,
                  double.parse(priceCtrl.text.replaceAll(',', '.')),
                );
                Navigator.pop(ctx);
              }
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
        title: Text(lang.menuServices),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      // --- O BOTÃO QUE FALTAVA ESTÁ AQUI ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: _stream,
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data as List;

          if (list.isEmpty) {
            return const Center(child: Text('Nenhum serviço cadastrado.'));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(item['name']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "R\$ ${item['price']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showDialog(service: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(item['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
