import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';

class SuscripcionScreen extends StatefulWidget {
  const SuscripcionScreen({super.key});

  @override
  State<SuscripcionScreen> createState() => _SuscripcionScreenState();
}

class _SuscripcionScreenState extends State<SuscripcionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _anuales = false; // false = mensual, true = anual

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _abrirURL(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }
    catch (_) {}
  }

  void _confirmarPlan(BuildContext ctx, String plan, String precio) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Confirmar plan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      content: Text('Plan $plan — $precio\n\nSerás contactado por WhatsApp para completar el pago.',
          style: GoogleFonts.poppins(fontSize: 13.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.poppins())),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _abrirURL(
              'https://wa.me/18098765432?text=Hola,%20quiero%20activar%20el%20plan%20$plan%20de%20NegocioPro%20(%24$precio)');
          },
          child: Text('Activar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Planes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(children: [

          // ── Encabezado ───────────────────────────────────────────
          _Header(),
          const SizedBox(height: 24),

          // ── Toggle mensual / anual ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(children: [
              _Toggle('Mensual', !_anuales, () => setState(() => _anuales = false)),
              _Toggle('Anual  · 2 meses gratis 🎉', _anuales,
                  () => setState(() => _anuales = true)),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Tarjeta BÁSICO ───────────────────────────────────────
          _PlanCard(
            nombre: 'Básico',
            icono: Icons.store_outlined,
            precio: _anuales ? '\$8.32' : '\$9.99',
            periodo: _anuales ? '/mes · facturado \$99.99/año' : '/mes',
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
            onActivar: () => _confirmarPlan(context, 'Básico',
                _anuales ? '99.99/año' : '9.99/mes'),
          ),
          const SizedBox(height: 16),

          // ── Tarjeta PRO ──────────────────────────────────────────
          _PlanCard(
            nombre: 'Pro',
            icono: Icons.workspace_premium_rounded,
            precio: _anuales ? '\$16.66' : '\$19.99',
            periodo: _anuales ? '/mes · facturado \$199.99/año' : '/mes',
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
            onActivar: () => _confirmarPlan(context, 'Pro',
                _anuales ? '199.99/año' : '19.99/mes'),
          ),
          const SizedBox(height: 28),

          // ── Garantía ─────────────────────────────────────────────
          _GarantiaCard(),
          const SizedBox(height: 16),

          // ── Soporte ──────────────────────────────────────────────
          _SoporteCard(onTap: () => _abrirURL('https://wa.me/18098765432')),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F36), Color(0xFF2D3561)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        Text('NegocioPro', style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 4),
        Text('Elige el plan perfecto para tu negocio',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white70, fontSize: 13,
            )),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _Toggle(this.label, this.activo, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12.5, fontWeight: FontWeight.w600,
            color: activo ? Colors.white : AppColors.textSecondary,
          )),
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  final String nombre, precio, periodo;
  final IconData icono;
  final Color colorTop, colorBottom;
  final String? badge;
  final List<(String, String)> features;
  final VoidCallback onActivar;

  const _PlanCard({
    required this.nombre, required this.icono, required this.precio,
    required this.periodo, required this.colorTop, required this.colorBottom,
    required this.features, required this.onActivar, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Cabecera con gradiente
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorTop, colorBottom],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icono, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Text(nombre, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                )),
                const Spacer(),
                if (badge != null) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge!, style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
                ),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(precio, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800,
                  height: 1,
                )),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(periodo, style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 12,
                  )),
                ),
              ]),
            ]),
          ),

          // Features
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(children: [
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(children: [
                  Text(f.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(f.$2, style: GoogleFonts.poppins(
                    fontSize: 13.5, color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ))),
                  Icon(Icons.check_circle_rounded, color: colorTop, size: 18),
                ]),
              )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorTop, colorBottom],
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                    ),
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
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GarantiaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.success.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.success.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.verified_rounded, color: AppColors.success, size: 32),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sin contratos ni sorpresas',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13.5)),
        Text('Cancela cuando quieras. Sin letras pequeñas.',
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 12)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.whatsapp_rounded, color: Color(0xFF25D366), size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Tienes preguntas?', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
          Text('Escríbenos por WhatsApp y te ayudamos',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A9AB0)),
      ]),
    ),
  );
}
