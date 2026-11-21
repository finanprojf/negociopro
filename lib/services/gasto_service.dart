import 'package:shared_preferences/shared_preferences.dart';
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
    final idsLocalesSinSubir = local
        .where((m) => (m['synced'] ?? 0) == 0)
        .map((m) => m['id'] as String)
        .toSet();

    if (await SupabaseService.isOnlineAsync) {
      try {
        // Primero borrar en la nube lo que se eliminó sin internet
        final pendientesBorrar = await _procesarBorradosPendientes();
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
        // No traer de vuelta gastos que el usuario ya borró
        res = res.where((m) => !pendientesBorrar.contains(m['id'])).toList();
        // Guardar en local
        for (final m in res) {
          try {
            final map = Map<String, dynamic>.from(m);
            map['synced'] = 1;
            await LocalDatabase.insertar('gastos', map);
          } catch (_) {}
        }
       final gastosOnline = res.map((m) => GastoModel.fromMap(m)).toList();
        final idsOnline = gastosOnline.map((g) => g.id).toSet();
        // Solo los locales que aún no se han subido (los demás ya no existen en la nube)
        final gastosPendientes = gastosLocal
            .where((g) => !idsOnline.contains(g.id) && idsLocalesSinSubir.contains(g.id))
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
    final ahora = DateTime.now().toUtc().toIso8601String();

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
  // ── Eliminar gasto (funciona sin internet) ─────────────────
  static const _keyBorrar = 'gastos_borrar_pendientes';

  static Future<void> eliminarGasto(String id) async {
    await LocalDatabase.eliminar('gastos', 'id', id);
    var borrado = false;
    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('gastos').delete().eq('id', id)
            .timeout(const Duration(seconds: 8));
        borrado = true;
      } catch (_) {}
    }
    if (!borrado) {
      final prefs = await SharedPreferences.getInstance();
      final lista = prefs.getStringList(_keyBorrar) ?? [];
      if (!lista.contains(id)) lista.add(id);
      await prefs.setStringList(_keyBorrar, lista);
    }
  }

  /// Intenta borrar en la nube los gastos eliminados sin internet.
  /// Devuelve los IDs que siguen pendientes (para no mostrarlos).
  static Future<Set<String>> _procesarBorradosPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_keyBorrar) ?? [];
    if (lista.isEmpty) return {};
    final quedan = <String>[];
    for (final id in lista) {
      try {
        await SupabaseService.client.from('gastos').delete().eq('id', id)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        quedan.add(id);
      }
    }
    await prefs.setStringList(_keyBorrar, quedan);
    return lista.toSet();
  }

  /// Elimina todos los gastos vinculados a un producto (por notas origen)
  static Future<void> eliminarGastosPorProducto(String productoId) async {
    try {
      final db = await LocalDatabase.database;
      final origen = 'origen:producto:$productoId';
      final rows = await db.query('gastos',
          where: 'notas = ?', whereArgs: [origen]);
      for (final row in rows) {
        final id = row['id'] as String;
        await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
        try {
          if (await SupabaseService.isOnlineAsync) {
            await SupabaseService.client
                .from('gastos')
                .delete()
                .eq('id', id)
                .timeout(const Duration(seconds: 8));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

}