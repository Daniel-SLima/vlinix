import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlinix/l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  bool _isLoading = false;
  String? _avatarUrl;
  File? _imageFile; // Para preview local antes de salvar

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _nameController.text = user.userMetadata?['full_name'] ?? '';
      setState(() {
        _avatarUrl = user.userMetadata?['avatar_url'];
      });
    }
  }

  // 1. Escolher Imagem da Galeria
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600, // Reduz tamanho para economizar dados
        maxHeight: 600,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
    }
  }

  // 2. Salvar Tudo (Upload + Update Profile)
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      if (user == null) throw 'Usuário não logado';

      String? newAvatarUrl = _avatarUrl; // Começa com a URL atual

      // A. Se o usuário escolheu uma imagem nova na galeria
      if (_imageFile != null) {
        // --- PASSO EXTRA: LIMPEZA (Evita acumular fotos velhas) ---
        try {
          // 1. Lista todos os arquivos na pasta deste usuário
          final list = await supabase.storage
              .from('avatars')
              .list(path: user.id);

          // 2. Se tiver algo lá, apaga tudo antes de subir a nova
          if (list.isNotEmpty) {
            final itemsToDelete = list
                .map((file) => '${user.id}/${file.name}')
                .toList();
            await supabase.storage.from('avatars').remove(itemsToDelete);
          }
        } catch (e) {
          // Se der erro ao limpar, apenas ignora e segue o baile (não trava o upload)
          debugPrint('Erro ao limpar fotos antigas: $e');
        }
        // -----------------------------------------------------------

        final fileExt = _imageFile!.path.split('.').last;
        final fileName =
            '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        // Faz o upload da nova
        await supabase.storage
            .from('avatars')
            .upload(
              fileName,
              _imageFile!,
              fileOptions: const FileOptions(upsert: true),
            );

        // Gera o link público
        newAvatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

        // Truque para "quebrar o cache" e forçar o app a baixar a foto nova imediatamente
        // Adicionamos um número aleatório no final da URL
        newAvatarUrl =
            '$newAvatarUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      // B. Atualiza os dados do usuário (Auth)
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
            'avatar_url': newAvatarUrl,
          },
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso! ✅')),
        );
        Navigator.pop(context, true); // Volta para a Home avisando que mudou
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Traduções (se houver) ou texto fixo para MVP
    // final lang = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // --- ÁREA DA FOTO ---
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : (_avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : null),
                      child: (_imageFile == null && _avatarUrl == null)
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Toque na foto para alterar',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 32),

              // --- CAMPO NOME ---
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome de Exibição',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),

              const SizedBox(height: 32),

              // --- BOTÃO SALVAR ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SALVAR ALTERAÇÕES',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
