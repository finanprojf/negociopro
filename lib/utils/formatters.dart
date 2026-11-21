import 'package:intl/intl.dart';

class AppFormatters {
  static final _moneda = NumberFormat('#,##0.00', 'es_DO');
  static final _fecha = DateFormat('dd/MM/yyyy', 'es_DO');
  static final _fechaHora = DateFormat('dd/MM/yyyy hh:mm a', 'es_DO');
  static final _fechaCorta = DateFormat('dd MMM', 'es_DO');
  static final _mes = DateFormat('MMMM yyyy', 'es_DO');

  /// RD$ 1,250.00
  static String moneda(double monto, {String simbolo = 'RD\$'}) {
    return '$simbolo ${_moneda.format(monto)}';
  }

  /// 1,250.00 (sin símbolo)
  static String numero(double monto) => _moneda.format(monto);

  /// 15/06/2025
  static String fecha(DateTime? date) {
    if (date == null) return '—';
    return _fecha.format(date);
  }

  /// 15/06/2025 02:30 PM (hora local)
  static String fechaHora(DateTime? date) {
    if (date == null) return '—';
    return _fechaHora.format(date.toLocal());
  }

  /// 15 Jun
  static String fechaCorta(DateTime? date) {
    if (date == null) return '—';
    return _fechaCorta.format(date);
  }

  /// junio 2025
  static String mes(DateTime? date) {
    if (date == null) return '—';
    return _mes.format(date);
  }

  /// 5 → "5 unidades" / 0.5 → "0.5 kg"
  static String stock(double cantidad, String unidad) {
    final n = cantidad == cantidad.roundToDouble()
        ? cantidad.toInt().toString()
        : cantidad.toStringAsFixed(2);
    var u = unidad;
    final esUno = cantidad == 1;
    if (!esUno) {
      final l = u.toLowerCase();
      if (l == 'unidad') u = 'unidades';
      else if (l == 'libra') u = 'libras';
      else if (l == 'caja') u = 'cajas';
      else if (l == 'paquete') u = 'paquetes';
      else if (l == 'botella') u = 'botellas';
      else if (l == 'galón' || l == 'galon') u = 'galones';
      else if (l == 'litro') u = 'litros';
      else if (l == 'kilo') u = 'kilos';
      else if (l == 'onza') u = 'onzas';
    }
    return '$n $u';
  }

  /// Tiempo relativo: "hace 5 min", "hace 2 horas"
  static String tiempoRelativo(DateTime date) {
    final ahoraUtc = DateTime.now().toUtc();
    final fechaUtc = date.isUtc ? date : date.toUtc();
    final diff = ahoraUtc.difference(fechaUtc);
    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return fecha(date);
  }

  /// Porcentaje: 0.25 → "25%"
  static String porcentaje(double valor) {
    return '${(valor * 100).toStringAsFixed(0)}%';
  }
}