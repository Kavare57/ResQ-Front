class UbicacionAmbulancia {
  final double latitud;
  final double longitud;
  final DateTime fecha;
  final int velocidad; // km/h
  final double distancia; // metros al solicitante

  UbicacionAmbulancia({
    required this.latitud,
    required this.longitud,
    required this.fecha,
    required this.velocidad,
    required this.distancia,
  });

  factory UbicacionAmbulancia.fromJson(Map<String, dynamic> json) {
    return UbicacionAmbulancia(
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      velocidad: json['velocidad'] as int? ?? 0,
      distancia: (json['distancia'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get estaCerca => distancia < 500; // Menos de 500 metros

  String get distanciaFormato {
    if (distancia < 1000) {
      return '${distancia.toInt()}m';
    } else {
      return '${(distancia / 1000).toStringAsFixed(1)}km';
    }
  }
}

class EstadoEmergencia {
  final String
      estado; // EMERGENCIA_CREADA, VALORADA, AMBULANCIA_ASIGNADA, RESUELTA
  final DateTime fecha;
  final String descripcion;

  EstadoEmergencia({
    required this.estado,
    required this.fecha,
    required this.descripcion,
  });

  factory EstadoEmergencia.fromJson(Map<String, dynamic> json) {
    return EstadoEmergencia(
      estado: json['estado'] as String,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      descripcion: json['descripcion'] as String? ?? '',
    );
  }

  String get estadoLabel {
    switch (estado.toUpperCase()) {
      case 'EMERGENCIA_CREADA':
        return '📋 Emergencia creada';
      case 'VALORADA':
        return '⚕️ Valorada';
      case 'AMBULANCIA_ASIGNADA':
        return '🚑 Ambulancia asignada';
      case 'RESUELTA':
        return '✅ Resuelta';
      default:
        return estado;
    }
  }

  int get paso {
    switch (estado.toUpperCase()) {
      case 'EMERGENCIA_CREADA':
        return 1;
      case 'VALORADA':
        return 2;
      case 'AMBULANCIA_ASIGNADA':
        return 3;
      case 'RESUELTA':
        return 4;
      default:
        return 0;
    }
  }
}

class SolicitudSeguimiento {
  final int id;
  final String nombrePaciente;
  final String descripcion;
  final double latitudEmergencia;
  final double longitudEmergencia;
  final EstadoEmergencia estadoActual;
  final List<EstadoEmergencia> historialEstados;
  final UbicacionAmbulancia? ubicacionAmbulancia;
  final int? idAmbulancia;
  final String? nombreOperador;

  SolicitudSeguimiento({
    required this.id,
    required this.nombrePaciente,
    required this.descripcion,
    required this.latitudEmergencia,
    required this.longitudEmergencia,
    required this.estadoActual,
    required this.historialEstados,
    this.ubicacionAmbulancia,
    this.idAmbulancia,
    this.nombreOperador,
  });

  factory SolicitudSeguimiento.fromJson(Map<String, dynamic> json) {
    final estados = (json['historialEstados'] as List?)
            ?.map((e) => EstadoEmergencia.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SolicitudSeguimiento(
      id: json['id'] as int? ?? 0,
      nombrePaciente: json['nombrePaciente'] as String? ?? 'Paciente',
      descripcion: json['descripcion'] as String? ?? '',
      latitudEmergencia: (json['latitudEmergencia'] as num?)?.toDouble() ?? 0.0,
      longitudEmergencia:
          (json['longitudEmergencia'] as num?)?.toDouble() ?? 0.0,
      estadoActual: EstadoEmergencia.fromJson(
        json['estadoActual'] as Map<String, dynamic>? ??
            {
              'estado': 'DESCONOCIDO',
              'fecha': DateTime.now().toIso8601String()
            },
      ),
      historialEstados: estados,
      ubicacionAmbulancia: json['ubicacionAmbulancia'] != null
          ? UbicacionAmbulancia.fromJson(
              json['ubicacionAmbulancia'] as Map<String, dynamic>)
          : null,
      idAmbulancia: json['idAmbulancia'] as int?,
      nombreOperador: json['nombreOperador'] as String?,
    );
  }

  bool get ambulanciaAsignada =>
      idAmbulancia != null && ubicacionAmbulancia != null;
  bool get ambulanciaCerca => ubicacionAmbulancia?.estaCerca ?? false;
}
