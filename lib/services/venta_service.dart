import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../models/venta_model.dart';
import '../models/producto_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';
class VentaService {
  static const _uuid = Uuid();

  static Future<List<VentaModel>> getVentas({DateTime? fecha}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    // Cargar local primero (con detalles desde detalle_ventas)
    final local = await LocalDatabase.consultar('ventas', empresaId);
    final db = await LocalDatabase.database;
    // Batch load detalles (1 query instead of N)
    final ids1 = local.map((m) => "'${m['id']}'").join(',');
    final detallesAll1 = ids1.isEmpty ? <Map<String,Object?>>[] :
        await db.rawQuery('SELECT * FROM detalle_ventas WHERE venta_id IN ($ids1)');
    final detallesMap1 = <String, List<Map<String,Object?>>>{};
    for (final d in detallesAll1) {
      final vid = d['venta_id'] as String;
      detallesMap1.putIfAbsent(vid, () => []).add(d);
    }
    var ventasLocal = local.map((m) {
      final map = Map<String, dynamic>.from(m);
      map['detalle_ventas'] = detallesMap1[m['id']] ?? [];
      return VentaModel.fromMap(map);
    }).toList();
    // Filtrar por fecha en modo offline también
    if (fecha != null) {
      final inicioFiltroLocal = DateTime(fecha.year, fecha.month, fecha.day);
      final finFiltroLocal = inicioFiltroLocal.add(const Duration(days: 1));
      ventasLocal = ventasLocal.where((v) {
        if (v.createdAt == null) return false;
        final fl = v.createdAt!.toLocal();
        return fl.isAfter(inicioFiltroLocal) && fl.isBefore(finFiltroLocal);
      }).toList();
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        List<dynamic> res;

        if (fecha != null) {
          final inicioLocal = DateTime(fecha.year, fecha.month, fecha.day);
          final finLocal = inicioLocal.add(const Duration(days: 1));
          res = await SupabaseService.client
              .from('ventas')
              .select('*, clientes(nombre), detalle_ventas(*)')
              .eq('empresa_id', empresaId)
              .gte('created_at', inicioLocal.toUtc().toIso8601String())
              .lt('created_at', finLocal.toUtc().toIso8601String())
              .order('created_at', ascending: false);
        } else {
          res = await SupabaseService.client
              .from('ventas')
              .select('*, clientes(nombre), detalle_ventas(*)')
              .eq('empresa_id', empresaId)
              .order('created_at', ascending: false);
        }

        // Guardar en local (ventas + detalles para consistencia offline)
        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          final detallesRemoto = List<dynamic>.from(map['detalle_ventas'] ?? []);
          map.remove('clientes');
          map.remove('detalle_ventas');
          map['synced'] = 1;
          try { await LocalDatabase.insertar('ventas', map); } catch (_) {}
          for (final d in detallesRemoto) {
            try {
              await LocalDatabase.insertar(
                  'detalle_ventas', Map<String, dynamic>.from(d as Map));
            } catch (_) {}
          }
        }

        final ventasOnline = res.map((m) {
          final map = Map<String, dynamic>.from(m);
          if (m['clientes'] != null) {
            map['cliente_nombre'] = m['clientes']['nombre'];
          }
          return VentaModel.fromMap(map);
        }).toList();

        // PASO FINAL: añadir explícitamente ventas offline (synced=0) no en el resultado.
        // Esto garantiza que ventas hechas sin internet siempre aparezcan al volver en línea.
        final idsYaEnResultado = ventasOnline.map((v) => v.id).toSet();
        final pendientesOffline = await _getVentasPendientes(
            db, empresaId, fecha, idsYaEnResultado);

        final resultado = [...ventasOnline, ...pendientesOffline]
          ..sort((a, b) => (b.createdAt ?? DateTime.now())
              .compareTo(a.createdAt ?? DateTime.now()));
        return resultado;

      } catch (_) {}
    }

    // Modo offline: devolver todas las locales + garantizar pendientes synced=0
    return ventasLocal;
  }

  /// Busca ventas synced=0 en SQLite no incluidas en [idsExcluir].
  /// Usa comparación UTC de strings para el filtro de fecha.
  static Future<List<VentaModel>> _getVentasPendientes(
    Database db,
    String empresaId,
    DateTime? fecha,
    Set<String> idsExcluir,
  ) async {
    List<Map<String, Object?>> rows;
    if (fecha != null) {
      final inicioUtc = DateTime(fecha.year, fecha.month, fecha.day)
          .toUtc()
          .toIso8601String();
      final finUtc = DateTime(fecha.year, fecha.month, fecha.day + 1)
          .toUtc()
          .toIso8601String();
      rows = await db.query(
        'ventas',
        where: 'empresa_id = ? AND synced = 0 AND created_at >= ? AND created_at < ?',
        whereArgs: [empresaId, inicioUtc, finUtc],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query(
        'ventas',
        where: 'empresa_id = ? AND synced = 0',
        whereArgs: [empresaId],
        orderBy: 'created_at DESC',
      );
    }

    final result = <VentaModel>[];
    for (final row in rows) {
      final id = row['id'] as String? ?? '';
      if (idsExcluir.contains(id)) continue;
      // Cargar detalles de la venta offline
      final detalles = await db.query(
          'detalle_ventas', where: 'venta_id = ?', whereArgs: [id]);
      final map = Map<String, dynamic>.from(row);
      map['detalle_ventas'] = detalles;
      try { result.add(VentaModel.fromMap(map)); } catch (_) {}
    }
    return result;
  }

  static Future<double> getTotalVentasHoy() async {
    final ventas = await getVentas(fecha: DateTime.now());
    double total = 0;
    for (final v in ventas) {
      if (v.estado == 'completada') total += v.total;
    }
    return total;
  }
static Future<void> sincronizarPendientes() async {
    if (!await SupabaseService.isOnlineAsync) return;

    final pendientes = await LocalDatabase.consultarPendientesSync('ventas');
    final db = await LocalDatabase.database;

    for (final v in pendientes) {
      try {
        // 1. Subir la venta
        final ventaData = Map<String, dynamic>.from(v)..remove('synced');
        // Si numero_venta es null, quitar el campo para que Supabase use su DEFAULT (secuencia)
        // Si se envía null explícito, PostgreSQL NO aplica el DEFAULT y falla en columna NOT NULL
        if (ventaData['numero_venta'] == null) ventaData.remove('numero_venta');
        // Limpiar campos nulos que puedan causar error en columnas NOT NULL
        ventaData.removeWhere((k, v) => v == null &&
            ['itbis', 'notas', 'updated_at'].contains(k));
        await SupabaseService.client.from('ventas').upsert(ventaData);

        // 2. Subir los detalles y actualizar stock con el valor ACTUAL remoto
        final detalles = await db.query('detalle_ventas',
            where: 'venta_id = ?', whereArgs: [v['id']]);
        final ahoraSync = DateTime.now().toUtc().toIso8601String();
        for (final d in detalles) {
          try {
            await SupabaseService.client
                .from('detalle_ventas')
                .upsert(Map<String, dynamic>.from(d));
          } catch (_) {}
          // Descontar stock del servidor leyendo el valor remoto primero
          final pid = d['producto_id'] as String?;
          final qty = (d['cantidad'] as num? ?? 0).toDouble();
          if (pid != null && qty > 0) {
            try {
              final res = await SupabaseService.client
                  .from('productos')
                  .select('stock_actual')
                  .eq('id', pid)
                  .single();
              final stockRemoto = (res['stock_actual'] as num? ?? 0).toDouble();
              final nuevoStock = (stockRemoto - qty).clamp(0.0, double.infinity);
              await SupabaseService.client
                  .from('productos')
                  .update({'stock_actual': nuevoStock, 'updated_at': ahoraSync})
                  .eq('id', pid);
            } catch (_) {}
          }
        }

        // 3. Si era fiado, sincronizar el fiado asociado
        if (v['tipo_pago'] == 'fiado' && v['cliente_id'] != null) {
          final fiados = await db.query('fiados',
              where: 'venta_id = ? AND synced = 0', whereArgs: [v['id']]);
          for (final f in fiados) {
            try {
              final fiadoData = Map<String, dynamic>.from(f)..remove('synced');
              await SupabaseService.client.from('fiados').upsert(fiadoData);
              await LocalDatabase.marcarSynced('fiados', f['id'] as String);
            } catch (_) {}
          }
        }

        await LocalDatabase.marcarSynced('ventas', v['id'] as String);
      } catch (_) {}
    }
  }
  static Future<bool> registrarVenta({
    required List<Map<String, dynamic>> items,
    required String tipoPago,
    String? clienteId,
    double descuento = 0,
    double montoPagado = 0,
  }) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final ventaId = _uuid.v4();
   final ahora = DateTime.now().toUtc().toIso8601String();

    double subtotal = 0;
    for (final item in items) {
      final p = item['producto'] as ProductoModel;
      final cantidad = (item['cantidad'] as num).toDouble();
      subtotal += p.precioEfectivo * cantidad;
    }
    final total = subtotal - descuento;
    final cambio = (montoPagado - total).clamp(0.0, double.infinity);

    final ventaMap = {
      'id': ventaId,
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'usuario_id': SupabaseService.userId,
      'tipo_pago': tipoPago,
      'subtotal': subtotal,
      'descuento': descuento,
      'total': total,
      'monto_pagado': montoPagado,
      'cambio': cambio,
      'estado': 'completada',
      'synced': 0,
      'created_at': ahora,
    };

    await LocalDatabase.insertar('ventas', ventaMap);

    for (final item in items) {
      final p = item['producto'] as ProductoModel;
      final cantidad = (item['cantidad'] as num).toDouble();
      final sub = p.precioEfectivo * cantidad;

      await LocalDatabase.insertar('detalle_ventas', {
        'id': _uuid.v4(),
        'venta_id': ventaId,
        'producto_id': p.id,
        'nombre_producto': p.nombre,
        'cantidad': cantidad,
        'precio_unitario': p.precioEfectivo,
        'descuento': 0,
        'subtotal': sub,
        'created_at': ahora,
      });

      final nuevoStock =
          (p.stockActual - cantidad).clamp(0.0, double.infinity);
      await LocalDatabase.actualizar('productos',
          {'stock_actual': nuevoStock, 'updated_at': ahora}, 'id', p.id);
    }

  if (tipoPago == 'fiado' && clienteId != null) {
      final saldoFiado = total - montoPagado;
      await LocalDatabase.insertar('fiados', {
        'id': _uuid.v4(),
        'empresa_id': empresaId,
        'cliente_id': clienteId,
        'venta_id': ventaId,
        'monto_original': saldoFiado,
        'saldo_pendiente': saldoFiado,
        'estado': 'activo',
        'synced': 0,
        'created_at': ahora,
        'updated_at': ahora,
      });
    }

   

   // Sync en background — no bloquea la UI
    SupabaseService.isOnlineAsync.then((online) {
      if (online) _syncVenta(ventaId, ventaMap, items, ahora).ignore();
    });

    // Los descuentos NO se registran como gastos:
    // ya reducen el total de la venta directamente en el campo descuento.
    return true;
  }
  // Sync inmediato después de registrar una venta cuando hay internet
  static Future<void> _syncVenta(
    String ventaId,
    Map<String, dynamic> ventaMap,
    List<Map<String, dynamic>> items,
    String ahora,
  ) async {
    final ventaOnline = Map<String, dynamic>.from(ventaMap)..remove('synced');
    await SupabaseService.client.from('ventas').upsert(ventaOnline);

    // Detalles: leer desde SQLite para usar los mismos IDs (evitar duplicados)
    final db = await LocalDatabase.database;
    final detalles = await db.query('detalle_ventas',
        where: 'venta_id = ?', whereArgs: [ventaId]);
    for (final d in detalles) {
      try {
        await SupabaseService.client
            .from('detalle_ventas')
            .upsert(Map<String, dynamic>.from(d));
      } catch (_) {}
    }

    // Actualizar stock en Supabase — leer el stock ACTUAL remoto primero
    // para evitar sobreescribir con datos viejos si hubo ventas offline múltiples
    for (final item in items) {
      final p = item['producto'] as ProductoModel;
      final cantidad = (item['cantidad'] as num).toDouble();
      try {
        final res = await SupabaseService.client
            .from('productos')
            .select('stock_actual')
            .eq('id', p.id)
            .single();
        final stockRemoto = (res['stock_actual'] as num? ?? p.stockActual).toDouble();
        final nuevoStock = (stockRemoto - cantidad).clamp(0.0, double.infinity);
        await SupabaseService.client
            .from('productos')
            .update({'stock_actual': nuevoStock, 'updated_at': ahora})
            .eq('id', p.id);
      } catch (_) {}
    }

    // Si era fiado, sincronizar el registro de fiado
    if (ventaMap['tipo_pago'] == 'fiado' && ventaMap['cliente_id'] != null) {
      final db = await LocalDatabase.database;
      final fiadosLocal = await db.query('fiados',
          where: 'venta_id = ? AND synced = 0', whereArgs: [ventaId]);
      for (final f in fiadosLocal) {
        try {
          final fiadoData = Map<String, dynamic>.from(f)..remove('synced');
          await SupabaseService.client.from('fiados').upsert(fiadoData);
          await LocalDatabase.marcarSynced('fiados', f['id'] as String);
        } catch (_) {}
      }
    }

    await LocalDatabase.marcarSynced('ventas', ventaId);
  }
}