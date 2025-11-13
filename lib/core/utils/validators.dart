class Validators {
  static String? email(String? v) {
    final x = v?.trim() ?? '';
    if (x.isEmpty) return 'Ingresa tu email';
    final re = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    if (!re.hasMatch(x)) return 'Email no válido';
    return null;
  }

  static String? password(String? v) {
    final x = v ?? '';
    if (x.isEmpty) return 'Ingresa tu contraseña';
    if (x.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? required(String? v, {String label = 'Campo'}) {
    if ((v ?? '').trim().isEmpty) return 'Ingresa $label';
    return null;
  }
}
