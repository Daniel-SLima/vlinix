import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';

  final _clientsStream = Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .order('full_name');

  @override
  void initState() {
    super.initState();
    // Ouve o que é digitado na busca
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- CRUD ---
  Future<void> _createOrUpdateClient({
    int? id,
    required String name,
    required String phone,
    required String email,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = {
      'user_id': userId,
      'full_name': name,
      'phone': phone,
      'email': email,
    };

    try {
      if (id == null) {
        await Supabase.instance.client.from('clients').insert(data);
      } else {
        await Supabase.instance.client
            .from('clients')
            .update(data)
            .eq('id', id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteClient(int id) async {
    try {
      await Supabase.instance.client.from('clients').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClientDialog({Map<String, dynamic>? client}) {
    final lang = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: client?['full_name']);
    final phoneCtrl = TextEditingController(text: client?['phone']);
    final emailCtrl = TextEditingController(text: client?['email']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          client == null ? lang.titleNewClient : lang.titleEditClient,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: lang.labelName),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: lang.labelPhone),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(labelText: lang.labelEmail),
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
              if (nameCtrl.text.isEmpty) return;
              _createOrUpdateClient(
                id: client?['id'],
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                email: emailCtrl.text,
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
        title: Text(lang.titleManageClients),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(),
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
                labelText: 'Pesquisar Cliente',
                hintText: 'Nome, telefone ou email...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // --- LISTA ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _clientsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final allClients = snapshot.data!;

                // Lógica de Filtro
                final clients = allClients.where((client) {
                  final name = (client['full_name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final phone = (client['phone'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (client['email'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchText) ||
                      phone.contains(_searchText) ||
                      email.contains(_searchText);
                }).toList();

                if (clients.isEmpty)
                  return Center(child: Text(lang.msgNoClients));

                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            client['full_name']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(client['full_name']),
                        subtitle: Text(
                          '${client['phone'] ?? '-'} \n${client['email'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showClientDialog(client: client),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteClient(client['id']),
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
