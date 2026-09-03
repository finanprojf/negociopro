import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import 'local_database.dart';
import 'cliente_service.dart';

class PuntosService {
  static const _uuid = Uuid();

  /// Puntos que gana el cliente por el monto de la venta
  static int calcularPuntos(double montoVenta, {double puntosPorPeso = 1.0}) {
    return (montoVenta * puntosPorPeso).floor();
  }

  /// Valor en RD$ de los puntos acumulados
  static double valorEnDinero(int puntos, {double valorPunto = 0.01}) {
    return puntos * valorPunto;
  }

  /// Agregar puntos a un cliente tras una venta
  static Future<bool> acumularPuntos(
      String clienteId, String? ventaId, double montoVenta) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final puntos = calcularPuntos(montoVenta);
    if (puntos <= 0) return true;

    final id = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();

    await LocalDatabase.insertar('movimientos_puntos', {
      'id': id, 'empresa_id': empresaId,
      'cliente_id': clienteId, 'venta_id': ventaId,
      'tipo': 'ganado', 'puntos': puntos,
      'descripcion': 'Compra por ${montoVenta.toStringAsFixed(2)}',
      'synced': 0, 'created_at': ahora,
    });

    if (SupabaseService.isOnline) {
      try {
        await SupabaseService.client.from('movimientos_puntos').insert({
          'id': id, 'empresa_id': empresaId,
          'cliente_id': clienteId, 'venta_id': ventaId,
          'tipo': 'ganado', 'puntos': puntos,
          'descripcion': 'Compra por ${montoVenta.toStringAsFixed(2)}',
        });
        await LocalDatabase.marcarSynced('movimientos_puntos', id);
      } catch (_) {}
    }

    return true;
  }

  /// Canjear puntos de un cliente
  static Future<bool> canjearPuntos(
      String clienteId, int puntosACanjear) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();

    await LocalDatabase.insertar('movimientos_puntos', {
      'id': id, 'empresa_id': empresaId,
      'cliente_id': clienteId,
      'tipo': 'canjeado', 'puntos': -puntosACanjear,
      'descripcion': 'Canje de $puntosACanjear puntos',
      'synced': 0, 'created_at': ahora,
    });

    if (SupabaseService.isOnline) {
      try {
        await SupabaseService.client.from('movimientos_puntos').insert({
          'id': id, 'empresa_id': empresaId,
          'cliente_id': clienteId,
          'tipo': 'canjeado', 'puntos': -puntosACanjear,
          'descripcion': 'Canje de $puntosACanjear puntos',
        });
      } catch (_) {}
    }

    return true;
  }

  /// Obtener puntos actuales de un cliente
  static Future<int> getPuntosCliente(String clienteId) async {
    final db = await LocalDatabase.database;
    final res = await db.rawQuery(
      'SELECT SUM(puntos) as total FROM movimientos_puntos WHERE cliente_id = ?',
      [clienteId],
    );
    return (res.first['total'] as num?)?.toInt() ?? 0;
  }
}