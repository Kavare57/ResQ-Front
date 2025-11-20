import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/env.dart';

class AuthApi {
  final baseUrl = Env.apiBaseUrl;
  static const Duration _timeout = Duration(seconds: 10);

  /// LOGIN: POST /auth/login
  /// body:
  /// {
  ///   "identificador": "email o nombredeusuario",
  ///   "contrasena": "string"
  /// }
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    print('[LOGIN] Iniciando...');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identificador': email,
          'contrasena': password,
        }),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout en login (10s)');
      });

      print('[LOGIN] Respuesta: ${res.statusCode}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
      print('[LOGIN] Error: $e');
      rethrow;
    }
  }

  /// REGISTRO: POST /usuarios
  /// body:
  /// {
  ///   "nombreDeUsuario": "string",
  ///   "email": "user@example.com",
  ///   "contrasenaHasheada": "string"
  /// }
  ///
  /// Respuesta 201: Objeto Usuario creado (JSON)
  Future<Map<String, dynamic>> register(String nombre, String email, String password) async {
    final url = Uri.parse('$baseUrl/usuarios');
    print('[REGISTER] 1/9 - Creando usuario...');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombreDeUsuario': nombre,
          'email': email,
          'contrasenaHasheada': password,
        }),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout en registro (10s)');
      });

      print('[REGISTER] 1/9 - Respuesta: ${res.statusCode}');
      if (res.statusCode == 201) {
        final usuarioCreado = jsonDecode(res.body) as Map<String, dynamic>;
        print('[REGISTER] 1/9 - Usuario creado con ID: ${usuarioCreado['id']}');
        return usuarioCreado;
      } else {
        print('[REGISTER] Error ${res.statusCode}: ${res.body}');
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
      print('[REGISTER] Error: $e');
      rethrow;
    }
  }

  /// VERIFICAR TOKEN: asumo POST /auth/verify con Authorization: Bearer
   Future<Map<String, dynamic>> verify(String token) async {
    final url = Uri.parse('$baseUrl/auth/verify');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token, // 👈 como lo pide FastAPI
      }),
    );

    // print('VERIFY -> ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception('Token inválido: ${res.body}');
    }
  }

  /// OBTENER ID_PERSONA: POST /usuarios/obtener-id-persona
  /// body:
  /// {
  ///   "email": "user@example.com",
  ///   "contrasena": "string"
  /// }
  /// Respuesta: { "id_persona": int | null }
  Future<int?> obtenerIdPersona(String email, String contrasena) async {
    final url = Uri.parse('$baseUrl/usuarios/obtener-id-persona');
    print('[OBTENER_ID_PERSONA] Buscando id_persona...');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'contrasena': contrasena,
        }),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout obteniendo id_persona (10s)');
      });

      print('[OBTENER_ID_PERSONA] Respuesta: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['id_persona'] as int?;
      } else {
        print('[OBTENER_ID_PERSONA] Error: ${res.statusCode} ${res.body}');
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
      print('[OBTENER_ID_PERSONA] Error: $e');
      // No relanzamos el error, retornamos null para que el flujo continúe
      return null;
    }
  }

}