import 'package:uuid/uuid.dart';
import '../models/apartado_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';
import 'dart:async';

class ApartadoService {
  static const _uuid = Uuid();

  /// Sincroniza abonos y apartados pendientes a Supabase antes de leer.
  static Future<void> _sincronizarPendientes(String empresaId) async {
    final db = await LocalDatabase.database;

    // 1. Sincronizar abonos pendientes
    final abonosPend = await db.query('abonos_apartado',
        where: 'empresa_id = ? AND synced = 0', whereArgs: [empresaId]);
    for (final ab in abonosPend) {
      try {
        final abMap = Map<String, dynamic>.from(ab)..remove('synced');
        await SupabaseService.client.from('abonos_apartado').upsert(abMap);
        await LocalDatabase.marcarSynced('abonos_apartado', ab['id'] as String);
      } catch (_) {}
    }

    // 2. Sincronizar apartados con cambios pendientes
    final apartadosPend = await db.query('apartados',
        where: 'empresa_id = ? AND synced = 0', whereArgs: [empresaId]);
    for (final a in apartadosPend) {
      try {
        final aMap = Map<String, dynamic>.from(a)
          ..remove('synced')
          ..remove('cliente_nombre')
          ..remove('cliente_telefono');
        await SupabaseService.client.from('apartados').upsert(aMap);
        await LocalDatabase.marcarSynced('apartados', a['id'] as String);
      } catch (_) {}
    }
  }

  static Future<List<ApartadoModel>> getApartados({String? estado}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    // Cargar local primero (incluye pendientes offline)
    final local = await LocalDatabase.consultar('apartados', empresaId);
    var localLista = local.map((m) => ApartadoModel.fromMap(m)).toList();

    if (await SupabaseService.isOnlineAsync) {
      // Primero sincronizar cambios locales pendientes a Supabase
      try { await _sincronizarPendientes(empresaId); } catch (_) {}

      try {
        List<dynamic> res;
        if (estado != null) {
          res = await SupabaseService.client
              .from('apartados')
              .select('*, clientes(nombre, telefono)')
              .eq('empresa_id', empresaId)
              .eq('estado', estado)
              .order('created_at', ascending: false);
        } else {
          res = await SupabaseService.client
              .from('apartados')
              .select('*, clientes(nombre, telefono)')
              .eq('empresa_id', empresaId)
              .order('created_at', ascending: false);
        }

        // IDs con cambios locales pendientes — NO sobreescribir
        // Incluye apartados que tienen abonos sin sincronizar
        final db2 = await LocalDatabase.database;
        final abonosPend = await db2.query('abonos_apartado',
            where: 'empresa_id = ? AND synced = 0', whereArgs: [empresaId]);
        final idsPendientes = {
          ...local.where((m) => m['synced'] == 0).map((m) => m['id'] as String),
          ...abonosPend.map((a) => a['apartado_id'] as String),
        };

        // Cachear en SQLite los registros de Supabase
        for (final m in res) {
          if (idsPendientes.contains(m['id'] as String?)) continue;
          final map = Map<String, dynamic>.from(m);
          // Guardar nombre y teléfono del cliente antes de quitar el join
          if (m['clientes'] != null) {
            map['cliente_nombre'] = m['clientes']['nombre'];
            map['cliente_telefono'] = m['clientes']['telefono'];
          }
          map.remove('clientes');
          map['synced'] = 1;
          try { await LocalDatabase.insertar('apartados', map); } catch (_) {}
        }

        // Combinar: online tiene prioridad salvo pendientes locales
        // IMPORTANTE: usar idsPendientes (no solo synced==0) para que
        // apartados con abonos offline también usen la versión local
        final localPendientes = Map.fromEntries(
          local.where((m) => idsPendientes.contains(m['id'] as String))
               .map((m) => MapEntry(m['id'] as String, ApartadoModel.fromMap(m))),
        );
        final idsOnline = res.map((m) => m['id'] as String).toSet();
        final soloLocales = localLista.where((a) => !idsOnline.contains(a.id)).toList();
        var lista = [
          ...res.map((m) => localPendientes[m['id']] ?? ApartadoModel.fromMap(m)),
          ...soloLocales,
        ];
        if (estado != null) lista = lista.where((a) => a.estado == estado).toList();
        return lista;
      } catch (_) {}
    }

    if (estado != null) localLista = localLista.where((a) => a.estado == estado).toList();
    return localLista;
  }

