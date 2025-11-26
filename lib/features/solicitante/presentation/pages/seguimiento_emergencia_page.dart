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

class _SeguimientoEmergenciaPageState extends State<SeguimientoEmergenciaPage> {
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

  // Para rastrear desplazamiento total
  double _desplazamientoTotal = 0.0; // en metros
  bool _ubicacionDespachoGuardada = false; // Flag para guardar solo una vez
  bool _estadoDespachado = false; // Flag para saber si el estado es AMBULANCIA_ASIGNADA
  double? _primeraUbicacionLat; // Primera ubicación recibida (por si llega antes del cambio de estado)
  double? _primeraUbicacionLng;

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

    // Verificar estado actual de la emergencia
    _verificarEstadoInicial();

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

  Future<void> _verificarEstadoInicial() async {
    final emergenciaActiva = await _storage.getEmergenciaActiva();
    final estado = emergenciaActiva?['estado'] as String?;
    if (estado != null && estado.toUpperCase() == 'AMBULANCIA_ASIGNADA') {
      _estadoDespachado = true;
    }
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
      } else {
        // Intentar actualizar la ubicación
        final updatedPosition = await locationService.updateLocation();
        if (updatedPosition != null) {
          setState(() {
            _usuarioLat = updatedPosition.latitude;
            _usuarioLng = updatedPosition.longitude;
          });
        }
      }
    } catch (e) {
      // Error obteniendo ubicación actual; se mantiene la última conocida
    }
  }

  void _procesarMensajeWebSocket(Map<String, dynamic> data) async {
    // El backend envía "type", pero también puede venir "tipo" para compatibilidad
    final tipo = data['type'] as String? ?? data['tipo'] as String?;

    if (tipo == 'ubicacion_ambulancia') {
      final latitud = data['latitud'] as double?;
      final longitud = data['longitud'] as double?;

      if (latitud != null && longitud != null) {
        _actualizarUbicacionAmbulancia(latitud, longitud);
      }
      // No pasar este mensaje al callback original, ya lo procesamos aquí
      return;
    }

    // Procesar mensajes de estado para detectar cuando cambia a VALORADA o AMBULANCIA_ASIGNADA
    if (tipo == 'estado_actualizado' || tipo == null) {
      final datos = data['data'] as Map<String, dynamic>?;
      if (datos != null) {
        final estado = datos['estado'] as String?;
        if (estado != null) {
          // Extraer la hora del mensaje si viene
          final fechaHoraStr = datos['fechaHora'] as String?;
          
          // Actualizar el estado en storage para que se guarden las horas
          await _storage.updateEstadoEmergenciaActiva(
            estado,
            fechaHora: fechaHoraStr,
          );
          
          // Marcar si el estado es AMBULANCIA_ASIGNADA para capturar la primera ubicación
          if (estado.toUpperCase() == 'AMBULANCIA_ASIGNADA' && !_estadoDespachado) {
            _estadoDespachado = true;
            print('[DEBUG] Estado cambiado a AMBULANCIA_ASIGNADA, esperando primera ubicación');
            
            // Si ya tenemos una ubicación guardada (llegó antes del cambio de estado), guardarla ahora
            if (_primeraUbicacionLat != null && _primeraUbicacionLng != null && !_ubicacionDespachoGuardada) {
              await _guardarUbicacionDespacho(_primeraUbicacionLat!, _primeraUbicacionLng!);
              print('[DEBUG] Guardando ubicación que llegó antes del cambio de estado');
            }
          }
        }
      }
    }

    // Pasar otros mensajes al callback original si existe
    _originalCallback?.call(data);
  }

  void _actualizarUbicacionAmbulancia(double lat, double lng) async {
    if (!mounted) return;

    final ahora = DateTime.now();
    
    // Guardar la primera ubicación recibida (por si llega antes del cambio de estado)
    if (_primeraUbicacionLat == null && _primeraUbicacionLng == null) {
      _primeraUbicacionLat = lat;
      _primeraUbicacionLng = lng;
      print('[DEBUG] Primera ubicación recibida: lat=$lat, lng=$lng');
    }
    
    // Guardar ubicación de despacho si es la primera vez que recibimos ubicación
    // y el estado es AMBULANCIA_ASIGNADA (hacer esto fuera del setState)
    if (!_ubicacionDespachoGuardada) {
      await _guardarUbicacionDespacho(lat, lng);
    }

    setState(() {
      // Calcular velocidad si tenemos un punto anterior
      if (_ultimaLat != null &&
          _ultimaLng != null &&
          _ultimoTimestamp != null) {
        // Calcular distancia entre el punto anterior y el actual
        final distanciaEntrePuntos = _distance.as(
          LengthUnit.Meter,
          LatLng(_ultimaLat!, _ultimaLng!),
          LatLng(lat, lng),
        );

        // Acumular desplazamiento total
        _desplazamientoTotal += distanciaEntrePuntos;

        // Calcular tiempo transcurrido en segundos
        final tiempoTranscurrido =
            ahora.difference(_ultimoTimestamp!).inMilliseconds / 1000.0;

        // Calcular velocidad en m/s (solo si el tiempo es mayor a 0)
        if (tiempoTranscurrido > 0) {
          _velocidadMs = distanciaEntrePuntos / tiempoTranscurrido;
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
        _tiempoEstimado =
            minutos <= 1 ? 'Menos de 1 minuto' : '$minutos minutos';
      } else {
        _tiempoEstimado = 'Calculando...';
      }

      // Verificar si está a menos de 30 metros
      if (distancia < 30 && !_ambulanciaLlego) {
        _ambulanciaLlego = true;
        _finalizarSeguimiento();
      }

      // Centrar cámara en la ambulancia solo la primera vez
      if (_ambulanciaLat != null &&
          _ambulanciaLng != null &&
          !_yaSeCentroEnAmbulancia) {
        _yaSeCentroEnAmbulancia = true;
        _mapController.move(
          LatLng(_ambulanciaLat!, _ambulanciaLng!),
          16.0,
        );
      }
    });
  }

  Future<void> _guardarUbicacionDespacho(double lat, double lng) async {
    if (_ubicacionDespachoGuardada) return;
    
    // Guardar la primera ubicación recibida después de que el estado sea AMBULANCIA_ASIGNADA
    // Usar el flag _estadoDespachado que se actualiza cuando se recibe el cambio de estado
    if (_estadoDespachado) {
      await _storage.saveUbicacionDespachoAmbulancia(lat, lng);
      _ubicacionDespachoGuardada = true;
      print('[DEBUG] Ubicación de despacho guardada: lat=$lat, lng=$lng');
    }
  }

  Future<void> _finalizarSeguimiento() async {
    // Obtener id de emergencia antes de limpiar
    final emergenciaActiva = await _storage.getEmergenciaActiva();
    final idEmergencia = emergenciaActiva?['id_emergencia'] as int? ??
        emergenciaActiva?['id'] as int?;

    // Imprimir estadísticas en consola
    _imprimirEstadisticas(emergenciaActiva);

    // Enviar mensaje de emergencia finalizada al servidor
    if (idEmergencia != null && idEmergencia > 0) {
      widget.wsService.enviarMensaje({
        'tipo': 'emergencia_finalizada',
        'id_emergencia': idEmergencia,
      });
    } else {
      // No se pudo obtener id de emergencia para enviar mensaje
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

    if (mounted) {
      setState(() {});
    }
  }

  void _imprimirEstadisticas(Map<String, dynamic>? emergenciaActiva) {
    print('═══════════════════════════════════════════════════════════');
    print('📊 ESTADÍSTICAS DE LA EMERGENCIA');
    print('═══════════════════════════════════════════════════════════');
    
    // Hora de inicio de la solicitud
    final fechaInicio = emergenciaActiva?['fecha'] as DateTime?;
    if (fechaInicio != null) {
      print('🕐 Hora de inicio de la solicitud: ${fechaInicio.toString()}');
    } else {
      print('🕐 Hora de inicio de la solicitud: No disponible');
    }
    
    // Hora de notificación valorada
    final horaValorada = emergenciaActiva?['hora_valorada'] as DateTime?;
    if (horaValorada != null) {
      print('⚕️ Hora de notificación VALORADA: ${horaValorada.toString()}');
    } else {
      // Si no está disponible, usar la hora del sistema como fallback
      // (aunque idealmente debería estar guardada)
      final horaFallback = DateTime.now();
      print('⚕️ Hora de notificación VALORADA: No disponible (usando hora actual: ${horaFallback.toString()})');
    }
    
    // Hora de notificación despachada
    final horaDespachada = emergenciaActiva?['hora_despachada'] as DateTime?;
    if (horaDespachada != null) {
      print('🚑 Hora de notificación DESPACHADA: ${horaDespachada.toString()}');
    } else {
      // Si no está disponible, usar la hora del sistema como fallback
      // (aunque idealmente debería estar guardada)
      final horaFallback = DateTime.now();
      print('🚑 Hora de notificación DESPACHADA: No disponible (usando hora actual: ${horaFallback.toString()})');
    }
    
    // Hora de llegada de la ambulancia
    final horaLLegada = DateTime.now();
    print('✅ Hora de llegada de la ambulancia: ${horaLLegada.toString()}');
    
    // Ubicación de la solicitud
    final latSolicitud = emergenciaActiva?['latitud'] as double?;
    final lngSolicitud = emergenciaActiva?['longitud'] as double?;
    if (latSolicitud != null && lngSolicitud != null) {
      print('📍 Ubicación de la solicitud: Lat: $latSolicitud, Lng: $lngSolicitud');
    } else {
      print('📍 Ubicación de la solicitud: No disponible');
    }
    
    // Ubicación de la ambulancia cuando fue despachada
    final latDespacho = emergenciaActiva?['ubicacion_despacho_lat'] as double?;
    final lngDespacho = emergenciaActiva?['ubicacion_despacho_lng'] as double?;
    if (latDespacho != null && lngDespacho != null) {
      print('🚑 Ubicación de la ambulancia cuando fue despachada: Lat: $latDespacho, Lng: $lngDespacho');
    } else {
      print('🚑 Ubicación de la ambulancia cuando fue despachada: No disponible');
    }
    
    // Desplazamiento total
    if (_desplazamientoTotal > 0) {
      final desplazamientoKm = _desplazamientoTotal / 1000.0;
      print('📏 Desplazamiento total de la ambulancia: ${_desplazamientoTotal.toStringAsFixed(2)} m (${desplazamientoKm.toStringAsFixed(2)} km)');
    } else {
      print('📏 Desplazamiento total de la ambulancia: No disponible');
    }
    
    print('═══════════════════════════════════════════════════════════');
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                          if (_ambulanciaLat != null &&
                              _ambulanciaLng != null) ...[
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
