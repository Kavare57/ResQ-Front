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
      print('[LOGIN] Respuesta completa: $res');
      final token = res['access_token'] as String?;

      bool personaGuardada = false;

      if (token != null) {
        // Guardamos el token SIEMPRE para que funcione la sesión actual
        await _storage.saveToken(token);
        print(
            '[LOGIN] 1/4 - Token guardado para la sesión actual (remember=$remember)');

        // Guardar el flag "remember" para saber si limpiar el token al cerrar
        await _storage.saveRemember(remember);
        print('[LOGIN] 1/4 - Flag "recuerdame" guardado: $remember');

        // Guardar el nombre de usuario
        final nombreDeUsuario = res['nombreDeUsuario'] as String?;
        if (nombreDeUsuario != null) {
          await _storage.saveNombreUsuario(nombreDeUsuario);
          print('[LOGIN] 1/4 - Nombre usuario guardado: $nombreDeUsuario');
        }

        // Extraer y guardar datos del JWT
        final idUsuario = JwtHelper.getIdUsuario(token);
        if (idUsuario != null) {
          await _storage.saveUserId(idUsuario);
          print('[LOGIN] 1/4 - ID usuario guardado: $idUsuario');
        }

        final tipoUsuario = JwtHelper.getTipoUsuario(token);
        if (tipoUsuario != null) {
          await _storage.saveTipoUsuario(tipoUsuario);
          print('[LOGIN] 1/4 - Tipo usuario guardado: $tipoUsuario');
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
            print(
                '[LOGIN] 1/4 - ID persona guardado desde payload: $personaIdPayload');
          }
        } catch (e) {
          print('[LOGIN] 1/4 - Error leyendo id_persona del payload: $e');
        }

        // Obtener y guardar id_persona desde GET /usuarios/me
        if (!personaGuardada) {
          print('[LOGIN] 2/4 - Obteniendo id_persona desde /usuarios/me...');
          try {
            final idPersona = await _api.obtenerIdPersonaActual(token);
            if (idPersona != null) {
              await _storage.savePersonaId(idPersona);
              print('[LOGIN] 2/4 - ID persona guardado: $idPersona');
              personaGuardada = true;
            } else {
              print(
                  '[LOGIN] 2/4 - Usuario sin persona asignada (perfil incompleto o rol diferente)');
            }
          } catch (e) {
            print('[LOGIN] 2/4 - Error obteniendo id_persona: $e');
          }
        } else {
          print(
              '[LOGIN] 2/4 - ID persona ya guardado desde payload, se omite /usuarios/me');
        }

        // Intenta sincronizar el solicitante después del login
        print('[LOGIN] 3/4 - Sincronizando solicitante...');
        try {
          await _solicitantesApi.sincronizarSolicitante();
          print('[LOGIN] 3/4 - Solicitante sincronizado');
        } catch (e) {
          print('[LOGIN] 3/4 - Error sincronizando solicitante: $e');
        }
      }

      print('[LOGIN] 4/4 - Completado exitosamente');
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
      print(
          '[REGISTER] 1/9 - Usuario creado: ${usuarioCreado['nombreDeUsuario']} (ID: $idUsuarioNuevo)');

      // PASO 2: Login automático después de registrar
      print('[REGISTER] 2/9 - Iniciando login automático...');
      try {
        final resLogin = await _api.login(email, password);
        final token = resLogin['access_token'] as String?;
        if (token != null) {
          // Guardamos el token TEMPORALMENTE para que la sesión sea válida
          // mientras el usuario completa su perfil
          await _storage.saveToken(token);
          print('[REGISTER] 3/9 - Token guardado temporalmente');

          // Extraer y guardar ID usuario
          final idUsuario = JwtHelper.getIdUsuario(token);
          if (idUsuario != null) {
            await _storage.saveUserId(idUsuario);
            print('[REGISTER] 4/9 - ID usuario guardado: $idUsuario');
          }

          // Para nuevo registro, siempre es SOLICITANTE
          await _storage.saveTipoUsuario('SOLICITANTE');
          print('[REGISTER] 5/9 - Tipo usuario establecido: SOLICITANTE');

          // NO intentamos obtener id_persona aquí porque el usuario
          // aún no tiene persona creada. Eso se hará después de completar perfil.
          print(
              '[REGISTER] 6/9 - Usuario sin persona aún (será completada en perfil)');
        } else {
          print('[REGISTER] ERROR: No se obtuvo token en login automático');
          throw Exception('Login automático falló: sin token');
        }
      } catch (e) {
        print('[REGISTER] ERROR en login automático: $e');
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
      print('[AUTH] No hay token almacenado');
      return false;
    }

    // Verificar si el token está expirado
    if (JwtHelper.isTokenExpired(token)) {
      print('[AUTH] Token expirado - limpiando sesión');
      await _storage.clearToken();
      return false;
    }

    print('[AUTH] Token válido encontrado');
    try {
      final verifyResponse = await _api.verify(token);
      final isValid = verifyResponse['valid'] as bool? ?? false;

      if (!isValid) {
        print('[AUTH] Token inválido según /auth/verify - limpiando sesión');
        await _storage.clearToken();
        return false;
      }

      print('[AUTH] Token verificado exitosamente con el backend');
      return true;
    } catch (e) {
      print('[AUTH] Error verificando token con backend: $e');
      await _storage.clearToken();
      return false;
    }
  }

  /// Cierra sesión limpiando el token.
  Future<void> logout() async {
    await _storage.clearToken();
  }
}
