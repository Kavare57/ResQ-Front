import 'package:flutter/material.dart';
import '../constants/colors.dart';

enum EstadoEmergencia { registrada, evaluada, asignada, enCamino, enSitio, atendida, cancelada }

class EmergencyStatusChip extends StatelessWidget {
  final EstadoEmergencia status;
  const EmergencyStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _map(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  (Color, Color, String) _map(EstadoEmergencia s) {
    switch (s) {
      case EstadoEmergencia.registrada:
        return (ResQColors.primary100, ResQColors.primary700, 'Registrada');
      case EstadoEmergencia.evaluada:
        return (const Color(0xFFE8F5E9), const Color(0xFF1B5E20), 'Evaluada');
      case EstadoEmergencia.asignada:
        return (const Color(0xFFE3F2FD), const Color(0xFF0D47A1), 'Asignada');
      case EstadoEmergencia.enCamino:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'En camino');
      case EstadoEmergencia.enSitio:
        return (const Color(0xFFEDE7F6), const Color(0xFF4527A0), 'En sitio');
      case EstadoEmergencia.atendida:
        return (const Color(0xFFE0F7FA), const Color(0xFF006064), 'Atendida');
      case EstadoEmergencia.cancelada:
        return (const Color(0xFFFFEBEE), const Color(0xFFB71C1C), 'Cancelada');
    }
  }
}
