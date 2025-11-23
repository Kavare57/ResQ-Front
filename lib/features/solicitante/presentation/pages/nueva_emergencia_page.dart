import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../core/api/emergencias_api.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/permissions_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/solicitante_websocket_service.dart';
import '../../../../core/services/error_handler.dart';
import '../../../../core/widgets/error_display_widget.dart';
import '../../../llamada/presentation/pages/llamada_page.dart';

class NuevaEmergenciaPage extends StatefulWidget {
  const NuevaEmergenciaPage({
    super.key,
  });

  @override
  State<NuevaEmergenciaPage> createState() => _NuevaEmergenciaPageState();
}

class _NuevaEmergenciaPageState extends State<NuevaEmergenciaPage> {
  final _direccionCtrl = TextEditingController();
  late MapController _mapController;
  final _wsService = SolicitanteWebSocketService();

  // Ubicación por defecto: Bogotá, Colombia
  static const double defaultLat = 4.710989;
  static const double defaultLng = -74.07209;

  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Inicializar con ubicación por defecto
    _lat = defaultLat;
    _lng = defaultLng;
    
    // Obtener ubicación del LocationService (precisa si está lista, última conocida si no)
    _loadLocationFromService();
  }

  Future<void> _loadLocationFromService() async {
    final locationService = LocationService();
    final position = locationService.getCurrentLocation();
    
    if (position != null) {
      final userPosition = LatLng(position.latitude, position.longitude);
      _updateSelectedPosition(userPosition);
      
      // Centrar el mapa en la ubicación obtenida
      if (mounted) {
        // Pequeño delay para asegurar que el mapa esté listo
        await Future.delayed(const Duration(milliseconds: 300));
        _mapController.move(userPosition, 16);
      }
      
      print('[NUEVA_EMERGENCIA] Ubicación cargada del servicio: ${position.latitude}, ${position.longitude}');
      
      // Si no hay ubicación precisa aún, continuar obteniéndola en segundo plano
      if (!locationService.hasPreciseLocation()) {
        print('[NUEVA_EMERGENCIA] Ubicación precisa aún no disponible, continuando obtención en segundo plano...');
        locationService.initialize().catchError((e) {
          print('[NUEVA_EMERGENCIA] Error obteniendo ubicación precisa: $e');
        });
      }
    } else {
      print('[NUEVA_EMERGENCIA] No hay ubicación disponible en el servicio, usando ubicación por defecto');
      // Intentar inicializar el servicio si no se ha hecho
      locationService.initialize().catchError((e) {
        print('[NUEVA_EMERGENCIA] Error inicializando LocationService: $e');
      });
    }
  }

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _mapController.dispose();
    // NO desconectar el websocket aquí - debe permanecer conectado para recibir actualizaciones
    // _wsService.desconectar();
    super.dispose();
  }

  Future<void> _usarMiUbicacion() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      final locationService = LocationService();
      
      // Actualizar la ubicación usando el servicio
      final position = await locationService.updateLocation();
      
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo obtener la ubicación. Por favor, verifica que el GPS esté activado y los permisos estén otorgados.';
        });
        return;
      }

      final userPosition = LatLng(position.latitude, position.longitude);
      _updateSelectedPosition(userPosition);
      
      // Animar la cámara al punto seleccionado con zoom adecuado
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        _mapController.move(userPosition, 16);
      }
      
      print('[UBICACION] Ubicación actualizada: ${position.latitude}, ${position.longitude}');
    } catch (e, stackTrace) {
      ErrorHandler.logError('[UBICACION]', e, stackTrace);
      if (!mounted) return;
      setState(() {
        String errorMsg = ErrorHandler.getErrorMessage(e);
        if (errorMsg.contains('timeout') || errorMsg.contains('Timeout')) {
          _error = 'Tiempo de espera agotado. Por favor, verifica que el GPS esté activado e intenta nuevamente.';
        } else if (errorMsg.contains('DeadSystem') || errorMsg.contains('DeadSystemException')) {
          _error = 'Error del sistema de ubicación. Por favor, reinicia la aplicación o selecciona tu ubicación manualmente en el mapa.';
        } else {
          _error = 'Error al obtener ubicación: $errorMsg. Puedes seleccionar tu ubicación manualmente en el mapa.';
        }
      });
    } finally {
      if (!mounted) return;
      setState(() => _locating = false);
    }
  }

  void _updateSelectedPosition(LatLng position) {
    if (!mounted) return;
    setState(() {
      _lat = position.latitude;
      _lng = position.longitude;
      _error = null;
    });
  }

  Future<void> _buscarDireccion() async {
    final query = _direccionCtrl.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Ingresa una direccion para buscar.';
      });
      return;
    }

    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      // Usar Nominatim (OpenStreetMap) - Completamente gratuito
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'json',
          'limit': '1',
          'countrycodes': 'co', // Limitar a Colombia
          'accept-language': 'es',
        },
      );

      print('[BUSCAR] URL: $uri');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'ResQ-App/1.0',
        },
      ).timeout(const Duration(seconds: 12));

      print('[BUSCAR] Status: ${response.statusCode}');
      print('[BUSCAR] Response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
            'Nominatim error ${response.statusCode}: ${response.body}');
      }

      final results = jsonDecode(response.body) as List<dynamic>?;

      if (results == null || results.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error =
              'No se encontraron resultados para "$query".\nIntenta con: Barrio, Dirección, Calle...';
        });
        return;
      }

      final firstResult = results.first as Map<String, dynamic>;
      final lat = double.parse(firstResult['lat'].toString());
      final lng = double.parse(firstResult['lon'].toString());
      final displayName =
          firstResult['display_name'] as String? ?? 'Ubicación encontrada';

      print('[BUSCAR] Encontrado: $displayName - Lat: $lat, Lng: $lng');

      final position = LatLng(lat, lng);
      _updateSelectedPosition(position);

      // Animar la cámara al punto buscado
      _mapController.move(position, 16);

      if (!mounted) return;
      setState(() {
        _error = null;
      });
    } catch (e, stackTrace) {
      ErrorHandler.logError('[BUSCAR-UBICACION]', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getErrorMessage(e);
      });
    } finally {
      if (!mounted) return;
      setState(() => _locating = false);
    }
  }

  Future<void> _enviarYLLamar() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      // Obtener la ubicación más precisa disponible del LocationService
      final locationService = LocationService();
      final position = locationService.getCurrentLocation();
      
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo obtener la ubicación. Por favor, espera un momento o selecciona tu ubicación manualmente en el mapa.';
        });
        return;
      }

      // Usar la ubicación del servicio (precisa si está lista, última conocida si no)
      final lat = position.latitude;
      final lng = position.longitude;
      
      // Actualizar también las variables locales para mantener consistencia
      _updateSelectedPosition(LatLng(lat, lng));
      
      print('[EMERGENCIA] Usando ubicación: $lat, $lng (precisa: ${locationService.hasPreciseLocation()})');

      // Solicitar permisos para la llamada
      print('[EMERGENCIA] Solicitando permisos de micrófono y cámara...');
      final hasPermissions = await PermissionsService.requestCallPermissions();

      if (!hasPermissions && !mounted) return;

      final api = EmergenciasApi();

      final sala = await api.solicitarAmbulancia(
        lat: lat,
        lng: lng,
      );

      print('[NUEVA_EMERGENCIA] Respuesta recibida:');
      print('[NUEVA_EMERGENCIA] room: ${sala['room']}');
      print('[NUEVA_EMERGENCIA] token: ${sala['token']?.substring(0, 20)}...');
      print('[NUEVA_EMERGENCIA] identity: ${sala['identity']}');
      print('[NUEVA_EMERGENCIA] server_url: ${sala['server_url']}');
      print('[NUEVA_EMERGENCIA] Credenciales completas: $sala');

      // Guardar id_solicitud cuando se recibe la respuesta
      final idSolicitud = sala['id_solicitud'];
      if (idSolicitud != null) {
        final storage = StorageService();
        final idFinal = idSolicitud is int ? idSolicitud : int.parse(idSolicitud.toString());
        await storage.saveIdSolicitud(idFinal);
        print('[NUEVA_EMERGENCIA] ID de solicitud guardado: $idFinal');
      }

      // Conectar al WebSocket del solicitante (NO se desconecta al colgar)
      try {
        final storage = StorageService();
        final idSolicitante = await storage.getPersonaId();
        if (idSolicitante != null && idSolicitante > 0) {
          print('[NUEVA_EMERGENCIA] Conectando al WebSocket del solicitante: $idSolicitante');
          await _wsService.conectar(idSolicitante);
        } else {
          print('[NUEVA_EMERGENCIA] No se pudo obtener id_solicitante para WebSocket');
        }
      } catch (e) {
        print('[NUEVA_EMERGENCIA] Error conectando al WebSocket: $e');
        // No bloquear el flujo si falla el WebSocket
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergencia registrada. Conectando con operador...'),
        ),
      );

      // No necesitamos guardar el ID aquí, se recibirá por websocket

      // Navegar a la pantalla de llamada
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LlamadaPage(credenciales: sala),
        ),
      );
    } catch (e, stackTrace) {
      ErrorHandler.logError('[CREAR-EMERGENCIA]', e, stackTrace);
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getErrorMessage(e);
      });
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQColors.surface,
      appBar: AppBar(
        backgroundColor: ResQColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nueva emergencia',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // ---- MAPA ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ResQColors.primary50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ingresa tu ubicación manualmente',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _direccionCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _buscarDireccion(),
                        decoration: InputDecoration(
                          hintText: 'Busca por dirección, barrio o referencia',
                          prefixIcon: const Icon(Icons.place_outlined),
                          suffixIcon: _locating
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  onPressed: _buscarDireccion,
                                  icon: const Icon(Icons.search),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ========== MAPA INTERACTIVO ==========
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 280,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    _lat ?? defaultLat,
                                    _lng ?? defaultLng,
                                  ),
                                  initialZoom: 13.0,
                                  minZoom: 5.0,
                                  maxZoom: 18.0,
                                  onTap: (tapPosition, latLng) {
                                    _updateSelectedPosition(latLng);
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.resq_app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      if (_lat != null && _lng != null)
                                        Marker(
                                          point: LatLng(_lat!, _lng!),
                                          width: 40,
                                          height: 40,
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: ResQColors.primary500,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: ResQColors
                                                          .primary500
                                                          .withOpacity(0.5),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.location_on,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              // Pin centrado en pantalla (visual feedback)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 40),
                                    child: Icon(
                                      Icons.add_circle_outline,
                                      color: ResQColors.primary500
                                          .withOpacity(0.3),
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Toca el mapa para seleccionar ubicación',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          if (_lat != null && _lng != null)
                            Text(
                              '✓ ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ResQColors.primary500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      // ===================================
                      const SizedBox(height: 12),
                      // Ubicación seleccionada - info adicional
                      if (_lat != null && _lng != null)
                        Container(
                          decoration: BoxDecoration(
                            color: ResQColors.primary50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ResQColors.primary200,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: ResQColors.primary500,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ubicación seleccionada correctamente',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ResQColors.primary500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _locating ? null : _usarMiUbicacion,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Usar mi ubicación actual'),
                  ),
                ),
                if (_lat != null && _lng != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Ubicación seleccionada: (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Botón de llamar posicionado para cumplir con ley FITS
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ResQColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _sending ? null : _enviarYLLamar,
                    child: _sending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Llamar al operador',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ErrorDisplayWidget(
                      errorMessage: _error!,
                      showRetryButton: false,
                      onDismiss: () {
                        setState(() {
                          _error = null;
                        });
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
