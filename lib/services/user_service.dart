import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Esta classe é um "Singleton". Só existe UMA instância dela no app inteiro.
class UserService {
  // Construtor privado: Agora ele escuta as mudanças de Auth automaticamente!
  UserService._() {
    AppBackend.client.auth.onAuthStateChange.listen((data) {
      refreshUser();
    });
  }

  // A única instância que todo mundo vai usar
  static final UserService instance = UserService._();

  // O "Notificador". Ele guarda o usuário atual e avisa quando muda.
  final ValueNotifier<User?> userNotifier = ValueNotifier(
    AppBackend.client.auth.currentUser,
  );

  // Função para forçar a atualização dos dados
  void refreshUser() {
    // Pegamos o usuário mais recente do Supabase Auth
    final updatedUser = AppBackend.client.auth.currentUser;
    // Atualizamos o notificador. Isso dispara o aviso para quem estiver ouvindo.
    userNotifier.value = updatedUser;
    debugPrint(
      'UserService: Dados atualizados. Usuário atual: ${updatedUser?.email}',
    );
  }
}
