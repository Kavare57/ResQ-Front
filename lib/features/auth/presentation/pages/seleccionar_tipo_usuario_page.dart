import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../solicitante/presentation/pages/perfil_solicitante_page.dart';

class SeleccionarTipoUsuarioPage extends StatelessWidget {
  /// El email y password ya fueron registrados,
  /// ahora el usuario debe elegir qué tipo de perfil quiere completar
  final String email;
  final String password;

  const SeleccionarTipoUsuarioPage({
    super.key,
    required this.email,
    required this.password,
  });

  void _irAPerfilSolicitante(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const PerfilSolicitantePage(
          forzarCompletar: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Evita volver atrás
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ResQColors.primary500,
          foregroundColor: Colors.white,
          title: const Text('Completar registro'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Completa tu perfil',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Proporciona tu información personal para activar tu cuenta',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Tarjeta: Solicitante
              _buildUserTypeCard(
                context,
                icon: Icons.person,
                title: 'Solicitante de emergencias',
                description:
                    'Solicita ayuda médica cuando la necesites',
                onTap: () => _irAPerfilSolicitante(context),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Eres operador de ambulancia?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los operadores se registran directamente por administración. '
                      'Contacta con el equipo de ResQ para obtener tu cuenta.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: ResQColors.primary500,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 40,
              color: ResQColors.primary500,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward,
                  color: ResQColors.primary500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
