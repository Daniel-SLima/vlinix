import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'add_service_screen.dart'; // IMPORTANTE: Importe a nova tela

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

  // A função de Delete continua aqui pois é uma ação rápida na lista
  Future<void> _delete(int id) async {
    try {
      await Supabase.instance.client.from('services').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Serviço em uso ou falha ao excluir!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Função para navegar para a tela de adicionar/editar
  void _navigateToAddEdit({Map<String, dynamic>? service}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddServiceScreen(serviceToEdit: service),
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

      // Botão Flutuante leva para a tela nova (Modo Criação)
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEdit(),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder(
        stream: _stream,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
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
                      // Botão Editar leva para a tela nova (Modo Edição)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _navigateToAddEdit(service: item),
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
