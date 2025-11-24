import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/solicitante_websocket_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../solicitante/presentation/pages/home_solicitante_page.dart';

class SeguimientoEmergenciaPage extends StatefulWidget {
  final double latitudEmergencia;
  final double longitudEmergencia;
  final SolicitanteWebSocketService wsService;

  const SeguimientoEmergenciaPage({
    super.key,
    required this.latitudEmergencia,
    required this.longitudEmergencia,
    required this.wsService,
  });

  @override
  State<SeguimientoEmergenciaPage> createState() =>
      _SeguimientoEmergenciaPageState();
}

class _SeguimientoEmergenciaPageState
    extends State<SeguimientoEmergenciaPage> {
  late MapController _mapController;
  final _storage = StorageService();
  final _distance = Distance();

  // Ubicación de la ambulancia
  double? _ambulanciaLat;
  double? _ambulanciaLng;
  
  // Ubicación actual del usuario
  double? _usuarioLat;
  double? _usuarioLng;
  
  // Estado
  bool _ambulanciaLlego = false;
  String? _tiempoEstimado;
  double _distanciaMetros = 0.0;
  bool _yaSeCentroEnAmbulancia = false; // Flag para centrar solo una vez

  // Para calcular velocidad basada en puntos anteriores
  double? _ultimaLat;
  double? _ultimaLng;
  DateTime? _ultimoTimestamp;
  double _velocidadMs = 0.0; // Velocidad en m/s

  // Callback original del websocket (para restaurarlo después)
  Function(Map<String, dynamic>)? _originalCallback;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Guardar callback original
    _originalCallback = widget.wsService.onMensajeRecibido;
    
    // Configurar callback para recibir ubicaciones
    widget.wsService.onMensajeRecibido = _procesarMensajeWebSocket;
    
    // Obtener ubicación actual del usuario
    _obtenerUbicacionActual();
    
    // Centrar mapa en la ubicación de emergencia inicialmente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(
        LatLng(widget.latitudEmergencia, widget.longitudEmergencia),
        15.0,
      );
    });
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final locationService = LocationService();
      final position = locationService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _usuarioLat = position.latitude;
          _usuarioLng = position.longitude;
        });
        print('[SEGUIMIENTO] Ubicación actual del usuario obtenida: ${_usuarioLat}, ${_usuarioLng}');
      } else {
        // Intentar actualizar la ubicación
        final updatedPosition = await locationService.updateLocation();
        if (updatedPosition != null) {
          setState(() {
            _usuarioLat = updatedPosition.latitude;
            _usuarioLng = updatedPosition.longitude;
          });
          print('[SEGUIMIENTO] Ubicación actual del usuario actualizada: ${_usuarioLat}, ${_usuarioLng}');
        }
      }
    } catch (e) {
      print('[SEGUIMIENTO] Error obteniendo ubicación actual: $e');
    }
  }

  void _procesarMensajeWebSocket(Map<String, dynamic> data) {
    print('[SEGUIMIENTO] Mensaje recibido: $data');
    
    final tipo = data['tipo'] as String?;
    
    if (tipo == 'ubicacion_ambulancia') {
      final latitud = data['latitud'] as double?;
      final longitud = data['longitud'] as double?;
      
      if (latitud != null && longitud != null) {
        _actualizarUbicacionAmbulancia(latitud, longitud);
      }
      // No pasar este mensaje al callback original, ya lo procesamos aquí
      return;
    }
    
    // Pasar otros mensajes al callback original si existe
    _originalCallback?.call(data);
  }

  void _actualizarUbicacionAmbulancia(double lat, double lng) {
    if (!mounted) return;
    
    final ahora = DateTime.now();
    
    setState(() {
      // Calcular velocidad si tenemos un punto anterior
      if (_ultimaLat != null && _ultimaLng != null && _ultimoTimestamp != null) {
        // Calcular distancia entre el punto anterior y el actual
        final distanciaEntrePuntos = _distance.as(
          LengthUnit.Meter,
          LatLng(_ultimaLat!, _ultimaLng!),
          LatLng(lat, lng),
        );
        
        // Calcular tiempo transcurrido en segundos
        final tiempoTranscurrido = ahora.difference(_ultimoTimestamp!).inMilliseconds / 1000.0;
        
        // Calcular velocidad en m/s (solo si el tiempo es mayor a 0)
        if (tiempoTranscurrido > 0) {
          _velocidadMs = distanciaEntrePuntos / tiempoTranscurrido;
          print('[SEGUIMIENTO] Velocidad calculada: ${(_velocidadMs * 3.6).toStringAsFixed(2)} km/h (distancia: ${distanciaEntrePuntos.toStringAsFixed(2)}m, tiempo: ${tiempoTranscurrido.toStringAsFixed(2)}s)');
        }
      }
      
      // Actualizar ubicación actual
      _ambulanciaLat = lat;
      _ambulanciaLng = lng;
      
      // Guardar como último punto para el próximo cálculo
      _ultimaLat = lat;
      _ultimaLng = lng;
      _ultimoTimestamp = ahora;
      
      // Calcular distancia hasta la ubicación de emergencia
      final distancia = _distance.as(
        LengthUnit.Meter,
        LatLng(widget.latitudEmergencia, widget.longitudEmergencia),
        LatLng(lat, lng),
      );
      
      _distanciaMetros = distancia;
      
      // Calcular tiempo estimado usando la velocidad calculada
      // Si no tenemos velocidad calculada aún, usar una velocidad por defecto (50 km/h = 13.89 m/s)
      final velocidadParaCalculo = _velocidadMs > 0 ? _velocidadMs : 13.89;
      
      if (distancia > 0 && velocidadParaCalculo > 0) {
        final tiempoSegundos = distancia / velocidadParaCalculo;
        final minutos = (tiempoSegundos / 60).ceil();
        _tiempoEstimado = minutos <= 1 ? 'Menos de 1 minuto' : '$minutos minutos';
      } else {
        _tiempoEstimado = 'Calculando...';
      }
      
      // Verificar si está a menos de 30 metros
      if (distancia < 30 && !_ambulanciaLlego) {
        _ambulanciaLlego = true;
        _finalizarSeguimiento();
      }
      
      // Centrar cámara en la ambulancia solo la primera vez
      if (_ambulanciaLat != null && _ambulanciaLng != null && !_yaSeCentroEnAmbulancia) {
        _yaSeCentroEnAmbulancia = true;
        _mapController.move(
          LatLng(_ambulanciaLat!, _ambulanciaLng!),
          16.0,
        );
        print('[SEGUIMIENTO] Mapa centrado en ambulancia (primera vez)');
      }
    });
  }

  Future<void> _finalizarSeguimiento() async {
    // Obtener id de emergencia antes de limpiar
    final emergenciaActiva = await _storage.getEmergenciaActiva();
    final idEmergencia = emergenciaActiva?['id_emergencia'] as int? ?? emergenciaActiva?['id'] as int?;
    
    // Enviar mensaje de emergencia finalizada al servidor
    if (idEmergencia != null && idEmergencia > 0) {
      widget.wsService.enviarMensaje({
        'tipo': 'emergencia_finalizada',
        'id_emergencia': idEmergencia,
      });
      print('[SEGUIMIENTO] Mensaje de emergencia finalizada enviado con id: $idEmergencia');
    } else {
      print('[SEGUIMIENTO] No se pudo obtener id de emergencia para enviar mensaje');
    }
    
    // Esperar un momento para que el mensaje se envíe antes de cerrar
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Limpiar shared preferences
    await _storage.clearEmergenciaActiva();
    await _storage.setTieneEmergenciaActiva(false);
    
    // Restaurar callback original antes de cerrar
    widget.wsService.onMensajeRecibido = _originalCallback;
    
    // Cerrar websocket
    widget.wsService.desconectar();
    
    print('[SEGUIMIENTO] Emergencia finalizada - datos limpiados y websocket cerrado');
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Restaurar callback original si no se finalizó
    if (!_ambulanciaLlego) {
      widget.wsService.onMensajeRecibido = _originalCallback;
    }
    _mapController.dispose();
    super.dispose();
  }

  String _formatDistancia(double metros) {
    if (metros < 1000) {
      return '${metros.toInt()}m';
    } else {
      return '${(metros / 1000).toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQColors.surface,
      appBar: AppBar(
        backgroundColor: ResQColors.primary500,
        elevation: 0,
        title: const Text(
          'Seguimiento de Ambulancia',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                widget.latitudEmergencia,
                widget.longitudEmergencia,
              ),
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.resq_app',
              ),
              MarkerLayer(
                markers: [
                  // Marcador de emergencia (ubicación donde se reportó)
                  Marker(
                    point: LatLng(
                      widget.latitudEmergencia,
                      widget.longitudEmergencia,
                    ),
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Marcador de ubicación actual del usuario
                  if (_usuarioLat != null && _usuarioLng != null)
                    Marker(
                      point: LatLng(_usuarioLat!, _usuarioLng!),
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Marcador de ambulancia
                  if (_ambulanciaLat != null && _ambulanciaLng != null)
                    Marker(
                      point: LatLng(_ambulanciaLat!, _ambulanciaLng!),
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_hospital,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // Información flotante
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _ambulanciaLlego
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '¡Ambulancia ha llegado!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ResQColors.primary500,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomeSolicitantePage(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: const Text(
                                'Salir',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ambulancia en camino',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_ambulanciaLat != null && _ambulanciaLng != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.straighten, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Distancia: ${_formatDistancia(_distanciaMetros)}',
                                    style: const TextStyle(fontSize: 16),
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_tiempoEstimado != null)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.access_time, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tiempo estimado: $_tiempoEstimado',
                                      style: const TextStyle(fontSize: 16),
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                          ] else
                            const Text(
                              'Esperando ubicación de la ambulancia...',
                              style: TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

