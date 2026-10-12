import 'package:uuid/uuid.dart';
import '../models/cliente_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class ClienteService {
  static const _uuid = Uuid();

  static Future<List<ClienteModel>> getClientes() async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    // Cargar local primero
    final local = await LocalDatabase.consultar('clientes', empresaId, orderBy: 'nombre ASC');
    var clientesLocal = local
        .where((m) => m['activo'] == 1)
        .map((m) => ClienteModel.fromMap(m))
        .toList();

    // Si hay internet, actualizar local y combinar con pendientes offline
    if (await SupabaseService.isOnlineAsync) {
      try {
        final res = await SupabaseService.client
            .from('clientes')
            .select()
            .eq('empresa_id', empresaId)
            .eq('activo', true)
            .order('nombre');

        // IDs pendientes de sync — NO sobreescribir con datos de Supabase
        final idsPendientes = local
            .where((m) => m['synced'] == 0)
            .map((m) => m['id'] as String)
            .toSet();

        for (final m in res) {
          if (idsPendientes.contains(m['id'])) continue; // preservar cambio local
          final map = Map<String, dynamic>.from(m);
          map['synced'] = 1;
          map['activo'] = m['activo'] == true ? 1 : 0;
          await LocalDatabase.insertar('clientes', map);
        }

        // IDs con cambios locales pendientes (synced=0) — tienen prioridad sobre Supabase
        final localPendientes = Map.fromEntries(
          local.where((m) => m['synced'] == 0)
               .map((m) => MapEntry(m['id'] as String, ClienteModel.fromMap(m))),
        );

        final clientesOnline = res.map((m) {
          // Si hay una edición local pendiente para este cliente, usarla
          return localPendientes[m['id']] ?? ClienteModel.fromMap(m);
        }).toList();

        final idsOnline = res.map((m) => m['id'] as String).toSet();
        final nuevos = clientesLocal.where((c) => !idsOnline.contains(c.id)).toList();
        clientesLocal = [...clientesOnline, ...nuevos]
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
      } catch (_) {}
    }

    // Mezclar saldos de fiado activos en cada cliente
    final saldos = await _getSaldosFiados(empresaId);
    return clientesLocal.map((c) {
      final saldo = saldos[c.id] ?? 0;
      return ClienteModel(
        id: c.id,
        empresaId: c.empresaId,
        nombre: c.nombre,
        telefono: c.telefono,
        cedula: c.cedula,
        correo: c.correo,
        direccion: c.direccion,
        fotoUrl: c.fotoUrl,
        notas: c.notas,
        puntosFidelidad: c.puntosFidelidad,
        limiteCredito: c.limiteCredito,
        activo: c.activo,
        createdAt: c.createdAt,
        saldoFiado: saldo > 0 ? saldo : null,
      );
    }).toList();
  }

  /// Devuelve mapa cliente_id → saldo fiado activo total.
  /// Siempre prefiere el saldo local para fiados con cambios pendientes (synced=0).
  static Future<Map<String, double>> _getSaldosFiados(String empresaId) async {
    final Map<String, double> saldos = {};

    // Leer siempre SQLite para tener los datos más frescos (incl. cambios offline)
    final local = await LocalDatabase.consultar('fiados', empresaId);

    try {
      if (await SupabaseService.isOnlineAsync) {
        final res = await SupabaseService.client
            .from('fiados')
            .select('id, cliente_id, saldo_pendiente')
            .eq('empresa_id', empresaId)
            .eq('estado', 'activo');

        // Mapa de fiados locales con cambios pendientes (synced=0)
        final localPendMap = <String, Map<String, dynamic>>{
          for (final f in local.where((m) => m['synced'] == 0))
            f['id'] as String: f
        };

        final idsOnline = <String>{};
        for (final f in res) {
          final fId = f['id'] as String;
          final cid = f['cliente_id'] as String;
          idsOnline.add(fId);
          // Usar saldo local si hay cambios pendientes; si no, usar Supabase
          final saldo = localPendMap.containsKey(fId)
              ? (localPendMap[fId]!['saldo_pendiente'] as num? ?? 0).toDouble()
              : (f['saldo_pendiente'] as num).toDouble();
          if (saldo > 0) saldos[cid] = (saldos[cid] ?? 0) + saldo;
        }

        // Agregar fiados solo-locales (aún no sincronizados a Supabase)
        for (final f in local) {
          final fId = f['id'] as String;
          if (!idsOnline.contains(fId) && f['estado'] == 'activo') {
            final cid = f['cliente_id'] as String;
            final saldo = (f['saldo_pendiente'] as num? ?? 0).toDouble();
            if (saldo > 0) saldos[cid] = (saldos[cid] ?? 0) + saldo;
          }
        }
        return saldos;
      }
    } catch (_) {}

    // Offline: leer de SQLite
    for (final f in local) {
      if (f['estado'] == 'activo') {
        final cid = f['cliente_id'] as String;
        final saldo = (f['saldo_pendiente'] as num? ?? 0).toDouble();
        if (saldo > 0) saldos[cid] = (saldos[cid] ?? 0) + saldo;
      }
    }
    return saldos;
  }

  

  static Future<bool> guardarCliente(ClienteModel cliente, {bool esNuevo = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = esNuevo ? _uuid.v4() : cliente.id;
    final ahora = DateTime.now().toUtc().toIso8601String();

    final datosBase = {
      ...cliente.toMap(),
      'activo': cliente.activo ? 1 : 0, // bool → int para SQLite
      'id': id,
      'empresa_id': empresaId,
      'synced': 0,
      'updated_at': ahora,
    };

    if (esNuevo) {
      await LocalDatabase.insertar('clientes', {...datosBase, 'created_at': ahora});
    } else {
      await LocalDatabase.actualizar('clientes', datosBase, 'id', id);
    }

    if (await SupabaseService.isOnlineAsync) {
      try {
        final datosOnline = {
          ...cliente.toMap(),
          'id': id,
          'empresa_id': empresaId,
          'activo': cliente.activo, // bool para Supabase
          'updated_at': ahora,
        };
        if (esNuevo) {
          datosOnline['created_at'] = ahora;
          await SupabaseService.client.from('clientes').insert(datosOnline);
        } else {
          await SupabaseService.client
              .from('clientes')
              .update(datosOnline)
              .eq('id', id);
        }
        await LocalDatabase.marcarSynced('clientes', id);
      } catch (_) {}
    }

    return true;
  }

  static Future<bool> actualizarPuntos(String clienteId, int puntos) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    await LocalDatabase.actualizar('clientes',
        {'puntos_fidelidad': puntos, 'updated_at': DateTime.now().toUtc().toIso8601String(), 'synced': 0},
        'id', clienteId);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client
            .from('clientes')
            .update({'puntos_fidelidad': puntos})
            .eq('id', clienteId);
        await LocalDatabase.marcarSynced('clientes', clienteId);
      } catch (_) {}
    }

    return true;
  }
}