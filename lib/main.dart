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
  print('=== ResQ App Starting ===');
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
    print('[APP] Solicitando permisos de ubicación...');
    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // Verificar permisos usando Geolocator directamente
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          print('[APP] Permisos de ubicación denegados, solicitando...');
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            print('[APP] Permisos de ubicación denegados por el usuario');
          } else if (permission == LocationPermission.deniedForever) {
            print('[APP] Permisos de ubicación denegados permanentemente');
          } else {
            print('[APP] Permisos de ubicación otorgados');
          }
        } else if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          print('[APP] Permisos de ubicación ya otorgados');
        }
      } else {
        print('[APP] Servicio de ubicación deshabilitado');
      }
    } catch (e) {
      print('[APP] Error solicitando permisos de ubicación: $e');
    }

    // Solicitar otros permisos (micrófono, cámara) si es necesario
    print('[APP] Solicitando otros permisos...');
    await PermissionsService.requestAllPermissions();

    // Iniciar obtención de ubicación precisa en segundo plano (no bloquea)
    print('[APP] Iniciando LocationService en segundo plano...');
    LocationService().initialize().catchError((e) {
      print('[APP] Error iniciando LocationService: $e');
    });

    // Pregunta al AuthController si hay token válido guardado
    final startTime = DateTime.now();

    final ok = await _auth.isLoggedIn();
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('[AUTH] Verificación completada en ${elapsed}ms - LoggedIn: $ok');
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
