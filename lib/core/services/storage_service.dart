import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _nombreUsuarioKey = 'nombre_usuario';
  static const _tipoUsuarioKey = 'tipo_usuario';
  static const _personaIdKey = 'persona_id';
  static const _rememberKey = 'remember_me';
  static const _emergenciaActivaIdSolicitudKey =
      'emergencia_activa_id_solicitud';
  static const _emergenciaActivaIdEmergenciaKey =
      'emergencia_activa_id_emergencia';
  static const _emergenciaActivaEstadoKey = 'emergencia_activa_estado';
  static const _emergenciaActivaFechaKey = 'emergencia_activa_fecha';
  static const _emergenciaActivaFlagKey = 'emergencia_activa_flag';
  static const _emergenciaActivaLatKey = 'emergencia_activa_lat';
  static const _emergenciaActivaLngKey = 'emergencia_activa_lng';
  static const _emergenciaActivaHoraValoradaKey =
      'emergencia_activa_hora_valorada';
  static const _emergenciaActivaHoraDespachadaKey =
      'emergencia_activa_hora_despachada';
  static const _emergenciaActivaUbicacionDespachoLatKey =
      'emergencia_activa_ubicacion_despacho_lat';
  static const _emergenciaActivaUbicacionDespachoLngKey =
      'emergencia_activa_ubicacion_despacho_lng';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<void> saveNombreUsuario(String nombreUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nombreUsuarioKey, nombreUsuario);
  }

  Future<String?> getNombreUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nombreUsuarioKey);
  }

  Future<void> saveTipoUsuario(String tipoUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tipoUsuarioKey, tipoUsuario);
  }

  Future<String?> getTipoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tipoUsuarioKey);
  }

  Future<void> savePersonaId(int personaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_personaIdKey, personaId);
  }

  Future<int?> getPersonaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_personaIdKey);
  }

  Future<void> saveRemember(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
  }

  Future<bool?> getRemember() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nombreUsuarioKey);
    await prefs.remove(_tipoUsuarioKey);
    await prefs.remove(_personaIdKey);
    await prefs.remove(_rememberKey);
  }

  // Métodos para emergencia activa
  Future<void> saveIdSolicitud(int idSolicitud) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_emergenciaActivaIdSolicitudKey, idSolicitud);
    await prefs.setBool(_emergenciaActivaFlagKey, true);
  }

  Future<void> saveEmergenciaActiva({
    int? idSolicitud,
    int? idEmergencia,
    required String estado,
    required DateTime fecha,
    double? latitud,
    double? longitud,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (idSolicitud != null && idSolicitud > 0) {
      await prefs.setInt(_emergenciaActivaIdSolicitudKey, idSolicitud);
    }
    if (idEmergencia != null && idEmergencia > 0) {
      await prefs.setInt(_emergenciaActivaIdEmergenciaKey, idEmergencia);
    }
    await prefs.setString(_emergenciaActivaEstadoKey, estado);
    await prefs.setString(_emergenciaActivaFechaKey, fecha.toIso8601String());
    if (latitud != null) {
      await prefs.setDouble(_emergenciaActivaLatKey, latitud);
    }
    if (longitud != null) {
      await prefs.setDouble(_emergenciaActivaLngKey, longitud);
    }
    await prefs.setBool(_emergenciaActivaFlagKey, true);
  }

  Future<void> updateIdEmergenciaActiva(int idEmergencia) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_emergenciaActivaIdEmergenciaKey, idEmergencia);
    // Poner id_solicitud en 0 cuando se recibe el id_emergencia
    await prefs.setInt(_emergenciaActivaIdSolicitudKey, 0);
    await prefs.setBool(_emergenciaActivaFlagKey, true);
  }

  Future<void> clearIdSolicitud() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_emergenciaActivaIdSolicitudKey, 0);
  }

  Future<Map<String, dynamic>?> getEmergenciaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    final idSolicitud = prefs.getInt(_emergenciaActivaIdSolicitudKey);
    final idEmergencia = prefs.getInt(_emergenciaActivaIdEmergenciaKey);
    final estado = prefs.getString(_emergenciaActivaEstadoKey);
    final fechaStr = prefs.getString(_emergenciaActivaFechaKey);
    final latitud = prefs.getDouble(_emergenciaActivaLatKey);
    final longitud = prefs.getDouble(_emergenciaActivaLngKey);
    final horaValoradaStr = prefs.getString(_emergenciaActivaHoraValoradaKey);
    final horaDespachadaStr =
        prefs.getString(_emergenciaActivaHoraDespachadaKey);
    final ubicacionDespachoLat =
        prefs.getDouble(_emergenciaActivaUbicacionDespachoLatKey);
    final ubicacionDespachoLng =
        prefs.getDouble(_emergenciaActivaUbicacionDespachoLngKey);

    // Solo mostrar el recuadro si hay un ID de emergencia válido (no null y no 0)
    // El id_solicitud se pone en 0 cuando llega el id_emergencia
    final idFinal = idEmergencia ??
        (idSolicitud != null && idSolicitud > 0 ? idSolicitud : null);

    if (idFinal == null || idFinal == 0) {
      return null;
    }

    // También necesitamos estado y fecha
    if (estado == null || fechaStr == null) {
      return null;
    }

    return {
      'id': idFinal,
      'id_solicitud': idSolicitud ?? 0,
      'id_emergencia': idEmergencia,
      'estado': estado,
      'fecha': DateTime.parse(fechaStr),
      'latitud': latitud,
      'longitud': longitud,
      'hora_valorada':
          horaValoradaStr != null ? DateTime.parse(horaValoradaStr) : null,
      'hora_despachada':
          horaDespachadaStr != null ? DateTime.parse(horaDespachadaStr) : null,
      'ubicacion_despacho_lat': ubicacionDespachoLat,
      'ubicacion_despacho_lng': ubicacionDespachoLng,
    };
  }

  Future<void> updateEstadoEmergenciaActiva(String estado,
      {String? fechaHora}) async {
    final prefs = await SharedPreferences.getInstance();
    final estadoAnterior = prefs.getString(_emergenciaActivaEstadoKey);
    await prefs.setString(_emergenciaActivaEstadoKey, estado);

    // Guardar tiempo cuando se recibe notificación de VALORADA
    // Solo guardar si no existe ya y si el estado cambió a VALORADA
    if ((estado.toUpperCase() == 'VALORADA' ||
            estado.toUpperCase() == 'EMERGENCIA_VALORADA') &&
        (estadoAnterior == null ||
            (estadoAnterior.toUpperCase() != 'VALORADA' &&
                estadoAnterior.toUpperCase() != 'EMERGENCIA_VALORADA'))) {
      final horaValoradaExistente =
          prefs.getString(_emergenciaActivaHoraValoradaKey);
      if (horaValoradaExistente == null) {
        // Usar la hora del mensaje si viene, sino usar la hora actual
        final horaAGuardar = fechaHora ?? DateTime.now().toIso8601String();
        await prefs.setString(_emergenciaActivaHoraValoradaKey, horaAGuardar);
      }
    }

    // Guardar tiempo cuando se recibe notificación de AMBULANCIA_ASIGNADA (despachada)
    // Solo guardar si no existe ya y si el estado cambió a AMBULANCIA_ASIGNADA
    if (estado.toUpperCase() == 'AMBULANCIA_ASIGNADA' &&
        (estadoAnterior == null ||
            estadoAnterior.toUpperCase() != 'AMBULANCIA_ASIGNADA')) {
      final horaDespachadaExistente =
          prefs.getString(_emergenciaActivaHoraDespachadaKey);
      if (horaDespachadaExistente == null) {
        // Usar la hora del mensaje si viene, sino usar la hora actual
        final horaAGuardar = fechaHora ?? DateTime.now().toIso8601String();
        await prefs.setString(_emergenciaActivaHoraDespachadaKey, horaAGuardar);
      }
    }
  }

  Future<void> saveUbicacionDespachoAmbulancia(
      double latitud, double longitud) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_emergenciaActivaUbicacionDespachoLatKey, latitud);
    await prefs.setDouble(_emergenciaActivaUbicacionDespachoLngKey, longitud);
  }

  Future<void> clearEmergenciaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emergenciaActivaIdSolicitudKey);
    await prefs.remove(_emergenciaActivaIdEmergenciaKey);
    await prefs.remove(_emergenciaActivaEstadoKey);
    await prefs.remove(_emergenciaActivaFechaKey);
    await prefs.remove(_emergenciaActivaLatKey);
    await prefs.remove(_emergenciaActivaLngKey);
    await prefs.remove(_emergenciaActivaHoraValoradaKey);
    await prefs.remove(_emergenciaActivaHoraDespachadaKey);
    await prefs.remove(_emergenciaActivaUbicacionDespachoLatKey);
    await prefs.remove(_emergenciaActivaUbicacionDespachoLngKey);
    await prefs.setBool(_emergenciaActivaFlagKey, false);
  }

  Future<void> setTieneEmergenciaActiva(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emergenciaActivaFlagKey, value);
  }

  Future<bool> getTieneEmergenciaActiva() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_emergenciaActivaFlagKey) ?? false;
  }
}
