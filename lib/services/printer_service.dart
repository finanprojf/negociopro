import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Singleton que mantiene la impresora BT seleccionada y persistida.
/// Todas las pantallas usan este servicio — nunca estado local.
class PrinterService {
  static const _keyAddress = 'printer_bt_address';
  static const _keyName    = 'printer_bt_name';

  static String? _address;
  static String? _name;

  static String? get address => _address;
  static String? get name    => _name;
  static bool    get hasPrinter => _address != null;

  /// Carga la impresora guardada al iniciar la app.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _address = prefs.getString(_keyAddress);
    _name    = prefs.getString(_keyName);
  }

  /// Guarda y conecta una impresora. Devuelve true si la conexión fue exitosa.
  static Future<bool> select(String address, String name) async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: address);
    if (ok) {
      _address = address;
      _name    = name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAddress, address);
      await prefs.setString(_keyName, name);
    }
    return ok;
  }

  /// Verifica si la impresora actualmente guardada sigue conectada.
  static Future<bool> isConnected() async {
    if (_address == null) return false;
    return await PrintBluetoothThermal.connectionStatus;
  }

  /// Reconecta si está desconectada. Devuelve true si queda conectada.
  static Future<bool> ensureConnected() async {
    if (_address == null) return false;
    final already = await PrintBluetoothThermal.connectionStatus;
    if (already) return true;
    return await PrintBluetoothThermal.connect(macPrinterAddress: _address!);
  }

  /// Borra la impresora guardada.
  static Future<void> forget() async {
    _address = null;
    _name    = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyName);
  }
}
