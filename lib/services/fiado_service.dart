import 'package:uuid/uuid.dart';
import '../models/fiado_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class FiadoService {
  static const _uuid = Uuid();

  /// Crea un fiado directamente (sin pasar por POS).
  /// Útil para encargos pagados a crédito o mixto.
  static Future<bool> crearFiado({
    required String clienteId,
    required double montoOriginal,
    double montoPagado = 0,
    String? notas,
    String? clienteNombre,
  }) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();
    final saldo = (montoOriginal - montoPagado).clamp(0.0, double.infinity);

    final map = {
      'id': id,
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'monto_original': montoOriginal,
      'saldo_pendiente': saldo,
      'estado': saldo <= 0 ? 'pagado' : 'activo',
      'notas': notas,
      'synced': 0,
      'created_at': ahora,
      'updated_at': ahora,
    };

    await LocalDatabase.insertar('fiados', map);

    if (await SupabaseService.isOnlineAsync) {
      try {
        final onlineMap = Map<String, dynamic>.from(map)
          ..remove('synced')
          ..remove('cliente_nombre');
        await SupabaseService.client.from('fiados').insert(onlineMap);
        await LocalDatabase.marcarSynced('fiados', id);
      } catch (_) {}
    }

    return true;
  }

  static Future<List<FiadoModel>> getFiados({String? estado}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

 // Cargar local primero
    final local = await LocalDatabase.consultar('fiados', empresaId);
    var fiadosLocal = local.map((m) => FiadoModel.fromMap(m)).toList();
    if (estado != null) {
      fiadosLocal = fiadosLocal.where((f) => f.estado == estado).toList();
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        List<dynamic> res;
        if (estado != null) {
          res = await SupabaseService.client
              .from('fiados')
              .select('*, clientes(nombre, telefono)')
              .eq('empresa_id', empresaId)
              .eq('estado', estado)
              .order('created_at', ascending: false);
        } else {
          res = await SupabaseService.client
              .from('fiados')
              .select('*, clientes(nombre, telefono)')
              .eq('empresa_id', empresaId)
              .order('created_at', ascending: false);
        }

        // IDs con cambios locales pendientes — NO sobreescribir
        // Incluye fiados que tienen abonos sin sincronizar
        final db2 = await LocalDatabase.database;
        final abonosPend = await db2.query('abonos_fiado',
            where: 'empresa_id = ? AND synced = 0', whereArgs: [empresaId]);
        final idsPendientes = {
          ...local.where((m) => m['synced'] == 0).map((m) => m['id'] as String),
          ...abonosPend.map((a) => a['fiado_id'] as String),
        };
        final localPendientes = Map.fromEntries(
          local.where((m) => idsPendientes.contains(m['id'] as String))
               .map((m) => MapEntry(m['id'] as String, FiadoModel.fromMap(m))),
        );

        // Guardar en local (solo si no hay cambios pendientes)
        for (final m in res) {
          if (idsPendientes.contains(m['id'] as String?)) continue;
          final map = Map<String, dynamic>.from(m);
          if (m['clientes'] != null) {
            map['cliente_nombre'] = m['clientes']['nombre'];
            map['cliente_telefono'] = m['clientes']['telefono'];
          }
          map.remove('clientes');
          map['synced'] = 1;
          try { await LocalDatabase.insertar('fiados', map); } catch (_) {}
        }

        final idsOnline = res.map((m) => m['id'] as String).toSet();
        final soloLocales = fiadosLocal.where((f) => !idsOnline.contains(f.id)).toList();
        var lista = [
          ...res.map((m) => localPendientes[m['id']] ?? FiadoModel.fromMap(m)),
          ...soloLocales,
        ];
        if (estado != null) lista = lista.where((f) => f.estado == estado).toList();
        return lista;
      } catch (_) {}
    }

    return fiadosLocal;
  }

  static Future<bool> cancelarAbono(String abonoId, String fiadoId, double monto) async {
    final db = await LocalDatabase.database;

    // Restaurar saldo en SQLite
    final fiados = await db.query('fiados', where: 'id = ?', whereArgs: [fiadoId]);
    if (fiados.isNotEmpty) {
      final saldoActual = (fiados.first['saldo_pendiente'] as num).toDouble();
      final montoOriginal = (fiados.first['monto_original'] as num).toDouble();
      final nuevoSaldo = (saldoActual + monto).clamp(0.0, montoOriginal);

      await LocalDatabase.actualizar('fiados', {
        'saldo_pendiente': nuevoSaldo,
        'estado': nuevoSaldo > 0 ? 'activo' : 'pagado',
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0,
      }, 'id', fiadoId);
    }

    await LocalDatabase.eliminar('abonos_fiado', 'id', abonoId);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('abonos_fiado').delete().eq('id', abonoId);
        if (fiados.isNotEmpty) {
          final saldoActual = (fiados.first['saldo_pendiente'] as num).toDouble();
          final montoOriginal = (fiados.first['monto_original'] as num).toDouble();
          final nuevoSaldo = (saldoActual + monto).clamp(0.0, montoOriginal);
          await SupabaseService.client.from('fiados').update({
            'saldo_pendiente': nuevoSaldo,
            'estado': nuevoSaldo > 0 ? 'activo' : 'pagado',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', fiadoId);
          await LocalDatabase.marcarSynced('fiados', fiadoId);
        }
      } catch (_) {}
    }

    return true;
  }

  static Future<bool> registrarAbono(
    String fiadoId,
    String clienteId,
    double monto,
    String metodoPago,
  ) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final abonoId = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();

    await LocalDatabase.insertar('abonos_fiado', {
      'id': abonoId,
      'empresa_id': empresaId,
      'fiado_id': fiadoId,
      'cliente_id': clienteId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'usuario_id': SupabaseService.userId,
      'synced': 0,
      'created_at': ahora,
    });

    final db = await LocalDatabase.database;
    final fiados = await db.query('fiados',
        where: 'id = ?', whereArgs: [fiadoId]);
    if (fiados.isNotEmpty) {
      final saldoActual =
          (fiados.first['saldo_pendiente'] as num).toDouble();
      final nuevoSaldo =
          (saldoActual - monto).clamp(0.0, double.infinity);
      final nuevoEstado = nuevoSaldo <= 0 ? 'pagado' : 'activo';
      await LocalDatabase.actualizar('fiados', {
        'saldo_pendiente': nuevoSaldo,
        'estado': nuevoEstado,
        'updated_at': ahora,
        'synced': 0,
      }, 'id', fiadoId);
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('abonos_fiado').insert({
          'id': abonoId,
          'empresa_id': empresaId,
          'fiado_id': fiadoId,
          'cliente_id': clienteId,
          'monto': monto,
          'metodo_pago': metodoPago,
          'usuario_id': SupabaseService.userId,
        });

        // Usar el saldo ya leído de SQLite para evitar race condition
        // (no volver a leer de Supabase, que puede no estar actualizado aún)
        if (fiados.isNotEmpty) {
          final saldoAntes = (fiados.first['saldo_pendiente'] as num).toDouble();
          final nuevoSaldo = (saldoAntes - monto).clamp(0.0, double.infinity);
          await SupabaseService.client.from('fiados').update({
            'saldo_pendiente': nuevoSaldo,
            'estado': nuevoSaldo <= 0 ? 'pagado' : 'activo',
            'updated_at': ahora,
          }).eq('id', fiadoId);
        }

        await LocalDatabase.marcarSynced('abonos_fiado', abonoId);
      } catch (_) {}
    }

    return true;
  }
}