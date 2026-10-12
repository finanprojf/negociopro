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

        // Detalles de esta venta (limpiar synced y convertir booleanos)
        final detalles = await db.query('detalle_ventas',
            where: 'venta_id = ?', whereArgs: [venta['id']]);
        for (final d in detalles) {
          try {
            await SupabaseService.client
                .from('detalle_ventas')
                .upsert(_limpiarParaSupabase(d));
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
        // NO llamar _actualizarSaldoFiado aquí: _syncFiados ya empuja el saldo
        // correcto desde SQLite local (que ya descontó todos los abonos).
        // Llamarlo aquí causaría doble-resta (saldo incorrecto en Supabase).
        await LocalDatabase.marcarSynced(
            'abonos_fiado', row['id'] as String);
      } catch (_) {}
    }
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
        // NO llamar _actualizarSaldoApartado aquí: _syncApartados ya empuja el
        // saldo correcto desde SQLite local. Llamarlo aquí causaría doble-resta.
        await LocalDatabase.marcarSynced(
            'abonos_apartado', row['id'] as String);
      } catch (_) {}
    }
  }

  // ============================================================
  // UTILIDAD — quitar campos que no van a Supabase
  // ============================================================

  static Map<String, dynamic> _limpiarParaSupabase(
      Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    data.remove('synced');
    // SQLite guarda booleanos como 0/1 (INTEGER).
    // Supabase (PostgreSQL) espera true/false. Convertir campos conocidos.
    for (final campo in ['activo', 'completado', 'entregado',
        'es_elaborado', 'visible', 'permitir_resenas']) {
      if (data.containsKey(campo) && data[campo] is int) {
        data[campo] = data[campo] == 1;
      }
    }
    // Quitar numero_venta si es null para que Supabase use su DEFAULT (secuencia)
    if (data['numero_venta'] == null) data.remove('numero_venta');
    return data;
  }
}
