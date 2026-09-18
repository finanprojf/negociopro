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

  // Color de marca
  Color _colorMarca = AppColors.primary;

  static const List<Color> _coloresPredefinidos = [
    Color(0xFF0F7B5B), // Verde NegocioPro
    Color(0xFFE91E8C), // Rosa
    Color(0xFF7C3AED), // Morado
    Color(0xFF1D4ED8), // Azul
    Color(0xFFDC2626), // Rojo
    Color(0xFFEA580C), // Naranja
    Color(0xFF0891B2), // Celeste
    Color(0xFF854D0E), // Café
    Color(0xFF1A1A2E), // Negro elegante
    Color(0xFF065F46), // Verde oscuro
  ];

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

    OverlayEntry? entry;
    Uint8List? bytes;
    final captureKey = GlobalKey();

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
                colorMarca: _colorMarca,
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(entry);
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
    final file = File('${dir.path}/promo_vitrina.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '🛍️ ¡Visita nuestra tienda en línea!',
      subject: 'Catálogo en línea - ${widget.empresaNombre}',
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
                    color: _colorMarca.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(children: [
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _colorMarca.withValues(alpha: 0.3), width: 2),
                  ),
                  child: QrImageView(
                    data: widget.url,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: _colorMarca,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _colorMarca,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _colorMarca.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.url,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: _colorMarca,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: _colorMarca,
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

          // ── Selector de color de marca ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.palette_rounded, color: _colorMarca, size: 18),
                const SizedBox(width: 8),
                Text('Color de tu marca',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const Spacer(),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _colorMarca,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(
                      color: _colorMarca.withValues(alpha: 0.4),
                      blurRadius: 6,
                    )],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _coloresPredefinidos.map((color) {
                  final selected = _colorMarca.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _colorMarca = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: selected ? 0.6 : 0.25),
                            blurRadius: selected ? 8 : 4,
                            spreadRadius: selected ? 1 : 0,
                          ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Botones de acción
          _botonAccion(
            icon: Icons.share_rounded,
            label: 'Compartir código QR',
            sublabel: 'Envía por WhatsApp, Instagram o email',
            color: _colorMarca,
            onTap: _compartirQr,
          ),
          const SizedBox(height: 10),
          _botonAccion(
            icon: Icons.image_rounded,
            label: 'Compartir imagen promocional',
            sublabel: 'Imagen lista para imprimir o compartir',
            color: _colorMarca,
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
              color: _colorMarca.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.tips_and_updates_rounded,
                  color: _colorMarca, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Imprime el código QR y colócalo en tu negocio para que tus clientes puedan ver tu catálogo en cualquier momento.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: _colorMarca),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
      bottomNavigationBar: _procesando
          ? const SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFE8F7F2),
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

// ── Tarjeta promocional para imprimir/compartir ─────────────────────────────
class _PromoCard extends StatelessWidget {
  final String url;
  final String empresaNombre;
  final Color colorMarca;

  const _PromoCard({
    required this.url,
    required this.empresaNombre,
    required this.colorMarca,
  });

  @override
  Widget build(BuildContext context) {
    // Color oscuro derivado del color de marca para el gradiente
    final colorOscuro = HSLColor.fromColor(colorMarca)
        .withLightness((HSLColor.fromColor(colorMarca).lightness - 0.15).clamp(0.0, 1.0))
        .toColor();

    return Container(
      width: 400,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorMarca, colorOscuro],
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
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: colorMarca,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: colorMarca,
            ),
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
