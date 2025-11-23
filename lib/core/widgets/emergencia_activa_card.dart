import 'package:flutter/material.dart';
import '../constants/colors.dart';

class EmergenciaActivaCard extends StatelessWidget {
  final String estado;
  final DateTime fecha;
  final int? idSolicitud;

  const EmergenciaActivaCard({
    super.key,
    required this.estado,
    required this.fecha,
    this.idSolicitud,
  });

  String _getEstadoLabel(String estado) {
    switch (estado.toUpperCase()) {
      case 'CREADA':
      case 'EMERGENCIA_CREADA':
        return 'Creada';
      case 'VALORADA':
        return 'Valorada';
      case 'AMBULANCIA_ASIGNADA':
      case 'ASIGNADA':
        return 'Ambulancia asignada';
      case 'EN_CAMINO':
      case 'ENCAMINO':
        return 'En camino';
      case 'EN_SITIO':
      case 'ENSITIO':
        return 'En sitio';
      case 'RESUELTA':
      case 'ATENDIDA':
        return 'Resuelta';
      case 'CANCELADA':
        return 'Cancelada';
      default:
        // También manejar versión en minúsculas por compatibilidad
        switch (estado.toLowerCase()) {
          case 'creada':
          case 'emergencia_creada':
            return 'Creada';
          case 'valorada':
            return 'Valorada';
          case 'ambulancia_asignada':
          case 'asignada':
            return 'Ambulancia asignada';
          case 'en_camino':
          case 'encamino':
            return 'En camino';
          case 'en_sitio':
          case 'ensitio':
            return 'En sitio';
          case 'resuelta':
          case 'atendida':
            return 'Resuelta';
          case 'cancelada':
            return 'Cancelada';
          default:
            return estado;
        }
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toUpperCase()) {
      case 'CREADA':
      case 'EMERGENCIA_CREADA':
        return Colors.orange;
      case 'VALORADA':
        return Colors.amber; // Amarillo/naranja para valorada
      case 'AMBULANCIA_ASIGNADA':
      case 'ASIGNADA':
        return Colors.purple;
      case 'EN_CAMINO':
      case 'ENCAMINO':
        return Colors.indigo;
      case 'EN_SITIO':
      case 'ENSITIO':
        return Colors.teal;
      case 'RESUELTA':
      case 'ATENDIDA':
        return Colors.green;
      case 'CANCELADA':
        return Colors.red;
      default:
        // También manejar versión en minúsculas por compatibilidad
        switch (estado.toLowerCase()) {
          case 'creada':
          case 'emergencia_creada':
            return Colors.orange;
          case 'valorada':
            return Colors.amber; // Amarillo/naranja para valorada
          case 'ambulancia_asignada':
          case 'asignada':
            return Colors.purple;
          case 'en_camino':
          case 'encamino':
            return Colors.indigo;
          case 'en_sitio':
          case 'ensitio':
            return Colors.teal;
          case 'resuelta':
          case 'atendida':
            return Colors.green;
          case 'cancelada':
            return Colors.red;
          default:
            return Colors.grey;
        }
    }
  }

  String _formatFecha(DateTime fecha) {
    final now = DateTime.now();
    final diferencia = now.difference(fecha);

    if (diferencia.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} minuto${diferencia.inMinutes > 1 ? 's' : ''}';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} hora${diferencia.inHours > 1 ? 's' : ''}';
    } else {
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final hora = fecha.hour.toString().padLeft(2, '0');
      final minuto = fecha.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$hora:$minuto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _getEstadoColor(estado);
    final estadoLabel = _getEstadoLabel(estado);

    return Card(
      color: ResQColors.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: estadoColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: estadoColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Emergencia Activa',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: estadoColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: estadoColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Estado: $estadoLabel',
                        style: TextStyle(
                          color: estadoColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatFecha(fecha),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            if (idSolicitud != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.tag,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ID: $idSolicitud',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

