import 'package:uuid/uuid.dart';
import '../models/gasto_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class GastoService {
  static const _uuid = Uuid();

  static Future<List<GastoModel>> getGastos({DateTime? fecha}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    if (SupabaseService.isOnline) {
      try {
        List<dynamic> res;

        if (fecha != null) {
          final inicio = DateTime(fecha.year, fecha.month, 1);
          final fin = DateTime(fecha.year, fecha.month + 1, 1);
          res = await SupabaseService.client
              .from('gastos')
              .select()
              .eq('empresa_id', empresaId)
              .gte('fecha', inicio.toIso8601String().split('T')[0])
              .lt('fecha', fin.toIso8601String().split('T')[0])
              .order('fecha', ascending: false);
        } else {
          res = await SupabaseService.client
              .from('gastos')
              .select()
              .eq('empresa_id', empresaId)
              .order('fecha', ascending: false);
        }

        return res.map((m) => GastoModel.fromMap(m)).toList();
      } catch (_) {}
    }

    final local = await LocalDatabase.consultar(
        'gastos', empresaId, orderBy: 'fecha DESC');
    return local.map((m) => GastoModel.fromMap(m)).toList();
  }

  static Future<bool> guardarGasto(GastoModel gasto) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = _uuid.v4();
    final ahora = DateTime.now().toIso8601String();

    final map = {
      ...gasto.toMap(),
      'id': id,
      'empresa_id': empresaId,
      'synced': 0,
      'created_at': ahora,
    };

    await LocalDatabase.insertar('gastos', map);

    if (SupabaseService.isOnline) {
      try {
        await SupabaseService.client.from('gastos').insert({
          ...gasto.toMap(),
          'id': id,
          'empresa_id': empresaId,
          'usuario_id': SupabaseService.userId,
        });
        await LocalDatabase.marcarSynced('gastos', id);
      } catch (_) {}
    }

    return true;
  }

  static Future<double> getTotalMes() async {
    final gastos = await getGastos(fecha: DateTime.now());
    double total = 0;
    for (final g in gastos) {
      total += g.monto;
    }
    return total;
  }
}