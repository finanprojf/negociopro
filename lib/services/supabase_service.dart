import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

 static String? get userId {
    final id = client.auth.currentUser?.id;
    print('👤 userId: $id');
    return id;
  }

static String? _empresaIdCache;

  static Future<String?> getEmpresaId() async {
    // 1. Si ya está en memoria, usarlo directo
    if (_empresaIdCache != null) return _empresaIdCache;

    // 2. Buscar en SharedPreferences (cache local)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('empresa_id');
    if (cached != null) {
      _empresaIdCache = cached;
      return cached;
    }

    // 3. Si no hay cache, ir a Supabase
    if (userId == null) return null;
    try {
      final res = await client
          .from('usuarios')
          .select('empresa_id')
          .eq('id', userId!)
          .single();
      final id = res['empresa_id'] as String?;
      if (id != null) {
        _empresaIdCache = id;
        await prefs.setString('empresa_id', id);
      }
      return id;
    } catch (e) {
      print('❌ getEmpresaId error: ${e.toString()}');
      return null;
    }
  }

 static Future<bool> get isOnlineAsync async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) return false;
      // Verificar conexión real con timeout corto
      final response = await SupabaseService.client
          .from('empresas')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }
}