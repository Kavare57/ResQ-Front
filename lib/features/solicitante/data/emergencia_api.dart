// Stub de puerto/datos: SOLO indica dónde van los endpoints.
// No requiere http por ahora.

//warning porque no se esta usando

class EmergenciaApi {
  // Cuando tengas endpoints reales, usarás: Env.apiBaseUrl
  // Ej: final base = Env.apiBaseUrl; // https://api.resq.xxx

  /// GET /solicitante/emergencias
  /// TODO: Reemplazar por llamada HTTP a: `${Env.apiBaseUrl}/solicitante/emergencias`
  Future<List<Map<String, dynamic>>> getHistorial() async {
    // Placeholder de ejemplo local (UI puede probar sin backend)
    return [
      {
        'id': 'E-1001',
        'titulo': 'Dificultad respiratoria',
        'fechaTexto': 'Hoy, 10:24 a. m.',
        'estado': 'asignada',
      },
      {
        'id': 'E-1000',
        'titulo': 'Dolor torácico',
        'fechaTexto': 'Ayer, 7:50 p. m.',
        'estado': 'enCamino',
      },
    ];
  }

  /// POST /solicitante/emergencias
  /// payload mínimo: { ubicacion:{lat,lon}, descripcion?:string }
  /// TODO: Reemplazar por POST a: `${Env.apiBaseUrl}/solicitante/emergencias`
  Future<Map<String, dynamic>> createSolicitud(
      Map<String, dynamic> payload) async {
    // Simulación/UI: responder como si el backend hubiera creado el recurso
    return {
      'id': 'E-1002',
      'message': 'Solicitud enviada',
      'status': 'registrada',
    };
  }
}
