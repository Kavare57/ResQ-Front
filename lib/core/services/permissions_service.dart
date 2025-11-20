import 'package:flutter/services.dart';

class PermissionsService {
  static const platform = MethodChannel('com.example.resq_app/permissions');

  /// Solicita todos los permisos necesarios: micrófono, cámara y ubicación
  static Future<bool> requestAllPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestAllPermissions');
      print('[PERMISSIONS] Resultado de solicitud: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      print('[PERMISSIONS] Error solicitando permisos: $e');
      return false;
    }
  }

  /// Solicita permisos específicos para llamadas (micrófono, cámara)
  static Future<bool> requestCallPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestCallPermissions');
      print('[PERMISSIONS] Permisos de llamada solicitados: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      print('[PERMISSIONS] Error solicitando permisos de llamada: $e');
      return false;
    }
  }

  /// Solicita permisos de ubicación (GPS)
  static Future<bool> requestLocationPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestLocationPermissions');
      print('[PERMISSIONS] Permisos de ubicación solicitados: ${result ?? false}');
      return result ?? false;
    } catch (e) {
      print('[PERMISSIONS] Error solicitando permisos de ubicación: $e');
      return false;
    }
  }

  /// Verifica si el usuario tiene todos los permisos necesarios
  static Future<bool> hasAllPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('hasAllPermissions');
      return result ?? false;
    } catch (e) {
      print('[PERMISSIONS] Error verificando permisos: $e');
      return false;
    }
  }
}

