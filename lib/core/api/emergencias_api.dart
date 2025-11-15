import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/env.dart';

class EmergenciasApi {
  final baseUrl = Env.apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> solicitarAmbulancia({
    required double lat,
    required double lng,
    required String nombrePaciente,
    required String descripcion,
  }) async {
    final url = Uri.parse('$baseUrl/emergencias/solicitar-ambulancia');
    print('[EMERGENCIA] Solicitando ambulancia...');

    final ahora = DateTime.now().toUtc().toIso8601String();

    final body = {
      'solicitante': {
        'id': 0,
        'nombre': nombrePaciente,
        'apellido': '',
        'fechaNacimiento': ahora,
        'tipoDocumento': 'CC',
        'numeroDocumento': '0000000000',
        'nombreDeUsuario': nombrePaciente,
        'apellidos2': '',
        'apellidosAnteriores': [],
      },
      'ubicacion': {
        'latitud': lat,
        'longitud': lng,
        'fechaHoraUbicacion': ahora,
      },
      'fechaHora': ahora,
    };

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout (15s)');
      });

      print('[EMERGENCIA] Respuesta: ${res.statusCode}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
      print('[EMERGENCIA] Error: $e');
      rethrow;
    }
  }
}
