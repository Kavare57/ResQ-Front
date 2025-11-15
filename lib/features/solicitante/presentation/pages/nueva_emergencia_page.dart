import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/emergencias_api.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/env.dart';
import '../../../../routes.dart';

class NuevaEmergenciaPage extends StatefulWidget {
  final String nombrePacientePorDefecto;

  const NuevaEmergenciaPage({
    super.key,
    this.nombrePacientePorDefecto = 'Paciente',
  });

  @override
  State<NuevaEmergenciaPage> createState() => _NuevaEmergenciaPageState();
}

class _NuevaEmergenciaPageState extends State<NuevaEmergenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  static const LatLng _defaultCenter = LatLng(4.710989, -74.07209);
  GoogleMapController? _mapController;

  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.nombrePacientePorDefecto;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _direccionCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _usarMiUbicacion() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      // TODO: integrar geolocator / permisos reales.
      // Esto es un valor ficticio para pruebas:
      await Future.delayed(const Duration(seconds: 1));
      const fakePosition = LatLng(10.4000, -75.5000);
      _updateSelectedPosition(fakePosition);
      await _animateCameraTo(fakePosition, zoom: 16);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo obtener tu ubicacion';
      });
    } finally {
      if (!mounted) return;
      setState(() => _locating = false);
    }
  }

  LatLng get _mapTarget =>
      (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : _defaultCenter;

  Set<Marker> get _markers {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return {};

    final selected = LatLng(lat, lng);
    return {
      Marker(
        markerId: const MarkerId('selected-location'),
        position: selected,
        draggable: true,
        onDragEnd: _updateSelectedPosition,
      ),
    };
  }

  void _updateSelectedPosition(LatLng position) {
    if (!mounted) return;
    setState(() {
      _lat = position.latitude;
      _lng = position.longitude;
      _error = null;
    });
  }

  Future<void> _animateCameraTo(LatLng target, {double? zoom}) async {
    final controller = _mapController;
    if (controller == null) return;

    final update = zoom != null
        ? CameraUpdate.newLatLngZoom(target, zoom)
        : CameraUpdate.newLatLng(target);
    await controller.animateCamera(update);
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

    if (Env.googleMapsApiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Configura la clave de Google Maps antes de buscar.';
      });
      return;
    }

    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'address': query,
          'key': Env.googleMapsApiKey,
          'language': 'es',
          'region': 'co',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Google Maps error ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'No se encontraron resultados para esa direccion.';
        });
        return;
      }

      final firstResult = results.first as Map<String, dynamic>;
      final geometry = firstResult['geometry'] as Map<String, dynamic>;
      final location = geometry['location'] as Map<String, dynamic>;
      final target = LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      );

      _updateSelectedPosition(target);
      await _animateCameraTo(target, zoom: 16);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo buscar la direccion ingresada.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _locating = false);
    }
  }

  Future<void> _enviarYLLamar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      setState(() {
        _error = 'Por favor selecciona una ubicacion antes de continuar.';
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final api = EmergenciasApi();

      final sala = await api.solicitarAmbulancia(
        lat: _lat!,
        lng: _lng!,
        nombrePaciente: _nombreCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
      );

      // sala['room'], sala['token'], sala['identity'], sala['server_url']

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergencia registrada. Conectando con operador...'),
        ),
      );

      // Navegar a la pantalla de llamada
      Navigator.pushNamed(
        context,
        AppRoutes.llamada,
        arguments: sala,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrio un error al registrar la emergencia.';
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _mapTarget,
                            zoom: (_lat != null && _lng != null) ? 15.5 : 12,
                          ),
                          onMapCreated: (controller) {
                            _mapController ??= controller;
                          },
                          onTap: _updateSelectedPosition,
                          markers: _markers,
                          myLocationButtonEnabled: false,
                          myLocationEnabled: false,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toca el mapa para colocar el pin o escribe una dirección para centrarlo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
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

              const Text(
                'Nombre del paciente',
                style: TextStyle(color: Colors.grey),
              ),
              TextFormField(
                controller: _nombreCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                decoration: const InputDecoration(
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ResQColors.primary500),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Descripción / información médica',
                style: TextStyle(color: Colors.grey),
              ),
              TextFormField(
                controller: _descripcionCtrl,
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Describe la situación' : null,
                decoration: const InputDecoration(
                  hintText:
                      'Ejemplo: dificultad para respirar, antecedentes, alergias…',
                  alignLabelWithHint: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: ResQColors.primary500),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ResQColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _sending ? null : _enviarYLLamar,
                  child: _sending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Llamar al operador',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
