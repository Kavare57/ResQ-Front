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
        print('[WS-SOLICITANTE] Ya está conectado al solicitante: $idSolicitante');
        return;
      }

      _idSolicitante = idSolicitante;
      final wsUrl = '${Env.wsBaseUrl}/ws/solicitantes/$idSolicitante';

      print('[WS-SOLICITANTE] Conectando a: $wsUrl');

      _canal = WebSocketChannel.connect(Uri.parse(wsUrl));

      _canal?.stream.listen(
        (mensaje) {
          print('[WS-SOLICITANTE] Mensaje recibido: $mensaje');
          try {
            // Intentar parsear como JSON
            final data = jsonDecode(mensaje as String) as Map<String, dynamic>;
            print('[WS-SOLICITANTE] Mensaje JSON: $data');
            // Llamar al callback si está configurado
            onMensajeRecibido?.call(data);
          } catch (e) {
            // Si no es JSON, imprimir como texto plano
            print('[WS-SOLICITANTE] Mensaje texto: $mensaje');
          }
        },
        onError: (error) {
          print('[WS-SOLICITANTE] Error en WebSocket: $error');
          onError?.call('Error en WebSocket: $error');
          onConexionPerdida?.call();
        },
        onDone: () {
          print('[WS-SOLICITANTE] WebSocket cerrado');
          onConexionPerdida?.call();
        },
      );

      print('[WS-SOLICITANTE] Conectado exitosamente');
    } catch (e, stackTrace) {
      print('[WS-SOLICITANTE] Error conectando: $e');
      print('[WS-SOLICITANTE] Stack: $stackTrace');
      onError?.call('Error conectando: $e');
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

  /// Envía un mensaje al servidor por WebSocket
  void enviarMensaje(Map<String, dynamic> mensaje) {
    try {
      if (_canal == null) {
        print('[WS-SOLICITANTE] No se puede enviar mensaje: WebSocket no está conectado');
        return;
      }
      
      final mensajeJson = jsonEncode(mensaje);
      _canal!.sink.add(mensajeJson);
      print('[WS-SOLICITANTE] Mensaje enviado: $mensajeJson');
    } catch (e) {
      print('[WS-SOLICITANTE] Error enviando mensaje: $e');
    }
  }
}

