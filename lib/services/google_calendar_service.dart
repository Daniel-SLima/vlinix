import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  // Singleton
  GoogleCalendarService._();
  static final instance = GoogleCalendarService._();

  // Cliente HTTP autenticado (Classe interna para injetar o token)
  http.Client _getAuthClient(String token) {
    return _AuthenticatedClient(token, http.Client());
  }

  // Recupera o token do Supabase
  String? _getProviderToken() {
    final session = AppBackend.client.auth.currentSession;
    return session?.providerToken;
  }

  // --- 1. DELETAR EVENTO ---
  Future<void> deleteEvent(String eventId) async {
    final token = _getProviderToken();
    if (token == null) {
      debugPrint(
        '⚠️ Erro: Usuário não tem token do Google (faça login novamente).',
      );
      return;
    }

    try {
      final authClient = _getAuthClient(token);
      final calendarApi = calendar.CalendarApi(authClient);

      await calendarApi.events.delete('primary', eventId);
      debugPrint('📅 Evento Google $eventId deletado.');
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar do Google: $e');
    }
  }

  // --- 2. CRIAR/INSERIR EVENTO ---
  Future<String?> insertEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final token = _getProviderToken();
    if (token == null) {
      debugPrint('⚠️ Erro: Token do Google não encontrado.');
      return null;
    }

    try {
      final authClient = _getAuthClient(token);
      final calendarApi = calendar.CalendarApi(authClient);

      final event = calendar.Event(
        summary: title,
        description: description,
        start: calendar.EventDateTime(
          dateTime: startTime,
          timeZone: 'America/Sao_Paulo', // Ajuste para seu fuso se necessário
        ),
        end: calendar.EventDateTime(
          dateTime: endTime,
          timeZone: 'America/Sao_Paulo',
        ),
      );

      final insertedEvent = await calendarApi.events.insert(event, 'primary');
      debugPrint('📅 Evento Google criado: ${insertedEvent.id}');
      return insertedEvent.id;
    } catch (e) {
      debugPrint('⚠️ Erro ao criar evento no Google: $e');
      return null;
    }
  }
}

// --- CLASSE AUXILIAR PARA INJETAR O TOKEN ---
class _AuthenticatedClient extends http.BaseClient {
  final String _token;
  final http.Client _inner;

  _AuthenticatedClient(this._token, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}
