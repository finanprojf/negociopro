import 'supabase_service.dart';
import 'local_database.dart';

/// Sincronización centralizada: empuja a Supabase todo lo que
/// quedó pendiente (synced = 0) cuando no había internet.
class SyncService {
  // Evitar que corra dos veces al mismo tiempo
  static bool _corriendo = false;

  /// Llama esto cada vez que detectes conexión o al abrir la app.
  static Future<void> sincronizarTodo() async {
    if (_corriendo) return;
    if (!await SupabaseService.isOnlineAsync) return;

    _corriendo = true;
    try {
      await _syncTablaSimple('categorias');
      await _syncTablaSimple('clientes');
      await _syncProductos();
      await _syncVentas();
      await _syncFiados();
      await _syncAbonosFiado();
      await _syncApartados();
      await _syncAbonosApartado();
      await _syncTablaSimple('gastos');
      await _syncTablaSimple('encargos');
    } finally {
      _corriendo = false;
    }
  }

  // ============================================================
  // TABLAS SIMPLES — upsert directo sin relaciones
  // ============================================================

  static Future<void> _syncTablaSimple(String tabla) async {
    final pendientes = await LocalDatabase.consultarPendientesSync(tabla);
    for (final row in pendientes) {
      try {
        final data = _limpiarParaSupabase(row);
        await SupabaseService.client.from(tabla).upsert(data);
        await LocalDatabase.marcarSynced(tabla, row['id'] as String);
      } catch (_) {
        // Si falla un registro, continuar con el siguiente
      }
    }
  }

  // ============================================================
  // PRODUCTOS — igual que simple pero limpia campos extra
  // ============================================================

  static Future<void> _syncProductos() async {
    final pendientes =
        await LocalDatabase.consultarPendientesSync('productos');
    for (final row in pendientes) {
      try {
        final data = _limpiarParaSupabase(row);
        data.remove('categoria_nombre'); // campo solo local
        await SupabaseService.client.from('productos').upsert(data);
        await LocalDatabase.marcarSynced('productos', row['id'] as String);
      } catch (_) {}
    }
  }

  // ============================================================
  // VENTAS — primero la venta, luego sus detalles
  // ============================================================

  static Future<void> _syncVentas() async {
    final pendientes = await LocalDatabase.consultarPendientesSync('ventas');
    final db = await LocalDatabase.database;

    for (final venta in pendientes) {
      try {
        final ventaData = _limpiarParaSupabase(venta);
        await SupabaseService.client.from('ventas').upsert(ventaData);

        // Detalles de esta venta
        final detalles = await db.query('detalle_ventas',
            where: 'venta_id = ?', whereArgs: [venta['id']]);
        for (final d in detalles) {
          try {
            await SupabaseService.client
                .from('detalle_ventas')
                .upsert(Map<String, dynamic>.from(d));
          } catch (_) {}
        }

        // Si era fiado, sincronizar el fiado asociado
        if (venta['tipo_pago'] == 'fiado') {
          final fiados = await db.query('fiados',
              where: 'venta_id = ? AND synced = 0',
              whereArgs: [venta['id']]);
          for (final f in fiados) {
            try {
              await SupabaseService.client
                  .from('fiados')
                  .upsert(_limpiarParaSupabase(f));
              await LocalDatabase.marcarSynced(
                  'fiados', f['id'] as String);
            } catch (_) {}
          }
        }

        await LocalDatabase.marcarSynced('ventas', venta['id'] as String);
      } catch (_) {}
    }
  }

  // ============================================================
  // FIADOS Y ABONOS
  // ============================================================

  static Future<void> _syncFiados() async {
    await _syncTablaSimple('fiados');
  }

  static Future<void> _syncAbonosFiado() async {
    final pendientes =
        await LocalDatabase.consultarPendientesSync('abonos_fiado');
    for (final row in pendientes) {
      try {
        final data = _limpiarParaSupabase(row);
        await SupabaseService.client.from('abonos_fiado').upsert(data);

        // Actualizar saldo en Supabase después de sync abono
        final monto = (row['monto'] as num).toDouble();
        final fiadoId = row['fiado_id'] as String;
        await _actualizarSaldoFiado(fiadoId, monto);

        await LocalDatabase.marcarSynced(
            'abonos_fiado', row['id'] as String);
      } catch (_) {}
    }
  }

  static Future<void> _actualizarSaldoFiado(
      String fiadoId, double monto) async {
    try {
      final res = await SupabaseService.client
          .from('fiados')
          .select('saldo_pendiente')
          .eq('id', fiadoId)
          .single();
      final saldoActual = (res['saldo_pendiente'] as num).toDouble();
      final nuevoSaldo = (saldoActual - monto).clamp(0.0, double.infinity);
      await SupabaseService.client.from('fiados').update({
        'saldo_pendiente': nuevoSaldo,
        'estado': nuevoSaldo <= 0 ? 'pagado' : 'activo',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', fiadoId);
    } catch (_) {}
  }

  // ============================================================
  // APARTADOS Y ABONOS
  // ============================================================

  static Future<void> _syncApartados() async {
    await _syncTablaSimple('apartados');
  }

  static Future<void> _syncAbonosApartado() async {
    final pendientes =
        await LocalDatabase.consultarPendientesSync('abonos_apartado');
    for (final row in pendientes) {
      try {
        final data = _limpiarParaSupabase(row);
        await SupabaseService.client.from('abonos_apartado').upsert(data);

        final monto = (row['monto'] as num).toDouble();
        final apartadoId = row['apartado_id'] as String;
        await _actualizarSaldoApartado(apartadoId, monto);

        await LocalDatabase.marcarSynced(
            'abonos_apartado', row['id'] as String);
      } catch (_) {}
    }
  }

  static Future<void> _actualizarSaldoApartado(
      String apartadoId, double monto) async {
    try {
      final res = await SupabaseService.client
          .from('apartados')
          .select('saldo_pendiente, monto_pagado')
          .eq('id', apartadoId)
          .single();
      final saldoActual = (res['saldo_pendiente'] as num).toDouble();
      final pagadoActual = (res['monto_pagado'] as num).toDouble();
      final nuevoSaldo = (saldoActual - monto).clamp(0.0, double.infinity);
      await SupabaseService.client.from('apartados').update({
        'saldo_pendiente': nuevoSaldo,
        'monto_pagado': pagadoActual + monto,
        'estado': nuevoSaldo <= 0 ? 'completado' : 'activo',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', apartadoId);
    } catch (_) {}
  }

  // ============================================================
  // UTILIDAD — quitar campos que no van a Supabase
  // ============================================================

  static Map<String, dynamic> _limpiarParaSupabase(
      Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    data.remove('synced');
    return data;
  }
}
