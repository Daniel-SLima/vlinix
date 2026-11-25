import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/screens/edit_profile_screen.dart';
import 'package:vlinix/screens/login_screen.dart';
import 'package:vlinix/services/user_service.dart';

class UserProfileMenu extends StatelessWidget {
  const UserProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    if (AppBackend.isDemo) {
      return const Tooltip(
        message: 'Alex Demo • Perfil fictício',
        child: CircleAvatar(
          backgroundColor: AppColors.accent,
          child: Icon(Icons.person_outline, color: AppColors.primary),
        ),
      );
    }

    // Ouve as mudanças do usuário em tempo real
    return ValueListenableBuilder<User?>(
      valueListenable: UserService.instance.userNotifier,
      builder: (context, currentUser, child) {
        final String? avatarUrl = currentUser?.userMetadata?['avatar_url'];
        final String fullName =
            currentUser?.userMetadata?['full_name'] ?? lang.labelDefaultUser;
        final String displayName = fullName.isNotEmpty
            ? fullName
            : lang.labelDefaultUser;

        return PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          // O Avatar que se atualiza sozinho
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                  : null,
            ),
          ),

          onSelected: (value) async {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            } else if (value == 'logout') {
              await AppBackend.client.auth.signOut();

              // --- FORÇA A LIMPEZA DA MEMÓRIA AQUI ---
              UserService.instance.refreshUser();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },

          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentUser?.email ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Divider(),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(lang.tooltipEditProfile),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(
                    Icons.exit_to_app,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    lang.menuLogout,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
