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
        // Primero empujar cambios pendientes locales a Supabase
        await _sincronizarPendientes(empresaId);

        var query = SupabaseService.client
            .from('encargos')
            .select('*, clientes(nombre)')
            .eq('empresa_id', empresaId)
            .order('created_at', ascending: false);

        final res = await query;

        // IDs con cambios locales no sincronizados — no sobreescribir
        final idsPendientes = local
            .where((m) => m['synced'] == 0)
            .map((m) => m['id'] as String)
            .toSet();

        for (final m in res) {
          // Si hay cambios locales pendientes para este encargo, respetar local
          if (idsPendientes.contains(m['id'] as String?)) continue;
          final map = Map<String, dynamic>.from(m);
          // Guardar nombre del cliente antes de quitar el join
          if (m['clientes'] != null) {
            map['cliente_nombre'] = m['clientes']['nombre'];
          }
          map.remove('clientes');
          map['es_lista_propia'] = m['es_lista_propia'] == true ? 1 : 0;
          map['synced'] = 1;
          try { await LocalDatabase.insertar('encargos', map); } catch (_) {}
        }

        // Mapa local de pendientes para que la lista use versión local
        final localPendMap = Map.fromEntries(
          encargosLocal
              .where((e) => idsPendientes.contains(e.id))
              .map((e) => MapEntry(e.id, e)),
        );

        var encargosOnline = res.map((m) {
          final id = m['id'] as String;
          return localPendMap[id] ?? EncargoModel.fromMap(m);
        }).toList();

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
      'cliente_nombre': encargo.clienteNombre,
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
          // costo_pedido ya va en toMap(); cliente_nombre NO existe en Supabase
        };
        dataOnline.remove('cliente_nombre'); // campo solo local
        if (esNuevo) {
          await SupabaseService.client.from('encargos').insert(dataOnline);
        } else {
          await SupabaseService.client.from('encargos')
              .update(dataOnline).eq('id', id);
        }
        await LocalDatabase.marcarSynced('encargos', id);
      } catch (_) {}
    }

    return true;
  }

  static Future<bool> actualizarEstado(String id, String estado) async {
    final ahora = DateTime.now().toUtc().toIso8601String();
    // Marcar synced=0 para que el cambio sobreviva si Supabase falla
    await LocalDatabase.actualizar('encargos',
        {'estado': estado, 'updated_at': ahora, 'synced': 0}, 'id', id);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client.from('encargos')
            .update({'estado': estado, 'updated_at': ahora}).eq('id', id);
        await LocalDatabase.marcarSynced('encargos', id);
      } catch (_) {}
    }
    return true;
  }

  /// Empuja encargos con synced=0 a Supabase antes de leer desde la nube.
  static Future<void> _sincronizarPendientes(String empresaId) async {
    final db = await LocalDatabase.database;
    final pendientes = await db.query('encargos',
        where: 'empresa_id = ? AND synced = 0', whereArgs: [empresaId]);
    for (final row in pendientes) {
      try {
        final data = Map<String, dynamic>.from(row)
          ..remove('synced')
          ..remove('cliente_nombre'); // campo solo local
        data['es_lista_propia'] = data['es_lista_propia'] == 1;
        await SupabaseService.client.from('encargos').upsert(data);
        await LocalDatabase.marcarSynced('encargos', row['id'] as String);
      } catch (_) {}
    }
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