  static Future<bool> crearApartado({
    required String clienteId,
    required String descripcion,
    required double montoTotal,
    double abonoInicial = 0,
    DateTime? fechaEstimada,
    String? notas,
    List<Map<String, dynamic>> lineas = const [],
  }) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();
    final saldo = montoTotal - abonoInicial;

    final map = {
      'id': id,
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'usuario_id': SupabaseService.userId,
      'descripcion': descripcion,
      'monto_total': montoTotal,
      'monto_pagado': abonoInicial,
      'saldo_pendiente': saldo,
      'fecha_estimada': fechaEstimada?.toIso8601String().split('T')[0],
      'estado': saldo <= 0 ? 'completado' : 'activo',
      'notas': notas,
      'synced': 0,
      'created_at': ahora,
      'updated_at': ahora,
    };

    await LocalDatabase.insertar('apartados', map);

    // Guardar líneas del apartado
    final db = await LocalDatabase.database;
    for (final linea in lineas) {
      await db.insert('apartado_productos', {
        'id': _uuid.v4(),
        'apartado_id': id,
        'empresa_id': empresaId,
        'producto_id': linea['producto_id'],
        'nombre': linea['nombre'],
        'cantidad': linea['cantidad'] ?? 1.0,
        'precio': linea['precio'] ?? 0.0,
        'costo': linea['costo'],
        'entregado': 0,
        'fecha_entrega': null,
        'synced': 0,
      });
    }

