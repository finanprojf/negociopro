import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo "sin inventario": oculta el inventario y permite usar
/// fiados, apartados, etc. escribiendo los artículos a mano.
class ModoService {
  static const _key = 'modo_sin_inventario';

  /// true = la app se usa SIN inventario.
  static final ValueNotifier<bool> sinInventario = ValueNotifier(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    sinInventario.value = prefs.getBool(_key) ?? false;
  }

  static Future<void> setSinInventario(bool v) async {
    sinInventario.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, v);
  }
}
