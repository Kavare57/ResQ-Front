import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/env.dart';

/// Servicio WebSocket para recibir mensajes del servidor para solicitantes
class SolicitanteWebSocketService {
  WebSocketChannel? _canal;
  int? _idSolicitante;

  /// Conecta al WebSocket del solicitante
  Future<void> conectar(int idSolicitante) async {
    try {
      _idSolicitante = idSolicitante;
      final wsUrl = '${Env.wsBaseUrl}/ws/solicitantes/$idSolicitante';

      print('[WS-SOLICITANTE] Conectando a: $wsUrl');

      _canal = WebSocketChannel.connect(Uri.parse(wsUrl));

      _canal?.stream.listen(
        (mensaje) {
          print('[WS-SOLICITANTE] Mensaje recibido: $mensaje');
          try {
            // Intentar parsear como JSON
            final data = jsonDecode(mensaje as String);
            print('[WS-SOLICITANTE] Mensaje JSON: $data');
          } catch (e) {
            // Si no es JSON, imprimir como texto plano
            print('[WS-SOLICITANTE] Mensaje texto: $mensaje');
          }
        },
        onError: (error) {
          print('[WS-SOLICITANTE] Error en WebSocket: $error');
        },
        onDone: () {
          print('[WS-SOLICITANTE] WebSocket cerrado');
        },
      );

      print('[WS-SOLICITANTE] Conectado exitosamente');
    } catch (e, stackTrace) {
      print('[WS-SOLICITANTE] Error conectando: $e');
      print('[WS-SOLICITANTE] Stack: $stackTrace');
      rethrow;
    }
  }

  /// Desconecta del WebSocket
  void desconectar() {
    try {
      _canal?.sink.close();
      _canal = null;
      if (_idSolicitante != null) {
        print('[WS-SOLICITANTE] Desconectado del solicitante: $_idSolicitante');
      }
      _idSolicitante = null;
    } catch (e) {
      print('[WS-SOLICITANTE] Error desconectando: $e');
    }
  }

  /// Verifica si está conectado
  bool get estaConectado => _canal != null;
}

