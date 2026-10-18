import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../services/plan_service.dart';

// ─── Modelos de precios ────────────────────────────────────────────
class _Periodo {
  final String label;
  final String precioBasico;
  final String precioPro;
  final String porMesBasico;
  final String porMesPro;
  final String? ahorroBasico;
  final String? ahorroPro;
  final String? badge;

  const _Periodo({
    required this.label,
    required this.precioBasico,
    required this.precioPro,
    required this.porMesBasico,
    required this.porMesPro,
    this.ahorroBasico,
    this.ahorroPro,
    this.badge,
  });
}

const _periodos = [
  _Periodo(
    label: 'Mensual',
    precioBasico: '\$7.99', precioPro: '\$14.99',
    porMesBasico: '\$7.99/mes', porMesPro: '\$14.99/mes',
  ),
  _Periodo(
    label: '3 meses',
    precioBasico: '\$19.99', precioPro: '\$37.99',
    porMesBasico: '\$6.66/mes', porMesPro: '\$12.66/mes',
    ahorroBasico: 'Ahorras \$4.00', ahorroPro: 'Ahorras \$7.00',
  ),
  _Periodo(
    label: '6 meses',
    precioBasico: '\$37.99', precioPro: '\$71.99',
    porMesBasico: '\$6.33/mes', porMesPro: '\$12.00/mes',
    ahorroBasico: 'Ahorras \$10.00', ahorroPro: 'Ahorras \$18.00',
    badge: 'POPULAR',
  ),
  _Periodo(
    label: 'Anual',
    precioBasico: '\$69.99', precioPro: '\$129.99',
    porMesBasico: '\$5.83/mes', porMesPro: '\$10.83/mes',
    ahorroBasico: '🎉 2 meses gratis', ahorroPro: '🎉 2 meses gratis',
    badge: 'MEJOR PRECIO',
  ),
];

// ═══════════════════════════════════════════════════════════════════
class SuscripcionScreen extends StatefulWidget {
  const SuscripcionScreen({super.key});
  @override
  State<SuscripcionScreen> createState() => _SuscripcionScreenState();
}

class _SuscripcionScreenState extends State<SuscripcionScreen> {
  int _periodoIdx = 0;

