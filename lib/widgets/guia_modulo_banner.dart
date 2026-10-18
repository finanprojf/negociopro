import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/guia_service.dart';
import '../theme/app_colors.dart';

/// Banner de guía contextual que aparece la primera vez en cada módulo.
/// Se oculta al presionar "Entendido" y nunca vuelve (salvo reset manual).
class GuiaModuloBanner extends StatefulWidget {
  final String modulo;

  const GuiaModuloBanner({super.key, required this.modulo});

  @override
  State<GuiaModuloBanner> createState() => _GuiaModuloBannerState();
}

class _GuiaModuloBannerState extends State<GuiaModuloBanner>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _cargando = true;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _verificar();
  }

  Future<void> _verificar() async {
    final visto = await GuiaService.moduloVisto(widget.modulo);
    if (mounted) {
      setState(() {
        _visible = !visto;
        _cargando = false;
      });
      if (_visible) _ctrl.forward();
    }
  }

  Future<void> _cerrar() async {
    await _ctrl.reverse();
    await GuiaService.marcarModulo(widget.modulo);
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || !_visible) return const SizedBox.shrink();

    final info = GuiaService.modulos[widget.modulo];
    if (info == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji / icono
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(info.icono,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.titulo,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const SizedBox(height: 3),
                    Text(info.descripcion,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.45)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _cerrar,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Entendido',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              // X
              GestureDetector(
                onTap: _cerrar,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.close_rounded,
                      size: 18,
                      color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
