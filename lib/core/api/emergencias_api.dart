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
    required String nombrePaciente,
    required String descripcion,
  }) async {
    final url = Uri.parse('$baseUrl/solicitudes/solicitar-ambulancia');
    print('[EMERGENCIA] Solicitando ambulancia...');

    final ahora = DateTime.now().toUtc().toIso8601String();

    // Obtener el id_persona del storage
    final storage = StorageService();
    final idPersona = await storage.getPersonaId() ?? 0;
    print('[EMERGENCIA] Usando id_persona: $idPersona');
    
    // Obtener el token JWT para autenticación
    final token = await storage.getToken();
    if (token == null) {
      throw Exception('No hay token de autenticación disponible');
    }
    print('[EMERGENCIA] Token obtenido: ${token.substring(0, 20)}...');
    
    final body = {
      'solicitante': {
        'id': idPersona,  // Usar el id_persona obtenido del storage
        'nombre': nombrePaciente,
        'apellido': 'Paciente',  // Campo requerido - no puede estar vacío
        'fechaNacimiento': '2000-01-01',  // Fecha por defecto si no se proporciona
        'tipoDocumento': 'CEDULA',  // El backend espera CEDULA o TARJETA_DE_IDENTIDAD
        'numeroDocumento': '0000000000',  // Documento temporal
        'padecimientos': []
      },
      'ubicacion': {
        'latitud': lat,
        'longitud': lng,
        'fechaHora': ahora
      },
      'fechaHora': ahora
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

      print('[EMERGENCIA] Respuesta: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print('[EMERGENCIA] Error: ${res.body}');
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('[EMERGENCIA] Error: $e');
      rethrow;
    }
  }
}
