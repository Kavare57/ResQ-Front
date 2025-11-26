import 'package:flutter/services.dart';

class PermissionsService {
  static const platform = MethodChannel('com.example.resq_app/permissions');

  /// Solicita todos los permisos necesarios: micrófono, cámara y ubicación
  static Future<bool> requestAllPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestAllPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Solicita permisos específicos para llamadas (micrófono, cámara)
  static Future<bool> requestCallPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestCallPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Solicita permisos de ubicación (GPS)
  static Future<bool> requestLocationPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('requestLocationPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si el usuario tiene todos los permisos necesarios
  static Future<bool> hasAllPermissions() async {
    try {
      final result = await platform.invokeMethod<bool>('hasAllPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}

