import 'package:uuid/uuid.dart';
import '../models/gasto_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class GastoService {
  static const _uuid = Uuid();

  static Future<List<GastoModel>> getGastos({DateTime? fecha}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

   // Cargar local primero
    final local = await LocalDatabase.consultar(
        'gastos', empresaId, orderBy: 'created_at DESC');
    final gastosLocal = local.map((m) => GastoModel.fromMap(m)).toList();

    if (await SupabaseService.isOnlineAsync) {
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
        // Guardar en local
        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          map['synced'] = 1;
          await LocalDatabase.insertar('gastos', map);
        }
       final gastosOnline = res.map((m) => GastoModel.fromMap(m)).toList();
        final idsOnline = gastosOnline.map((g) => g.id).toSet();
        final gastosPendientes = gastosLocal
            .where((g) => !idsOnline.contains(g.id))
            .toList();
        return [...gastosOnline, ...gastosPendientes]
          ..sort((a, b) => b.fecha.compareTo(a.fecha));
      } catch (_) {}
    }

    return gastosLocal;
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

   if (await SupabaseService.isOnlineAsync) {
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