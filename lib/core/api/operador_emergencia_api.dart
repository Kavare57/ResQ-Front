import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/env.dart';
import '../services/storage_service.dart';

class OperadorEmergenciaApi {
  final baseUrl = Env.apiBaseUrl;
  final _storage = StorageService();
  static const Duration _timeout = Duration(seconds: 15);

  /// GET /operadores-emergencia/me
  /// Obtiene el perfil actual del operador de emergencias autenticado
  Future<Map<String, dynamic>> obtenerPerfilActual() async {
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('No hay token disponible');

      final url = Uri.parse('$baseUrl/operadores-emergencia/me');
      print('[OPERADOR_EMERGENCIA] Obteniendo perfil actual...');

      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout obteniendo perfil (15s)');
      });

      print('[OPERADOR_EMERGENCIA] Respuesta: ${res.statusCode}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
      print('[OPERADOR_EMERGENCIA] Error obteniendo perfil: $e');
      rethrow;
    }
  }

  /// POST /operadores-emergencia
  /// Crea un nuevo perfil de operador de emergencias
  /// Retorna el operador creado con su ID
  Future<Map<String, dynamic>> crearPerfil({
    required String nombre,
    required String? nombre2,
    required String apellido,
    required String? apellido2,
    required String tipoDocumento,
    required String numeroDocumento,
    required DateTime fechaNacimiento,
    required String turno,
    required bool disponibilidad,
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('No hay token disponible');

      final url = Uri.parse('$baseUrl/operadores-emergencia');
      print('[OPERADOR_EMERGENCIA] Creando perfil...');

      final body = {
        'nombre': nombre,
        if (nombre2 != null && nombre2.isNotEmpty) 'nombre2': nombre2,
        'apellido': apellido,
        if (apellido2 != null && apellido2.isNotEmpty) 'apellido2': apellido2,
        'tipoDocumento': tipoDocumento,
        'numeroDocumento': numeroDocumento,
        'fechaNacimiento': fechaNacimiento.toIso8601String(),
        'turno': turno,
        'disponibilidad': disponibilidad,
      };

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout creando perfil (15s)');
      });

      print('[OPERADOR_EMERGENCIA] Respuesta: ${res.statusCode}');
      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('[OPERADOR_EMERGENCIA] Error creando perfil: $e');
      rethrow;
    }
  }

  /// PUT /operadores-emergencia/me
  /// Actualiza el perfil del operador de emergencias
  Future<Map<String, dynamic>> guardarPerfil({
    required String nombre,
    required String? nombre2,
    required String apellido,
    required String? apellido2,
    required String tipoDocumento,
    required String numeroDocumento,
    required DateTime fechaNacimiento,
    required String turno,
    required bool disponibilidad,
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('No hay token disponible');

      final url = Uri.parse('$baseUrl/operadores-emergencia/me');
      print('[OPERADOR_EMERGENCIA] Guardando perfil...');

      final body = {
        'nombre': nombre,
        if (nombre2 != null && nombre2.isNotEmpty) 'nombre2': nombre2,
        'apellido': apellido,
        if (apellido2 != null && apellido2.isNotEmpty) 'apellido2': apellido2,
        'tipoDocumento': tipoDocumento,
        'numeroDocumento': numeroDocumento,
        'fechaNacimiento': fechaNacimiento.toIso8601String(),
        'turno': turno,
        'disponibilidad': disponibilidad,
      };

      final res = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout guardando perfil (15s)');
      });

      print('[OPERADOR_EMERGENCIA] Respuesta: ${res.statusCode}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('[OPERADOR_EMERGENCIA] Error guardando perfil: $e');
      rethrow;
    }
  }

  /// Sincroniza el perfil del operador desde el backend
  /// Se ejecuta después del login para traer datos actuales
  Future<void> sincronizarOperador() async {
    try {
      await obtenerPerfilActual();
      print('[OPERADOR_EMERGENCIA] Sincronización exitosa');
    } catch (e) {
      print('[OPERADOR_EMERGENCIA] Error en sincronización: $e');
      rethrow;
    }
  }
}
