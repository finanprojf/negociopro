import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';

class SuscripcionScreen extends StatelessWidget {
  const SuscripcionScreen({super.key});

  Future<void> _abrirURL(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Suscripción')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Icon(Icons.store_rounded, color: Colors.white, size: 48),
              const SizedBox(height: 8),
              Text('NegocioPro', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Plan Pro', style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              _PlanCard(precioTotal: '\$6.99', periodo: '1 mes', porMes: '\$6.99/mes',
                  onTap: () => _confirmarPlan(context, '\$6.99', '1 mes')),
              const SizedBox(height: 10),
              _PlanCard(precioTotal: '\$17.99', periodo: '3 meses', porMes: '\$5.99/mes',
                  badge: 'Ahorras \$3.00',
                  onTap: () => _confirmarPlan(context, '\$17.99', '3 meses')),
              const SizedBox(height: 10),
              _PlanCard(precioTotal: '\$29.99', periodo: '6 meses', porMes: '\$4.99/mes',
                  badge: 'Ahorras \$11.94',
                  onTap: () => _confirmarPlan(context, '\$29.99', '6 meses')),
              const SizedBox(height: 10),
              _PlanCard(precioTotal: '\$49.99', periodo: '1 año', porMes: '\$4.16/mes',
                  badge: 'Ahorras \$33.89', destacado: true,
                  onTap: () => _confirmarPlan(context, '\$49.99', '1 año')),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Incluye:', style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15)),
              const SizedBox(height: 12),
              _buildBeneficio('Inventario ilimitado'),
              _buildBeneficio('Ventas con POS'),
              _buildBeneficio('Control de fiado y apartados'),
              _buildBeneficio('Clientes ilimitados'),
              _buildBeneficio('Reportes y gráficas'),
              _buildBeneficio('Control de gastos'),
              _buildBeneficio('Funciona sin internet'),
              _buildBeneficio('Respaldo en la nube'),
              _buildBeneficio('Soporte por WhatsApp'),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_outlined,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 14),
              Text('¿Listo para activar tu plan?', style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Escríbenos por WhatsApp y te ayudaremos a activar tu suscripción de forma rápida y sencilla.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _abrirURL(
                  'https://wa.me/18093190140?text=Hola,%20quiero%20activar%20mi%20suscripci%C3%B3n%20de%20NegocioPro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.chat),
              label: Text('Contactar por WhatsApp',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Te atenderemos y activaremos tu cuenta en el menor tiempo posible.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildBeneficio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
        const SizedBox(width: 10),
        Text(texto, style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 14)),
      ]),
    );
  }

  void _confirmarPlan(BuildContext context, String precio, String periodo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmar plan', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text('¿Deseas activar el plan de $periodo por $precio?',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final mensaje = Uri.encodeComponent(
                  'Hola, quiero activar el plan de $periodo por $precio en NegocioPro');
              _abrirURL('https://wa.me/18093190140?text=$mensaje');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sí, continuar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String precioTotal, periodo, porMes;
  final String? badge;
  final bool destacado;
  final VoidCallback onTap;

  const _PlanCard({
    required this.precioTotal, required this.periodo,
    required this.porMes, required this.onTap,
    this.badge, this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: destacado ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: destacado ? Colors.white : Colors.white.withValues(alpha: 0.4),
            width: destacado ? 2 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(precioTotal, style: GoogleFonts.poppins(
                  color: destacado ? AppColors.primary : Colors.white,
                  fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(periodo, style: GoogleFonts.poppins(
                  color: destacado ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.8),
                  fontSize: 13)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Text(porMes, style: GoogleFonts.poppins(
                  color: destacado ? AppColors.textMuted : Colors.white.withValues(alpha: 0.7),
                  fontSize: 11)),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: destacado ? AppColors.success : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge!, style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ]),
          Icon(Icons.arrow_forward_ios_rounded,
              color: destacado ? AppColors.primary : Colors.white, size: 14),
        ]),
      ),
    );
  }
}