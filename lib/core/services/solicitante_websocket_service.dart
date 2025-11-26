import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/env.dart';

/// Servicio WebSocket para recibir mensajes del servidor para solicitantes
class SolicitanteWebSocketService {
  WebSocketChannel? _canal;
  int? _idSolicitante;
  
  // Callbacks para eventos
  Function(Map<String, dynamic>)? onMensajeRecibido;
  Function(String)? onError;
  Function()? onConexionPerdida;

  /// Conecta al WebSocket del solicitante
  Future<void> conectar(int idSolicitante) async {
    try {
      // Si ya está conectado al mismo solicitante, no reconectar
      if (_canal != null && _idSolicitante == idSolicitante) {
        return;
      }

      _idSolicitante = idSolicitante;
      final wsUrl = '${Env.wsBaseUrl}/ws/solicitantes/$idSolicitante';
      _canal = WebSocketChannel.connect(Uri.parse(wsUrl));

      _canal?.stream.listen(
        (mensaje) {
          try {
            // Intentar parsear como JSON
            final data = jsonDecode(mensaje as String) as Map<String, dynamic>;
            // Llamar al callback si está configurado
            onMensajeRecibido?.call(data);
          } catch (e) {}
        },
        onError: (error) {
          onError?.call('Error en WebSocket: $error');
          onConexionPerdida?.call();
        },
        onDone: () {
          onConexionPerdida?.call();
        },
      );
    } catch (e, stackTrace) {
      onError?.call('Error conectando: $e');
      rethrow;
    }
  }

  /// Desconecta del WebSocket
  void desconectar() {
    try {
      _canal?.sink.close();
      _canal = null;
      _idSolicitante = null;
    } catch (e) {
    }
  }

  /// Verifica si está conectado
  bool get estaConectado => _canal != null;

  /// Envía un mensaje al servidor por WebSocket
  void enviarMensaje(Map<String, dynamic> mensaje) {
    try {
      if (_canal == null) {
        return;
      }
      
      final mensajeJson = jsonEncode(mensaje);
      _canal!.sink.add(mensajeJson);
    } catch (e) {
    }
  }
}

