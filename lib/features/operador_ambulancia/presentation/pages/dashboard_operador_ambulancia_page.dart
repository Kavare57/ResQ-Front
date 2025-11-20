import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../llamada/presentation/pages/llamada_page.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../routes.dart';

class DashboardOperadorAmbulanciaPage extends StatefulWidget {
  const DashboardOperadorAmbulanciaPage({super.key});

  @override
  State<DashboardOperadorAmbulanciaPage> createState() =>
      _DashboardOperadorAmbulanciaPageState();
}

class _DashboardOperadorAmbulanciaPageState
    extends State<DashboardOperadorAmbulanciaPage> {
  final _auth = AuthController();
  
  // Lista de emergencias asignadas (simulada por ahora)
  final List<Map<String, dynamic>> _emergenciasAsignadas = [
    {
      'id': 1,
      'solicitante': 'Juan Pérez',
      'ubicacion': 'Calle Principal 123',
      'estado': 'PENDIENTE',
      'emergenciaId': '123abc',
    },
    {
      'id': 2,
      'solicitante': 'María García',
      'ubicacion': 'Avenida Central 456',
      'estado': 'EN_CAMINO',
      'emergenciaId': '456def',
    },
  ];

  void _atenderEmergencia(Map<String, dynamic> emergencia) {
    // Navegar a llamada_page
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ResQColors.primary500,
        foregroundColor: Colors.white,
        title: const Text('Dashboard - Operador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Ir a perfil
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
      body: _emergenciasAsignadas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_ind,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay emergencias asignadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Espera a que se asigne una emergencia',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _emergenciasAsignadas.length,
              itemBuilder: (context, index) {
                final emergencia = _emergenciasAsignadas[index];
                final estado = emergencia['estado'] as String;

                Color estadoColor;
                switch (estado) {
                  case 'PENDIENTE':
                    estadoColor = Colors.orange;
                    break;
                  case 'EN_CAMINO':
                    estadoColor = Colors.blue;
                    break;
                  case 'ATENDIDA':
                    estadoColor = Colors.green;
                    break;
                  default:
                    estadoColor = Colors.grey;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
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
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ubicación: ${emergencia['ubicacion']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
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
                                color: estadoColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                estado,
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _atenderEmergencia(emergencia),
                            icon: const Icon(Icons.call),
                            label: const Text('Atender emergencia'),
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
