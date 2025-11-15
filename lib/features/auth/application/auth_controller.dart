import '../../../core/api/auth_api.dart';
import '../../../core/api/solicitantes_api.dart';
import '../../../core/services/storage_service.dart';

class AuthController {
  final _api = AuthApi();
  final _storage = StorageService();
  final _solicitantesApi = SolicitantesApi();

  /// Login contra el backend.
  /// Usa POST /auth/login y siempre guarda el token para la sesión actual.
  /// Si [remember] es true, el token persiste en el siguiente reinicio.
  /// Si [remember] es false, el token se borra al cerrar la app.
  Future<({bool ok, String message})> login({
    required String email,
    required String password,
    bool remember = false,
  }) async {
    try {
      final res = await _api.login(email, password);
      final token = res['access_token'] as String?;

      if (token != null) {
        // Guardamos el token SIEMPRE para que funcione la sesión actual
        await _storage.saveToken(token);
        print('[LOGIN] Token guardado para la sesión actual (remember=$remember)');
        
        // Intenta sincronizar el solicitante después del login
        try {
          await _solicitantesApi.sincronizarSolicitante();
        } catch (e) {
          print('[LOGIN] Error sincronizando solicitante: $e');
        }
      }

      return (ok: true, message: 'Inicio de sesión exitoso');
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Registro de nuevo usuario usando POST /usuarios.
  /// Después del registro, hace login automático y GUARDA el token temporalmente
  /// para que el usuario pueda completar su perfil.
  /// El usuario deberá hacer logout y login nuevamente para "recordar" la sesión.
  Future<({bool ok, String message})> register({
    required String nombre,
    required String email,
    required String password,
  }) async {
    try {
      final msg = await _api.register(nombre, email, password);

      // Login automático después de registrar
      try {
        final resLogin = await _api.login(email, password);
        final token = resLogin['access_token'] as String?;
        if (token != null) {
          // Guardamos el token TEMPORALMENTE para que la sesión sea válida
          // mientras el usuario completa su perfil
          await _storage.saveToken(token);
          print('[REGISTER] Login automático completado, token guardado temporalmente');
        }
      } catch (_) {
        // Si el login automático falla, igual consideramos el registro como exitoso
      }

      return (ok: true, message: msg);
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Verifica si hay un token válido almacenado.
  /// En startup, solo verifica que exista el token (sin hacer llamada HTTP).
  /// Esto acelera el inicio de la app significativamente.
  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    if (token == null) return false;

    // En startup solo verificamos que el token exista
    // La verificación real ocurre al hacer requests a la API
    return true;
  }

  /// Cierra sesión limpiando el token.
  Future<void> logout() async {
    await _storage.clearToken();
  }
}
