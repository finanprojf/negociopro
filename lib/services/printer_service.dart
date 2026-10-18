import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Resultado de una operación de impresión.
class PrintResult {
  final bool ok;
  final String? error;
  const PrintResult.success() : ok = true, error = null;
  const PrintResult.fail(this.error) : ok = false;
}

/// Servicio centralizado de impresora térmica.
/// TODAS las pantallas usan este servicio — nunca llaman a
/// PrintBluetoothThermal directamente.
class PrinterService {
  static const _keyAddress = 'printer_bt_address';
  static const _keyName    = 'printer_bt_name';

  static String? _address;
  static String? _name;

  static String? get address   => _address;
  static String? get name      => _name;
  static bool    get hasPrinter => _address != null;

  // ── Inicialización ────────────────────────────────────────────────
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _address = prefs.getString(_keyAddress);
    _name    = prefs.getString(_keyName);
  }

  // ── Seleccionar impresora ─────────────────────────────────────────
  /// Intenta conectar y guarda si tiene éxito.
  static Future<PrintResult> select(String address, String name) async {
    try {
      await PrintBluetoothThermal.connect(macPrinterAddress: address);
      await Future.delayed(const Duration(milliseconds: 800));
      final ok = await PrintBluetoothThermal.connectionStatus;
      if (ok) {
        _address = address;
        _name    = name;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyAddress, address);
        await prefs.setString(_keyName, name);
        return const PrintResult.success();
      }
      return const PrintResult.fail('La impresora no respondió. ¿Está encendida?');
    } catch (e) {
      return PrintResult.fail('Verifica que la impresora esté encendida y el Bluetooth activo');
    }
  }

  /// Borra la impresora guardada.
  static Future<void> forget() async {
    _address = null;
    _name    = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyName);
  }

  // ── Enviar bytes ──────────────────────────────────────────────────
  /// Conecta (siempre fresco) y envía los bytes.
  /// Devuelve PrintResult con el error si falla.
  static Future<PrintResult> sendBytes(List<int> bytes) async {
    if (_address == null) return const PrintResult.fail('No hay impresora configurada.');
    try {
      // Pattern that works: connect → check return → write immediately → wait → disconnect (flush)
      final conectado = await PrintBluetoothThermal.connect(macPrinterAddress: _address!);
      if (!conectado) {
        return const PrintResult.fail('Verifica que la impresora esté encendida y cerca');
      }
      final byteList = bytes.map((c) => c > 255 ? 63 : c).toList();
      await PrintBluetoothThermal.writeBytes(byteList);
      await Future.delayed(const Duration(milliseconds: 300));
      await PrintBluetoothThermal.disconnect;
      return const PrintResult.success();
    } catch (e) {
      return PrintResult.fail('No se pudo imprimir. Verifica que la impresora esté encendida');
    }
  }

  // ── Prueba de impresión ───────────────────────────────────────────
  static Future<PrintResult> testPrint() async {
    // Raw text only - no ESC/POS - confirms BT connection sends data
    final lines = [
      '================================',
      '     PRUEBA DE IMPRESION        ',
      '================================',
      'Sistema: NegocioPro',
      'Si ves esto funciona bien!',
      '================================',
      '',
      '',
      '',
    ];
    final bytes = <int>[];
    for (final line in lines) {
      bytes.addAll(line.codeUnits.map((c) => c > 255 ? 63 : c));
      bytes.add(10); // newline
    }
    return sendBytes(bytes);
  }

  // ── Ticket de cocina ──────────────────────────────────────────────
  static Future<PrintResult> printKitchenTicket({
    required String empresaNombre,
    required String mesa,
    required String hora,
    required List items,       // [{nombre, cantidad, precio}]
    required String notas,
  }) async {
    final b = EscPos.init()
      ..center()..bold()..text(empresaNombre)..bold(on: false)
      ..text('Mesa: $mesa   $hora')
      ..left()..divider()
      ..text('PEDIDO DE COCINA')..divider();
    for (final it in items) {
      final nombre = (it['nombre'] ?? '').toString();
      final cant   = (it['cantidad'] ?? 1).toString();
      final nom = nombre.length > 20 ? nombre.substring(0, 20) : nombre;
      b.text('$nom  x$cant');
    }
    b.divider();
    if (notas.isNotEmpty) {
      b.bold()..text('NOTA: $notas')..bold(on: false)..text('');
    }
    b.center()..text('- Gracias -')..left()..feed(3)..cut();
    return sendBytes(b.bytes);
  }

  // ── Factura de venta ──────────────────────────────────────────────
  static Future<PrintResult> printReceipt({
    required String empresaNombre,
    required String fecha,
    required String hora,
    required List<Map<String, dynamic>> items, // [{nombre, cantidad, subtotal}]
    required String tipoPago,
    required double total,
    required double montoPagado,
    double descuento = 0,
  }) async {
    final cambio = (tipoPago == 'efectivo' && montoPagado > total)
        ? montoPagado - total : 0.0;
    final tipLabel = tipoPago == 'fiado'
        ? 'FIADO'
        : tipoPago == 'transferencia' ? 'TRANSFERENCIA' : 'EFECTIVO';

    final b = EscPos.init()
      ..center()..bold()..text(empresaNombre)..bold(on: false)
      ..text('$fecha  $hora')
      ..left()..divider()
      ..text('PRODUCTO           CANT  PRECIO')
      ..divider();
    for (final item in items) {
      final nom  = (item['nombre'] as String).length > 16
          ? (item['nombre'] as String).substring(0, 16)
          : (item['nombre'] as String).padRight(16);
      final cant = item['cantidad'].toString().padLeft(4);
      final prec = item['subtotal'].toString().padLeft(7);
      b.text('$nom$cant  $prec');
    }
    b.divider();
    if (descuento > 0) b.text('Descuento: -RD\$${descuento.toStringAsFixed(0)}');
    b.bold()..text('TOTAL: RD\$${total.toStringAsFixed(0)}')..bold(on: false)
     .text('Pago: $tipLabel');
    if (montoPagado > 0 && tipoPago == 'efectivo') {
      b.text('Recibido: RD\$${montoPagado.toStringAsFixed(0)}');
    }
    if (cambio > 0) b.text('Cambio: RD\$${cambio.toStringAsFixed(0)}');
    b.divider()..center()..text('Gracias por su compra!')..left()..feed(3)..cut();
    return sendBytes(b.bytes);
  }
}

// ── Helper ESC/POS fluent builder ─────────────────────────────────────
class EscPos {
  final List<int> bytes = [];

  EscPos.init() {
    bytes.addAll([0x1B, 0x40]); // reset
  }

  EscPos text(String s) {
    // Clamp to Latin-1 — ESC/POS printers speak 8-bit; chars > 255 become '?'
    bytes.addAll(s.codeUnits.map((c) => c > 255 ? 63 : c));
    bytes.add(10);
    return this;
  }

  EscPos bold({bool on = true}) {
    bytes.addAll([0x1B, 0x45, on ? 1 : 0]);
    return this;
  }

  EscPos center() { bytes.addAll([0x1B, 0x61, 1]); return this; }
  EscPos left()   { bytes.addAll([0x1B, 0x61, 0]); return this; }

  EscPos divider() {
    bytes.addAll('--------------------------------'.codeUnits);
    bytes.add(10);
    return this;
  }

  EscPos feed(int lines) {
    for (int i = 0; i < lines; i++) bytes.add(10);
    return this;
  }

  EscPos cut() {
    bytes.addAll([0x1D, 0x56, 0x00]);
    return this;
  }
}
