import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../llamada/presentation/pages/llamada_page.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../routes.dart';

class DashboardOperadorEmergenciaPage extends StatefulWidget {
  const DashboardOperadorEmergenciaPage({super.key});

  @override
  State<DashboardOperadorEmergenciaPage> createState() =>
      _DashboardOperadorEmergenciaPageState();
}

class _DashboardOperadorEmergenciaPageState
    extends State<DashboardOperadorEmergenciaPage> {
  final _auth = AuthController();
  
  // Lista de emergencias en cola (simulada por ahora)
  final List<Map<String, dynamic>> _emergenciasActivas = [
    {
      'id': 1,
      'solicitante': 'Juan Pérez',
      'ubicacion': 'Calle Principal 123',
      'motivo': 'Dolor en el pecho',
      'urgencia': 'CRÍTICA',
      'emergenciaId': '123abc',
    },
    {
      'id': 2,
      'solicitante': 'María García',
      'ubicacion': 'Avenida Central 456',
      'motivo': 'Fractura de pierna',
      'urgencia': 'URGENTE',
      'emergenciaId': '456def',
    },
    {
      'id': 3,
      'solicitante': 'Carlos López',
      'ubicacion': 'Plaza Mayor 789',
      'motivo': 'Alergia severa',
      'urgencia': 'URGENTE',
      'emergenciaId': '789ghi',
    },
  ];

  void _asignarEmergencia(Map<String, dynamic> emergencia) {
    // Mostrar diálogo de confirmación
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asignar emergencia'),
        content: Text(
          '¿Deseas asignar esta emergencia?\n\n'
          'Solicitante: ${emergencia['solicitante']}\n'
          'Ubicación: ${emergencia['ubicacion']}\n'
          'Motivo: ${emergencia['motivo']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ResQColors.primary500,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              // Navegar a llamada
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LlamadaPage(
                    credenciales: {
                      'emergenciaId': emergencia['emergenciaId'],
                      'solicitante': emergencia['solicitante'],
                    },
                  ),
                ),
              );
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Color _getUrgenciaColor(String urgencia) {
    switch (urgencia) {
      case 'CRÍTICA':
        return Colors.red;
      case 'URGENTE':
        return Colors.orange;
      case 'MODERADA':
        return Colors.yellow;
      case 'LEVE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ResQColors.primary500,
        foregroundColor: Colors.white,
        title: const Text('Central de Emergencias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil (próximamente)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Estás seguro?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar')),
                  ],
                ),
              );
              if (confirm == true) {
                await _auth.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                }
              }
            },
          ),
        ],
      ),
      body: _emergenciasActivas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay emergencias en cola',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Permanece atento a nuevas emergencias',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _emergenciasActivas.length,
              itemBuilder: (context, index) {
                final emergencia = _emergenciasActivas[index];
                final urgencia = emergencia['urgencia'] as String;
                final urgenciaColor = _getUrgenciaColor(urgencia);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Emergencia #${emergencia['id']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Solicitante: ${emergencia['solicitante']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: urgenciaColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                urgencia,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                emergencia['ubicacion'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Motivo: ${emergencia['motivo']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _asignarEmergencia(emergencia),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Asignar a mí'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ResQColors.primary500,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
