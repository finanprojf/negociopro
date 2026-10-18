import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/guia_service.dart';

class WelcomeScreen extends StatefulWidget {
  final String nombreNegocio;
  final VoidCallback onComenzar;
  final VoidCallback onSaltar;

  const WelcomeScreen({
    super.key,
    required this.nombreNegocio,
    required this.onComenzar,
    required this.onSaltar,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIcon;
  late Animation<double> _fadeTexto;
  late Animation<double> _fadeBotones;
  late Animation<Offset> _slideTexto;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIcon = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _fadeTexto = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _slideTexto = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _fadeBotones = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _comenzar() async {
    await GuiaService.marcarBienvenida();
    widget.onComenzar();
  }

  Future<void> _saltar() async {
    await GuiaService.marcarBienvenida();
    widget.onSaltar();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.nombreNegocio.isNotEmpty &&
            widget.nombreNegocio != 'Mi Negocio'
        ? widget.nombreNegocio
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 2),
            FadeTransition(
              opacity: _fadeIcon,
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.store_rounded, size: 52, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
            SlideTransition(
              position: _slideTexto,
              child: FadeTransition(
                opacity: _fadeTexto,
                child: Column(children: [
                  Text(
                    nombre != null ? '¡Bienvenido a\n$nombre! 💚' : '¡Bienvenido a\nNegocioPro! 💚',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary, height: 1.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu negocio tiene mucho potencial.\nVamos a organizarlo paso a paso para que trabajes con más claridad y confianza.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14,
                        color: AppColors.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _Chip(icono: '🛒', label: 'Ventas'),
                      _Chip(icono: '📦', label: 'Inventario'),
                      _Chip(icono: '📋', label: 'Fiado'),
                      _Chip(icono: '👥', label: 'Clientes'),
                      _Chip(icono: '📊', label: 'Reportes'),
                      _Chip(icono: '💸', label: 'Gastos'),
                    ],
                  ),
                ]),
              ),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _fadeBotones,
              child: Column(children: [
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _comenzar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Comenzar el recorrido',
                        style: GoogleFonts.poppins(fontSize: 15,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _saltar,
                  child: Text('Explorar por mi cuenta',
                      style: GoogleFonts.poppins(fontSize: 14,
                          fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String icono;
  final String label;
  const _Chip({required this.icono, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icono, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.poppins(fontSize: 12,
            fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
    );
  }
}
