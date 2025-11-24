import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/env.dart';
import '../services/storage_service.dart';
import '../services/jwt_helper.dart';

class SolicitantesApi {
  final _baseUrl = Env.apiBaseUrl;
  final _storage = StorageService();
  static const Duration _timeout = Duration(seconds: 10);

  /// Intenta encontrar y guardar el ID del solicitante después del login
  /// Ahora prefiere usar id_persona del storage si está disponible
  Future<void> sincronizarSolicitante() async {
    try {
      // Primero intentamos usar el id_persona obtenido en login
      final idPersona = await _storage.getPersonaId();
      if (idPersona != null) {
        print('[SOLICITANTE] Ya hay id_persona guardado: $idPersona');
        return;
      }

      // Si no hay id_persona aún, el usuario probablemente no ha completado su perfil
      print('[SOLICITANTE] Sin id_persona aún (perfil incompleto)');
    } catch (e) {
      print('[SOLICITANTE] Error sincronizando: $e');
    }
  }

  /// Busca un solicitante por su número de documento
  Future<Map<String, dynamic>> obtenerSolicitantePorDocumento(
    String numeroDocumento,
  ) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse(
      '$_baseUrl/solicitantes/buscar/documento?numero_documento=$numeroDocumento',
    );

    final res = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Error al obtener el solicitante: ${res.body}');
    }

    final perfil = jsonDecode(res.body);
    
    // Guardar el ID (id_persona) para futuras llamadas
    final id = perfil['id'];
    if (id != null) {
      await _storage.savePersonaId(id);
      print('[SOLICITANTE] ID persona guardado desde búsqueda por documento: $id');
    }

    return perfil;
  }

  /// Obtiene el perfil del solicitante actual
  /// Usa id_persona del storage (obtenido en login o completación de perfil)
  /// 
  /// Lanza excepción si:
  /// - No hay token (sesión no válida)
  /// - No hay id_persona (usuario sin perfil completado)
  Future<Map<String, dynamic>> obtenerPerfilActual() async {
    print('[SOLICITANTE] Obteniendo perfil actual...');
    
    int? idPersona = await _storage.getPersonaId();
    
    if (idPersona == null) {
      print('[SOLICITANTE] ERROR: No hay id_persona en storage');
      throw Exception('Perfil incompleto. Por favor completa tu información personal.');
    }

    return obtenerPerfil(idPersona);
  }

  /// Obtiene el perfil de un solicitante por ID
  Future<Map<String, dynamic>> obtenerPerfil(int idSolicitante) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse('$_baseUrl/solicitantes/$idSolicitante');
    print('[SOLICITANTE] Obteniendo perfil $idSolicitante...');

    try {
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Timeout (10s)');
      });

      print('[SOLICITANTE] Perfil OK: ${res.statusCode}');
      if (res.statusCode != 200) {
        throw Exception('Error: ${res.statusCode}');
      }

      return jsonDecode(res.body);
    } catch (e) {
      print('[SOLICITANTE] Error: $e');
      rethrow;
    }
  }

  /// Crea o actualiza el perfil del solicitante del usuario actual.
  ///
  /// FLUJO EN REGISTRO NUEVO (forzarCompletar=true):
  /// 1. POST /solicitantes → crea solicitante (obtiene id_persona)
  /// 2. Guarda id_persona en storage
  /// 3. PUT /usuarios/{id_usuario}/asignar-persona → vincula usuario con persona
  /// 4. Token temporal se limpia y usuario vuelve a login formal
  ///
  /// FLUJO EN EDICIÓN (desde home):
  /// 1. PUT /solicitantes/{id_persona} → actualiza datos
  /// 2. Guarda cambios locales
  /// 3. Vuelve al home
  Future<void> guardarPerfil({
    required String nombre,
    String? nombre2,
    required String apellido,
    String? apellido2,
    required String tipoDocumento,
    required String numeroDocumento,
    required DateTime fechaNacimiento,
  }) async {
    final token = await _storage.getToken();
    if (token == null) {
      throw Exception('No hay sesión iniciada.');
    }

    final url = Uri.parse('$_baseUrl/solicitantes');

    final body = {
      'nombre': nombre,
      'nombre2': nombre2,
      'apellido': apellido,
      'apellido2': apellido2,
      'tipoDocumento': tipoDocumento,
      'numeroDocumento': numeroDocumento,
      'fechaNacimiento': '${fechaNacimiento.year}-${fechaNacimiento.month.toString().padLeft(2, '0')}-${fechaNacimiento.day.toString().padLeft(2, '0')}',
    };

    print('[SOLICITANTE] 1/3 - Creando solicitante...');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    print('[SOLICITANTE] 1/3 - POST /solicitantes → ${res.statusCode}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Error al guardar el perfil: ${res.body}');
    }

    // Guardar el ID del solicitante si está en la respuesta
    try {
      final respuesta = jsonDecode(res.body);
      final idPersona = respuesta['id'];  // Este es el id_persona del solicitante
      if (idPersona != null) {
        await _storage.savePersonaId(idPersona);
        print('[SOLICITANTE] 1/3 - ID persona guardado en storage: $idPersona');
        
        // IMPORTANTE: Ahora asociamos el usuario con la persona
        print('[SOLICITANTE] 2/3 - Asociando usuario con persona...');
        try {
          await _asociarUsuarioConPersona(idPersona, 'SOLICITANTE');
          print('[SOLICITANTE] 3/3 - Proceso completado exitosamente');
        } catch (e) {
          print('[SOLICITANTE] ERROR en asociación: $e');
          // Si la asociación falla, el perfil ya fue creado
          // El usuario puede intentar de nuevo en siguiente login
          throw Exception('Perfil creado pero error en asociación: $e');
        }
      } else {
        throw Exception('No se recibió id_persona en la respuesta del servidor');
      }
    } catch (e) {
      print('[SOLICITANTE] Error procesando respuesta: $e');
      rethrow;
    }
  }

  /// Asocia el usuario actual (del token) con una persona (solicitante, operador, etc)
  /// 
  /// Llamada: PUT /usuarios/{id_usuario}/asignar-persona
  /// Body: { "id_persona": int, "tipoUsuario": "SOLICITANTE" }
  /// 
  /// Esto actualiza el usuario en la BD, asignándole:
  /// - id_persona: el ID de la persona (solicitante en este caso)
  /// - tipoUsuario: su tipo de usuario
  /// 
  /// Lanza excepción si algo falla, para que el caller pueda manejar.
  Future<void> _asociarUsuarioConPersona(
    int idPersona,
    String tipoUsuario,
  ) async {
    try {
      final token = await _storage.getToken();
      if (token == null) {
        throw Exception('No hay sesión iniciada (token nulo).');
      }

      // Extraer el id_usuario del JWT
      final idUsuario = JwtHelper.getIdUsuario(token);
      if (idUsuario == null) {
        // Debug: mostrar el payload completo
        final payload = JwtHelper.decodeToken(token);
        print('[SOLICITANTE] DEBUG - Payload del token: $payload');
        throw Exception('No se pudo extraer id_usuario del token. Payload: $payload');
      }

      print('[SOLICITANTE] DEBUG - ID usuario extraído: $idUsuario');
      final url = Uri.parse('$_baseUrl/usuarios/$idUsuario/asignar-persona');
      print('[SOLICITANTE] Enviando PUT a: $url');

      final body = {
        'id_persona': idPersona,
        'tipoUsuario': tipoUsuario,
      };

      final res = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('[SOLICITANTE] Respuesta PUT: ${res.statusCode}');
      if (res.statusCode != 200) {
        print('[SOLICITANTE] Error en PUT: ${res.body}');
        throw Exception('Error asignando persona (${res.statusCode}): ${res.body}');
      }
      
      print('[SOLICITANTE] Asociación usuario-persona exitosa');
      await _storage.savePersonaId(idPersona);
      print('[SOLICITANTE] ID persona guardado localmente: $idPersona');
    } catch (e) {
      print('[SOLICITANTE] Error en _asociarUsuarioConPersona: $e');
      rethrow;  // Relanzar para que guardarPerfil maneje el error
    }
  }
}