  Future<void> _abrirURL(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }
    catch (_) {}
  }

  void _confirmarPlan(String plan, String precio, String periodo) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Confirmar plan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: Text(
        'Plan $plan · $periodo\n$precio\n\nSerás contactado por WhatsApp para completar el pago.',
        style: GoogleFonts.poppins(fontSize: 13.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins())),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _abrirURL(
              'https://wa.me/18098765432?text=Hola,%20quiero%20activar%20el%20plan%20$plan%20de%20NegocioPro%20($precio%20·%20$periodo)');
          },
          child: Text('Activar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = _periodos[_periodoIdx];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Planes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(children: [

          // ── Encabezado ───────────────────────────────────────────
          _Header(),
          const SizedBox(height: 20),

          // ── Banner trial ─────────────────────────────────────────
          if (PlanService.enTrial) ...[
            _TrialBanner(dias: PlanService.diasTrial ?? 30),
            const SizedBox(height: 16),
          ],

          // ── Selector de período ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: List.generate(_periodos.length, (i) {
                final sel = i == _periodoIdx;
                final per = _periodos[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _periodoIdx = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(per.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5, fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textSecondary,
                          )),
                        if (per.badge != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Colors.white.withOpacity(0.25)
                                  : const Color(0xFFFFD700).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(per.badge!,
                              style: GoogleFonts.poppins(
                                fontSize: 7.5, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : const Color(0xFFC8920A),
                                letterSpacing: 0.3,
                              )),
                          ),
                        ],
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // ── Tarjeta BÁSICO ───────────────────────────────────────
          _PlanCard(
            nombre: 'Básico',
            icono: Icons.store_outlined,
            precio: p.precioBasico,
            porMes: p.porMesBasico,
            ahorro: p.ahorroBasico,
            periodo: _periodos[_periodoIdx].label,
            colorTop: const Color(0xFF4A90D9),
            colorBottom: const Color(0xFF357ABD),
            badge: null,
            features: const [
              ('🛒', 'Punto de Venta (POS)'),
              ('📦', 'Inventario ilimitado'),
              ('👥', 'Clientes ilimitados'),
              ('📋', 'Control de Fiado'),
              ('💸', 'Control de Gastos'),
              ('📊', 'Reportes de ventas'),
              ('☁️', 'Respaldo en la nube'),
              ('📵', 'Funciona sin internet'),
            ],
            onActivar: () => _confirmarPlan('Básico', p.precioBasico, _periodos[_periodoIdx].label),
          ),
          const SizedBox(height: 16),

          // ── Tarjeta PRO ──────────────────────────────────────────
          _PlanCard(
            nombre: 'Pro',
            icono: Icons.workspace_premium_rounded,
            precio: p.precioPro,
            porMes: p.porMesPro,
            ahorro: p.ahorroPro,
            periodo: _periodos[_periodoIdx].label,
            colorTop: const Color(0xFFFFD700),
            colorBottom: const Color(0xFFFFA500),
            badge: 'MÁS POPULAR',
            features: const [
              ('✅', 'Todo lo del Plan Básico'),
              ('🏷️', 'Apartados con pagos parciales'),
              ('🧾', 'Cuadre de Caja diario'),
              ('🏪', 'Vitrina Digital con QR'),
              ('📝', 'Encargos de clientes'),
              ('🖨️', 'Impresora Térmica'),
              ('💬', 'Recibos por WhatsApp'),
              ('⭐', 'Soporte Prioritario'),
            ],
            onActivar: () => _confirmarPlan('Pro', p.precioPro, _periodos[_periodoIdx].label),
          ),
          const SizedBox(height: 28),

          // ── Garantía ─────────────────────────────────────────────
          _GarantiaCard(),
          const SizedBox(height: 12),

          // ── Soporte ──────────────────────────────────────────────
          _SoporteCard(onTap: () => _abrirURL('https://wa.me/18098765432')),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _TrialBanner extends StatelessWidget {
  final int dias;
  const _TrialBanner({required this.dias});

  @override
  Widget build(BuildContext context) {
    final urgente = dias <= 5;
    final color = urgente ? const Color(0xFFE17055) : const Color(0xFF00B894);
    final bgColor = urgente
        ? const Color(0xFFE17055).withOpacity(0.08)
        : const Color(0xFF00B894).withOpacity(0.08);
    final borderColor = color.withOpacity(0.3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(urgente ? Icons.timer_outlined : Icons.card_giftcard_rounded,
              color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            dias <= 0
                ? '¡Tu período de prueba ha vencido!'
                : dias == 1
                    ? '¡Te queda 1 día de prueba gratis!'
                    : '🎉 Prueba gratuita activa — $dias días restantes',
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            dias <= 0
                ? 'Activa un plan para seguir usando NegocioPro.'
                : 'Estás usando el Plan Pro completo gratis. Activa tu plan antes de que venza.',
            style: GoogleFonts.poppins(fontSize: 11.5, color: color.withOpacity(0.8)),
          ),
        ])),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1F36), Color(0xFF2D3561)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle,
        ),
        child: const Icon(Icons.store_rounded, color: Colors.white, size: 34),
      ),
      const SizedBox(height: 12),
      Text('NegocioPro', style: GoogleFonts.poppins(
        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Elige el plan y el período que más te convenga',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5)),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final String nombre, precio, porMes, periodo;
  final String? ahorro, badge;
  final IconData icono;
  final Color colorTop, colorBottom;
  final List<(String, String)> features;
  final VoidCallback onActivar;

  const _PlanCard({
    required this.nombre, required this.icono, required this.precio,
    required this.porMes, required this.periodo,
    required this.colorTop, required this.colorBottom,
    required this.features, required this.onActivar,
    this.ahorro, this.badge,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: badge != null
          ? Border.all(color: colorTop.withOpacity(0.6), width: 2)
          : Border.all(color: AppColors.cardBorder),
      boxShadow: badge != null ? [
        BoxShadow(color: colorTop.withOpacity(0.18),
            blurRadius: 20, offset: const Offset(0, 6)),
      ] : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(children: [
        // Cabecera
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colorTop, colorBottom],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icono, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(nombre, style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (badge != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(precio, style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 34,
                fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(porMes, style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 11.5)),
              ),
            ]),
            if (ahorro != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(ahorro!, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
        // Features
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(children: [
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Text(f.$1, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 10),
                Expanded(child: Text(f.$2, style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500))),
                Icon(Icons.check_circle_rounded, color: colorTop, size: 17),
              ]),
            )),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorTop, colorBottom],
                      begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onActivar,
                  child: Text('Activar Plan $nombre',
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}

class _GarantiaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.success.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.verified_rounded, color: AppColors.success, size: 30),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sin contratos ni sorpresas', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13)),
        Text('Cancela cuando quieras. Sin letras pequeñas.',
            style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11.5)),
      ])),
    ]),
  );
}

class _SoporteCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SoporteCard({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.whatsapp_rounded, color: Color(0xFF25D366), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Tienes preguntas?', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
          Text('Escríbenos por WhatsApp y te ayudamos',
              style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF8A9AB0)),
      ]),
    ),
  );
}
