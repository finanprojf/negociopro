import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'plan_service.dart';
import 'local_database.dart';

class AuthService {
  static Future<void> logout() async {
    try { await LocalDatabase.limpiarDatosLocales(); } catch (_) {}
    PlanService.limpiar();
    await SupabaseService.limpiarCache();
    await SupabaseService.client.auth.signOut();
  }

  static User? get currentUser => SupabaseService.client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;
}