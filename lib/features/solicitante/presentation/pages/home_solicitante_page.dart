import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/jwt_helper.dart';
import '../../../../core/services/error_handler.dart';
import '../../../../core/services/solicitante_websocket_service.dart';
import '../../../../core/widgets/error_display_widget.dart';
import '../../../../core/widgets/emergencia_activa_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/apis/historial_emergencias_api.dart';
import '../../data/models/emergencia_historial.dart';
import 'perfil_solicitante_page.dart';
import 'nueva_emergencia_page.dart';
import 'seguimiento_emergencia_page.dart';

class HomeSolicitantePage extends StatefulWidget {
  final String nombreUsuario;

  const HomeSolicitantePage({
    super.key,
    this.nombreUsuario = 'Usuario',
  });

  @override
  State<HomeSolicitantePage> createState() => _HomeSolicitantePageState();
}

class _HomeSolicitantePageState extends State<HomeSolicitantePage> with WidgetsBindingObserver {
  final _auth = AuthController();
  final _storage = StorageService();
  final _historialApi = HistorialEmergenciasApi();
  final _wsSolicitanteService = SolicitanteWebSocketService();

  late String _nombreUsuario;
  bool _cargandoNombre = true;

  List<EmergenciaHistorial> _emergencias = [];
  bool _cargandoHistorial = true;
  String? _errorHistorial;

  // Emergencia activa
  Map<String, dynamic>? _emergenciaActiva;
  bool _cargandoEmergenciaActiva = true;

