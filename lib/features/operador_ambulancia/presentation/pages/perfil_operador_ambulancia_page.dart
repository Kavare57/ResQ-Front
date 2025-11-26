import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/api/operador_ambulancia_api.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/pages/login_page.dart';

class PerfilOperadorAmbulanciaPage extends StatefulWidget {
  /// Si es true, no dejamos salir hasta que el usuario complete y guarde
  /// toda la información obligatoria (flujo justo después del registro).
  final bool forzarCompletar;

  const PerfilOperadorAmbulanciaPage({
    super.key,
    this.forzarCompletar = false,
  });

  @override
  State<PerfilOperadorAmbulanciaPage> createState() =>
      _PerfilOperadorAmbulanciaPageState();
}

class _PerfilOperadorAmbulanciaPageState
    extends State<PerfilOperadorAmbulanciaPage> {
  final _formKey = GlobalKey<FormState>();

  final _nombre1Ctrl = TextEditingController();
  final _nombre2Ctrl = TextEditingController();
  final _apellido1Ctrl = TextEditingController();
  final _apellido2Ctrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _licenciaCtrl = TextEditingController();

  String _tipoDoc = 'CEDULA';
  DateTime? _fechaNac;
  bool _disponibilidad = true;
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
      final api = OperadorAmbulanciaApi();
      final perfil = await api.obtenerPerfilActual();

      if (!mounted) return;

      setState(() {
        _nombre1Ctrl.text = perfil['nombre'] ?? '';
        _nombre2Ctrl.text = perfil['nombre2'] ?? '';
        _apellido1Ctrl.text = perfil['apellido'] ?? '';
        _apellido2Ctrl.text = perfil['apellido2'] ?? '';
        _docCtrl.text = perfil['numeroDocumento'] ?? '';
        _licenciaCtrl.text = perfil['numerolicencia'] ?? '';
        _tipoDoc = perfil['tipoDocumento'] ?? 'CEDULA';
        _disponibilidad = perfil['disponibilidad'] ?? true;

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
    _licenciaCtrl.dispose();
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
      final api = OperadorAmbulanciaApi();

      if (widget.forzarCompletar) {
        // Es registro: crear nuevo perfil
        await api.crearPerfil(
          nombre: _nombre1Ctrl.text.trim(),
          nombre2: _nombre2Ctrl.text.trim().isEmpty
              ? null
              : _nombre2Ctrl.text.trim(),
          apellido: _apellido1Ctrl.text.trim(),
          apellido2: _apellido2Ctrl.text.trim().isEmpty
              ? null
              : _apellido2Ctrl.text.trim(),
          tipoDocumento: _tipoDoc,
          numeroDocumento: _docCtrl.text.trim(),
          fechaNacimiento: _fechaNac!,
          numerolicencia: _licenciaCtrl.text.trim(),
          disponibilidad: _disponibilidad,
        );
      } else {
        // Es edición: actualizar perfil
        await api.guardarPerfil(
          nombre: _nombre1Ctrl.text.trim(),
          nombre2: _nombre2Ctrl.text.trim().isEmpty
              ? null
              : _nombre2Ctrl.text.trim(),
          apellido: _apellido1Ctrl.text.trim(),
          apellido2: _apellido2Ctrl.text.trim().isEmpty
              ? null
              : _apellido2Ctrl.text.trim(),
          tipoDocumento: _tipoDoc,
          numeroDocumento: _docCtrl.text.trim(),
          fechaNacimiento: _fechaNac!,
          numerolicencia: _licenciaCtrl.text.trim(),
          disponibilidad: _disponibilidad,
        );
      }

      if (!mounted) return;

      if (widget.forzarCompletar) {
        // Después del registro: redirigir a Login para iniciar sesión formalmente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil completado! Por favor, inicia sesión'),
            duration: Duration(seconds: 2),
          ),
        );

        // Esperamos a que el snackbar se muestre y luego redirigimos
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted) {
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
        _licenciaCtrl.text.trim().isNotEmpty &&
        _fechaNac != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoPerfil) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: ResQColors.primary500,
          foregroundColor: Colors.white,
          title: const Text('Perfil del operador'),
          automaticallyImplyLeading: !widget.forzarCompletar,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ResQColors.primary500,
        foregroundColor: Colors.white,
        title: const Text('Perfil del operador'),
        automaticallyImplyLeading: !widget.forzarCompletar,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              const SizedBox(height: 16),

              // Nombres
              Text(
                'Nombres',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombre1Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre (obligatorio)',
                  hintText: 'Tu nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombre2Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Segundo nombre (opcional)',
                  hintText: 'Tu segundo nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Apellidos
              Text(
                'Apellidos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _apellido1Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Apellido (obligatorio)',
                  hintText: 'Tu apellido',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellido2Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Segundo apellido (opcional)',
                  hintText: 'Tu segundo apellido',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Fecha de nacimiento
              Text(
                'Fecha de nacimiento',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickFechaNac,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fechaNac == null
                            ? 'Selecciona una fecha'
                            : _fechaNac!.toString().split(' ')[0],
                        style: TextStyle(
                          color: _fechaNac == null ? Colors.grey : Colors.black,
                        ),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Documento
              Text(
                'Documento de identidad',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _tipoDoc,
                items: const [
                  DropdownMenuItem(value: 'CEDULA', child: Text('Cédula')),
                  DropdownMenuItem(
                      value: 'PASAPORTE', child: Text('Pasaporte')),
                  DropdownMenuItem(value: 'VISA', child: Text('Visa')),
                ].map((e) => e).toList(),
                onChanged: (v) => setState(() => _tipoDoc = v ?? 'CEDULA'),
                decoration: const InputDecoration(
                  labelText: 'Tipo de documento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _docCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de documento (obligatorio)',
                  hintText: '1234567890',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // Licencia de conducir
              Text(
                'Licencia de conducir',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _licenciaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de licencia (obligatorio)',
                  hintText: 'ABC123456',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // Disponibilidad
              SwitchListTile(
                title: const Text('Disponible para emergencias'),
                value: _disponibilidad,
                onChanged: (v) => setState(() => _disponibilidad = v),
                contentPadding: const EdgeInsets.all(0),
              ),
              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _datosCompletos && !_loading ? _guardar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResQColors.primary500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Guardar perfil',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
