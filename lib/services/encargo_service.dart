import 'package:uuid/uuid.dart';
import '../models/encargo_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class EncargoService {
  static const _uuid = Uuid();

  static Future<List<EncargoModel>> getEncargos({bool? esListaPropia}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    final local = await LocalDatabase.consultar('encargos', empresaId);
    var encargosLocal = local.map((m) => EncargoModel.fromMap(m)).toList();
    if (esListaPropia != null) {
      encargosLocal = encargosLocal
          .where((e) => e.esListaPropia == esListaPropia)
          .toList();
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        var query = SupabaseService.client
            .from('encargos')
            .select('*, clientes(nombre)')
            .eq('empresa_id', empresaId)
            .order('created_at', ascending: false);

        final res = await query;

        for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          map.remove('clientes');
          map['es_lista_propia'] = m['es_lista_propia'] == true ? 1 : 0;
          map['synced'] = 1;
          try { await LocalDatabase.insertar('encargos', map); } catch (_) {}
        }

        var encargosOnline = res.map((m) => EncargoModel.fromMap(m)).toList();
        if (esListaPropia != null) {
          encargosOnline = encargosOnline
              .where((e) => e.esListaPropia == esListaPropia)
              .toList();
        }

        final idsOnline = encargosOnline.map((e) => e.id).toSet();
        final pendientes = encargosLocal
            .where((e) => !idsOnline.contains(e.id))
            .toList();
        return [...encargosOnline, ...pendientes];
      } catch (_) {}
    }

    return encargosLocal;
  }

  static Future<bool> guardarEncargo(EncargoModel encargo,
      {bool esNuevo = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = esNuevo ? _uuid.v4() : encargo.id;
    final ahora = DateTime.now().toUtc().toIso8601String();

    final map = {
      ...encargo.toMap(),
      'id': id,
      'empresa_id': empresaId,
      'synced': 0,
      'created_at': ahora,
      'updated_at': ahora,
    };

    if (esNuevo) {
      await LocalDatabase.insertar('encargos', map);
    } else {
      await LocalDatabase.actualizar('encargos', map, 'id', id);
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        final dataOnline = {
          ...encargo.toMap(),
          'id': id,
          'empresa_id': empresaId,
          'es_lista_propia': encargo.esListaPropia,
        };
        if (esNuevo) {
          await SupabaseService.client.from('encargos').insert(dataOnline);
        } else {
          await SupabaseService.client.from('encargos')
              .update(dataOnline).eq('id', id);
        }
        await LocalDatabase.marcarSynced('encargos', id);
      } catch (e) {
        print('❌ Error guardando encargo: $e');
      }
    }

    return true;
  }

  static Future<bool> actualizarEstado(String id, String estado) async {
    final ahora = DateTime.now().toUtc().toIso8601String();
    await LocalDatabase.actualizar('encargos',
        {'estado': estado, 'updated_at': ahora}, 'id', id);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('encargos')
            .update({'estado': estado, 'updated_at': ahora}).eq('id', id);
      } catch (_) {}
    }
    return true;
  }

  static Future<bool> eliminarEncargo(String id) async {
    await LocalDatabase.eliminar('encargos', 'id', id);
    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('encargos').delete().eq('id', id);
      } catch (_) {}
    }
    return true;
  }
}