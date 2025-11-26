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
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final res = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identificador': identifier,
          'contrasena': password,
        }),
      )
          .timeout(_timeout, onTimeout: () {
        throw Exception('Timeout en login (10s)');
      });

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        String message = 'Error: ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          if (body is Map<String, dynamic>) {
            message = body['mensaje'] as String? ??
                body['message'] as String? ??
                body['detail']?.toString() ??
                message;
          } else {
            message = body.toString();
          }
        } catch (_) {
          message = res.body.isNotEmpty ? res.body : message;
        }
        throw Exception(message);
      }
    } catch (e) {
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
  Future<Map<String, dynamic>> register(
      String nombre, String email, String password) async {
    final url = Uri.parse('$baseUrl/usuarios');

    try {
      final res = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombreDeUsuario': nombre,
          'email': email,
          'contrasenaHasheada': password,
        }),
      )
          .timeout(_timeout, onTimeout: () {
        throw Exception('Timeout en registro (10s)');
      });

      if (res.statusCode == 201) {
        final usuarioCreado = jsonDecode(res.body) as Map<String, dynamic>;
        return usuarioCreado;
      } else {
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
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
  ///   "identificador": "email o usuario",
  ///   "contrasena": "string"
  /// }
  /// Respuesta: { "id_persona": int | null }
  Future<int?> obtenerIdPersona(String identifier, String contrasena) async {
    final url = Uri.parse('$baseUrl/usuarios/obtener-id-persona');

    try {
      final res = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identificador': identifier,
          'contrasena': contrasena,
        }),
      )
          .timeout(_timeout, onTimeout: () {
        throw Exception('Timeout obteniendo id_persona (10s)');
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['id_persona'] as int?;
      } else {
        throw Exception('Error: ${res.statusCode}');
      }
    } catch (e) {
      // No relanzamos el error, retornamos null para que el flujo continúe
      return null;
    }
  }

  /// OBTENER ID_PERSONA DEL USUARIO ACTUAL: GET /usuarios/me?id_usuario=...
  /// Headers: Authorization: Bearer <token>
  /// Respuesta: { "id_persona": int | null }
  Future<int?> obtenerIdPersonaActual({
    required String token,
    required int idUsuario,
  }) async {
    final url = Uri.parse('$baseUrl/usuarios/me?id_usuario=$idUsuario');

    try {
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout obteniendo id_persona (10s)');
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final idPersona = data['id_persona'] as int?;
        return idPersona;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
