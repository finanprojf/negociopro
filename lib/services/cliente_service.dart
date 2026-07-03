import 'package:uuid/uuid.dart';
import '../models/cliente_model.dart';
import 'supabase_service.dart';
import 'local_database.dart';

class ClienteService {
  static const _uuid = Uuid();

 static Future<List<ClienteModel>> getClientes() async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return [];

    // Cargar local primero siempre
    final local = await LocalDatabase.consultar('clientes', empresaId, orderBy: 'nombre ASC');
    final clientesLocal = local
        .where((m) => m['activo'] == 1)
        .map((m) => ClienteModel.fromMap(m))
        .toList();

    // Si hay internet actualizar local y devolver Supabase
    if (await SupabaseService.isOnlineAsync) {
      try {
        final res = await SupabaseService.client
            .from('clientes')
            .select()
            .eq('empresa_id', empresaId)
            .eq('activo', true)
            .order('nombre');
        // Guardar en local
       for (final m in res) {
          final map = Map<String, dynamic>.from(m);
          map['synced'] = 1;
          map['activo'] = m['activo'] == true ? 1 : 0;
          await LocalDatabase.insertar('clientes', map);
        }
        return res.map((m) => ClienteModel.fromMap(m)).toList();
      } catch (e) {
        print('❌ Error getClientes: $e');
      }
    }

    return clientesLocal;
  }

  

  static Future<bool> guardarCliente(ClienteModel cliente, {bool esNuevo = true}) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    final id = esNuevo ? _uuid.v4() : cliente.id;
    final ahora = DateTime.now().toIso8601String();

    final map = {
      ...cliente.toMap(),
      'id': id, 'empresa_id': empresaId,
      'synced': 0, 'created_at': ahora, 'updated_at': ahora,
    };

    await LocalDatabase.insertar('clientes', map);

  if (await SupabaseService.isOnlineAsync) {
      try {
       print('💾 guardando cliente empresaId: $empresaId');
       print('💾 guardando cliente empresaId: $empresaId');
        await SupabaseService.client.from('clientes').insert({
          ...cliente.toMap(),
          'id': id,
          'empresa_id': empresaId,
          'created_at': ahora,
          'updated_at': ahora,
        });
        print('✅ Cliente guardado');
        print('✅ Cliente guardado');
        await LocalDatabase.marcarSynced('clientes', id);
        print('✅ Cliente guardado en Supabase');
      } catch (e) {
        print('❌ Error guardando cliente: ${e.toString()}');
      }
    }

    return true;
  }

  static Future<bool> actualizarPuntos(String clienteId, int puntos) async {
    final empresaId = await SupabaseService.getEmpresaId();
    if (empresaId == null) return false;

    await LocalDatabase.actualizar('clientes',
        {'puntos_fidelidad': puntos, 'updated_at': DateTime.now().toIso8601String()},
        'id', clienteId);

    if (await SupabaseService.isOnlineAsync) {
      try {
        await SupabaseService.client
            .from('clientes')
            .update({'puntos_fidelidad': puntos})
            .eq('id', clienteId);
      } catch (_) {}
    }

    return true;
  }
}