import 'supabase_service.dart';

class SoporteService {
  static final _db = SupabaseService.client;

  // ── Avisos ─────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAvisos() async {
    final res = await _db
        .from('avisos')
        .select('id, titulo, mensaje, tipo, created_at')
        .eq('activo', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ── Soporte usuario ────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMensajes(String empresaId) async {
    final res = await _db
        .from('soporte_mensajes')
        .select('id, mensaje, es_admin, leido, created_at')
        .eq('empresa_id', empresaId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> enviarMensaje({
    required String empresaId,
    required String mensaje,
  }) async {
    final userId = SupabaseService.userId;
    if (userId == null) return;
    await _db.from('soporte_mensajes').insert({
      'empresa_id': empresaId,
      'usuario_id': userId,
      'mensaje': mensaje,
      'es_admin': false,
      'leido': false,
    });
  }

  static Future<int> contarNoLeidos(String? empresaId) async {
    if (empresaId == null || empresaId.isEmpty) return 0;
    try {
      final res = await _db.rpc('admin_contar_no_leidos',
          params: {'p_empresa_id': empresaId});
      return (res as num? ?? 0).toInt();
    } catch (_) {
      return 0;
    }
  }

  static Future<void> marcarLeidosUsuario(String empresaId) async {
    await _db
        .from('soporte_mensajes')
        .update({'leido': true})
        .eq('empresa_id', empresaId)
        .eq('es_admin', true)
        .eq('leido', false);
  }

  // ── Admin ──────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> adminGetConversaciones() async {
    final res = await _db.rpc('admin_get_all_mensajes');
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final row in (res as List)) {
      final eid = row['empresa_id']?.toString() ?? '';
      if (seen.add(eid)) list.add(Map<String, dynamic>.from(row));
    }
    list.sort((a, b) {
      final ta = DateTime.tryParse(a['ultimo_at']?.toString() ?? '') ?? DateTime(2000);
      final tb = DateTime.tryParse(b['ultimo_at']?.toString() ?? '') ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    return list;
  }

  static Future<List<Map<String, dynamic>>> adminGetConversacion(
      String empresaId) async {
    final res = await _db.rpc('admin_get_conversacion',
        params: {'p_empresa_id': empresaId});
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> adminResponder(String empresaId, String mensaje) async {
    await _db.rpc('admin_responder_soporte',
        params: {'p_empresa_id': empresaId, 'p_mensaje': mensaje});
  }

  static Future<void> adminMarcarLeidos(String empresaId) async {
    await _db.rpc('admin_marcar_leidos',
        params: {'p_empresa_id': empresaId});
  }

  static Future<void> adminEliminarConversacion(String empresaId) async {
    await _db.rpc('admin_eliminar_conversacion',
        params: {'p_empresa_id': empresaId});
  }

  static Future<void> adminEliminarMensaje(String mensajeId) async {
    await _db.rpc('admin_eliminar_mensaje',
        params: {'p_mensaje_id': mensajeId});
  }

  // ── Admin Avisos ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> adminGetAvisos() async {
    final res = await _db
        .from('avisos')
        .select('id, titulo, mensaje, tipo, activo, created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  static Future<void> adminPublicarAviso(
      {required String titulo,
      required String mensaje,
      required String tipo}) async {
    await _db.rpc('admin_publicar_aviso',
        params: {'p_titulo': titulo, 'p_mensaje': mensaje, 'p_tipo': tipo});
  }

  static Future<void> adminDesactivarAviso(String avisoId) async {
    await _db.rpc('admin_desactivar_aviso',
        params: {'p_aviso_id': avisoId});
  }
}
