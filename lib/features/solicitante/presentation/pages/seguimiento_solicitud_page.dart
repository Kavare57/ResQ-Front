import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/error_handler.dart';
import '../../../../core/widgets/error_display_widget.dart';
import '../models/solicitud_seguimiento.dart';
import '../services/solicitud_websocket_service.dart';

class SeguimientoSolicitudPage extends StatefulWidget {
  final int idSolicitud;
  final SolicitudSeguimiento? datosIniciales;

  const SeguimientoSolicitudPage({
    super.key,
    required this.idSolicitud,
    this.datosIniciales,
  });

  @override
  State<SeguimientoSolicitudPage> createState() =>
      _SeguimientoSolicitudPageState();
}

class _SeguimientoSolicitudPageState extends State<SeguimientoSolicitudPage> {
  late final SolicitudWebSocketService _wsService;
  late SolicitudSeguimiento _solicitud;

  bool _conectando = true;
  String? _errorConexion;
  bool _mostrarNotificacionCerca = false;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _wsService = SolicitudWebSocketService();

    // Usar datos iniciales si están disponibles
    if (widget.datosIniciales != null) {
      _solicitud = widget.datosIniciales!;
      _conectando = false;
    } else {
      _solicitud = SolicitudSeguimiento(
        id: widget.idSolicitud,
        nombrePaciente: 'Cargando...',
        descripcion: '',
        latitudEmergencia: 0,
        longitudEmergencia: 0,
        estadoActual: EstadoEmergencia(
          estado: 'DESCONOCIDA',
          fecha: DateTime.now(),
          descripcion: '',
        ),
        historialEstados: [],
      );
    }

