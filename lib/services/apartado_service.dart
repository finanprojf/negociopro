import 'package:uuid/uuid.dart';
import '../models/apartado_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class ApartadoService {
  static const _uuid = Uuid();

  static Future<List<ApartadoModel>> getApartados({String? estado}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    if (await SupabaseService.isOnlineAsync) {
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
        return res.map((m) => ApartadoModel.fromMap(m)).toList();
      } catch (_) {}
    }

    final local = await LocalDatabase.consultar('apartados', empresaId);
    var lista = local.map((m) => ApartadoModel.fromMap(m)).toList();
    if (estado != null) {
      lista = lista.where((a) => a.estado == estado).toList();
    }
    return lista;
  }

  static Future<bool> crearApartado({
    required String clienteId,
    required String descripcion,
    required double montoTotal,
    double abonoInicial = 0,
    DateTime? fechaEstimada,
    String? notas,
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

    if (abonoInicial > 0) {
      await LocalDatabase.insertar('abonos_apartado', {
        'id': _uuid.v4(),
        'empresa_id': empresaId,
        'apartado_id': id,
        'cliente_id': clienteId,
        'monto': abonoInicial,
        'metodo_pago': 'efectivo',
        'synced': 0,
        'created_at': ahora,
      });
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        final onlineMap = Map<String, dynamic>.from(map)..remove('synced');
        await SupabaseService.client.from('apartados').insert(onlineMap);
        await LocalDatabase.marcarSynced('apartados', id);
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
        }

        await LocalDatabase.marcarSynced('abonos_apartado', abonoId);
      } catch (_) {}
    }
    return true;
  }
}