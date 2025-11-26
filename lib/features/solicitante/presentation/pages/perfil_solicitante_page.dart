import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/api/solicitantes_api.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/pages/login_page.dart';

class PerfilSolicitantePage extends StatefulWidget {
  /// Si es true, no dejamos salir hasta que el usuario complete y guarde
  /// toda la información obligatoria (flujo justo después del registro).
  final bool forzarCompletar;

  const PerfilSolicitantePage({
    super.key,
    this.forzarCompletar = false,
  });

  @override
  State<PerfilSolicitantePage> createState() => _PerfilSolicitantePageState();
}

class _PerfilSolicitantePageState extends State<PerfilSolicitantePage> {
  final _formKey = GlobalKey<FormState>();

  final _nombre1Ctrl = TextEditingController();
  final _nombre2Ctrl = TextEditingController();
  final _apellido1Ctrl = TextEditingController();
  final _apellido2Ctrl = TextEditingController();
  final _docCtrl = TextEditingController();

  String _tipoDoc = 'CEDULA';
  DateTime? _fechaNac;
  bool _loading = false;
  bool _cargandoPerfil = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Si NO es forzar completar, cargar datos existentes
    if (!widget.forzarCompletar) {
      _cargarPerfil();
    } else {
      setState(() => _cargandoPerfil = false);
    }
  }

  Future<void> _cargarPerfil() async {
    try {
      final api = SolicitantesApi();
      final perfil = await api.obtenerPerfilActual();

      if (!mounted) return;

      setState(() {
        _nombre1Ctrl.text = perfil['nombre'] ?? '';
        _nombre2Ctrl.text = perfil['nombre2'] ?? '';
        _apellido1Ctrl.text = perfil['apellido'] ?? '';
        _apellido2Ctrl.text = perfil['apellido2'] ?? '';
        _docCtrl.text = perfil['numeroDocumento'] ?? '';
        _tipoDoc = perfil['tipoDocumento'] ?? 'CEDULA';

        // Parsear la fecha
        if (perfil['fechaNacimiento'] != null) {
          try {
            _fechaNac = DateTime.parse(perfil['fechaNacimiento']);
          } catch (_) {
            _fechaNac = null;
          }
        }

        _cargandoPerfil = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoPerfil = false;
        _error = 'Error al cargar el perfil: $e';
      });
    }
  }

  @override
  void dispose() {
    _nombre1Ctrl.dispose();
    _nombre2Ctrl.dispose();
    _apellido1Ctrl.dispose();
    _apellido2Ctrl.dispose();
    _docCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFechaNac() async {
    final now = DateTime.now();
    final inicial = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      setState(() => _fechaNac = picked);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaNac == null) {
      setState(() => _error = 'Selecciona tu fecha de nacimiento.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = SolicitantesApi();
      await api.guardarPerfil(
        nombre: _nombre1Ctrl.text.trim(),
        nombre2:
            _nombre2Ctrl.text.trim().isEmpty ? null : _nombre2Ctrl.text.trim(),
        apellido: _apellido1Ctrl.text.trim(),
        apellido2: _apellido2Ctrl.text.trim().isEmpty
            ? null
            : _apellido2Ctrl.text.trim(),
        tipoDocumento: _tipoDoc,
        numeroDocumento: _docCtrl.text.trim(),
        fechaNacimiento: _fechaNac!,
      );

      if (!mounted) return;

      if (widget.forzarCompletar) {
        // Después del registro: completamos perfil y luego volvemos a login
        // Esto asegura que el id_persona se obtenga correctamente en el próximo login

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perfil completado! Tu cuenta está lista.'),
            duration: Duration(seconds: 3),
          ),
        );

        // Esperamos más tiempo para que todas las operaciones en backend se completen
        // y para que el snackbar se muestre correctamente
        Future.delayed(const Duration(seconds: 4), () async {
          if (mounted) {
            // Limpiamos el token temporal porque ahora se debe hacer login formal
            // En el próximo login se obtendrá id_persona correctamente
            final storage = StorageService();
            await storage.clearToken();

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          }
        });
      } else {
        // Desde el home: mostrar confirmación y volver atrás
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _datosCompletos {
    return _nombre1Ctrl.text.trim().isNotEmpty &&
        _apellido1Ctrl.text.trim().isNotEmpty &&
        _docCtrl.text.trim().isNotEmpty &&
        _fechaNac != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoPerfil) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: ResQColors.primary500,
          foregroundColor: Colors.white,
          title: const Text('Mi perfil'),
          automaticallyImplyLeading: !widget.forzarCompletar,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      // Si está en modo forzado y los datos no están completos, bloquear back.
      onWillPop: () async {
        if (widget.forzarCompletar && !_datosCompletos) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Debes completar y guardar tu información para continuar.'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ResQColors.primary500,
          foregroundColor: Colors.white,
          title: const Text('Mi perfil'),
          automaticallyImplyLeading: !widget.forzarCompletar,
          // Si es forzado, ocultamos la flecha hacia atrás.
        ),
        backgroundColor: ResQColors.surface,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.forzarCompletar)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ResQColors.primary50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Para poder usar ResQ, necesitamos algunos datos básicos '
                      'sobre ti. Esto ayuda a los equipos médicos a atenderte '
                      'de forma más segura.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                const Text('Primer nombre',
                    style: TextStyle(color: Colors.grey)),
                TextFormField(
                  controller: _nombre1Ctrl,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu primer nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text('Segundo nombre (opcional)',
                    style: TextStyle(color: Colors.grey)),
                TextFormField(controller: _nombre2Ctrl),
                const SizedBox(height: 12),
                const Text('Primer apellido',
                    style: TextStyle(color: Colors.grey)),
                TextFormField(
                  controller: _apellido1Ctrl,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu primer apellido'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text('Segundo apellido (opcional)',
                    style: TextStyle(color: Colors.grey)),
                TextFormField(controller: _apellido2Ctrl),
                const SizedBox(height: 12),
                const Text('Tipo de documento',
                    style: TextStyle(color: Colors.grey)),
                DropdownButtonFormField<String>(
                  initialValue: _tipoDoc,
                  items: const [
                    DropdownMenuItem(
                      value: 'CEDULA',
                      child: Text('Cédula de ciudadanía'),
                    ),
                    DropdownMenuItem(
                      value: 'TARJETA_DE_IDENTIDAD',
                      child: Text('Tarjeta de identidad'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _tipoDoc = v ?? 'CEDULA'),
                ),
                const SizedBox(height: 12),
                const Text('Número de documento',
                    style: TextStyle(color: Colors.grey)),
                TextFormField(
                  controller: _docCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa tu documento'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text('Fecha de nacimiento',
                    style: TextStyle(color: Colors.grey)),
                InkWell(
                  onTap: _pickFechaNac,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: UnderlineInputBorder(),
                    ),
                    child: Text(
                      _fechaNac == null
                          ? 'Selecciona fecha'
                          : '${_fechaNac!.day}/${_fechaNac!.month}/${_fechaNac!.year}',
                      style: TextStyle(
                        color:
                            _fechaNac == null ? Colors.black45 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
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
                    onPressed: _loading ? null : _guardar,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(
                            widget.forzarCompletar
                                ? 'Guardar y continuar'
                                : 'Guardar cambios',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
