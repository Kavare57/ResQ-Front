import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'dart:async';

import '../../../../core/constants/colors.dart';
import '../../../../core/services/error_handler.dart';
import '../../../../core/widgets/error_display_widget.dart';

class LlamadaPage extends StatefulWidget {
  final Map<String, dynamic>
      credenciales; // {room, token, identity, server_url}

  const LlamadaPage({
    super.key,
    required this.credenciales,
  });

  @override
  State<LlamadaPage> createState() => _LlamadaPageState();
}

class _LlamadaPageState extends State<LlamadaPage> {
  late livekit.Room _room;
  late livekit.EventsListener<livekit.RoomEvent> _listener;
  bool _isAudioEnabled = false;
  bool _isConnected = false;
  bool _sdkInitialized = false;
  String _estado = 'Presiona conectar para iniciar';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // SOLO inicializar el SDK, no conectar
    _inicializarSDK();
  }

  Future<void> _inicializarSDK() async {
    try {
      if (_sdkInitialized) {
        print('[LLAMADA] SDK ya está inicializado');
        return;
      }

      print('[LLAMADA] Inicializando LiveKitClient...');
      await livekit.LiveKitClient.initialize(
        bypassVoiceProcessing: true,
      );
      print(
          '[LLAMADA] ✅ LiveKitClient inicializado con bypassVoiceProcessing=true');

      if (mounted) {
        setState(() {
          _sdkInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-SDK-INIT]', e, stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = ErrorHandler.getErrorMessage(e);
          _estado = 'Error';
        });
      }
    }
  }

  Future<void> _conectarALlamada() async {
    try {
      // Primero asegurar que el SDK está inicializado
      if (!_sdkInitialized) {
        print('[LLAMADA] SDK no inicializado, inicializando primero...');
        await _inicializarSDK();
        if (!_sdkInitialized) {
          throw Exception('No se pudo inicializar el SDK');
        }
      }

      setState(() {
        _estado = 'Conectando...';
      });

      // Extraer credenciales
      final String serverUrl = widget.credenciales['server_url'];
      final String token = widget.credenciales['token'];

      print('\n${'═' * 70}');
      print('[LLAMADA] 🔌 INICIANDO CONEXIÓN A LIVEKIT');
      print('═' * 70);
      print('[LLAMADA] Server URL: $serverUrl');
      print('[LLAMADA] Token length: ${token.length} chars\n');

      // Crear room
      print('[LLAMADA] [1] Creando Room...');
      _room = livekit.Room();
      print('[LLAMADA] [1a] Room creado');

      // Crear listener
      print('[LLAMADA] [1b] Creando listener...');
      _listener = _room.createListener();
      print('[LLAMADA] [1c] Listener creado');

      // Escuchar evento de conexión exitosa
      _listener.on<livekit.RoomConnectedEvent>((event) {
        print('[LLAMADA] ✅ RoomConnectedEvent recibido!');
      });

      _listener.on<livekit.RoomDisconnectedEvent>((event) {
        print('[LLAMADA] ❌ RoomDisconnectedEvent: ${event.reason}');
      });

      print('[LLAMADA] [2] Iniciando conexión...');
      print('[LLAMADA] [2a] URL: $serverUrl');
      print('[LLAMADA] [2b] Token válido: ${token.isNotEmpty}');

      // Intentar conectar sin options primero - simple approach
      print('[LLAMADA] [2c] Llamando a connect() sin options...');

      // NO esperar al Future directamente - usar polling del estado
      print('[LLAMADA] [2c1] Iniciando connect() sin esperar...');
      _room.connect(serverUrl, token);
      print('[LLAMADA] [2c2] Connect iniciado, ahora haciendo polling...');

      // Monitorear el estado de la conexión con polling
      bool connected = false;
      int pollCount = 0;
      const int maxPolls = 16; // 8 segundos con 500ms de intervalo
      const Duration pollInterval = Duration(milliseconds: 500);

      // Iniciar polling en background
      while (pollCount < maxPolls && !connected) {
        await Future.delayed(pollInterval);
        pollCount++;

        // Verificar si hay un participante local (indicador de conexión)
        try {
          if (_room.localParticipant != null) {
            print(
                '[LLAMADA] [2d] ✅ LocalParticipant detectado (poll #$pollCount)');
            connected = true;
            break;
          }
        } catch (e) {
          print(
              '[LLAMADA] [2c-error-poll] Error verificando localParticipant: $e');
        }

        if (pollCount % 4 == 0) {
          print('[LLAMADA] [polling] Intento $pollCount/$maxPolls');
        }
      }

      if (!connected) {
        print(
            '[LLAMADA] ❌ Timeout en polling: connect() no completó en 8 segundos');
        throw Exception('Timeout en conexión a LiveKit');
      }

      print('[LLAMADA] [2e] Conexión completada!');
      print('[LLAMADA] [3] ✅ Conectado exitosamente!');
      print('${'═' * 70}\n');

      if (!mounted) return;

      setState(() {
        _isConnected = true;
        _estado = 'Conectado con CRUE';
        _isAudioEnabled = false;
      });
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-CONEXION]', e, stackTrace);

      if (!mounted) return;

      final userMessage = ErrorHandler.getErrorMessage(e);
      setState(() {
        _errorMessage = userMessage;
        _estado = 'Error';
      });
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final isEnabled = _room.localParticipant?.isMicrophoneEnabled() ?? false;

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
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-AUDIO]', e, stackTrace);
      setState(() {
        _errorMessage = ErrorHandler.getErrorMessage(e);
      });
    }
  }

  Future<void> _finalizarLlamada() async {
    try {
      print('[LLAMADA] Finalizando llamada...');

      // Detener estado actual
      setState(() {
        _isConnected = false;
        _estado = 'Desconectando...';
      });

      // Desconectar y esperar
      if (_isConnected) {
        print('[LLAMADA] Iniciando desconexión...');
        try {
          await _room.disconnect().timeout(
                const Duration(seconds: 3),
              );
          print('[LLAMADA] Desconexión completada');
        } on TimeoutException {
          print('[LLAMADA] Timeout en disconnect');
        } catch (e) {
          print('[LLAMADA] Error en desconexión: $e');
        }
      }

      // Limpiar listener
      try {
        await _listener.dispose().timeout(
              const Duration(seconds: 2),
            );
        print('[LLAMADA] Listener disposado');
      } on TimeoutException {
        print('[LLAMADA] Timeout en listener.dispose');
      } catch (e) {
        print('[LLAMADA] Error disposing listener: $e');
      }

      // Esperar a que el native plugin se estabilice
      await Future.delayed(const Duration(milliseconds: 500));

      print('[LLAMADA] Pop seguro');
      if (!mounted) {
        print('[LLAMADA] Widget no montado');
        return;
      }

      // Navegar a SeguimientoSolicitudPage en lugar de solo pop
      // Extraer el ID de la solicitud del objeto credenciales
      final solicitud =
          widget.credenciales['solicitud'] as Map<String, dynamic>?;
      final idSolicitud = solicitud?['id'] as int? ?? 0;

      if (!mounted) return;
      if (idSolicitud > 0) {
        Navigator.of(context, rootNavigator: false).pushReplacementNamed(
          '/seguimiento-solicitud',
          arguments: {'idSolicitud': idSolicitud},
        );
      } else {
        print('[LLAMADA] No se pudo obtener ID de solicitud, navigando a pop');
        Navigator.of(context, rootNavigator: false).pop();
      }
    } catch (e) {
      print('[LLAMADA] Error finalizando: $e');
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: false).pop();
        } catch (err) {
          print('[LLAMADA] Error en pop final: $err');
        }
      }
    }
  }

  @override
  void dispose() {
    print('[LLAMADA] Disposing LlamadaPage...');
    try {
      if (_isConnected) {
        try {
          _room.dispose();
        } catch (e) {
          print('[LLAMADA] Error al disposar room: $e');
        }
      }
    } catch (e) {
      print('[LLAMADA] Error en dispose: $e');
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
        body:
            _errorMessage != null ? _buildErrorWidget() : _buildCallInterface(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ErrorDisplayWidget(
              errorMessage: _errorMessage ?? 'Error desconocido',
              showRetryButton: true,
              onRetry: () {
                setState(() {
                  _errorMessage = null;
                  _estado = 'Presiona conectar para iniciar';
                });
              },
              onDismiss: () => Navigator.pop(context),
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
                          _isAudioEnabled ? Icons.mic : Icons.mic_off,
                          color: _isAudioEnabled ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAudioEnabled
                              ? 'Micrófono activado'
                              : 'Micrófono desactivado',
                          style: TextStyle(
                            color: _isAudioEnabled ? Colors.green : Colors.red,
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
