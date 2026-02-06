import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/screens/edit_profile_screen.dart';
import 'package:vlinix/screens/login_screen.dart';
import 'package:vlinix/l10n/app_localizations.dart'; // <--- 1. Import adicionado

class UserProfileMenu extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const UserProfileMenu({super.key, this.onProfileUpdated});

  @override
  State<UserProfileMenu> createState() => _UserProfileMenuState();
}

class _UserProfileMenuState extends State<UserProfileMenu> {
  User? _user;
  String _displayName = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _user = user;
      _displayName = user?.userMetadata?['full_name'] ?? 'Usuário';
      _photoUrl = user?.userMetadata?['avatar_url'];
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!; // <--- 2. Pega as traduções

    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
          child: _photoUrl == null
              ? const Icon(Icons.person, color: AppColors.primary, size: 20)
              : null,
        ),
      ),
      onSelected: (value) async {
        if (value == 'edit') {
          final bool? updated = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
          );

          if (updated == true) {
            _loadUserData();
            widget.onProfileUpdated?.call();
          }
        } else if (value == 'logout') {
          _signOut();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _user?.email ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(lang.tooltipEditProfile), // <--- 3. Traduzido
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.exit_to_app, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Text(
                lang.menuLogout,
                style: const TextStyle(color: AppColors.error),
              ), // <--- 3. Traduzido
            ],
          ),
        ),
      ],
    );
  }
}
