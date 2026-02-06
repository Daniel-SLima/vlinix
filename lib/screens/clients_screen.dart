import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart'; // <--- IMPORTANTE: Nossas cores
import 'add_client_screen.dart';

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
    // Adicionei uma confirmação para ficar mais seguro/profissional
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Cliente?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('clients').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente excluído com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lang.titleManageClients),
        centerTitle: true,
        // Cor e estilo vêm do Theme (Chumbo)
        // Adicionamos ícone de busca na AppBar para ficar moderno (opcional, mas legal)
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: AppColors.accent, // Dourado
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),

      body: Column(
        children: [
          // --- BARRA DE PESQUISA (Agora mais limpa) ---
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white, // Fundo branco na área de busca
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText:
                    lang.hintSearchClient, // <--- Traduzido (Pesquisar Cliente)
                hintText: lang
                    .hintSearchGeneric, // <--- Traduzido (Nome, telefone...)
                prefixIcon: const Icon(Icons.search),
                // O Theme já cuida das bordas douradas!
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
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

          // --- LISTA ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _clientsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

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

                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          lang.msgNoClients,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 80,
                  ), // Espaço pro FAB
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final firstLetter = client['full_name']
                        .toString()
                        .substring(0, 1)
                        .toUpperCase();

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
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            firstLetter,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          client['full_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (client['phone'] != null &&
                                client['phone'] != '')
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    client['phone'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            if (client['email'] != null &&
                                client['email'] != '')
                              Text(
                                client['email'],
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _navigateToAddEdit(client: client);
                            } else if (value == 'delete') {
                              _deleteClient(client['id']);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: AppColors.error),
                                  SizedBox(width: 8),
                                  Text('Excluir'),
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
