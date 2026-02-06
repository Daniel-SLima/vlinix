import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:vlinix/l10n/app_localizations.dart'; // Descomente quando tiver traduções

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
  File? _imageFile;

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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80, // Otimização extra
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

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      if (user == null) throw 'Usuário não logado';

      String? newAvatarUrl = _avatarUrl;

      // --- 1. UPLOAD DA NOVA IMAGEM (Prioridade) ---
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        // Nome único para a nova foto
        final newFileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final fullPath = '${user.id}/$newFileName';

        // Faz o upload
        await supabase.storage
            .from('avatars')
            .upload(
              fullPath,
              _imageFile!,
              fileOptions: const FileOptions(upsert: true),
            );

        // Gera o link público
        final publicUrl = supabase.storage
            .from('avatars')
            .getPublicUrl(fullPath);
        // Adiciona timestamp para forçar atualização de cache no app
        newAvatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

        // --- 2. LIMPEZA SEGURA (Apaga as velhas DEPOIS de subir a nova) ---
        try {
          final list = await supabase.storage
              .from('avatars')
              .list(path: user.id);

          if (list.isNotEmpty) {
            // Filtra para apagar tudo que NÃO SEJA a foto que acabamos de subir
            final itemsToDelete = list
                .where((file) => file.name != newFileName)
                .map((file) => '${user.id}/${file.name}')
                .toList();

            if (itemsToDelete.isNotEmpty) {
              await supabase.storage.from('avatars').remove(itemsToDelete);
            }
          }
        } catch (e) {
          debugPrint('Erro não crítico na limpeza: $e');
        }
      }

      // --- 3. ATUALIZA O PERFIL ---
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
          const SnackBar(
            content: Text('Perfil atualizado com sucesso! ✅'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
    // Detecta tela grande (PC/Tablet) para aplicar o visual "Card"
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // Fundo responsivo (Cinza no PC, Branco no Mobile)
      backgroundColor: isLargeScreen ? Colors.grey[100] : Colors.white,

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              // Largura fixa e estilo de Card no PC
              width: isLargeScreen ? 500 : double.infinity,
              padding: isLargeScreen
                  ? const EdgeInsets.all(40)
                  : EdgeInsets.zero,
              decoration: isLargeScreen
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- TÍTULO (Só no PC) ---
                  if (isLargeScreen) ...[
                    const Text(
                      "Suas Informações",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // --- ÁREA DA FOTO ---
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1E88E5),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!) as ImageProvider
                                : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? NetworkImage(_avatarUrl!)
                                      : null),
                            child:
                                (_imageFile == null &&
                                    (_avatarUrl == null || _avatarUrl!.isEmpty))
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
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
                  const SizedBox(height: 12),
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
                        elevation: isLargeScreen ? 2 : 1,
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
        ),
      ),
    );
  }
}
