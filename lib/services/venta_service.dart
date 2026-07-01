import 'package:uuid/uuid.dart';
import '../models/venta_model.dart';
import '../models/producto_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';
import 'gasto_service.dart';
import '../models/gasto_model.dart';
class VentaService {
  static const _uuid = Uuid();

  static Future<List<VentaModel>> getVentas({DateTime? fecha}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    if (SupabaseService.isOnline) {
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

        return res.map((m) {
          final map = Map<String, dynamic>.from(m);
          if (m['clientes'] != null) {
            map['cliente_nombre'] = m['clientes']['nombre'];
          }
          return VentaModel.fromMap(map);
        }).toList();
      } catch (_) {}
    }

    final local = await LocalDatabase.consultar('ventas', empresaId);
    return local.map((m) => VentaModel.fromMap(m)).toList();
  }

  static Future<double> getTotalVentasHoy() async {
    final ventas = await getVentas(fecha: DateTime.now());
    double total = 0;
    for (final v in ventas) {
      if (v.estado == 'completada') total += v.total;
    }
    return total;
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

    if (SupabaseService.isOnline) {
      try {
        await _syncVenta(ventaId, ventaMap, items, ahora);
      } catch (_) {}
    }

    if (SupabaseService.isOnline) {
      try {
        await _syncVenta(ventaId, ventaMap, items, ahora);
      } catch (_) {}
    }

    if (SupabaseService.isOnline) {
      try {
        await _syncVenta(ventaId, ventaMap, items, ahora);
      } catch (_) {}
    }

    // Si hay descuento, registrarlo como gasto
    if (descuento > 0) {
      await GastoService.guardarGasto(GastoModel(
        id: '',
        empresaId: empresaId,
        categoria: 'otros',
        descripcion: 'Descuento en venta',
        monto: descuento,
        fecha: DateTime.now(),
      ));
    }

    return true;
  }
  static Future<void> _syncVenta(
    String ventaId,
    Map<String, dynamic> ventaMap,
    List<Map<String, dynamic>> items,
    String ahora,
  ) async {
    final ventaOnline = Map<String, dynamic>.from(ventaMap)
      ..remove('synced')
      ..remove('id');

    await SupabaseService.client
        .from('ventas')
        .insert({'id': ventaId, ...ventaOnline});
// Si es fiado, crear en Supabase también
    if (ventaMap['tipo_pago'] == 'fiado' && ventaMap['cliente_id'] != null) {
     final saldoFiado = (ventaMap['total'] as num).toDouble() - 
                   (ventaMap['monto_pagado'] as num).toDouble();
      await SupabaseService.client.from('fiados').insert({
        'id': const Uuid().v4(),
        'empresa_id': ventaMap['empresa_id'],
        'cliente_id': ventaMap['cliente_id'],
        'venta_id': ventaId,
        'monto_original': saldoFiado,
        'saldo_pendiente': saldoFiado,
        'estado': 'activo',
      });
    }
    for (final item in items) {
      final p = item['producto'] as ProductoModel;
      final cantidad = (item['cantidad'] as num).toDouble();

      await SupabaseService.client.from('detalle_ventas').insert({
        'id': _uuid.v4(),
        'venta_id': ventaId,
        'producto_id': p.id,
        'nombre_producto': p.nombre,
        'cantidad': cantidad,
        'precio_unitario': p.precioVenta,
        'descuento': 0,
        'subtotal': p.precioVenta * cantidad,
      });

      final nuevoStock =
          (p.stockActual - cantidad).clamp(0.0, double.infinity);
      await SupabaseService.client
          .from('productos')
          .update({'stock_actual': nuevoStock, 'updated_at': ahora})
          .eq('id', p.id);
    }

    await LocalDatabase.marcarSynced('ventas', ventaId);
  }
}