import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;

import '../../../../core/constants/colors.dart';

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
  bool _isAudioEnabled = true;
  bool _isConnected = false;
  String _estado = 'Conectando...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _conectarALlamada();
  }

  Future<void> _conectarALlamada() async {
    try {
      setState(() {
        _estado = 'Conectando...';
      });

      _room = livekit.Room();

      // Extraer credenciales
      final String serverUrl = widget.credenciales['server_url'];
      final String token = widget.credenciales['token'];

      print('DEBUG: Conectando a $serverUrl');
      print('DEBUG: Token: ${token.substring(0, 20)}...');

      // Conectar a la sala
      await _room.connect(
        serverUrl,
        token,
      );

      // Habilitar audio local
      await _room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _isConnected = true;
        _estado = 'Conectado con CRUE';
        _isAudioEnabled = true;
      });
    } catch (e) {
      print('Error conectando: $e');
      setState(() {
        _errorMessage = 'Error al conectar: $e';
        _estado = 'Desconectado';
      });
    }
  }

  Future<void> _toggleAudio() async {
    try {
      final isEnabled = await _room.localParticipant?.isMicrophoneEnabled() ?? false;
      await _room.localParticipant?.setMicrophoneEnabled(!isEnabled);
      setState(() {
        _isAudioEnabled = !isEnabled;
      });
    } catch (e) {
      print('Error toggling audio: $e');
    }
  }

  Future<void> _finalizarLlamada() async {
    try {
      await _room.disconnect();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error finalizando llamada: $e');
    }
  }

  @override
  void dispose() {
    _room.dispose();
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botón de audio
                      FloatingActionButton(
                        onPressed: _isConnected ? _toggleAudio : null,
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
                        onPressed: _finalizarLlamada,
                        backgroundColor: Colors.red[700],
                        tooltip: 'Terminar llamada',
                        child: const Icon(
                          Icons.call_end,
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
