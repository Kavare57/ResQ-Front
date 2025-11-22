import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/env.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/error_handler.dart';
import '../models/solicitud_seguimiento.dart';

class SolicitudWebSocketService {
  WebSocketChannel? _canal;
  final _storage = StorageService();
  
  // Callbacks para eventos
  Function(EstadoEmergencia)? onEstadoActualizado;
  Function(UbicacionAmbulancia)? onUbicacionAmbulancia;
  Function(bool)? onNearbyAmbulancia;
  Function(String)? onError;
  Function()? onConexionPerdida;

  Future<void> conectar(int idSolicitud) async {
    try {
      final token = await _storage.getToken();
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final baseUrl = Env.apiBaseUrl.replaceFirst('http', 'ws');
      final wsUrl = '$baseUrl/emergencias/seguimiento/$idSolicitud?token=$token';

      print('[WS-SOLICITUD] Conectando a: $wsUrl');

      _canal = WebSocketChannel.connect(Uri.parse(wsUrl));

      _canal?.stream.listen(
        _procesarMensaje,
        onError: (error) {
          print('[WS-SOLICITUD] Error en WebSocket: $error');
          ErrorHandler.logError('[WS-SOLICITUD-ERROR]', error, null);
          onError?.call('Error de conexión: $error');
          onConexionPerdida?.call();
        },
        onDone: () {
          print('[WS-SOLICITUD] WebSocket cerrado');
          onConexionPerdida?.call();
        },
      );

      print('[WS-SOLICITUD] Conectado exitosamente');
    } catch (e, stackTrace) {
      ErrorHandler.logError('[WS-SOLICITUD-CONEXION]', e, stackTrace);
      onError?.call(ErrorHandler.getErrorMessage(e));
      rethrow;
    }
  }

  void _procesarMensaje(dynamic mensaje) {
    try {
      final data = jsonDecode(mensaje as String) as Map<String, dynamic>;
      final tipo = data['tipo'] as String?;

      print('[WS-SOLICITUD] Mensaje recibido: tipo=$tipo');

      switch (tipo) {
        case 'estado_actualizado':
          final estado = EstadoEmergencia.fromJson(
            data['data'] as Map<String, dynamic>,
          );
          onEstadoActualizado?.call(estado);
          break;

        case 'ubicacion_ambulancia':
          final ubicacion = UbicacionAmbulancia.fromJson(
            data['data'] as Map<String, dynamic>,
          );
          onUbicacionAmbulancia?.call(ubicacion);
          
          if (ubicacion.estaCerca) {
            onNearbyAmbulancia?.call(true);
          }
          break;

        case 'ambulancia_cerca':
          onNearbyAmbulancia?.call(true);
          break;

        case 'error':
          final mensajeError = data['mensaje'] as String?;
          onError?.call(mensajeError ?? 'Error desconocido');
          break;

        default:
          print('[WS-SOLICITUD] Tipo de mensaje desconocido: $tipo');
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[WS-SOLICITUD-PROCESAR]', e, stackTrace);
      onError?.call('Error procesando mensaje: $e');
    }
  }

  void desconectar() {
    try {
      _canal?.sink.close();
      _canal = null;
      print('[WS-SOLICITUD] Desconectado');
    } catch (e) {
      print('[WS-SOLICITUD] Error desconectando: $e');
    }
  }

  bool get estaConectado => _canal != null;
}
