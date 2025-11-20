import 'dart:convert';
import 'package:flutter/foundation.dart';

class JwtHelper {
  /// Decodifica un JWT y extrae el payload (sin verificar firma)
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      // Dividir el token en sus 3 partes (header.payload.signature)
      final parts = token.split('.');
      if (parts.length != 3) {
        if (kDebugMode) print('[JWT] Token inválido: debe tener 3 partes');
        return null;
      }

      // Decodificar el payload (segunda parte)
      String payload = parts[1];

      // Agregar padding si es necesario
      payload = utf8.decode(base64Url.decode(base64Url.normalize(payload)));

      // Parsear el JSON
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      if (kDebugMode) print('[JWT] Error decodificando token: $e');
      return null;
    }
  }

  /// Extrae el tipoUsuario del JWT
  static String? getTipoUsuario(String token) {
    final payload = decodeToken(token);
    return payload?['tipoUsuario'] as String?;
  }

  /// Extrae el id_usuario del JWT
  /// El backend lo envía como "id" en el payload
  static int? getIdUsuario(String token) {
    final payload = decodeToken(token);
    // Intentar primero con "id" (como lo envía el backend)
    var id = payload?['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    
    // Fallback a "id_usuario" por compatibilidad
    id = payload?['id_usuario'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    
    return null;
  }

  /// Extrae el email del JWT
  static String? getEmail(String token) {
    final payload = decodeToken(token);
    return payload?['email'] as String?;
  }

  /// Extrae el nombreDeUsuario del JWT
  static String? getNombreDeUsuario(String token) {
    final payload = decodeToken(token);
    return payload?['nombreDeUsuario'] as String?;
  }

  /// Verifica si el token está expirado
  static bool isTokenExpired(String token) {
    try {
      final payload = decodeToken(token);
      if (payload == null) return true;

      final exp = payload['exp'];
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiryDate.isBefore(DateTime.now());
    } catch (e) {
      if (kDebugMode) print('[JWT] Error verificando expiración: $e');
      return true;
    }
  }
}
