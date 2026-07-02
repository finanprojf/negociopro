import 'package:uuid/uuid.dart';
import '../models/fiado_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class FiadoService {
  static const _uuid = Uuid();

  static Future<List<FiadoModel>> getFiados({String? estado}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

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
        return res.map((m) => FiadoModel.fromMap(m)).toList();
      } catch (_) {}
    }

    final local = await LocalDatabase.consultar('fiados', empresaId);
    var lista = local.map((m) => FiadoModel.fromMap(m)).toList();
    if (estado != null) {
      lista = lista.where((f) => f.estado == estado).toList();
    }
    return lista;
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

        final fiado = await SupabaseService.client
            .from('fiados')
            .select('saldo_pendiente')
            .eq('id', fiadoId)
            .single();

        final saldo = (fiado['saldo_pendiente'] as num).toDouble();
        final nuevoSaldo = (saldo - monto).clamp(0.0, double.infinity);

        await SupabaseService.client.from('fiados').update({
          'saldo_pendiente': nuevoSaldo,
          'estado': nuevoSaldo <= 0 ? 'pagado' : 'activo',
          'updated_at': ahora,
        }).eq('id', fiadoId);

        await LocalDatabase.marcarSynced('abonos_fiado', abonoId);
      } catch (_) {}
    }

    return true;
  }
}