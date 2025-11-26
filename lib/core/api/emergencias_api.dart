import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/env.dart';
import '../services/storage_service.dart';

class EmergenciasApi {
  final baseUrl = Env.apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> solicitarAmbulancia({
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse('$baseUrl/solicitudes/solicitar-ambulancia');

    // Obtener el id_persona del storage (este es el id_solicitante)
    final storage = StorageService();
    final idSolicitante = await storage.getPersonaId();
    if (idSolicitante == null || idSolicitante == 0) {
      throw Exception('No se encontró el ID del solicitante. Por favor, completa tu perfil.');
    }
    
    // Obtener el token JWT para autenticación
    final token = await storage.getToken();
    if (token == null) {
      throw Exception('No hay token de autenticación disponible');
    }
    
    final body = {
      'id_solicitante': idSolicitante,
      'ubicacion': {
        'latitud': lat,
        'longitud': lng,
      },
    };

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout (15s)');
      });

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
