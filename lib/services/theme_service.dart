import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestión de tema (claro / oscuro / sistema) sin paquetes adicionales.
/// Usar [ThemeService.themeMode] con ValueListenableBuilder en MaterialApp.
class ThemeService {
  static const _key = 'app_theme_mode';

  /// Notificador global: escúchalo en el widget raíz.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  /// Carga la preferencia guardada. Llamar en main() antes de runApp().
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    themeMode.value = _fromString(saved);
  }

  /// Cambia el tema y lo persiste.
  static Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      default:       return ThemeMode.light;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.system: return 'system';
    }
  }
}
