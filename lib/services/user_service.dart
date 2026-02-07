import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Esta classe é um "Singleton". Só existe UMA instância dela no app inteiro.
class UserService {
  // Construtor privado
  UserService._();
  // A única instância que todo mundo vai usar
  static final UserService instance = UserService._();

  // O "Notificador". Ele guarda o usuário atual e avisa quando muda.
  final ValueNotifier<User?> userNotifier = ValueNotifier(
    Supabase.instance.client.auth.currentUser,
  );

  // Função para forçar a atualização dos dados
  void refreshUser() {
    // Pegamos o usuário mais recente do Supabase Auth
    final updatedUser = Supabase.instance.client.auth.currentUser;
    // Atualizamos o notificador. Isso dispara o aviso para quem estiver ouvindo.
    userNotifier.value = updatedUser;
    debugPrint('UserService: Dados do usuário atualizados globalmente.');
  }
}
