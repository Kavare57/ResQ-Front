import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/env.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/error_handler.dart';
import '../models/emergencia_historial.dart';

class HistorialEmergenciasApi {
  final baseUrl = Env.apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  Future<List<EmergenciaHistorial>> obtenerHistorial({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final storage = StorageService();
      final idPersona = await storage.getPersonaId() ?? 0;
      final token = await storage.getToken();

      if (token == null) {
        throw Exception('No hay token de autenticación disponible');
      }

      if (idPersona == 0) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      final url = Uri.parse(
        '$baseUrl/emergencias/por-solicitante/$idPersona?limit=$limit&offset=$offset',
      );

      print('[HISTORIAL] Obteniendo emergencias para id_persona: $idPersona');

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout, onTimeout: () {
        throw Exception('Timeout (15s)');
      });

      print('[HISTORIAL] Respuesta: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body) as List<dynamic>;
        final emergencias = jsonData
            .map((item) => EmergenciaHistorial.fromJson(item as Map<String, dynamic>))
            .toList();
        print('[HISTORIAL] Se obtuvieron ${emergencias.length} emergencias');
        return emergencias;
      } else if (response.statusCode == 404) {
        print('[HISTORIAL] No se encontraron emergencias (404)');
        return [];
      } else {
        print('[HISTORIAL] Error: ${response.body}');
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[HISTORIAL-API]', e, stackTrace);
      rethrow;
    }
  }
}
