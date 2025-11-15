import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/env.dart';
import '../services/storage_service.dart';

class SolicitantesApi {
  final _baseUrl = Env.apiBaseUrl;
  final _storage = StorageService();
  static const Duration _timeout = Duration(seconds: 10);

  /// Intenta encontrar y guardar el ID del solicitante después del login
  /// Busca por número de documento usando el nuevo endpoint
  Future<void> sincronizarSolicitante() async {
    try {
      // Para sincronizar después del login, necesitamos el número de documento
      // Como no lo tenemos en el JWT, intentamos obtener el primer solicitante
      // o podríamos hacer una búsqueda por email (pero ese método no existe aún)
      
      // Por ahora, simplemente usaremos el ID del storage si está disponible
      final idGuardado = await _storage.getUserId();
      if (idGuardado != null) {
        print('DEBUG: Ya hay un ID guardado en storage: $idGuardado');
        return;
      }

      print('DEBUG: Sincronización completada sin errores');
    } catch (e) {
      print('DEBUG: Error sincronizando solicitante: $e');
    }
  }

  /// Busca un solicitante por su número de documento
  Future<Map<String, dynamic>> obtenerSolicitantePorDocumento(
    String numeroDocumento,
  ) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse(
      '$_baseUrl/solicitantes/buscar/documento?numero_documento=$numeroDocumento',
    );

    final res = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Error al obtener el solicitante: ${res.body}');
    }

    final perfil = jsonDecode(res.body);
    
    // Guardar el ID para futuras llamadas
    final id = perfil['id'];
    if (id != null) {
      await _storage.saveUserId(id);
      print('DEBUG: Solicitante encontrado por documento, ID guardado: $id');
    }

    return perfil;
  }

  /// Obtiene el perfil del solicitante actual
  Future<Map<String, dynamic>> obtenerPerfilActual() async {
    print('[SOLICITANTE] Obteniendo perfil actual...');
    
    int? idUsuario = await _storage.getUserId();
    
    if (idUsuario == null) {
      throw Exception('No sincronizado');
    }

    return obtenerPerfil(idUsuario);
  }

  /// Obtiene el perfil de un solicitante por ID
  Future<Map<String, dynamic>> obtenerPerfil(int idSolicitante) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse('$_baseUrl/solicitantes/$idSolicitante');
    print('[SOLICITANTE] Obteniendo perfil $idSolicitante...');

    try {
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout (10s)');
      });

      print('[SOLICITANTE] Perfil OK: ${res.statusCode}');
      if (res.statusCode != 200) {
        throw Exception('Error: ${res.statusCode}');
      }

      return jsonDecode(res.body);
    } catch (e) {
      print('[SOLICITANTE] Error: $e');
      rethrow;
    }
  }

  /// Crea o actualiza el perfil del solicitante del usuario actual.
  ///
  /// Guarda el ID del solicitante en storage para futuras llamadas.
  Future<void> guardarPerfil({
    required String nombre,
    String? nombre2,
    required String apellido,
    String? apellido2,
    required String tipoDocumento,
    required String numeroDocumento,
    required DateTime fechaNacimiento,
  }) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse('$_baseUrl/solicitantes');

    final body = {
      'nombre': nombre,
      'nombre2': nombre2,
      'apellido': apellido,
      'apellido2': apellido2,
      'tipoDocumento': tipoDocumento,
      'numeroDocumento': numeroDocumento,
      'fechaNacimiento': '${fechaNacimiento.year}-${fechaNacimiento.month.toString().padLeft(2, '0')}-${fechaNacimiento.day.toString().padLeft(2, '0')}',
    };

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    print('GUARDAR PERFIL -> ${res.statusCode} ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Error al guardar el perfil: ${res.body}');
    }

    // Guardar el ID del solicitante si está en la respuesta
    try {
      final respuesta = jsonDecode(res.body);
      final id = respuesta['id'];
      if (id != null) {
        await _storage.saveUserId(id);
        print('DEBUG: Solicitante ID guardado en storage: $id');
      }
    } catch (e) {
      print('DEBUG: No se pudo extraer el ID de la respuesta: $e');
    }
  }
}
