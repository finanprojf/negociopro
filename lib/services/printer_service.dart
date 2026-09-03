import '../models/venta_model.dart';
import '../utils/formatters.dart';

class PrinterService {
  static String? _dispositivoConectado;

  static bool get estaConectado => _dispositivoConectado != null;

  static Future<void> conectar(String dispositivo) async {
    _dispositivoConectado = dispositivo;
  }

  static void desconectar() {
    _dispositivoConectado = null;
  }

  /// Genera el texto del recibo de venta
  static String generarReciboVenta({
    required VentaModel venta,
    required String nombreNegocio,
    String? lema,
    String? mensajePie,
  }) {
    final sb = StringBuffer();
    final linea = '================================';

    sb.writeln(linea);
    sb.writeln(_centrar(nombreNegocio.toUpperCase(), 32));
    if (lema != null && lema.isNotEmpty) {
      sb.writeln(_centrar(lema, 32));
    }
    sb.writeln(linea);
    sb.writeln('Recibo: ${venta.numeroFormateado}');
    sb.writeln('Fecha:  ${AppFormatters.fechaHora(venta.createdAt)}');
    if (venta.clienteNombre != null) {
      sb.writeln('Cliente: ${venta.clienteNombre}');
    }
    sb.writeln(linea);

    // Productos
    for (final d in venta.detalles) {
      sb.writeln(d.nombreProducto);
      final cant = '${d.cantidad.toInt()} x ${AppFormatters.moneda(d.precioUnitario)}';
      final sub = AppFormatters.moneda(d.subtotal);
      sb.writeln('$cant${' ' * (32 - cant.length - sub.length)}$sub');
    }

    sb.writeln(linea);
    if (venta.descuento > 0) {
      sb.writeln(_fila('Descuento:', '-${AppFormatters.moneda(venta.descuento)}'));
    }
    sb.writeln(_fila('TOTAL:', AppFormatters.moneda(venta.total)));
    sb.writeln(_fila('Pago:', venta.tipoPago.toUpperCase()));
    if (venta.cambio > 0) {
      sb.writeln(_fila('Cambio:', AppFormatters.moneda(venta.cambio)));
    }
    sb.writeln(linea);

    if (mensajePie != null && mensajePie.isNotEmpty) {
      sb.writeln(_centrar(mensajePie, 32));
    }
    sb.writeln(_centrar('¡Gracias por su compra!', 32));
    sb.writeln(linea);
    sb.writeln('');

    return sb.toString();
  }

  static String _centrar(String texto, int ancho) {
    if (texto.length >= ancho) return texto;
    final espacios = (ancho - texto.length) ~/ 2;
    return ' ' * espacios + texto;
  }

  static String _fila(String label, String valor) {
    final espacio = 32 - label.length - valor.length;
    return '$label${' ' * (espacio > 0 ? espacio : 1)}$valor';
  }

  /// Imprimir recibo (requiere print_bluetooth_thermal)
  static Future<bool> imprimirRecibo(String texto) async {
    if (!estaConectado) return false;
    try {
      // TODO: integrar print_bluetooth_thermal igual que FinanPro
      // await PrintBluetoothThermal.writeBytes(Ticket(texto));
      return true;
    } catch (_) {
      return false;
    }
  }
}