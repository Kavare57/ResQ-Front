class EmergenciaHistorial {
  final int id;
  final String estado;
  final String tipoAmbulancia;
  final String nivelPrioridad;
  final String descripcion;
  final DateTime fechaCreacion;
  final int idOperador;

  EmergenciaHistorial({
    required this.id,
    required this.estado,
    required this.tipoAmbulancia,
    required this.nivelPrioridad,
    required this.descripcion,
    required this.fechaCreacion,
    required this.idOperador,
  });

  factory EmergenciaHistorial.fromJson(Map<String, dynamic> json) {
    return EmergenciaHistorial(
      id: json['id'] as int? ?? 0,
      estado: json['estado'] as String? ?? 'DESCONOCIDO',
      tipoAmbulancia: json['tipoAmbulancia'] as String? ?? 'AMBULANCIA',
      nivelPrioridad: json['nivelPrioridad'] as String? ?? 'MEDIA',
      descripcion: json['descripcion'] as String? ?? 'Sin descripción',
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'] as String)
          : DateTime.now(),
      idOperador: json['id_operador'] as int? ?? 0,
    );
  }

  String get estadoLabel {
    switch (estado.toUpperCase()) {
      case 'ABIERTA':
        return '🟡 Abierta';
      case 'EN_PROGRESO':
        return '🔵 En progreso';
      case 'CERRADA':
        return '🟢 Cerrada';
      case 'CANCELADA':
        return '🔴 Cancelada';
      default:
        return estado;
    }
  }

  String get prioridadLabel {
    switch (nivelPrioridad.toUpperCase()) {
      case 'BAJA':
        return '🟢 Baja';
      case 'MEDIA':
        return '🟡 Media';
      case 'ALTA':
        return '🔴 Alta';
      case 'CRITICA':
        return '⛔ Crítica';
      default:
        return nivelPrioridad;
    }
  }

  String get tipoLabel {
    switch (tipoAmbulancia.toUpperCase()) {
      case 'AMBULANCIA':
        return '🚑 Ambulancia';
      case 'AMBULANCIA_BASICA':
        return '🚑 Básica';
      case 'AMBULANCIA_AVANZADA':
        return '🚑 Avanzada';
      case 'HELICOPTERO':
        return '🚁 Helicóptero';
      default:
        return tipoAmbulancia;
    }
  }

  String get fechaFormato {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    
    if (fechaCreacion.year == hoy.year &&
        fechaCreacion.month == hoy.month &&
        fechaCreacion.day == hoy.day) {
      return 'Hoy ${fechaCreacion.hour.toString().padLeft(2, '0')}:${fechaCreacion.minute.toString().padLeft(2, '0')}';
    } else if (fechaCreacion.year == ayer.year &&
        fechaCreacion.month == ayer.month &&
        fechaCreacion.day == ayer.day) {
      return 'Ayer ${fechaCreacion.hour.toString().padLeft(2, '0')}:${fechaCreacion.minute.toString().padLeft(2, '0')}';
    } else {
      return '${fechaCreacion.day}/${fechaCreacion.month}/${fechaCreacion.year} ${fechaCreacion.hour.toString().padLeft(2, '0')}:${fechaCreacion.minute.toString().padLeft(2, '0')}';
    }
  }
}
