import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/underlined_textfield.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../routes.dart';
import '../../../../core/widgets/auth_sheet.dart';
import '../../../../core/services/jwt_helper.dart';
import '../../../../core/services/storage_service.dart';
import '../../../solicitante/presentation/pages/home_solicitante_page.dart';
import '../../../operador_ambulancia/presentation/pages/dashboard_operador_ambulancia_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _auth = AuthController();

  bool _loading = false;
  bool _remember = false;
  bool _hidePass = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final r = await _auth.login(
      email: _email.text.trim(),
      password: _pass.text,
      remember: _remember,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
    });

    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bienvenido')),
      );

      // Obtener el token para extraer tipoUsuario
      final storage = StorageService();
      final token = await storage.getToken();

      if (token != null) {
        // Extraer tipoUsuario del JWT
        final tipoUsuario = JwtHelper.getTipoUsuario(token);
        print('[LOGIN] tipoUsuario: $tipoUsuario');

        // Ruteo dinámico basado en tipoUsuario
        Widget destination;
        
        if (tipoUsuario != null) {
          // Si el JWT ya incluye tipoUsuario (backend actualizado)
          switch (tipoUsuario) {
            case 'SOLICITANTE':
              destination = const HomeSolicitantePage();
              break;
            case 'OPERADOR_AMBULANCIA':
              destination = const DashboardOperadorAmbulanciaPage();
              break;
            default:
              print('[LOGIN] tipoUsuario desconocido: $tipoUsuario');
              destination = const HomeSolicitantePage();
          }
        } else {
          // Mientras el backend no incluya tipoUsuario, por defecto ir a solicitante
          // (porque solo solicitantes pueden registrarse públicamente por ahora)
          print('[LOGIN] tipoUsuario no encontrado en JWT, asumiendo SOLICITANTE');
          destination = const HomeSolicitantePage();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      } else {
        // Si no hay token, por defecto ir a home solicitante
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeSolicitantePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // evita parpadeo detrás del PNG
      body: Stack(
        fit: StackFit.expand,
        children: [
          // CAPA 1: PNG de FONDO, adaptado a pantalla
          Image.asset(
            'assets/images/auth_bg.webp',
            fit: BoxFit.cover,
          ),

          // CAPA 2: SHEET inferior con la ola y el formulario
          AuthSheet(
            title: 'Inicio de sesión',
            minHeightFactor: 0.62, // ajústalo si quieres más/menos alto
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Correo',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  UnderlinedTextField(
                    controller: _email,
                    hint: 'demo@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Contraseña',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  UnderlinedTextField(
                    controller: _pass,
                    hint: 'Ingresa tu contraseña',
                    obscure: _hidePass,
                    validator: Validators.password,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _hidePass = !_hidePass),
                      icon: Icon(
                        _hidePass
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? false),
                        activeColor: ResQColors.primary500,
                      ),
                      const Text('Recuérdame'),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // TODO: pantalla de recuperación de contraseña
                        },
                        child: const Text(
                          '¿Recuperar contraseña?',
                          style: TextStyle(
                            color: ResQColors.primary600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ResQColors.primary400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("¿Aún no tienes una cuenta? "),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.register),
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            color: ResQColors.primary600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

