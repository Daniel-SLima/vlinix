import 'package:flutter/foundation.dart'; // Para Uint8List (Web/Mobile)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:vlinix/l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  bool _isLoading = false;
  String? _avatarUrl; // URL da foto ANTIGA (no banco)

  // VARIAVEIS DE "STANDBY"
  // Só existem na memória enquanto a tela está aberta.
  XFile? _imageFile;
  Uint8List? _imageBytes;

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

  // 1. ESCOLHER FOTO (MODO STANDBY)
  // Aqui a gente NÃO mexe no banco. Só mostra o preview.
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes; // Foto carregada na memória (Standby)
        });
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
    }
  }

  // 2. CONFIRMAR (SALVAR E TROCAR)
  // Só agora mexemos no banco.
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    try {
      if (user == null) throw 'Usuário não logado';

      String? newAvatarUrl = _avatarUrl;

      // Se existe uma foto em STANDBY (_imageBytes), vamos subir
      if (_imageFile != null && _imageBytes != null) {
        final fileExt = _imageFile!.name.split('.').last;
        final newFileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final fullPath = '${user.id}/$newFileName';

        // A. UPLOAD DA NOVA (Segurança: Primeiro garantimos que a nova subiu)
        await supabase.storage
            .from('avatars')
            .uploadBinary(
              fullPath,
              _imageBytes!,
              fileOptions: FileOptions(
                upsert: true,
                contentType: 'image/$fileExt',
              ),
            );

        // B. PEGA O LINK DA NOVA
        final publicUrl = supabase.storage
            .from('avatars')
            .getPublicUrl(fullPath);
        newAvatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

        // C. FAXINA (Agora que a nova está salva, apagamos as velhas)
        // Isso roda em segundo plano para garantir que o banco fique limpo
        try {
          final list = await supabase.storage
              .from('avatars')
              .list(path: user.id);

          // Filtra para apagar tudo que NÃO SEJA a foto nova que acabamos de subir
          final itemsToDelete = list
              .where((file) => file.name != newFileName)
              .map((file) => '${user.id}/${file.name}')
              .toList();

          if (itemsToDelete.isNotEmpty) {
            await supabase.storage.from('avatars').remove(itemsToDelete);
            debugPrint(
              'Faxina: ${itemsToDelete.length} fotos antigas apagadas.',
            );
          }
        } catch (e) {
          debugPrint('Erro não crítico na limpeza: $e');
        }
      }

      // D. ATUALIZA O PERFIL DO USUÁRIO
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
      debugPrint("Erro detalhado: $e");
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
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: isLargeScreen ? Colors.grey[100] : Colors.white,

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
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
                            // LÓGICA DO STANDBY (PRIORIDADE):
                            // 1. Se tem _imageBytes (Standby), mostra ele.
                            // 2. Se não, mostra a URL do banco.
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!) as ImageProvider
                                : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? NetworkImage(_avatarUrl!)
                                      : null),
                            child:
                                (_imageBytes == null &&
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

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome de Exibição',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),

                  const SizedBox(height: 32),

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
