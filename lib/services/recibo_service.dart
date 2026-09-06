import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/venta_model.dart';
import '../utils/formatters.dart';
import 'local_database.dart';

class ReciboService {
  // ── Nombre del negocio ────────────────────────────────────
  static Future<String> _getNombreNegocio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empresaId = prefs.getString('empresa_id');
      if (empresaId == null) return 'Mi Negocio';
      final db = await LocalDatabase.database;
      final rows = await db.query('empresas',
          where: 'id = ?', whereArgs: [empresaId], limit: 1);
      if (rows.isNotEmpty) {
        return (rows.first['nombre'] as String? ?? 'Mi Negocio');
      }
    } catch (_) {}
    return 'Mi Negocio';
  }

  // ── PDF en memoria ────────────────────────────────────────
  static Future<Uint8List> _generarPDFBytes(
      VentaModel venta, String nombreNegocio) async {
    final pdf = pw.Document();

    const gris      = PdfColor.fromInt(0xFF6B7280);
    const verde     = PdfColor.fromInt(0xFF0F7B5B);
    const negro     = PdfColor.fromInt(0xFF111827);
    const claroGris = PdfColor.fromInt(0xFFF3F4F6);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll57,
      margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(nombreNegocio.toUpperCase(),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                  color: verde),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 2),
          pw.Divider(color: gris, thickness: 0.5),
          pw.SizedBox(height: 4),
          _pdfFila('Recibo:', venta.numeroFormateado, gris),
          _pdfFila('Fecha:', AppFormatters.fechaHora(venta.createdAt), gris),
          if (venta.clienteNombre != null)
            _pdfFila('Cliente:', venta.clienteNombre!, gris),
          pw.SizedBox(height: 4),
          pw.Divider(color: gris, thickness: 0.5),
          pw.SizedBox(height: 4),
          ...venta.detalles.map((d) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(d.nombreProducto,
                  style: pw.TextStyle(fontSize: 9,
                      fontWeight: pw.FontWeight.bold, color: negro)),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                pw.Text(
                    '${d.cantidad.toInt()} x ${AppFormatters.moneda(d.precioUnitario)}',
                    style: pw.TextStyle(fontSize: 8, color: gris)),
                pw.Text(AppFormatters.moneda(d.subtotal),
                    style: const pw.TextStyle(fontSize: 9)),
              ]),
            ]),
          )),
          pw.Divider(color: gris, thickness: 0.5),
          pw.SizedBox(height: 4),
          if (venta.descuento > 0)
            _pdfFila('Descuento:',
                '-${AppFormatters.moneda(venta.descuento)}', gris,
                valorColor: const PdfColor.fromInt(0xFFDC2626)),
          pw.Container(
            color: claroGris,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
              pw.Text('TOTAL',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppFormatters.moneda(venta.total),
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: verde)),
            ]),
          ),
          pw.SizedBox(height: 4),
          _pdfFila('Método:', venta.tipoPago.toUpperCase(), gris),
          if (venta.cambio > 0)
            _pdfFila('Cambio:', AppFormatters.moneda(venta.cambio), gris),
          pw.SizedBox(height: 8),
          pw.Divider(color: gris, thickness: 0.5),
          pw.Text('¡Gracias por su compra!',
              style: pw.TextStyle(
                  fontSize: 9, color: gris,
                  fontStyle: pw.FontStyle.italic),
              textAlign: pw.TextAlign.center),
        ],
      ),
    ));

    return pdf.save();
  }

  static pw.Widget _pdfFila(String label, String valor, PdfColor labelColor,
      {PdfColor? valorColor}) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, color: labelColor)),
        pw.Text(valor,
            style: pw.TextStyle(
                fontSize: 9, color: valorColor,
                fontWeight: pw.FontWeight.bold)),
      ]);

  // ── COMPARTIR TEXTO (WhatsApp / SMS) ─────────────────────
  static Future<void> compartirTexto(VentaModel venta) async {
    final nombre = await _getNombreNegocio();
    final sb = StringBuffer();
    sb.writeln('🧾 *RECIBO DE VENTA*');
    sb.writeln('📍 $nombre');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('N°: ${venta.numeroFormateado}');
    sb.writeln('📅 ${AppFormatters.fechaHora(venta.createdAt)}');
    if (venta.clienteNombre != null) sb.writeln('👤 ${venta.clienteNombre}');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    for (final d in venta.detalles) {
      sb.writeln('• ${d.nombreProducto}');
      sb.writeln(
          '  ${d.cantidad.toInt()} x ${AppFormatters.moneda(d.precioUnitario)} = ${AppFormatters.moneda(d.subtotal)}');
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (venta.descuento > 0) {
      sb.writeln('Descuento:   -${AppFormatters.moneda(venta.descuento)}');
    }
    sb.writeln('*TOTAL:       ${AppFormatters.moneda(venta.total)}*');
    sb.writeln('Método pago: ${venta.tipoPago.toUpperCase()}');
    if (venta.cambio > 0) sb.writeln('Cambio:       ${AppFormatters.moneda(venta.cambio)}');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('¡Gracias por su compra! 🙏');
    await Share.share(sb.toString(),
        subject: 'Recibo ${venta.numeroFormateado} - $nombre');
  }

  // ── COMPARTIR PDF ─────────────────────────────────────────
  static Future<void> compartirPDF(VentaModel venta) async {
    final nombre = await _getNombreNegocio();
    final bytes  = await _generarPDFBytes(venta, nombre);
    final dir    = await getTemporaryDirectory();
    final file   = File(
        '${dir.path}/recibo_${venta.numeroVenta ?? venta.id.substring(0, 6)}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Recibo ${venta.numeroFormateado} - $nombre',
    );
  }

  // ── IMPRIMIR WiFi / Normal ────────────────────────────────
  static Future<void> imprimirWifi(VentaModel venta) async {
    final nombre = await _getNombreNegocio();
    final bytes  = await _generarPDFBytes(venta, nombre);
    await Printing.layoutPdf(onLayout: (_) async => bytes,
        name: 'Recibo ${venta.numeroFormateado}');
  }

  // ── IMPRIMIR Térmica Bluetooth ────────────────────────────
  static Future<BluetoothInfo?> seleccionarImpresora() async {
    try {
      final bonded = await PrintBluetoothThermal.pairedBluetooths;
      return bonded.isNotEmpty ? bonded.first : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<BluetoothInfo>> listarImpresoras() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  static Future<String> imprimirBluetooth(
      VentaModel venta, BluetoothInfo impresora) async {
    try {
      final conectado = await PrintBluetoothThermal.connect(
          macPrinterAddress: impresora.macAdress);
      if (!conectado) return 'No se pudo conectar a ${impresora.name}';

      final nombre = await _getNombreNegocio();
      const linea  = '================================\n';
      final sb     = StringBuffer();

      sb.write(linea);
      sb.writeln(_centrar(nombre.toUpperCase(), 32));
      sb.write(linea);
      sb.writeln('Recibo: ${venta.numeroFormateado}');
      sb.writeln('Fecha:  ${AppFormatters.fechaHora(venta.createdAt)}');
      if (venta.clienteNombre != null) {
        sb.writeln('Cliente: ${venta.clienteNombre}');
      }
      sb.write(linea);

      for (final d in venta.detalles) {
        sb.writeln(d.nombreProducto);
        final cant = '${d.cantidad.toInt()} x ${AppFormatters.moneda(d.precioUnitario)}';
        final sub  = AppFormatters.moneda(d.subtotal);
        final esp  = 32 - cant.length - sub.length;
        sb.writeln('$cant${' ' * (esp > 0 ? esp : 1)}$sub');
      }

      sb.write(linea);
      if (venta.descuento > 0) {
        sb.write(_fila('Descuento:', '-${AppFormatters.moneda(venta.descuento)}'));
      }
      sb.write(_fila('TOTAL:', AppFormatters.moneda(venta.total)));
      sb.write(_fila('Pago:', venta.tipoPago.toUpperCase()));
      if (venta.cambio > 0) {
        sb.write(_fila('Cambio:', AppFormatters.moneda(venta.cambio)));
      }
      sb.write(linea);
      sb.writeln(_centrar('Gracias por su compra!', 32));
      sb.write(linea);
      sb.write('\n\n\n');

      // Convertir texto a bytes (Latin-1 para impresoras térmicas)
      final bytes = sb.toString().codeUnits
          .map((c) => c > 255 ? 63 : c) // ? para caracteres no soportados
          .toList();
      await PrintBluetoothThermal.writeBytes(bytes);
      await Future.delayed(const Duration(milliseconds: 300));
      await PrintBluetoothThermal.disconnect;
      return 'ok';
    } catch (e) {
      return 'Error: $e';
    }
  }

  static String _centrar(String texto, int ancho) {
    if (texto.length >= ancho) return texto;
    final esp = (ancho - texto.length) ~/ 2;
    return ' ' * esp + texto;
  }

  static String _fila(String label, String valor) {
    final esp = 32 - label.length - valor.length;
    return '$label${' ' * (esp > 0 ? esp : 1)}$valor\n';
  }
}
