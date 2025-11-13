import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/env.dart';

class AuthController {
  final http.Client _client;
  AuthController({http.Client? client}) : _client = client ?? http.Client();

  Future<({bool ok, String message})> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}/auth/login'); // ← usa tu URL
    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode == 200) {
        // TODO: guarda token si el backend lo retorna
        return (ok: true, message: 'Inicio de sesión exitoso');
      }
      return (ok: false, message: 'Error ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (ok: false, message: 'No se pudo conectar al servidor: $e');
    }
  }

  Future<({bool ok, String message})> register({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}/auth/register'); // ← usa tu URL
    try {
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre, 'email': email, 'password': password}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        return (ok: true, message: 'Cuenta creada');
      }
      return (ok: false, message: 'Error ${res.statusCode}: ${res.body}');
    } catch (e) {
      return (ok: false, message: 'No se pudo conectar al servidor: $e');
    }
  }
}
