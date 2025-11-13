import 'package:flutter/material.dart';
import '../data/emergencia_api.dart';

class EmergenciaView {
  final String id;
  final String titulo;
  final String fechaTexto;
  final String estadoRaw; // texto crudo desde API: 'asignada', 'enCamino', etc.
  EmergenciaView({
    required this.id,
    required this.titulo,
    required this.fechaTexto,
    required this.estadoRaw,
  });
}

class EmergenciaController {
  final _api = EmergenciaApi();

  final List<EmergenciaView> historial = [
    EmergenciaView(id: 'E-1001', titulo: 'Dificultad respiratoria', fechaTexto: 'Hoy, 10:24 a. m.', estadoRaw: 'asignada'),
    EmergenciaView(id: 'E-1000', titulo: 'Dolor torácico',         fechaTexto: 'Ayer, 7:50 p. m.', estadoRaw: 'enCamino'),
  ];

  Future<void> refreshHistorial() async {
    // Cuando haya endpoint: final data = await _api.getHistorial();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<bool> probarGPS(BuildContext ctx) async {
    // TODO: geolocator/permission_handler
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  Future<({bool ok, String message, String? id})> crearEmergenciaRapida(BuildContext ctx) async {
    // Cuando haya endpoint:
    // final res = await _api.createSolicitud({"ubicacion":{"lat":..,"lon":..}, "descripcion": "..."} );
    await Future.delayed(const Duration(milliseconds: 600));
    return (ok: true, message: 'Solicitud enviada. Te notificaremos la asignación.', id: 'E-1002');
  }
}
