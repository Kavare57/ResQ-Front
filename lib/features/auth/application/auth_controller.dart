import '../../../core/api/auth_api.dart';
import '../../../core/api/solicitantes_api.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/jwt_helper.dart';

class AuthController {
  final _api = AuthApi();
  final _storage = StorageService();
  final _solicitantesApi = SolicitantesApi();

  /// Login contra el backend.
  ///
  /// FLUJO COMPLETO:
  /// 1. POST /auth/login → obtiene token (con id_usuario, tipoUsuario, sin id_persona)
  /// 2. POST /usuarios/obtener-id-persona → obtiene id_persona asociado
  /// 3. Guarda en storage: token, id_usuario, tipoUsuario, id_persona
  /// 4. Intenta sincronizar datos del solicitante
  ///
  /// El id_persona puede ser null si:
  /// - Usuario acaba de registrarse (no completó perfil aún)
  /// - Usuario es de otro tipo (operador, etc)
  Future<({bool ok, String message})> login({
    required String identifier,
    required String password,
    bool remember = false,
  }) async {
    try {
      final res = await _api.login(identifier, password);
      final token = res['access_token'] as String?;

      bool personaGuardada = false;

      if (token != null) {
        // Guardamos el token SIEMPRE para que funcione la sesión actual
        await _storage.saveToken(token);

        // Guardar el flag "remember" para saber si limpiar el token al cerrar
        await _storage.saveRemember(remember);

        // Guardar el nombre de usuario
        final nombreDeUsuario = res['nombreDeUsuario'] as String?;
        if (nombreDeUsuario != null) {
          await _storage.saveNombreUsuario(nombreDeUsuario);
        }

        // Extraer y guardar datos del JWT
        final idUsuario = JwtHelper.getIdUsuario(token);
        if (idUsuario != null) {
          await _storage.saveUserId(idUsuario);
        }

        final tipoUsuario = JwtHelper.getTipoUsuario(token);
        if (tipoUsuario != null) {
          await _storage.saveTipoUsuario(tipoUsuario);
        }

        // Intentar guardar id_persona directamente del payload del login (si viene)
        try {
          int? personaIdPayload;

          if (res['id_persona'] is int) {
            personaIdPayload = res['id_persona'] as int;
          } else if (res['persona_id'] is int) {
            personaIdPayload = res['persona_id'] as int;
          } else if (res['usuario'] is Map<String, dynamic>) {
            final usuario = res['usuario'] as Map<String, dynamic>;
            if (usuario['id_persona'] is int) {
              personaIdPayload = usuario['id_persona'] as int;
            } else if (usuario['persona_id'] is int) {
              personaIdPayload = usuario['persona_id'] as int;
            } else if (usuario['persona'] is Map<String, dynamic>) {
              final persona = usuario['persona'] as Map<String, dynamic>;
              if (persona['id'] is int) {
                personaIdPayload = persona['id'] as int;
              }
            }
          }

          if (personaIdPayload != null && personaIdPayload > 0) {
            await _storage.savePersonaId(personaIdPayload);
            personaGuardada = true;
          }
        } catch (e) {
        }

        // Obtener y guardar id_persona desde GET /usuarios/me
        if (!personaGuardada) {
          if (idUsuario != null) {
            try {
              final idPersona = await _api.obtenerIdPersonaActual(
                  token: token, idUsuario: idUsuario);
              if (idPersona != null) {
                await _storage.savePersonaId(idPersona);
                personaGuardada = true;
              }
            } catch (e) {
              // ignorar, se manejará más adelante si falta id_persona
            }
          }
        }

        // Intenta sincronizar el solicitante después del login
        try {
          await _solicitantesApi.sincronizarSolicitante();
        } catch (e) {
          // ignorar errores de sincronización en login
        }
      }

      return (ok: true, message: 'Inicio de sesión exitoso');
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Registro de nuevo usuario.
  ///
  /// FLUJO COMPLETO:
  /// 1. POST /usuarios → crea usuario (id_persona=null, tipoUsuario=null)
  /// 2. POST /auth/login → obtiene token (con id_usuario)
  /// 3. Token guardado TEMPORALMENTE para completar perfil
  /// 4. UI redirige a PerfilSolicitantePage(forzarCompletar=true)
  /// 5. Usuario completa datos de persona
  /// 6. POST /solicitantes → crea solicitante (obtiene id_persona)
  /// 7. PUT /usuarios/{id_usuario}/asignar-persona → vincula usuario con persona
  /// 8. Token temporal se limpia
  /// 9. Usuario vuelve a login formal donde obtiene id_persona en el JWT
  Future<({bool ok, String message})> register({
    required String nombre,
    required String email,
    required String password,
  }) async {
    try {
      // PASO 1: Crear usuario
      final usuarioCreado = await _api.register(nombre, email, password);
      final idUsuarioNuevo = usuarioCreado['id'] as int?;

      // PASO 2: Login automático después de registrar
      try {
        final resLogin = await _api.login(email, password);
        final token = resLogin['access_token'] as String?;
        if (token != null) {
          // Guardamos el token TEMPORALMENTE para que la sesión sea válida
          // mientras el usuario completa su perfil
          await _storage.saveToken(token);

          // Extraer y guardar ID usuario
          final idUsuario = JwtHelper.getIdUsuario(token);
          if (idUsuario != null) {
            await _storage.saveUserId(idUsuario);
          }

          // Para nuevo registro, siempre es SOLICITANTE
          await _storage.saveTipoUsuario('SOLICITANTE');

          // NO intentamos obtener id_persona aquí porque el usuario
          // aún no tiene persona creada. Eso se hará después de completar perfil.
        } else {
          throw Exception('Login automático falló: sin token');
        }
      } catch (e) {
        // Si el login automático falla, el registro ya se completó
        // El usuario deberá intentar login manual
        throw Exception(
            'Registro exitoso pero login automático falló. Por favor intenta iniciar sesión manualmente.');
      }

      return (ok: true, message: 'Cuenta creada correctamente');
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }

  /// Obtiene el tipoUsuario del token JWT.
  /// Primero intenta obtenerlo del JWT (cuando el backend lo agregue).
  /// Si no está en el JWT, retorna null (será manejado por el caller).
  Future<String?> getTipoUsuario() async {
    final token = await _storage.getToken();
    if (token == null) return null;

    return JwtHelper.getTipoUsuario(token);
  }

  /// Verifica si hay un token válido almacenado.
  /// Verifica que el token exista y no esté expirado.
  /// Si el token está expirado, lo limpia automáticamente.
  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    if (token == null) {
      return false;
    }

    // Verificar si el token está expirado
    if (JwtHelper.isTokenExpired(token)) {
      await _storage.clearToken();
      return false;
    }

    try {
      final verifyResponse = await _api.verify(token);
      final isValid = verifyResponse['valid'] as bool? ?? false;

      if (!isValid) {
        await _storage.clearToken();
        return false;
      }

      return true;
    } catch (e) {
      await _storage.clearToken();
      return false;
    }
  }

  /// Cierra sesión limpiando el token.
  Future<void> logout() async {
    await _storage.clearToken();
  }
}
