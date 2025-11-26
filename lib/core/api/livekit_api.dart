import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/env.dart';
import '../services/storage_service.dart';

class LiveKitApi {
  final _baseUrl = Env.apiBaseUrl;
  final _storage = StorageService();

  /// Solicita una ambulancia y obtiene credenciales para la llamada de LiveKit
  Future<Map<String, dynamic>> solicitarAmbulancia({
    required int idSolicitante,
    required String nombre,
    required String apellido,
    required String fechaNacimiento,
    required String tipoDocumento,
    required String numeroDocumento,
    String? nombre2,
    String? apellido2,
    List<String>? padecimientos,
    required double latitud,
    required double longitud,
  }) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse('$_baseUrl/emergencias/solicitar-ambulancia');

    final body = {
      'solicitante': {
        'id': idSolicitante,
        'nombre': nombre,
        'apellido': apellido,
        'fechaNacimiento': fechaNacimiento,
        'tipoDocumento': tipoDocumento,
        'numeroDocumento': numeroDocumento,
        if (nombre2 != null) 'nombre2': nombre2,
        if (apellido2 != null) 'apellido2': apellido2,
        if (padecimientos != null) 'padecimientos': padecimientos,
      },
      'ubicacion': {
        'latitud': latitud,
        'longitud': longitud,
      },
    };

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Error al solicitar ambulancia: ${res.body}');
    }

    return jsonDecode(res.body);
  }
}
