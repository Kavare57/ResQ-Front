import 'package:flutter/material.dart';
import 'core/services/storage_service.dart';
import 'core/services/permissions_service.dart';
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
    // Solicitar todos los permisos necesarios al iniciar
    print('[APP] Solicitando permisos...');
    await PermissionsService.requestAllPermissions();
    
    // Pregunta al AuthController si hay token válido guardado
    final startTime = DateTime.now();
    
    // Verificar si el usuario pidió "recuerdame"
    final storage = StorageService();
    final remember = await storage.getRemember() ?? false;
    
    // Si NO pidió recuerdame, borrar el token antes de verificar
    if (!remember) {
      await storage.clearToken();
      print('[AUTH] Remember desactivado - token limpiado');
    }
    
    final ok = await _auth.isLoggedIn();
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    print('Auth check completed in ${elapsed}ms');
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
      home: _loggedIn
          ? const HomeSolicitantePage()
          : const LoginPage(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
