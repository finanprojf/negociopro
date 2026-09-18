import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_colors.dart';

class VitrinaQrScreen extends StatefulWidget {
  final String url;
  final String empresaNombre;

  const VitrinaQrScreen({
    super.key,
    required this.url,
    required this.empresaNombre,
  });

  @override
  State<VitrinaQrScreen> createState() => _VitrinaQrScreenState();
}

class _VitrinaQrScreenState extends State<VitrinaQrScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _procesando = false;

  Future<Uint8List?> _capturarWidget(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _compartirQr() async {
    setState(() => _procesando = true);
    final bytes = await _capturarWidget(_qrKey);
    setState(() => _procesando = false);
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/qr_vitrina.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '📲 Escanea el código QR para ver el catálogo de ${widget.empresaNombre}',
      subject: 'QR Catálogo - ${widget.empresaNombre}',
    );
  }

  Future<void> _compartirPromo() async {
    if (!mounted) return;
    setState(() => _procesando = true);

    // Insertar tarjeta en Overlay fuera de pantalla para capturarla correctamente
    OverlayEntry? entry;
    final captureKey = GlobalKey();

    final completer = Future<Uint8List?>.value(null);
    Uint8List? bytes;

    try {
      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: -4000,
          top: 0,
          width: 400,
          child: RepaintBoundary(
            key: captureKey,
            child: Material(
              color: Colors.transparent,
              child: _PromoCard(
                url: widget.url,
                empresaNombre: widget.empresaNombre,
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(entry);

      // Esperar 2 frames para asegurar que se rendericé completamente
      await Future.delayed(const Duration(milliseconds: 400));

      bytes = await _capturarWidget(captureKey);
    } finally {
      entry?.remove();
      if (mounted) setState(() => _procesando = false);
    }

    if (bytes == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo generar la imagen'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('\${dir.path}/promo_vitrina.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '🛍️ ¡Visita nuestra tienda en línea!',
      subject: 'Catálogo en línea - \${widget.empresaNombre}',
    );
  }

  Future<void> _copiarEnlace() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Enlace copiado', style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mi código QR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Card QR principal
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(children: [
                // Nombre del negocio
                Text(
                  widget.empresaNombre,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('Tienda en línea',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 20),
                // QR Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                  ),
                  child: QrImageView(
                    data: widget.url,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.textPrimary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textPrimary,
                    ),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Escanea para ver nuestro catálogo',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                // URL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.url,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Logo / branding
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 13),
                  ),
                  const SizedBox(width: 6),
                  Text('NegocioPro',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Botones de acción
          _botonAccion(
            icon: Icons.share_rounded,
            label: 'Compartir código QR',
            sublabel: 'Envía por WhatsApp, Instagram o email',
            color: AppColors.primary,
            onTap: _compartirQr,
          ),
          const SizedBox(height: 10),
          _botonAccion(
            icon: Icons.image_rounded,
            label: 'Compartir imagen promocional',
            sublabel: 'Imagen lista para imprimir o compartir',
            color: const Color(0xFF7C3AED),
            onTap: _compartirPromo,
          ),
          const SizedBox(height: 10),
          _botonAccion(
            icon: Icons.copy_rounded,
            label: 'Copiar enlace',
            sublabel: widget.url,
            color: AppColors.textSecondary,
            onTap: _copiarEnlace,
          ),
          const SizedBox(height: 24),

          // Tip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Imprime el código QR y colócalo en tu negocio para que tus clientes puedan ver tu catálogo en cualquier momento.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.primary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
      bottomNavigationBar: _procesando
          ? Container(
              height: 4,
              child: const LinearProgressIndicator(
                  backgroundColor: AppColors.primarySurface,
                  color: AppColors.primary),
            )
          : null,
    );
  }

  Widget _botonAccion({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(sublabel,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ]),
        ),
      ),
    );
  }
}

// Tarjeta promocional para imprimir/compartir
class _PromoCard extends StatelessWidget {
  final String url;
  final String empresaNombre;

  const _PromoCard({required this.url, required this.empresaNombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            const Color(0xFF0A5C44),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('VITRINA ONLINE',
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 20),

        // Nombre negocio
        Text(empresaNombre,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('¡Escanea y descubre nuestro catálogo!',
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),

        // QR blanco
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: url,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 16),

        Text(url,
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),

        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Powered by NegocioPro',
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
