import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'core/services/permissions_service.dart';
import 'core/services/location_service.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/solicitante/presentation/pages/home_solicitante_page.dart';
import 'routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ResQApp());
}

class ResQApp extends StatefulWidget {
  const ResQApp({super.key});

  @override
  State<ResQApp> createState() => _ResQAppState();
}

class _ResQAppState extends State<ResQApp> {
  final _auth = AuthController();
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Solicitar permisos de ubicación al iniciar la app por primera vez
    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // Verificar permisos usando Geolocator directamente
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            // Permisos no otorgados, no hacer nada más aquí
          }
        }
      }
    } catch (e) {
    }

    // Solicitar otros permisos (micrófono, cámara) si es necesario
    await PermissionsService.requestAllPermissions();

    // Iniciar obtención de ubicación precisa en segundo plano (no bloquea)
    LocationService().initialize().catchError((e) {
    });

    // Pregunta al AuthController si hay token válido guardado
    final startTime = DateTime.now();

    final ok = await _auth.isLoggedIn();
    setState(() {
      _loggedIn = ok;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Si hay token válido -> Home; si no -> Login
      home: _loggedIn ? const HomeSolicitantePage() : const LoginPage(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
