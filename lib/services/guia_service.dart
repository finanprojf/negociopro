import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el estado del onboarding/guías de NegocioPro.
/// Usa SharedPreferences — funciona 100% offline.
class GuiaService {
  static const _keyBienvenida = 'guia_bienvenida_v1';
  static const _prefModulo    = 'guia_modulo_v1_';

  // ── Bienvenida ─────────────────────────────────────────────
  static Future<bool> bienvenidaMostrada() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyBienvenida) ?? false;
  }

  static Future<void> marcarBienvenida() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyBienvenida, true);
  }

  // ── Guías por módulo ───────────────────────────────────────
  static Future<bool> moduloVisto(String modulo) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('$_prefModulo$modulo') ?? false;
  }

  static Future<void> marcarModulo(String modulo) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('$_prefModulo$modulo', true);
  }

  /// Resetea TODAS las guías (para "Ver guías de nuevo")
  static Future<void> resetearTodo() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyBienvenida, false);
    for (final m in modulos.keys) {
      await p.setBool('$_prefModulo$m', false);
    }
  }

  /// Resetea solo las guías de módulos (mantiene bienvenida)
  static Future<void> resetearGuiasModulos() async {
    final p = await SharedPreferences.getInstance();
    for (final m in modulos.keys) {
      await p.setBool('$_prefModulo$m', false);
    }
  }

  // ── Definición de guías ────────────────────────────────────
  static const Map<String, _GuiaInfo> modulos = {
    'pos': _GuiaInfo(
      icono: '🛒',
      titulo: 'Punto de Venta',
      descripcion:
          'Aquí registras cada venta. Selecciona los productos, revisa el total y elige cómo te pagan. Rápido y sin complicaciones.',
    ),
    'inventario': _GuiaInfo(
      icono: '📦',
      titulo: 'Inventario',
      descripcion:
          'Mantén tus productos organizados. Agrega artículos con precio, costo y cantidad para saber siempre qué tienes disponible.',
    ),
    'clientes': _GuiaInfo(
      icono: '👥',
      titulo: 'Clientes',
      descripcion:
          'Registra a tus clientes para llevar su historial de compras, fiados y puntos de fidelización.',
    ),
    'fiado': _GuiaInfo(
      icono: '📋',
      titulo: 'Fiado',
      descripcion:
          'Controla las cuentas pendientes de tus clientes. Registra abonos, consulta saldos y comparte comprobantes al instante.',
    ),
    'apartados': _GuiaInfo(
      icono: '🏷️',
      titulo: 'Apartados',
      descripcion:
          'Reserva artículos para tus clientes. Lleva el control de los pagos parciales hasta la entrega final.',
    ),
    'gastos': _GuiaInfo(
      icono: '💸',
      titulo: 'Gastos',
      descripcion:
          'Registra los gastos del negocio para tener una visión clara de tus movimientos y calcular tus ganancias reales.',
    ),
    'reportes': _GuiaInfo(
      icono: '📊',
      titulo: 'Reportes',
      descripcion:
          'Consulta cómo van tus ventas, ganancias y productos más vendidos. Toda la información de tu negocio en un solo lugar.',
    ),
    'encargos': _GuiaInfo(
      icono: '📝',
      titulo: 'Encargos',
      descripcion:
          'Gestiona pedidos especiales de tus clientes. Anota lo que te encargan y lleva el seguimiento hasta la entrega.',
    ),
  };
}

class _GuiaInfo {
  final String icono;
  final String titulo;
  final String descripcion;
  const _GuiaInfo({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });
}
