import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class PinService {
  static const _kPinHash     = 'pin_hash';
  static const _kPinEnabled  = 'pin_enabled';
  static const _kPinModo     = 'pin_modo';  // 'suspender' | 'cerrar'
  static const _kPinRapido   = 'pin_rapido_hash';
  static const _kPinRapidoEn = 'pin_rapido_enabled';

  // Modo de bloqueo
  static const modoBloqueado  = 'suspender'; // se bloquea al ir al fondo
  static const modoCerrar     = 'cerrar';    // solo al cerrar completamente

  // ---------- PIN DE SEGURIDAD ----------
  static Future<bool> get habilitado async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kPinEnabled) ?? false;
  }

  static Future<String> get modo async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kPinModo) ?? modoBloqueado;
  }

  static Future<void> setModo(String modo) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPinModo, modo);
  }

  static Future<void> guardarPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPinHash, _hash(pin));
    await p.setBool(_kPinEnabled, true);
  }

  static Future<bool> verificarPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_kPinHash) ?? '';
    return _hash(pin) == stored;
  }

  static Future<void> desactivar() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPinEnabled, false);
    await p.remove(_kPinHash);
  }

  static Future<bool> tienePin() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kPinHash);
  }

  // ---------- PIN DE ACCIONES RÁPIDAS ----------
  static Future<bool> get rapidoHabilitado async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kPinRapidoEn) ?? false;
  }

  static Future<void> guardarPinRapido(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPinRapido, _hash(pin));
    await p.setBool(_kPinRapidoEn, true);
  }

  static Future<bool> verificarPinRapido(String pin) async {
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_kPinRapido) ?? '';
    return _hash(pin) == stored;
  }

  static Future<void> desactivarRapido() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPinRapidoEn, false);
    await p.remove(_kPinRapido);
  }

  // ---------- UTIL ----------
  static String _hash(String pin) {
    // Simple hash con salt fijo — suficiente para PIN local
    final bytes = utf8.encode('negociopro_salt_$pin');
    int h = 0;
    for (final b in bytes) { h = (h * 31 + b) & 0xFFFFFFFF; }
    return h.toRadixString(16).padLeft(8, '0');
  }
}
