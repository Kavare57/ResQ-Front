import 'package:flutter/material.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/llamada/presentation/pages/llamada_page.dart';
import 'features/solicitante/presentation/pages/home_solicitante_page.dart';
import 'features/solicitante/presentation/pages/perfil_solicitante_page.dart';
import 'features/solicitante/presentation/pages/seguimiento_solicitud_page.dart';
import 'features/operador_ambulancia/presentation/pages/perfil_operador_ambulancia_page.dart';
import 'features/operador_ambulancia/presentation/pages/dashboard_operador_ambulancia_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String homeSolicitante = '/home-solicitante';
  static const String llamada = '/llamada';
  static const String perfilSolicitante = '/perfil-solicitante';
  static const String seguimientoSolicitud = '/seguimiento-solicitud';
  static const String perfilOperador = '/perfil-operador';
  static const String dashboardOperador = '/dashboard-operador';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case homeSolicitante:
        return MaterialPageRoute(builder: (_) => const HomeSolicitantePage());
      case llamada:
        final credenciales = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => LlamadaPage(credenciales: credenciales),
        );
      case perfilSolicitante:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => PerfilSolicitantePage(
            forzarCompletar: args?['forzarCompletar'] ?? false,
          ),
        );
      case seguimientoSolicitud:
        final args = settings.arguments as Map<String, dynamic>?;
        final idSolicitud = args?['idSolicitud'] as int? ?? 0;
        return MaterialPageRoute(
          builder: (_) => SeguimientoSolicitudPage(idSolicitud: idSolicitud),
        );
      case perfilOperador:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => PerfilOperadorAmbulanciaPage(
            forzarCompletar: args?['forzarCompletar'] ?? false,
          ),
        );
      case dashboardOperador:
        return MaterialPageRoute(
          builder: (_) => const DashboardOperadorAmbulanciaPage(),
        );
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
