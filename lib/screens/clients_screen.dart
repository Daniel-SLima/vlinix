import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// OBRIGATÓRIO: Seu import definido como regra
import 'package:vlinix/l10n/app_localizations.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _clientsStream = Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .order('full_name');

  // --- CRUD (Criar e Editar) ---
  Future<void> _createOrUpdateClient({
    int? id,
    required String name,
    required String phone,
    required String email,
  }) async {
    final data = {'full_name': name, 'phone': phone, 'email': email};

    try {
      if (id == null) {
        // Criar Novo
        await Supabase.instance.client.from('clients').insert(data);
      } else {
        // Editar Existente
        await Supabase.instance.client
            .from('clients')
            .update(data)
            .eq('id', id);
      }
      if (mounted) {
        final lang = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              id == null ? lang.msgClientCreated : lang.msgClientUpdated,
            ),
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

  // --- DELETE ---
  Future<void> _deleteClient(int id) async {
    try {
      await Supabase.instance.client.from('clients').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.msgClientDeleted),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Removemos o "Erro: " manual e usamos só a tradução se preferir,
        // ou concatenamos se o texto do erro for técnico.
        // Aqui usaremos a mensagem amigável do dicionário.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.msgErrorDeleteClient),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- DIÁLOGO ---
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
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;

              // Executa a ação
              await _createOrUpdateClient(
                id: client?['id'],
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                email: emailCtrl.text,
              );

              // Só fecha o diálogo se a tela ainda estiver montada
              if (ctx.mounted) {
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _clientsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clients = snapshot.data!;
          if (clients.isEmpty) {
            return Center(child: Text(lang.msgNoClients));
          }

          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        onPressed: () => _showClientDialog(client: client),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(lang.dialogDeleteTitle),
                              content: Text(lang.dialogDeleteContent),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(lang.btnCancel),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _deleteClient(client['id']);
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
