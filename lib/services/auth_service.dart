import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  static Future<void> logout() async {
    await SupabaseService.client.auth.signOut();
  }

  static User? get currentUser => SupabaseService.client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;
}