    if (abonoInicial > 0) {
      await LocalDatabase.insertar('abonos_apartado', {
        'id': _uuid.v4(),
        'empresa_id': empresaId,
        'apartado_id': id,
        'cliente_id': clienteId,
        'monto': abonoInicial,
        'metodo_pago': 'efectivo',
        'tipo': 'inicial',
        'synced': 0,
        'created_at': ahora,
      });
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        final onlineMap = Map<String, dynamic>.from(map)..remove('synced');
        await SupabaseService.client.from('apartados').insert(onlineMap);
        await LocalDatabase.marcarSynced('apartados', id);

        // Sincronizar el abono inicial si existía
        if (abonoInicial > 0) {
          final abonosLocal = await LocalDatabase.database
              .then((db) => db.query('abonos_apartado',
                  where: 'apartado_id = ? AND synced = 0', whereArgs: [id]));
          for (final ab in abonosLocal) {
            try {
              final abMap = Map<String, dynamic>.from(ab)..remove('synced');
              await SupabaseService.client.from('abonos_apartado').insert(abMap);
              await LocalDatabase.marcarSynced('abonos_apartado', ab['id'] as String);
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    return true;
  }

  static Future<bool> cancelarAbono(String abonoId, String apartadoId, double monto) async {
    final db = await LocalDatabase.database;

    final rows = await db.query('apartados', where: 'id = ?', whereArgs: [apartadoId]);
    if (rows.isNotEmpty) {
      final saldoActual = (rows.first['saldo_pendiente'] as num).toDouble();
      final montoTotal = (rows.first['monto_total'] as num).toDouble();
      final pagadoActual = (rows.first['monto_pagado'] as num).toDouble();
      final nuevoSaldo = (saldoActual + monto).clamp(0.0, montoTotal);
      final nuevoPagado = (pagadoActual - monto).clamp(0.0, montoTotal);

      await LocalDatabase.actualizar('apartados', {
        'saldo_pendiente': nuevoSaldo,
        'monto_pagado': nuevoPagado,
        'estado': nuevoSaldo > 0 ? 'activo' : 'completado',
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      }, 'id', apartadoId);
    }

    await LocalDatabase.eliminar('abonos_apartado', 'id', abonoId);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('abonos_apartado').delete().eq('id', abonoId);
        if (rows.isNotEmpty) {
          final saldoActual = (rows.first['saldo_pendiente'] as num).toDouble();
          final montoTotal = (rows.first['monto_total'] as num).toDouble();
          final pagadoActual = (rows.first['monto_pagado'] as num).toDouble();
          final nuevoSaldo = (saldoActual + monto).clamp(0.0, montoTotal);
          final nuevoPagado = (pagadoActual - monto).clamp(0.0, montoTotal);
          await SupabaseService.client.from('apartados').update({
            'saldo_pendiente': nuevoSaldo,
            'monto_pagado': nuevoPagado,
            'estado': nuevoSaldo > 0 ? 'activo' : 'completado',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', apartadoId);
          await LocalDatabase.marcarSynced('apartados', apartadoId);
        }
      } catch (_) {}
    }

    return true;
  }

  static Future<bool> registrarAbono(
    String apartadoId,
    String clienteId,
    double monto,
    String metodoPago,
  ) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final abonoId = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();

    await LocalDatabase.insertar('abonos_apartado', {
      'id': abonoId,
      'empresa_id': empresaId,
      'apartado_id': apartadoId,
      'cliente_id': clienteId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'tipo': 'abono',
      'usuario_id': SupabaseService.userId,
      'synced': 0,
      'created_at': ahora,
    });

    final db = await LocalDatabase.database;
    final rows = await db.query('apartados',
        where: 'id = ?', whereArgs: [apartadoId]);
    if (rows.isNotEmpty) {
      final saldoActual = (rows.first['saldo_pendiente'] as num).toDouble();
      final pagadoActual = (rows.first['monto_pagado'] as num).toDouble();
      final nuevoSaldo = (saldoActual - monto).clamp(0.0, double.infinity);
      final nuevoPagado = pagadoActual + monto;
      final nuevoEstado = nuevoSaldo <= 0 ? 'completado' : 'activo';

      await LocalDatabase.actualizar('apartados', {
        'saldo_pendiente': nuevoSaldo,
        'monto_pagado': nuevoPagado,
        'estado': nuevoEstado,
        'updated_at': ahora,
        'synced': 0, // marcar como pendiente hasta sincronizar con Supabase
      }, 'id', apartadoId);
    }

  if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('abonos_apartado').insert({
          'id': abonoId,
          'empresa_id': empresaId,
          'apartado_id': apartadoId,
          'cliente_id': clienteId,
          'monto': monto,
          'metodo_pago': metodoPago,
          'tipo': 'abono',
        });

        // Usar el saldo ya leído de SQLite para evitar race condition
        if (rows.isNotEmpty) {
          final saldoAntes = (rows.first['saldo_pendiente'] as num).toDouble();
          final pagadoAntes = (rows.first['monto_pagado'] as num).toDouble();
          final nuevoSaldo = (saldoAntes - monto).clamp(0.0, double.infinity);
          final nuevoPagado = pagadoAntes + monto;
          final nuevoEstado = nuevoSaldo <= 0 ? 'completado' : 'activo';
          await SupabaseService.client.from('apartados').update({
            'saldo_pendiente': nuevoSaldo,
            'monto_pagado': nuevoPagado,
            'estado': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', apartadoId);
          // Marcar apartado como synced solo cuando Supabase confirma el saldo actualizado
          await LocalDatabase.marcarSynced('apartados', apartadoId);
        }

        await LocalDatabase.marcarSynced('abonos_apartado', abonoId);
      } catch (_) {}
    }

    // Si el apartado quedó completado, registrar venta financiera
    if (rows.isNotEmpty) {
      final saldoAntes = (rows.first['saldo_pendiente'] as num).toDouble();
      final nuevoSaldo = (saldoAntes - monto).clamp(0.0, double.infinity);
      if (nuevoSaldo <= 0) {
        final clienteIdApartado = rows.first['cliente_id'] as String? ?? clienteId;
        unawaited(_registrarVentaFinanciera(apartadoId, clienteIdApartado, empresaId));
      }
    }

    return true;
  }
  static Future<List<Map<String, dynamic>>> getLineasApartado(String apartadoId) async {
    final db = await LocalDatabase.database;
    return db.query('apartado_productos',
        where: 'apartado_id = ?', whereArgs: [apartadoId],
        orderBy: 'rowid ASC');
  }

  static Future<void> marcarLineaEntregada(String lineaId, bool entregada) async {
    final db = await LocalDatabase.database;
    final ahora = DateTime.now().toIso8601String();

    await db.update('apartado_productos', {
      'entregado': entregada ? 1 : 0,
      'fecha_entrega': entregada ? ahora : null,
      'synced': 0,
    }, where: 'id = ?', whereArgs: [lineaId]);

    // ── Descontar stock si el artículo viene del inventario ──────
    if (entregada) {
      final lineas = await db.query('apartado_productos',
          where: 'id = ?', whereArgs: [lineaId]);
      if (lineas.isNotEmpty) {
        final l = lineas.first;
        final productoId = l['producto_id'] as String?;
        final cantidad   = (l['cantidad'] as num? ?? 1).toDouble();
        if (productoId != null) {
          // SQLite local
          final prods = await db.query('productos',
              where: 'id = ?', whereArgs: [productoId]);
          if (prods.isNotEmpty) {
            final stockActual = (prods.first['stock_actual'] as num).toDouble();
            final nuevoStock  = (stockActual - cantidad).clamp(0.0, double.infinity);
            await db.update('productos',
                {'stock_actual': nuevoStock, 'updated_at': ahora, 'synced': 0},
                where: 'id = ?', whereArgs: [productoId]);
          }
          // Supabase background
          unawaited(SupabaseService.isOnlineAsync.then((online) async {
            if (!online) return;
            try {
              final res = await SupabaseService.client
                  .from('productos').select('stock_actual')
                  .eq('id', productoId).single();
              final remoto = (res['stock_actual'] as num? ?? 0).toDouble();
              await SupabaseService.client.from('productos').update({
                'stock_actual': (remoto - cantidad).clamp(0.0, double.infinity),
                'updated_at': ahora,
              }).eq('id', productoId);
            } catch (_) {}
          }));
        }
      }
    }
  }

  /// Cuando el apartado queda completamente pagado (saldo=0), registrar
  /// una venta en el sistema para que aparezca en finanzas y reportes.
  static Future<void> _registrarVentaFinanciera(
      String apartadoId, String clienteId, String empresaId) async {
    final db   = await LocalDatabase.database;
    final ahora = DateTime.now().toUtc().toIso8601String();

    // Leer lineas del apartado
    final lineas = await db.query('apartado_productos',
        where: 'apartado_id = ?', whereArgs: [apartadoId]);
    if (lineas.isEmpty) return;

    // Leer monto total del apartado
    final apRows = await db.query('apartados',
        where: 'id = ?', whereArgs: [apartadoId]);
    if (apRows.isEmpty) return;
    final montoTotal = (apRows.first['monto_total'] as num).toDouble();

    final ventaId = _uuid.v4();
    final ventaMap = {
      'id': ventaId,
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'usuario_id': SupabaseService.userId,
      'tipo_pago': 'apartado',
      'subtotal': montoTotal,
      'descuento': 0.0,
      'total': montoTotal,
      'monto_pagado': montoTotal,
      'cambio': 0.0,
      'estado': 'completada',
      'notas': 'Apartado completado',
      'synced': 0,
      'created_at': ahora,
    };
    await LocalDatabase.insertar('ventas', ventaMap);

    // Detalles de venta (una línea por artículo del apartado)
    for (final l in lineas) {
      final detalleId = _uuid.v4();
      final precio = (l['precio'] as num? ?? 0).toDouble();
      final cantidad = (l['cantidad'] as num? ?? 1).toDouble();
      await LocalDatabase.insertar('detalle_ventas', {
        'id': detalleId,
        'venta_id': ventaId,
        'producto_id': l['producto_id'],
        'nombre_producto': l['nombre'] as String? ?? '',
        'cantidad': cantidad,
        'precio_unitario': precio,
        'descuento': 0.0,
        'subtotal': precio * cantidad,
        'created_at': ahora,
      });

      // Si el artículo manual tiene costo registrado → registrar como gasto
      final costo = (l['costo'] as num?)?.toDouble();
      if (costo != null && costo > 0 && l['producto_id'] == null) {
        await LocalDatabase.insertar('gastos', {
          'id': _uuid.v4(),
          'empresa_id': empresaId,
          'descripcion': 'Costo artículo apartado: ${l['nombre']}',
          'monto': costo * cantidad,
          'categoria': 'compra_producto',
          'metodo_pago': 'efectivo',
          'synced': 0,
          'created_at': ahora,
        });
      }
    }

    // Sync a Supabase en background
    unawaited(SupabaseService.isOnlineAsync.then((online) async {
      if (!online) return;
      try {
        final ventaOnline = Map<String, dynamic>.from(ventaMap)..remove('synced');
        await SupabaseService.client.from('ventas').upsert(ventaOnline);
        final detalles = await db.query('detalle_ventas',
            where: 'venta_id = ?', whereArgs: [ventaId]);
        for (final d in detalles) {
          try {
            await SupabaseService.client.from('detalle_ventas')
                .upsert(Map<String, dynamic>.from(d));
          } catch (_) {}
        }
        await LocalDatabase.marcarSynced('ventas', ventaId);
      } catch (_) {}
    }));
  }

}