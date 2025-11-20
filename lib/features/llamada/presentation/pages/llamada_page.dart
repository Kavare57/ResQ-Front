import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;

import '../../../../core/constants/colors.dart';
import '../../../../routes.dart';

class LlamadaPage extends StatefulWidget {
  final Map<String, dynamic> credenciales; // {room, token, identity, server_url}

  const LlamadaPage({
    Key? key,
    required this.credenciales,
  }) : super(key: key);

  @override
  State<LlamadaPage> createState() => _LlamadaPageState();
}

class _LlamadaPageState extends State<LlamadaPage> {
  late livekit.Room _room;
  bool _isAudioEnabled = false;
  bool _isConnected = false;
  String _estado = 'Presiona conectar para iniciar';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // NO conectar automáticamente - esperar a que el usuario presione el botón
    print('[LLAMADA] Esperando que el usuario inicie la conexión');
  }

  Future<void> _conectarALlamada() async {
    try {
      setState(() {
        _estado = 'Conectando a sala...';
        _errorMessage = null;
      });

      print('[LLAMADA] Inicializando Room...');
      _room = livekit.Room();

      // Extraer credenciales
      final String serverUrl = widget.credenciales['server_url'];
      final String token = widget.credenciales['token'];

      print('[LLAMADA] Server URL: $serverUrl');
      print('[LLAMADA] Token: ${token.substring(0, 20)}...');
      print('[LLAMADA] Intentando conectar...');

      // Conectar a la sala con manejo específico de errores
      try {
        // Añadir pequeño delay para que el UI se actualice primero
        await Future.delayed(const Duration(milliseconds: 500));
        
        await _room.connect(
          serverUrl,
          token,
          connectOptions: livekit.ConnectOptions(
            autoSubscribe: false,
          ),
        );
        
        print('[LLAMADA] Conexión exitosa');
        
        if (!mounted) return;
        setState(() {
          _isConnected = true;
          _estado = 'Conectado con CRUE';
          _isAudioEnabled = false;
        });
        print('[LLAMADA] Estado actualizado');
      } on PlatformException catch (pe) {
        print('[LLAMADA] PlatformException: ${pe.code} - ${pe.message}');
        throw 'Error de plataforma: ${pe.message}';
      } catch (connectError) {
        print('[LLAMADA] Error en connect(): $connectError');
        print('[LLAMADA] Stack trace: $connectError');
        rethrow;
      }
    } catch (e) {
      print('[LLAMADA] Error general: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _estado = 'Error al conectar';
      });
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final isEnabled = await _room.localParticipant?.isMicrophoneEnabled() ?? false;
      
      // Si va a habilitar, pedir permisos primero
      if (!isEnabled) {
        // Pequeño retraso para asegurar que los permisos estén listos
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await _room.localParticipant?.setMicrophoneEnabled(!isEnabled);
      setState(() {
        _isAudioEnabled = !isEnabled;
        if (!isEnabled) {
          _estado = 'Micrófono activado';
        } else {
          _estado = 'Micrófono desactivado';
        }
      });
    } catch (e) {
      print('Error toggling audio: $e');
      setState(() {
        _errorMessage = 'Error al cambiar micrófono: $e';
      });
    }
  }

  Future<void> _finalizarLlamada() async {
    try {
      print('[LLAMADA] Finalizando llamada...');
      
      // Iniciar desconexión de forma asincrónica sin esperar
      if (_isConnected) {
        print('[LLAMADA] Desconectando de LiveKit...');
        
        // Ejecutar la desconexión en background sin bloquear
        _room.disconnect().then((_) {
          print('[LLAMADA] Desconexión completada en background');
        }).catchError((e) {
          print('[LLAMADA] Error en desconexión background: $e');
        });
      }
      
      // Esperar un poco para que comience la desconexión
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        print('[LLAMADA] Navegando al home...');
        // Navegar al home del solicitante y limpiar la pila de navegación
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.homeSolicitante,
          (route) => false,
        );
      }
    } catch (e) {
      print('[LLAMADA] Error finalizando llamada: $e');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.homeSolicitante,
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    if (_isConnected) {
      try {
        _room.dispose();
      } catch (e) {
        print('[LLAMADA] Error al disposar room: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _finalizarLlamada();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _errorMessage != null
            ? _buildErrorWidget()
            : _buildCallInterface(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Error en la llamada',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ResQColors.primary500,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCallInterface() {
    return Stack(
      children: [
        // Fondo oscuro
        Container(
          color: Colors.black,
          child: Center(
            child: _isConnected
                ? const Icon(
                    Icons.call,
                    color: Colors.white24,
                    size: 120,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_errorMessage == null)
                        Column(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.white60,
                              size: 80,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Centro Regulador de Urgencias',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Toca el botón para conectar',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            const SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _estado,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ),

        // Header con información de la llamada
        if (_isConnected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.only(
                top: 24,
                left: 16,
                right: 16,
                bottom: 24,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_in_talk,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Llamada con CRUE',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Solo Audio',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Controles en la parte inferior
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black87,
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 32,
              top: 40,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Estado del audio
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isAudioEnabled
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isAudioEnabled ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAudioEnabled
                              ? Icons.mic
                              : Icons.mic_off,
                          color: _isAudioEnabled
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAudioEnabled
                              ? 'Micrófono activado'
                              : 'Micrófono desactivado',
                          style: TextStyle(
                            color: _isAudioEnabled
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones de control
                  if (_isConnected)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botón de audio
                        FloatingActionButton(
                          onPressed: _toggleAudio,
                          backgroundColor: _isAudioEnabled
                              ? ResQColors.primary500
                              : Colors.grey[700],
                          tooltip: _isAudioEnabled
                              ? 'Desactivar micrófono'
                              : 'Activar micrófono',
                          child: Icon(
                            _isAudioEnabled ? Icons.mic : Icons.mic_off,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Botón de colgar
                        FloatingActionButton(
                          onPressed: () {
                            _finalizarLlamada();
                          },
                          backgroundColor: Colors.red[700],
                          tooltip: 'Terminar llamada',
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    )
                  else if (_errorMessage == null)
                    FloatingActionButton(
                      onPressed: _conectarALlamada,
                      backgroundColor: ResQColors.primary500,
                      tooltip: 'Conectar con CRUE',
                      child: const Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton(
                          onPressed: () {
                            _conectarALlamada();
                          },
                          backgroundColor: ResQColors.primary500,
                          tooltip: 'Reintentar conexión',
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 24),
                        FloatingActionButton(
                          onPressed: () {
                            _finalizarLlamada();
                          },
                          backgroundColor: Colors.red[700],
                          tooltip: 'Cerrar',
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
