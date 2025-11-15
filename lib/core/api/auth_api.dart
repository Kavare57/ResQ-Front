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
  ///   "nombredeusuario": "string",
  ///   "email": "user@example.com",
  ///   "contrasenaHasheada": "string"
  /// }
  ///
  /// Respuesta 201: string plano (mensaje).
  Future<String> register(String nombre, String email, String password) async {
    final url = Uri.parse('$baseUrl/usuarios');
    print('[REGISTER] Iniciando...');

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

      print('[REGISTER] Respuesta: ${res.statusCode}');
      if (res.statusCode == 201) {
        return res.body;
      } else {
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

}