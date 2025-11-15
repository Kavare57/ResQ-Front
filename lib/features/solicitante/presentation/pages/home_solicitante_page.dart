import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/api/solicitantes_api.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'perfil_solicitante_page.dart';
import 'nueva_emergencia_page.dart';

class HomeSolicitantePage extends StatefulWidget {
  final String nombreUsuario;

  const HomeSolicitantePage({
    super.key,
    this.nombreUsuario = 'Usuario',
  });

  @override
  State<HomeSolicitantePage> createState() => _HomeSolicitantePageState();
}

class _HomeSolicitantePageState extends State<HomeSolicitantePage> {
  final _auth = AuthController();
  late String _nombreUsuario;
  bool _cargandoNombre = true;

  @override
  void initState() {
    super.initState();
    _nombreUsuario = widget.nombreUsuario;
    print('[HOME] Iniciando...');
    _cargarNombreUsuario();
  }

  Future<void> _cargarNombreUsuario() async {
    try {
      print('[HOME] Cargando perfil...');
      final api = SolicitantesApi();
      final perfil = await api.obtenerPerfilActual();
      print('[HOME] Perfil cargado OK');

      if (!mounted) return;

      setState(() {
        final nombre = perfil['nombre'] ?? 'Usuario';
        final apellido = perfil['apellido'] ?? '';
        _nombreUsuario = '$nombre $apellido'.trim();
        _cargandoNombre = false;
      });
    } catch (e) {
      if (!mounted) return;

      print('[HOME] Error cargando perfil: $e');
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        await _auth.logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      }

      setState(() {
        _cargandoNombre = false;
      });
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
              _cargandoNombre
                  ? 'Cargando...'
                  : 'Hola, $_nombreUsuario',
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
                MaterialPageRoute(builder: (_) => const PerfilSolicitantePage()),
              );
            },
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),

      // ----------- CUERPO -----------
      body: SafeArea(
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
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ******** TARJETA: Última emergencia ********
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _InfoCard(
                title: 'Última emergencia',
                subtitle: 'No hay emergencias recientes.',
                icon: Icons.history,
              ),
            ),

            const SizedBox(height: 12),

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
          ],
        ),
      ),
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
