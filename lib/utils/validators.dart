class AppValidators {
  static String? requerido(String? v, [String campo = 'Este campo']) {
    if (v == null || v.trim().isEmpty) return '$campo es requerido';
    return null;
  }

  static String? correo(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final regex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!regex.hasMatch(v.trim())) return 'Correo inválido';
    return null;
  }

  static String? monto(String? v, {bool requerido = true, double min = 0}) {
    if (v == null || v.isEmpty) return requerido ? 'Ingresa un monto' : null;
    final n = double.tryParse(v);
    if (n == null) return 'Número inválido';
    if (n < min) return 'Debe ser mayor a $min';
    return null;
  }

  static String? telefono(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final limpio = v.replaceAll(RegExp(r'[\s\-()]'), '');
    if (limpio.length < 7) return 'Teléfono muy corto';
    return null;
  }

  static String? cedula(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final limpio = v.replaceAll(RegExp(r'[\s\-]'), '');
    if (limpio.length != 11) return 'Cédula debe tener 11 dígitos';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? confirmarPassword(String? v, String original) {
    if (v != original) return 'Las contraseñas no coinciden';
    return null;
  }
}