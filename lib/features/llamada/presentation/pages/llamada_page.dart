import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'dart:async';
import 'dart:io';

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
  livekit.Room? _room;
  livekit.EventsListener<livekit.RoomEvent>? _listener;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerEnabled = true; // Altavoz activado por defecto
  bool _hasOperator = false;
  String? _errorMessage;
  Timer? _connectionTimeoutTimer;
  Timer? _audioDetectionTimer;
  bool _isDetectingSound = false;
  double _audioLevel = 0.0; // Nivel de audio (0.0 - 1.0)

  livekit.RemoteParticipant? _operatorParticipant;
  String _operatorName = 'Operador';

  @override
  void initState() {
    super.initState();
    _connectToCall();
  }

  Future<void> _connectToCall() async {
    if (_isConnecting || _isConnected) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      // Inicializar SDK con timeout
      print('[LLAMADA] Inicializando SDK...');
      await livekit.LiveKitClient.initialize(
        bypassVoiceProcessing: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout inicializando SDK de LiveKit');
        },
      );
      print('[LLAMADA] SDK inicializado');

      // Extraer credenciales
      final String serverUrl = widget.credenciales['server_url'] as String;
      final String token = widget.credenciales['token'] as String;
      final String identity =
          widget.credenciales['identity'] as String? ?? 'Solicitante';

      print('[LLAMADA] Conectando a: $serverUrl');
      print('[LLAMADA] Identity: $identity');

      // Validar URL de LiveKit
      try {
        final uri = Uri.parse(serverUrl);
        if (uri.scheme != 'wss' && uri.scheme != 'ws') {
          throw Exception('URL de LiveKit debe usar ws:// o wss://');
        }
        if (uri.host.isEmpty) {
          throw Exception('URL de LiveKit no tiene un host válido');
        }
        print('[LLAMADA] ✅ URL de LiveKit válida: ${uri.scheme}://${uri.host}');

        // Si hay una URL configurada en Env, validar que coincida
        // (opcional, solo para desarrollo/debugging)
        // final envUrl = Env.livekitServerUrl;
        // if (envUrl != null && serverUrl != envUrl) {
        //   print('[LLAMADA] ⚠️ Advertencia: URL recibida ($serverUrl) no coincide con la configurada en Env ($envUrl)');
        // }
      } catch (e) {
        print('[LLAMADA] ❌ Error validando URL de LiveKit: $e');
        throw Exception('URL de LiveKit inválida: $e');
      }

      // Verificar DNS antes de conectar con logging detallado
      try {
        final uri = Uri.parse(serverUrl);
        final host = uri.host;
        final scheme = uri.scheme;
        final port = uri.port;

        print('\n${'═' * 70}');
        print('[LLAMADA] 🔍 VERIFICACIÓN DE DNS');
        print('═' * 70);
        print('[LLAMADA] URL completa: $serverUrl');
        print('[LLAMADA] Host: $host');
        print('[LLAMADA] Scheme: $scheme');
        print('[LLAMADA] Port: $port');
        print('[LLAMADA] Intentando resolver DNS...\n');

        // Intentar resolver el hostname con diferentes tipos
        try {
          // Intentar primero con IPv4
          print('[LLAMADA] Intentando resolución IPv4...');
          final addressesIPv4 = await InternetAddress.lookup(
            host,
            type: InternetAddressType.IPv4,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('[LLAMADA] ⏱️ Timeout en resolución IPv4');
              throw TimeoutException('Timeout resolviendo IPv4 para $host');
            },
          );

          if (addressesIPv4.isNotEmpty) {
            print('[LLAMADA] ✅ DNS IPv4 resuelto correctamente:');
            for (var addr in addressesIPv4) {
              print('[LLAMADA]   - ${addr.address} (${addr.type})');
            }
          } else {
            print('[LLAMADA] ⚠️ No se encontraron direcciones IPv4');
          }
        } catch (e, stackTrace) {
          print('[LLAMADA] ❌ Error en resolución IPv4:');
          print('[LLAMADA]   Tipo: ${e.runtimeType}');
          print('[LLAMADA]   Mensaje: $e');
          print('[LLAMADA]   Stack: $stackTrace');

          // Intentar con IPv6 como fallback
          try {
            print('[LLAMADA] Intentando resolución IPv6 como fallback...');
            final addressesIPv6 = await InternetAddress.lookup(
              host,
              type: InternetAddressType.IPv6,
            ).timeout(const Duration(seconds: 5));

            if (addressesIPv6.isNotEmpty) {
              print('[LLAMADA] ✅ DNS IPv6 resuelto:');
              for (var addr in addressesIPv6) {
                print('[LLAMADA]   - ${addr.address} (${addr.type})');
              }
            }
          } catch (e2) {
            print('[LLAMADA] ❌ Error también en IPv6: $e2');
          }

          // Intentar con tipo ANY como último recurso
          try {
            print('[LLAMADA] Intentando resolución ANY (último recurso)...');
            final addressesAny = await InternetAddress.lookup(host)
                .timeout(const Duration(seconds: 5));

            if (addressesAny.isNotEmpty) {
              print('[LLAMADA] ✅ DNS ANY resuelto:');
              for (var addr in addressesAny) {
                print('[LLAMADA]   - ${addr.address} (${addr.type})');
              }
            } else {
              throw Exception('No se encontraron direcciones para $host');
            }
          } catch (e3) {
            print('[LLAMADA] ❌ Error también en resolución ANY: $e3');
            rethrow; // Re-lanzar el error original
          }
        }

        print('[LLAMADA] ✅ Verificación DNS completada\n');
        print('${'═' * 70}\n');
      } catch (dnsError, stackTrace) {
        print('\n${'═' * 70}');
        print('[LLAMADA] ❌ ERROR CRÍTICO DE DNS');
        print('═' * 70);
        print('[LLAMADA] Tipo de error: ${dnsError.runtimeType}');
        print('[LLAMADA] Mensaje: $dnsError');
        print('[LLAMADA] Stack trace completo:');
        print(stackTrace);
        print(
            '[LLAMADA] ⚠️ Continuando de todas formas - LiveKit puede manejar el error');
        print('${'═' * 70}\n');

        // Continuar de todas formas - LiveKit puede manejar el error mejor
        // pero al menos logueamos el problema detalladamente
      }

      // Crear room
      _room = livekit.Room();
      _listener = _room!.createListener();

      // Configurar listeners ANTES de conectar
      _setupEventListeners();

      // Conectar de forma completamente asíncrona
      print('[LLAMADA] Iniciando conexión...');

      // Usar Future.microtask para ejecutar en el siguiente ciclo del event loop
      // Esto evita que connect() bloquee el hilo principal
      Future.microtask(() async {
        try {
          print('[LLAMADA] Ejecutando connect() en microtask...');

          // Intentar conectar con un timeout más largo que el interno de LiveKit
          // LiveKit tiene un timeout interno de 10s, pero podemos esperar más
          // y verificar si la conexión se estableció a pesar del timeout
          try {
            await _room!
                .connect(serverUrl, token)
                .timeout(const Duration(seconds: 30));
            print('[LLAMADA] Connect() completado exitosamente');
          } on TimeoutException {
            // Si hay timeout, verificar si la conexión se estableció de todas formas
            print(
                '[LLAMADA] ⚠️ Timeout en connect(), verificando estado de conexión...');
            await Future.delayed(const Duration(milliseconds: 500));

            // Verificar si la room está realmente conectada
            // Usar localParticipant como indicador de conexión
            if (_room != null && _room!.localParticipant != null) {
              print(
                  '[LLAMADA] ✅ Conexión establecida a pesar del timeout (localParticipant existe)');
              // No lanzar error, la conexión está activa
              return;
            } else {
              print('[LLAMADA] ❌ Conexión no establecida después del timeout');
              throw TimeoutException(
                'La conexión a LiveKit tardó más de 30 segundos. '
                'Verifica tu conexión a internet.',
                const Duration(seconds: 30),
              );
            }
          }
        } catch (error, stackTrace) {
          // Solo mostrar error si realmente no estamos conectados
          if (_isConnected) {
            print(
                '[LLAMADA] ⚠️ Error en connect() pero ya estamos conectados, ignorando...');
            return;
          }

          print('\n${'═' * 70}');
          print('[LLAMADA] ❌ ERROR EN CONNECT()');
          print('═' * 70);
          print('[LLAMADA] Tipo de error: ${error.runtimeType}');
          print('[LLAMADA] Mensaje completo: $error');
          print('[LLAMADA] Stack trace:');
          print(stackTrace);
          print('${'═' * 70}\n');

          // Detectar específicamente errores de timeout
          String errorMsg = ErrorHandler.getErrorMessage(error);
          final errorString = error.toString().toLowerCase();

          if (error is TimeoutException || errorString.contains('timeout')) {
            errorMsg = 'Timeout conectando a LiveKit.\n\n'
                'La conexión está tardando más de lo esperado.\n\n'
                'Posibles causas:\n'
                '• Conexión a internet lenta o inestable\n'
                '• El servidor LiveKit está sobrecargado\n'
                '• Problemas de red en el emulador/dispositivo\n\n'
                'Intenta:\n'
                '1. Verificar tu conexión a internet\n'
                '2. Reiniciar el emulador con DNS configurado\n'
                '3. Probar en un dispositivo físico\n'
                '4. Intentar nuevamente en unos momentos';
          } else if (errorString
                  .contains('no address associated with hostname') ||
              errorString.contains('failed host lookup') ||
              errorString.contains('getaddrinfo failed') ||
              errorString.contains('socketexception') ||
              errorString.contains('name resolution')) {
            print('[LLAMADA] 🔍 Error identificado como problema de DNS/Red');
            print('[LLAMADA] Detalles adicionales:');
            print('[LLAMADA]   - Error original: $error');
            print('[LLAMADA]   - Tipo: ${error.runtimeType}');

            errorMsg =
                'Error de DNS/Red: No se pudo conectar al servidor LiveKit.\n\n'
                'Detalles del error:\n'
                '• ${error.toString()}\n\n'
                'Posibles soluciones:\n'
                '1. Verifica tu conexión a internet\n'
                '2. Si estás en un emulador:\n'
                '   - Reinicia el emulador con: emulator -avd Medium_Phone -dns-server 8.8.8.8,8.8.4.4\n'
                '   - Verifica que el emulador tenga acceso a internet\n'
                '   - Prueba abriendo el navegador del emulador\n'
                '3. Prueba en un dispositivo físico\n'
                '4. Verifica que el servidor LiveKit esté accesible desde tu red';
          }

          if (mounted) {
            setState(() {
              _errorMessage = errorMsg;
              _isConnecting = false;
            });
          }
        }
      });

      // No esperar aquí - dejar que los eventos manejen la conexión
      // El RoomConnectedEvent actualizará el estado automáticamente
      print('[LLAMADA] Conexión iniciada, esperando eventos...');

      // Configurar un timeout más largo (40 segundos) para conexiones lentas
      // El timeout se cancelará automáticamente cuando se reciba RoomConnectedEvent
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(const Duration(seconds: 40), () {
        if (mounted && !_isConnected && _isConnecting) {
          print(
              '[LLAMADA] ❌ Timeout esperando conexión después de 40 segundos');
          setState(() {
            _errorMessage =
                'Timeout conectando a LiveKit después de 40 segundos.\n\n'
                'La conexión está tomando más tiempo del esperado.\n'
                'Verifica tu conexión a internet y vuelve a intentar.';
            _isConnecting = false;
          });
        }
      });
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-CONEXION]', e, stackTrace);
      print('[LLAMADA] Error en conexión: $e');

      // Limpiar recursos en caso de error
      try {
        _listener?.dispose();
        _room?.dispose();
        _room = null;
        _listener = null;
      } catch (cleanupError) {
        print('[LLAMADA] Error limpiando recursos: $cleanupError');
      }

      if (mounted) {
        setState(() {
          _errorMessage = ErrorHandler.getErrorMessage(e);
          _isConnecting = false;
          _isConnected = false;
        });
      }
    }
  }

  void _setupEventListeners() {
    if (_listener == null || _room == null) return;

    // Escuchar conexión/desconexión
    _listener!.on<livekit.RoomConnectedEvent>((event) {
      print('[LLAMADA] ✅ RoomConnectedEvent recibido - Conexión establecida');
      print(
          '[LLAMADA] LocalParticipant: ${_room!.localParticipant?.identity ?? "null"}');
      print('[LLAMADA] Room name: ${_room!.name}');

      // Cancelar el timeout ya que la conexión fue exitosa
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = null;

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _errorMessage = null; // Limpiar cualquier error previo
        });
        print(
            '[LLAMADA] Estado actualizado: _isConnected=true, _isConnecting=false');

        // Habilitar micrófono automáticamente al conectar
        _enableMicrophoneAutomatically();

        // Iniciar detección de audio cuando se conecta
        _startAudioDetection();
      }
    });

    _listener!.on<livekit.RoomDisconnectedEvent>((event) {
      print('[LLAMADA] ❌ RoomDisconnectedEvent: ${event.reason}');

      // Solo mostrar error si no fue una desconexión intencional
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
          _hasOperator = false;
          _operatorParticipant = null;

          // Mostrar error solo si fue un fallo de conexión
          if (event.reason == livekit.DisconnectReason.joinFailure ||
              event.reason ==
                  livekit.DisconnectReason.signalingConnectionFailure) {
            _errorMessage = 'Error de conexión: ${event.reason}.\n\n'
                'No se pudo establecer la conexión con LiveKit.\n'
                'Verifica tu conexión a internet e intenta nuevamente.';
          }
        });
      }
    });

    // Escuchar participantes remotos (operador)
    _listener!.on<livekit.ParticipantConnectedEvent>((event) {
      final participant = event.participant;
      // Solo procesar participantes remotos (no el local)
      if (participant != _room!.localParticipant) {
        print('[LLAMADA] Operador conectado: ${participant.identity}');
        if (mounted) {
          setState(() {
            _hasOperator = true;
            _operatorParticipant = participant;
            _operatorName = participant.name.isNotEmpty
                ? participant.name
                : (participant.identity.isNotEmpty
                    ? participant.identity
                    : 'Operador');
          });
        }
      }
    });

    _listener!.on<livekit.ParticipantDisconnectedEvent>((event) {
      final participant = event.participant;
      // Solo procesar si es el operador que estaba conectado
      if (participant != _room!.localParticipant &&
          participant == _operatorParticipant) {
        print('[LLAMADA] Operador desconectado');
        if (mounted) {
          setState(() {
            _hasOperator = false;
            _operatorParticipant = null;
          });
        }
      }
    });

    // Escuchar cambios en el estado del micrófono
    _listener!.on<livekit.TrackSubscribedEvent>((event) {
      print('[LLAMADA] Track suscrito: ${event.track.kind}');
    });

    _listener!.on<livekit.TrackUnsubscribedEvent>((event) {
      print('[LLAMADA] Track desuscrito: ${event.track.kind}');
    });

    // Escuchar cambios en los speakers activos para obtener el nivel de audio real
    _listener!.on<livekit.ActiveSpeakersChangedEvent>((event) {
      print('[LLAMADA] 🔊 ActiveSpeakersChangedEvent recibido');
      print('[LLAMADA] Speakers activos: ${event.speakers.length}');

      // Buscar el localParticipant en la lista de speakers activos
      if (_room?.localParticipant != null) {
        final localParticipant = _room!.localParticipant!;
        final audioLevel = localParticipant.audioLevel;
        final isSpeaking = localParticipant.isSpeaking;

        print(
            '[LLAMADA] 🔊 LocalParticipant - audioLevel: $audioLevel, isSpeaking: $isSpeaking');

        // Actualizar el estado con el nivel de audio real
        if (mounted) {
          setState(() {
            _audioLevel = audioLevel;
            // Considerar que hay sonido si el nivel es mayor a 0.01 (umbral mínimo)
            _isDetectingSound =
                isSpeaking && audioLevel > 0.01 && _isMicrophoneEnabled;
          });
        }

        print(
            '[LLAMADA] Audio level actualizado: $audioLevel, isSpeaking: $isSpeaking');
      } else {
        print(
            '[LLAMADA] ⚠️ No hay localParticipant en ActiveSpeakersChangedEvent');
      }
    });
  }

  Future<void> _enableMicrophoneAutomatically() async {
    try {
      if (_room?.localParticipant == null) {
        print(
            '[LLAMADA] ⚠️ No hay localParticipant, no se puede habilitar micrófono');
        return;
      }

      // Esperar un poco para asegurar que el participante esté completamente inicializado
      await Future.delayed(const Duration(milliseconds: 500));

      final isEnabled = _room!.localParticipant!.isMicrophoneEnabled();
      print('[LLAMADA] Estado actual del micrófono: $isEnabled');

      if (!isEnabled) {
        print('[LLAMADA] Habilitando micrófono automáticamente...');
        await _room!.localParticipant!.setMicrophoneEnabled(true);

        // Verificar que realmente se habilitó
        await Future.delayed(const Duration(milliseconds: 200));
        final nowEnabled = _room!.localParticipant!.isMicrophoneEnabled();
        print('[LLAMADA] ✅ Micrófono habilitado. Verificación: $nowEnabled');

        // Verificar tracks de audio
        final audioTracks = _room!.localParticipant!.audioTrackPublications;
        print('[LLAMADA] Tracks de audio publicados: ${audioTracks.length}');
        for (var track in audioTracks) {
          print('[LLAMADA]   - Track: ${track.name}, kind: ${track.kind}');
        }
      } else {
        print('[LLAMADA] Micrófono ya estaba habilitado');
      }

      if (mounted) {
        setState(() {
          _isMicrophoneEnabled = true;
        });
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-ENABLE-MIC]', e, stackTrace);
      print('[LLAMADA] ❌ Error habilitando micrófono automáticamente: $e');
    }
  }

  Future<void> _toggleMicrophone() async {
    try {
      if (_room?.localParticipant == null) return;

      final isEnabled = _room!.localParticipant!.isMicrophoneEnabled();
      await _room!.localParticipant!.setMicrophoneEnabled(!isEnabled);

      if (mounted) {
        setState(() {
          _isMicrophoneEnabled = !isEnabled;
          // Si se desactiva el micrófono, detener la detección de sonido
          if (isEnabled) {
            _isDetectingSound = false;
            _audioLevel = 0.0;
          }
        });
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-MIC]', e, stackTrace);
    }
  }

  void _startAudioDetection() {
    // Cancelar timer anterior si existe
    _audioDetectionTimer?.cancel();

    // Verificar audio cada 50ms para una respuesta muy fluida
    // Usamos polling como respaldo, pero el evento ActiveSpeakersChangedEvent
    // también actualizará el estado automáticamente
    _audioDetectionTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _room?.localParticipant == null) {
        timer.cancel();
        return;
      }

      final localParticipant = _room!.localParticipant!;

      // Verificar si el micrófono está habilitado
      final isMicEnabled = localParticipant.isMicrophoneEnabled();

      if (!isMicEnabled) {
        if (_isDetectingSound) {
          setState(() {
            _isDetectingSound = false;
            _audioLevel = 0.0;
          });
        }
        return;
      }

      // Obtener el nivel de audio REAL del micrófono del celular
      final audioLevel = localParticipant.audioLevel;
      final isSpeaking = localParticipant.isSpeaking;

      // Umbral mínimo para considerar que hay sonido (0.01 = 1% del máximo)
      // Esto evita falsos positivos por ruido de fondo mínimo
      final hasSound = isSpeaking && audioLevel > 0.01;

      // Log periódicamente para debug (cada 2 segundos o cuando cambia)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now % 2000 < 50 ||
          hasSound != _isDetectingSound ||
          (hasSound && audioLevel > 0.05)) {
        print(
            '[LLAMADA] 🎤 Polling audio - Level: ${audioLevel.toStringAsFixed(4)}, Speaking: $isSpeaking, HasSound: $hasSound, MicEnabled: $isMicEnabled');
      }

      if (mounted) {
        setState(() {
          _audioLevel = audioLevel;
          _isDetectingSound = hasSound;
        });
      }
    });
  }

  void _stopAudioDetection() {
    _audioDetectionTimer?.cancel();
    _audioDetectionTimer = null;
    // No actualizar el estado aquí si se llama desde dispose()
    // El widget se está desmontando, no tiene sentido actualizar el estado
  }

  Future<void> _toggleSpeaker() async {
    try {
      if (_room == null) return;

      // Alternar el estado del altavoz
      setState(() {
        _isSpeakerEnabled = !_isSpeakerEnabled;
      });

      // Si hay operador, silenciar/activar su audio
      if (_operatorParticipant != null) {
        // LiveKit maneja el audio automáticamente, pero podemos ajustar el volumen
        // Por ahora solo cambiamos el estado visual
        print(
            '[LLAMADA] Altavoz ${_isSpeakerEnabled ? "activado" : "desactivado"}');
      }
    } catch (e, stackTrace) {
      ErrorHandler.logError('[LLAMADA-SPEAKER]', e, stackTrace);
    }
  }

  Future<void> _hangUp() async {
    try {
      if (_room != null) {
        await _room!.disconnect();
      }
      if (_listener != null) {
        await _listener!.dispose();
      }

      // NO crear emergencia activa al colgar - solo se creará cuando llegue el ID por websocket
      print('[LLAMADA] Colgando llamada - el recuadro aparecerá cuando llegue el ID por websocket');

      if (mounted) {
        // Regresar directamente a HomeSolicitantePage (saltando NuevaEmergenciaPage)
        // Hacer pop dos veces: una para salir de LlamadaPage, otra para salir de NuevaEmergenciaPage
        Navigator.of(context).pop(); // Sale de LlamadaPage
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Sale de NuevaEmergenciaPage, regresa a Home
        }
      }
    } catch (e) {
      print('[LLAMADA] Error al colgar: $e');
      if (mounted) {
        // Regresar directamente a HomeSolicitantePage
        Navigator.of(context).pop(); // Sale de LlamadaPage
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Sale de NuevaEmergenciaPage, regresa a Home
        }
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildParticipantAvatar(String name, {bool isLocal = false}) {
    final initials = _getInitials(name);
    final size = isLocal ? 120.0 : 150.0;
    final showSoundIndicator =
        isLocal && _isDetectingSound && _isMicrophoneEnabled;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ondas de sonido animadas (solo para el participante local cuando detecta sonido)
        if (showSoundIndicator) ..._buildSoundWaves(size),

        // Avatar principal
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLocal
                  ? [ResQColors.primary500, ResQColors.primary600]
                  : [Colors.blue.shade400, Colors.blue.shade600],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
              // Sombra adicional cuando detecta sonido
              if (showSoundIndicator)
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Indicador de sonido (punto verde pulsante)
        if (showSoundIndicator)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSoundWaves(double baseSize) {
    // Crear múltiples ondas concéntricas que se animan continuamente
    return List.generate(3, (index) {
      final sizeMultiplier = 1.0 + (index * 0.25); // Cada onda es más grande

      return _SoundWaveWidget(
        baseSize: baseSize * sizeMultiplier,
        delay: Duration(milliseconds: index * 300),
        audioLevel: _audioLevel,
      );
    });
  }

  @override
  void dispose() {
    print('[LLAMADA] Disposing LlamadaPage...');

    // Cancelar timers
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
    _stopAudioDetection();

    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _hangUp();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1F22), // Fondo oscuro estilo Discord
        body:
            _errorMessage != null ? _buildErrorWidget() : _buildCallInterface(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ErrorDisplayWidget(
              errorMessage: _errorMessage ?? 'Error desconocido',
              showRetryButton: true,
              onRetry: () {
                setState(() {
                  _errorMessage = null;
                });
                _connectToCall();
              },
              onDismiss: () => Navigator.pop(context),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ResQColors.primary500,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallInterface() {
    if (_isConnecting) {
      return _buildConnectingView();
    }

    if (!_isConnected) {
      return _buildConnectingView();
    }

    return Stack(
      children: [
        // Fondo con gradiente
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1F22),
                const Color(0xFF2C2D31),
                const Color(0xFF1E1F22),
              ],
            ),
          ),
        ),

        // Contenido principal
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Vista de participantes
              Expanded(
                child: _hasOperator
                    ? _buildParticipantsView()
                    : _buildWaitingView(),
              ),

              // Controles
              _buildControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ResQColors.primary500),
          ),
          const SizedBox(height: 24),
          const Text(
            'Conectando...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isConnected ? Colors.green : Colors.orange,
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
                    color: _isConnected ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Conectado' : 'Conectando',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _hangUp,
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildParticipantAvatar('Tú', isLocal: true),
          const SizedBox(height: 32),
          const Text(
            'Esperando operador de emergencia...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Por favor espera mientras te conectamos',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Operador (arriba)
          Column(
            children: [
              _buildParticipantAvatar(_operatorName, isLocal: false),
              const SizedBox(height: 16),
              Text(
                _operatorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Operador de emergencia',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),

          // Separador
          Container(
            width: 200,
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),

          const SizedBox(height: 48),

          // Tú (abajo)
          Column(
            children: [
              _buildParticipantAvatar('Tú', isLocal: true),
              const SizedBox(height: 16),
              const Text(
                'Tú',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Solicitante',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF1E1F22).withOpacity(0.95),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Silenciar micrófono
            _buildControlButton(
              icon: _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
              label: _isMicrophoneEnabled ? 'Micrófono' : 'Silenciado',
              isActive: _isMicrophoneEnabled,
              onPressed: _toggleMicrophone,
              color: _isMicrophoneEnabled
                  ? ResQColors.primary500
                  : Colors.grey[700]!,
            ),

            // Silenciar altavoz
            _buildControlButton(
              icon: _isSpeakerEnabled ? Icons.volume_up : Icons.volume_off,
              label: _isSpeakerEnabled ? 'Altavoz' : 'Silenciado',
              isActive: _isSpeakerEnabled,
              onPressed: _toggleSpeaker,
              color: _isSpeakerEnabled ? Colors.blue : Colors.grey[700]!,
            ),

            // Colgar
            _buildControlButton(
              icon: Icons.call_end,
              label: 'Colgar',
              isActive: false,
              onPressed: _hangUp,
              color: Colors.red[700]!,
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required Color color,
    bool isDanger = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 28),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Widget separado para las ondas de sonido animadas
class _SoundWaveWidget extends StatefulWidget {
  final double baseSize;
  final Duration delay;
  final double audioLevel;

  const _SoundWaveWidget({
    required this.baseSize,
    required this.delay,
    required this.audioLevel,
  });

  @override
  State<_SoundWaveWidget> createState() => _SoundWaveWidgetState();
}

class _SoundWaveWidgetState extends State<_SoundWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Iniciar animación después del delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = (1.0 - _animation.value).clamp(0.0, 1.0);
        final currentSize = widget.baseSize * (1.0 + _animation.value * 0.4);
        final intensity = widget.audioLevel.clamp(0.3, 1.0);

        return Container(
          width: currentSize,
          height: currentSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.green.withOpacity(opacity * 0.6 * intensity),
              width: 2 * intensity,
            ),
          ),
        );
      },
    );
  }
}