  @override
  void initState() {
    super.initState();
    _nombreUsuario = widget.nombreUsuario;
    print('[HOME] Iniciando...');
    WidgetsBinding.instance.addObserver(this);
    // Cargar nombre de forma lazy (cuando sea necesario renderizar)
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Solo cargar una vez
    if (_cargandoNombre) {
      _cargarNombreDelStorage();
      _cargarHistorial();
      _cargarEmergenciaActiva();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // NO desconectar el websocket del solicitante - debe permanecer conectado
    // _wsSolicitanteService.desconectar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Recargar emergencia activa cuando la app vuelve al foreground
    if (state == AppLifecycleState.resumed) {
      _cargarEmergenciaActiva();
    }
  }

  Future<void> _cargarNombreDelStorage() async {
    if (!mounted) return;

    try {
      print('[HOME] Cargando nombre del storage...');

      // Primero intentar del storage con timeout
      String? nombre;
      try {
        nombre = await _storage.getNombreUsuario().timeout(
              const Duration(milliseconds: 500),
              onTimeout: () => null,
            );
      } catch (e) {
        print('[HOME] Error obteniendo nombre del storage: $e');
        nombre = null;
      }

      // Si no está en storage, intentar obtenerlo del JWT (rápido, no es async)
      if (nombre == null || nombre.isEmpty) {
        print('[HOME] Nombre no en storage, intentando obtener del JWT...');
        try {
          final token = await _storage.getToken();
          if (token != null) {
            nombre = JwtHelper.getNombreDeUsuario(token);
            print('[HOME] Nombre obtenido del JWT: $nombre');
            if (nombre != null && nombre.isNotEmpty) {
              // Guardar en background sin esperar
              _storage.saveNombreUsuario(nombre);
            }
          }
        } catch (e) {
          print('[HOME] Error obteniendo token: $e');
        }
      } else {
        print('[HOME] Nombre obtenido del storage: $nombre');
      }

      if (!mounted) return;

      setState(() {
        if (nombre != null && nombre.isNotEmpty) {
          _nombreUsuario = nombre;
          print('[HOME] Nombre establecido: $nombre');
        }
        _cargandoNombre = false;
      });
    } catch (e) {
      print('[HOME] Error cargando nombre: $e');
      if (mounted) {
        setState(() {
          _cargandoNombre = false;
        });
      }
    }
  }

  Future<void> _cargarHistorial() async {
    if (!mounted) return;

    try {
      print('[HOME] Cargando historial de emergencias...');
      final emergencias = await _historialApi.obtenerHistorial(limit: 10);

      if (!mounted) return;

      setState(() {
        _emergencias = emergencias;
        _cargandoHistorial = false;
        _errorHistorial = null;
      });
      print('[HOME] Historial cargado: ${emergencias.length} emergencias');
    } catch (e, stackTrace) {
      ErrorHandler.logError('[HOME-HISTORIAL]', e, stackTrace);
      if (!mounted) return;

      setState(() {
        _cargandoHistorial = false;
        _errorHistorial = ErrorHandler.getErrorMessage(e);
      });
    }
  }

  Future<void> _cargarEmergenciaActiva() async {
    if (!mounted) return;

    try {
      print('[HOME] Cargando emergencia activa...');
      final emergencia = await _storage.getEmergenciaActiva();

      if (!mounted) return;

      setState(() {
        _emergenciaActiva = emergencia;
        _cargandoEmergenciaActiva = false;
      });

      // Siempre conectar al websocket del solicitante para recibir mensajes
      // (incluso si no hay emergencia activa aún, puede llegar el ID en el primer mensaje)
      print('[HOME] Verificando websocket del solicitante...');
      _conectarWebSocketSolicitante();
      
      if (emergencia != null) {
        print('[HOME] Emergencia activa encontrada con ID: ${emergencia['id']}');
      } else {
        print('[HOME] No hay emergencia activa - esperando ID por websocket');
      }
    } catch (e) {
      print('[HOME] Error cargando emergencia activa: $e');
      if (!mounted) return;
      setState(() {
        _cargandoEmergenciaActiva = false;
      });
    }
  }

  void _conectarWebSocketSolicitante() async {
    try {
      final idSolicitante = await _storage.getPersonaId();
      if (idSolicitante == null || idSolicitante == 0) {
        print('[HOME] No se pudo obtener id_solicitante para WebSocket');
        return;
      }

      // Configurar callbacks antes de conectar
      _wsSolicitanteService.onMensajeRecibido = (Map<String, dynamic> data) async {
        print('[HOME] Mensaje recibido del websocket del solicitante: $data');
        
        final tipo = data['tipo'] as String?;
        
        // Procesar mensajes de ubicación de ambulancia
        if (tipo == 'ubicacion_ambulancia') {
          // Este mensaje se procesará en la pantalla de seguimiento
          // Solo logueamos aquí
          print('[HOME] Mensaje de ubicación de ambulancia recibido (se procesará en seguimiento)');
          return;
        }
        
        // Procesar el mensaje - puede venir con "type" o "tipo"
        final datos = data['data'] as Map<String, dynamic>?;
        
        if (datos != null) {
          // Si el mensaje contiene información de estado o ID de emergencia
          final estado = datos['estado'] as String?;
          final idEmergencia = datos['id'] as int?; // El ID en el mensaje es el id_emergencia
          
          // Si viene el ID de emergencia, actualizar la emergencia activa
          if (idEmergencia != null && idEmergencia != 0) {
            final idEmergenciaFinal = idEmergencia;
            
            // Verificar si ya existe una emergencia activa
            final emergenciaActual = await _storage.getEmergenciaActiva();
            
            if (emergenciaActual == null) {
              // Crear nueva emergencia activa con id_emergencia
              // Poner id_solicitud en 0 y guardar id_emergencia
              await _storage.saveEmergenciaActiva(
                idSolicitud: 0, // Poner en 0 cuando llega id_emergencia
                idEmergencia: idEmergenciaFinal,
                estado: estado ?? 'creada',
                fecha: DateTime.now(),
              );
              print('[HOME] Emergencia activa creada con ID Emergencia: $idEmergenciaFinal, Estado: ${estado ?? 'creada'}');
            } else {
              // Actualizar: poner id_solicitud en 0 y guardar id_emergencia
              await _storage.updateIdEmergenciaActiva(idEmergenciaFinal);
              if (estado != null) {
                await _storage.updateEstadoEmergenciaActiva(estado);
                print('[HOME] Emergencia activa actualizada - ID Emergencia: $idEmergenciaFinal, Estado: $estado');
              } else {
                print('[HOME] Emergencia activa actualizada - ID Emergencia: $idEmergenciaFinal');
              }
            }
            
            // Recargar la emergencia activa para mostrarla
            // Actualizar en memoria sin recargar todo
            if (mounted) {
              setState(() {
                _emergenciaActiva = {
                  'id': idEmergenciaFinal,
                  'id_solicitud': 0,
                  'id_emergencia': idEmergenciaFinal,
                  'estado': estado ?? 'creada',
                  'fecha': DateTime.now(),
                };
              });
            }
          } else if (estado != null) {
            // Si solo viene el estado (sin ID), actualizar si ya existe emergencia activa
            final emergenciaActual = await _storage.getEmergenciaActiva();
            if (emergenciaActual != null) {
              await _storage.updateEstadoEmergenciaActiva(estado);
              print('[HOME] Estado de emergencia actualizado: $estado');
              if (mounted) {
                setState(() {
                  _emergenciaActiva!['estado'] = estado;
                });
              }
            }
          }
        }
      };

      _wsSolicitanteService.onError = (String error) {
        print('[HOME] Error en websocket del solicitante: $error');
      };

      _wsSolicitanteService.onConexionPerdida = () {
        print('[HOME] Conexión websocket del solicitante perdida, intentando reconectar...');
        // Intentar reconectar después de un delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _conectarWebSocketSolicitante();
          }
        });
      };

