import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/underlined_textfield.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../../core/widgets/auth_sheet.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email  = TextEditingController();
  final _pass   = TextEditingController();
  final _auth   = AuthController();

  bool _loading = false;
  bool _hidePass = true;
  String? _error;

  @override
  void dispose() { _nombre.dispose(); _email.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final r = await _auth.register(nombre: _nombre.text.trim(), email: _email.text.trim(), password: _pass.text);
    setState(() { _loading = false; _error = r.ok ? null : r.message; });
    if (r.ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/auth_bg.webp', fit: BoxFit.cover),

          AuthSheet(
            title: '', // ✅ este título es obligatorio
            minHeightFactor: 0.66,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔙 Flecha + Título en la misma fila
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                      tooltip: 'Volver al inicio de sesión',
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Formulario de registro ---
                Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Name', style: TextStyle(color: Colors.grey)),
                      ),
                      UnderlinedTextField(
                        controller: _nombre,
                        hint: 'Your name',
                        validator: (v) => Validators.required(v, label: 'tu nombre'),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Email', style: TextStyle(color: Colors.grey)),
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
                        child: Text('Password', style: TextStyle(color: Colors.grey)),
                      ),
                      UnderlinedTextField(
                        controller: _pass,
                        hint: 'Enter your password',
                        obscure: _hidePass,
                        validator: Validators.password,
                        suffix: IconButton(
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                          icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ResQColors.primary400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const CircularProgressIndicator()
                              : const Text('Sign up',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