    _configurarWebSocket();
  }

  void _configurarWebSocket() {
    _wsService.onEstadoActualizado = (estado) {
      print('[SEGUIMIENTO] Estado actualizado: ${estado.estado}');
      setState(() {
        _solicitud = SolicitudSeguimiento(
          id: _solicitud.id,
          nombrePaciente: _solicitud.nombrePaciente,
          descripcion: _solicitud.descripcion,
          latitudEmergencia: _solicitud.latitudEmergencia,
          longitudEmergencia: _solicitud.longitudEmergencia,
          estadoActual: estado,
          historialEstados: [estado, ..._solicitud.historialEstados],
          ubicacionAmbulancia: _solicitud.ubicacionAmbulancia,
          idAmbulancia: _solicitud.idAmbulancia,
          nombreOperador: _solicitud.nombreOperador,
        );
      });
    };

    _wsService.onUbicacionAmbulancia = (ubicacion) {
      print(
          '[SEGUIMIENTO] Ubicación ambulancia: ${ubicacion.distanciaFormato}');
      setState(() {
        _solicitud = SolicitudSeguimiento(
          id: _solicitud.id,
          nombrePaciente: _solicitud.nombrePaciente,
          descripcion: _solicitud.descripcion,
          latitudEmergencia: _solicitud.latitudEmergencia,
          longitudEmergencia: _solicitud.longitudEmergencia,
          estadoActual: _solicitud.estadoActual,
          historialEstados: _solicitud.historialEstados,
          ubicacionAmbulancia: ubicacion,
          idAmbulancia: _solicitud.idAmbulancia,
          nombreOperador: _solicitud.nombreOperador,
        );
      });

      // Animar cámara al marcador de la ambulancia
      if (mounted) {
        _mapController.move(
          LatLng(ubicacion.latitud, ubicacion.longitud),
          16,
        );
      }
    };

    _wsService.onNearbyAmbulancia = (cerca) {
      if (cerca && !_mostrarNotificacionCerca) {
        setState(() {
          _mostrarNotificacionCerca = true;
        });
        _showAmbulanceNotif();
      }
    };

    _wsService.onError = (mensaje) {
      print('[SEGUIMIENTO] Error: $mensaje');
      if (mounted) {
        setState(() {
          _errorConexion = mensaje;
        });
      }
    };

    _wsService.onConexionPerdida = () {
      print('[SEGUIMIENTO] Conexión perdida');
      if (mounted) {
        setState(() {
          _errorConexion = 'Conexión perdida con el servidor';
        });
      }
    };

    // Conectar
    _conectarWebSocket();
  }

  Future<void> _conectarWebSocket() async {
    try {
      await _wsService.conectar(widget.idSolicitud);
      if (mounted) {
        setState(() {
          _conectando = false;
          _errorConexion = null;
        });
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[SEGUIMIENTO-CONEXION]', e, stackTrace);
      if (mounted) {
        setState(() {
          _conectando = false;
          _errorConexion = ErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  void _showAmbulanceNotif() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.local_hospital, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('¡Ambulancia cerca!'),
            ],
          ),
          content: const Text(
            'La ambulancia está a menos de 500 metros de tu ubicación.\n\nEstá casi llegando.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _wsService.desconectar();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _wsService.desconectar();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ResQColors.primary500,
          title: Text('Solicitud #${_solicitud.id}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _wsService.desconectar();
              Navigator.pop(context);
            },
          ),
        ),
        body: Stack(
          children: [
            // Mapa si la ambulancia está asignada
            if (_solicitud.ambulanciaAsignada)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    _solicitud.ubicacionAmbulancia?.latitud ?? 4.7110,
                    _solicitud.ubicacionAmbulancia?.longitud ?? -74.0072,
                  ),
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  MarkerLayer(
                    markers: [
                      // Marcador del paciente
                      Marker(
                        point: LatLng(
                          _solicitud.latitudEmergencia,
                          _solicitud.longitudEmergencia,
                        ),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      // Marcador de la ambulancia
                      if (_solicitud.ubicacionAmbulancia != null)
                        Marker(
                          point: LatLng(
                            _solicitud.ubicacionAmbulancia!.latitud,
                            _solicitud.ubicacionAmbulancia!.longitud,
                          ),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            // Contenido principal (encima del mapa si existe)
            if (!_solicitud.ambulanciaAsignada)
              SingleChildScrollView(
                child: _buildContenidoPrincipal(),
              ),
            // Panel flotante con información
            if (_solicitud.ambulanciaAsignada)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildPanelInformacion(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenidoPrincipal() {
    if (_conectando) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Conectando con el servidor...'),
            ],
          ),
        ),
      );
    }

    if (_errorConexion != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: ErrorDisplayWidget(
          errorMessage: _errorConexion!,
          showRetryButton: true,
          onRetry: _conectarWebSocket,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del paciente
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _solicitud.nombrePaciente,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _solicitud.descripcion,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Timeline de estados
          const Text(
            'Estado de la solicitud',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTimelineEstados(),

          const SizedBox(height: 24),

          // Información del operador
          if (_solicitud.nombreOperador != null)
            Card(
              color: ResQColors.primary100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Operador asignado'),
                        Text(
                          _solicitud.nombreOperador!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineEstados() {
    const pasos = ['📋 Creada', '⚕️ Valorada', '🚑 Ambulancia', '✅ Resuelta'];
    final pasoActual = _solicitud.estadoActual.paso;

    return Column(
      children: List.generate(pasos.length, (index) {
        final paso = index + 1;
        final completado = pasoActual >= paso;
        final activo = pasoActual == paso;

        return Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        completado ? ResQColors.primary500 : Colors.grey[300],
                  ),
                  child: Center(
                    child: completado
                        ? const Icon(Icons.check, color: Colors.white)
                        : Text(
                            '$paso',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  pasos[index],
                  style: TextStyle(
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    color: activo ? ResQColors.primary500 : Colors.black54,
                  ),
                ),
              ],
            ),
            if (index < pasos.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: SizedBox(
                  height: 20,
                  child: VerticalDivider(
                    color:
                        completado ? ResQColors.primary500 : Colors.grey[300],
                    thickness: 2,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildPanelInformacion() {
    final ubicacion = _solicitud.ubicacionAmbulancia;
    if (ubicacion == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de separación
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Distancia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distancia',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                ubicacion.distanciaFormato,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Velocidad
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Velocidad',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                '${ubicacion.velocidad} km/h',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estado',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                _solicitud.estadoActual.estadoLabel,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Botón cerrar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ResQColors.primary500,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                _wsService.desconectar();
                Navigator.pop(context);
              },
              child: const Text('Cerrar seguimiento'),
            ),
          ),
        ],
      ),
    );
  }
}