      // Conectar al websocket del solicitante (solo si no está conectado)
      if (!_wsSolicitanteService.estaConectado) {
        print('[HOME] Conectando al WebSocket del solicitante: $idSolicitante');
        await _wsSolicitanteService.conectar(idSolicitante);
        print('[HOME] WebSocket del solicitante conectado exitosamente');
      } else {
        print('[HOME] WebSocket del solicitante ya está conectado');
      }
    } catch (e) {
      print('[HOME] Error conectando al WebSocket del solicitante: $e');
    }
  }

  // ----------- CERRAR SESIÓN -----------
  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQColors.surface,

      // ----------- APP BAR -----------
      appBar: AppBar(
        backgroundColor: ResQColors.primary500,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ResQ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _cargandoNombre ? 'Cargando...' : 'Hola, $_nombreUsuario',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ver / editar perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PerfilSolicitantePage()),
              );
            },
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),

      // ----------- CUERPO -----------
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ******** BOTÓN SOS ********
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _SosCard(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NuevaEmergenciaPage(),
                      ),
                    ).then((_) {
                      // Recargar emergencia activa cuando se regrese de crear emergencia
                      _cargarEmergenciaActiva();
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ******** EMERGENCIA ACTIVA ********
              if (!_cargandoEmergenciaActiva && _emergenciaActiva != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      EmergenciaActivaCard(
                        estado: _emergenciaActiva!['estado'] as String,
                        fecha: _emergenciaActiva!['fecha'] as DateTime,
                        idSolicitud: _emergenciaActiva!['id'] as int?,
                        onIniciarSeguimiento: () async {
                          final emergencia = await _storage.getEmergenciaActiva();
                          if (emergencia != null) {
                            final latitud = emergencia['latitud'] as double?;
                            final longitud = emergencia['longitud'] as double?;
                            
                            if (latitud != null && longitud != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeguimientoEmergenciaPage(
                                    latitudEmergencia: latitud,
                                    longitudEmergencia: longitud,
                                    wsService: _wsSolicitanteService,
                                  ),
                                ),
                              ).then((_) {
                                // Recargar emergencia activa cuando se regrese
                                _cargarEmergenciaActiva();
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No se encontró la ubicación de la emergencia'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Botón temporal de pruebas para limpiar flag de emergencia activa
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await _storage.setTieneEmergenciaActiva(false);
                          await _storage.clearEmergenciaActiva();
                          if (mounted) {
                            setState(() {
                              _emergenciaActiva = null;
                            });
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Flag de emergencia activa limpiado (solo pruebas)'),
                              ),
                            );
                          }
                        },
                        child: const Text('TEST: Limpiar emergencia activa'),
                      ),
                    ],
                  ),
                ),

              if (!_cargandoEmergenciaActiva && _emergenciaActiva != null)
                const SizedBox(height: 24),

              // ******** TARJETA: Contactos de emergencia ********
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _InfoCard(
                  title: 'Contactos de emergencia',
                  subtitle:
                      'Agrega familiares o contactos de confianza para avisos rápidos.',
                  icon: Icons.group_outlined,
                ),
              ),

              const SizedBox(height: 12),

              // ******** TARJETA: Historial de emergencias ********
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  color: ResQColors.onPrimary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: ResQColors.primary100,
                              child: Icon(Icons.history,
                                  color: ResQColors.primary600),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Historial de emergencias',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHistorialContent(),
                      ],
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

  // ========== Método para construir el contenido del historial ==========
  Widget _buildHistorialContent() {
    if (_cargandoHistorial) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            const SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cargando historial...',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_errorHistorial != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ErrorDisplayWidget(
          errorMessage: _errorHistorial!,
          showRetryButton: true,
          onRetry: _cargarHistorial,
          onDismiss: () {
            setState(() {
              _errorHistorial = null;
            });
          },
        ),
      );
    }

    if (_emergencias.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Icon(Icons.history, color: Colors.black26, size: 32),
            const SizedBox(height: 8),
            const Text(
              'No hay emergencias registradas',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    // Mostrar lista de emergencias (máximo 10)
    return Column(
      children: [
        ..._emergencias.take(10).map((emergencia) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _EmergenciaHistorialItem(emergencia: emergencia),
          );
        }),
        if (_emergencias.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'y ${_emergencias.length - 10} más...',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
//                                WIDGETS EXTRA
// ============================================================================

// ----------- TARJETA SOS -----------
class _SosCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _SosCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ResQColors.onPrimary.withOpacity(0.98),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          children: [
            const Text(
              'Emergencia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Presiona el botón SOS solo si tú o alguien necesita una ambulancia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 140,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ResQColors.primary500,
                  shape: const CircleBorder(),
                  elevation: 10,
                ),
                onPressed: onPressed,
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------- TARJETA DE INFORMACIÓN -----------
class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ResQColors.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: ResQColors.primary100,
              child: Icon(icon, color: ResQColors.primary600),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------- ITEM DE EMERGENCIA EN HISTORIAL -----------
class _EmergenciaHistorialItem extends StatelessWidget {
  final EmergenciaHistorial emergencia;

  const _EmergenciaHistorialItem({required this.emergencia});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Estado, Prioridad y Fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  emergencia.estadoLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  emergencia.prioridadLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  emergencia.fechaFormato,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila 2: Tipo de ambulancia
          Row(
            children: [
              const Icon(Icons.local_hospital, size: 14, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  emergencia.tipoLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Fila 3: Descripción
          Text(
            emergencia.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
