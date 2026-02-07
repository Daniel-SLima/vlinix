import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';
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

  Future<void> _deleteClient(int id) async {
    final lang = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.dialogDeleteTitle),
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
      await Supabase.instance.client.from('clients').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgClientDeleted),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorDeleteClient),
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
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_clients',
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: lang.hintSearchClient,
                hintText: lang.hintSearchGeneric,
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
              stream: _clientsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Erro: ${snapshot.error}'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final allClients = snapshot.data!;
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
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
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
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
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
                            if (client['address'] != null &&
                                client['address'] != '') // <--- EXIBE ENDEREÇO
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      client['address'],
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
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
                              _navigateToAddEdit(client: client);
                            } else if (value == 'delete') {
                              _deleteClient(client['id']);
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
