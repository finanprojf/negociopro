import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

 static String? get userId {
    final id = client.auth.currentUser?.id;
    print('👤 userId: $id');
    return id;
  }

static Future<String?> getEmpresaId() async {
    if (userId == null) return null;
    print('🔍 buscando empresa para userId: $userId');
    try {
      final res = await client
          .from('usuarios')
          .select('empresa_id')
          .eq('id', userId!)
          .single();
      print('✅ empresaId encontrado: ${res['empresa_id']}');
      return res['empresa_id'] as String?;
    } catch (e) {
      print('❌ getEmpresaId error: ${e.toString()}');
      return null;
    }
  }

  static bool get isOnline {
    // TODO: usar connectivity_plus
    return true;
  }
}