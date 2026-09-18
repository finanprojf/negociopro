import 'package:uuid/uuid.dart';
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
    final ventasLocal = await Future.wait(local.map((m) async {
      final map = Map<String, dynamic>.from(m);
      final detalles = await db.query('detalle_ventas',
          where: 'venta_id = ?', whereArgs: [m['id']]);
      map['detalle_ventas'] = detalles;
      return VentaModel.fromMap(map);
    }));

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
// Guardar en local
        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          map.remove('clientes');
          map.remove('detalle_ventas');
          map['synced'] = 1;
          try {
            await LocalDatabase.insertar('ventas', map);
          } catch (_) {}
        }
       final ventasOnline = res.map((m) {
          final map = Map<String, dynamic>.from(m);
          if (m['clientes'] != null) {
            map['cliente_nombre'] = m['clientes']['nombre'];
          }
          return VentaModel.fromMap(map);
        }).toList();
// Releer SQLite completo después de guardar
        final localActualizado = await LocalDatabase.consultar('ventas', empresaId);
        final todasLocal = await Future.wait(localActualizado.map((m) async {
          final map = Map<String, dynamic>.from(m);
          final detalles = await db.query('detalle_ventas',
              where: 'venta_id = ?', whereArgs: [m['id']]);
          map['detalle_ventas'] = detalles;
          return VentaModel.fromMap(map);
        }));
        final idsOnline = ventasOnline.map((v) => v.id).toSet();
        final ventasNoEnOnline = todasLocal
            .where((v) => !idsOnline.contains(v.id))
            .toList();
        
        return [...ventasOnline, ...ventasNoEnOnline]
          ..sort((a, b) => (b.createdAt ?? DateTime.now())
              .compareTo(a.createdAt ?? DateTime.now()));
       
      } catch (_) {}
    }

  return ventasLocal;
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
      subtotal += p.precioVenta * cantidad;
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
      final sub = p.precioVenta * cantidad;

      await LocalDatabase.insertar('detalle_ventas', {
        'id': _uuid.v4(),
        'venta_id': ventaId,
        'producto_id': p.id,
        'nombre_producto': p.nombre,
        'cantidad': cantidad,
        'precio_unitario': p.precioVenta,
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

   

   if (await SupabaseService.isOnlineAsync) {
      try {
        await _syncVenta(ventaId, ventaMap, items, ahora);
      } catch (_) {}
    }

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