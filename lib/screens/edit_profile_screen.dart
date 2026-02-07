import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/services/user_service.dart';

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
          _imageBytes = bytes;
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

      if (_imageFile != null && _imageBytes != null) {
        final fileExt = _imageFile!.name.split('.').last;
        final newFileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final fullPath = '${user.id}/$newFileName';

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

        final publicUrl = supabase.storage
            .from('avatars')
            .getPublicUrl(fullPath);
        newAvatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

        try {
          final list = await supabase.storage
              .from('avatars')
              .list(path: user.id);

          final itemsToDelete = list
              .where((file) => file.name != newFileName)
              .map((file) => '${user.id}/${file.name}')
              .toList();

          if (itemsToDelete.isNotEmpty) {
            await supabase.storage.from('avatars').remove(itemsToDelete);
          }
        } catch (e) {
          debugPrint('Erro não crítico na limpeza: $e');
        }
      }

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
            'avatar_url': newAvatarUrl,
          },
        ),
      );

      UserService.instance.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso! ✅'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Erro detalhado: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(lang.tooltipEditProfile), centerTitle: true),
      backgroundColor: AppColors.background,
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
                    Text(
                      lang.labelProfileInfo,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                              color: AppColors.accent,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade200,
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
                              color: AppColors.accent,
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
                  Text(
                    lang.msgTapPhoto,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),

                  const SizedBox(height: 32),

                  // Campo Nome
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: lang.labelDisplayName,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              lang.btnUpdate.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
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
