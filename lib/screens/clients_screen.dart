import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'add_client_screen.dart'; // IMPORTANTE: Importe a nova tela

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

  // --- DELETE ---
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

  // Navegação para a tela de Adicionar/Editar
  void _navigateToAddEdit({Map<String, dynamic>? client}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddClientScreen(clientToEdit: client),
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
                                  _navigateToAddEdit(client: client),
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
