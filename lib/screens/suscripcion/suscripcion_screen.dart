import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../services/plan_service.dart';
import '../../services/billing_service.dart';

// ─── Períodos ────────────────────────────────────────────────────────────────
class _Periodo {
  final String label;
  final String idBasico, idPro;
  final String precioBasicoFallback, precioProfallback;
  final String porMesBasico, porMesPro;
  final String? ahorroBasico, ahorroPro, badge;
  const _Periodo({
    required this.label,
    required this.idBasico, required this.idPro,
    required this.precioBasicoFallback, required this.precioProfallback,
    required this.porMesBasico, required this.porMesPro,
    this.ahorroBasico, this.ahorroPro, this.badge,
  });
}

const _periodos = [
  _Periodo(
    label: 'Mensual',
    idBasico: BillingProducts.basicoMensual,    idPro: BillingProducts.proMensual,
    precioBasicoFallback: '\$7.99',  precioProfallback: '\$14.99',
    porMesBasico: '\$7.99/mes',      porMesPro: '\$14.99/mes',
  ),
  _Periodo(
    label: '3 meses',
    idBasico: BillingProducts.basicoTrimestral, idPro: BillingProducts.proTrimestral,
    precioBasicoFallback: '\$19.99', precioProfallback: '\$37.99',
    porMesBasico: '\$6.66/mes',      porMesPro: '\$12.66/mes',
    ahorroBasico: 'Ahorras \$4.00',  ahorroPro: 'Ahorras \$7.00',
  ),
  _Periodo(
    label: '6 meses',
    idBasico: BillingProducts.basicoSemestral,  idPro: BillingProducts.proSemestral,
    precioBasicoFallback: '\$37.99', precioProfallback: '\$71.99',
    porMesBasico: '\$6.33/mes',      porMesPro: '\$12.00/mes',
    ahorroBasico: 'Ahorras \$10.00', ahorroPro: 'Ahorras \$18.00',
    badge: 'POPULAR',
  ),
  _Periodo(
    label: 'Anual',
    idBasico: BillingProducts.basicoAnual,      idPro: BillingProducts.proAnual,
    precioBasicoFallback: '\$69.99', precioProfallback: '\$129.99',
    porMesBasico: '\$5.83/mes',      porMesPro: '\$10.83/mes',
    ahorroBasico: '🎉 2 meses gratis', ahorroPro: '🎉 2 meses gratis',
    badge: 'MEJOR PRECIO',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
class SuscripcionScreen extends StatefulWidget {
  const SuscripcionScreen({super.key});
  @override
  State<SuscripcionScreen> createState() => _SuscripcionScreenState();
}

class _SuscripcionScreenState extends State<SuscripcionScreen> {
  int  _periodoIdx = 0;
  int  _planIdx    = 0; // 0=Básico, 1=Pro
  bool _cargando   = false;
  final _billing   = BillingService.instance;

  NivelPlan get _plan     => PlanService.nivel;
  int?      get _diasLeft => PlanService.diasEnPlan;
  bool      get _tieneBasico => _plan == NivelPlan.basico;
  bool      get _tienePro    => _plan == NivelPlan.pro;
  bool      get _tienePlan   => _tieneBasico || _tienePro;

  @override
  void initState() {
    super.initState();
    _initBilling();
  }

  Future<void> _initBilling() async {
    _billing.onCargando      = () => setState(() => _cargando = true);
    _billing.onCargaCompleta = () { if (mounted) setState(() => _cargando = false); };
    _billing.onError         = (msg) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.danger,
      ));
    };
    _billing.onCompraExitosa = (productId) async {
      if (!mounted) return;
      await PlanService.cargar();
      setState(() {});
      final meta = BillingProducts.info[productId];
      final plan = meta?['plan'] == 'pro' ? 'Pro' : 'Básico';
      showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¡Plan activado! 🎉',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Tu plan $plan está activo. ¡Gracias por confiar en NegocioPro!',
            style: GoogleFonts.poppins(fontSize: 13.5)),
        actions: [ElevatedButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          child: Text('¡Perfecto!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        )],
      ));
    };
    if (!_billing.disponible) await _billing.init();
    if (mounted) setState(() {});
  }

  String _precio(String productId, String fallback) =>
      _billing.getPrecio(productId) ?? fallback;

  void _activar(String productId) {
    if (_cargando) return;
    _billing.comprar(productId);
  }

  // ── Cancelar suscripción ─────────────────────────────────────────
  Future<void> _mostrarEncuestaCancelacion() async {
    String? razon;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('¿Por qué quieres cancelar?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Queremos mejorar para ti. Selecciona una razón:',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ...[
              ('💰', 'El precio es muy alto'),
              ('🛠️', 'Le faltan funciones que necesito'),
              ('🐛', 'Tiene errores o problemas'),
              ('🏪', 'Cerré mi negocio'),
              ('🔄', 'Voy a usar otra app'),
              ('❓', 'Otra razón'),
            ].map((op) => RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${op.$1} ${op.$2}',
                  style: GoogleFonts.poppins(fontSize: 13)),
              value: op.$2,
              groupValue: razon,
              onChanged: (v) => setS(() => razon = v),
            )),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Volver', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: razon == null ? null : () => Navigator.pop(ctx, true),
              child: Text('Continuar',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    if (confirmar == true) {
      await launchUrl(
        Uri.parse('https://play.google.com/store/account/subscriptions'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Planes'),
        actions: [
          TextButton.icon(
            onPressed: _cargando ? null : _billing.restaurar,
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: Text('Restaurar', style: GoogleFonts.poppins(fontSize: 12)),
          ),
        ],
      ),
      body: _tienePlan
          ? Stack(children: [
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: Column(children: [
                  if (_tienePro) ...[
                    _PlanActivoBanner(
                      plan: _plan,
                      diasLeft: _diasLeft,
                      onCancelar: _mostrarEncuestaCancelacion,
                    ),
                    const SizedBox(height: 16),
                    _BeneficiosActivos(esPro: true),
                    const SizedBox(height: 10),
                    _GarantiaCard(),
                    const SizedBox(height: 6),
                    _SoporteCard(onTap: () => launchUrl(
                      Uri.parse('https://wa.me/18093190140'),
                      mode: LaunchMode.externalApplication,
                    )),
                  ] else if (_tieneBasico) ...[
                    _PlanActivoBanner(
                      plan: _plan,
                      diasLeft: _diasLeft,
                      onCancelar: _mostrarEncuestaCancelacion,
                    ),
                    const SizedBox(height: 16),
                    _BeneficiosActivos(esPro: false),
                    const SizedBox(height: 20),
                    _UpgradeProCard(
                      periodoIdx: _periodoIdx,
                      periodos: _periodos,
                      precio: (id, fb) => _precio(id, fb),
                      cargando: _cargando,
                      onActivar: _activar,
                      mostrarSelector: true,
                    ),
                    const SizedBox(height: 10),
                    _GarantiaCard(),
                    const SizedBox(height: 6),
                    _SoporteCard(onTap: () => launchUrl(
                      Uri.parse('https://wa.me/18093190140'),
                      mode: LaunchMode.externalApplication,
                    )),
                  ],
                ]),
              ),
              if (_cargando)
                Container(
                  color: Colors.black.withOpacity(0.35),
                  child: const Center(child: CircularProgressIndicator(
                      color: AppColors.primary)),
                ),
            ])
          : _buildSinPlanUI(context),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIN PLAN / TRIAL — nueva UI estilo FinanPro
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSinPlanUI(BuildContext context) {
    final bottomPad  = MediaQuery.of(context).padding.bottom;
    final periodo    = _periodos[_periodoIdx];
    final esPro      = _planIdx == 1;
    final productId  = esPro ? periodo.idPro    : periodo.idBasico;
    final precioFb   = esPro ? periodo.precioProfallback : periodo.precioBasicoFallback;
    final precio     = _precio(productId, precioFb);
    final planName   = esPro ? 'Pro' : 'Básico';
    final planColor  = esPro ? const Color(0xFFE6A817) : const Color(0xFF4A90D9);
    final planColorB = esPro ? const Color(0xFFC47F0A) : const Color(0xFF357ABD);

    return Stack(children: [
      Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Trial banner
            if (PlanService.enTrial) ...[
              _TrialBanner(dias: PlanService.diasTrial ?? 30),
              const SizedBox(height: 6),
            ],

            // Header branding
            _Header(),
            const SizedBox(height: 10),

            // ── Plan selector (Básico / Pro) ─────────────────────
            _PlanSelectorRow(
              planIdx: _planIdx,
              onSelect: (i) => setState(() => _planIdx = i),
            ),
            const SizedBox(height: 10),

            // ── Features del plan seleccionado ───────────────────
            _FeatureListCompacta(esPro: esPro),
            const SizedBox(height: 12),

            // ── Período de suscripción ───────────────────────────
            Row(children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text('Período de suscripción',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: AppColors.textPrimary,
                  )),
            ]),
            const SizedBox(height: 6),

            // ── Lista radio con todos los períodos ───────────────
            _PeriodoRadioList(
              periodoIdx: _periodoIdx,
              planIdx: _planIdx,
              periodos: _periodos,
              getPrecio: (id, fb) => _precio(id, fb),
              onSelect: (i) => setState(() => _periodoIdx = i),
            ),

            const SizedBox(height: 10),
            _GarantiaCard(),
            const SizedBox(height: 6),
            _SoporteCard(onTap: () => launchUrl(
              Uri.parse('https://wa.me/18093190140'),
              mode: LaunchMode.externalApplication,
            )),
            const SizedBox(height: 2),
          ]),
        )),

        // ── Botón sticky ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + bottomPad),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              top: BorderSide(color: AppColors.cardBorder.withOpacity(0.6)),
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12, offset: const Offset(0, -3),
            )],
          ),
          child: SizedBox(
            width: double.infinity, height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [planColor, planColorB],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: planColor.withOpacity(0.38),
                  blurRadius: 14, offset: const Offset(0, 5),
                )],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _cargando ? null : () => _activar(productId),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.shopping_cart_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Suscribir Plan $planName  •  $precio',
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w700, letterSpacing: 0.2,
                      ),
                    ),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ]),

      if (_cargando)
        Container(
          color: Colors.black.withOpacity(0.35),
          child: const Center(child: CircularProgressIndicator(
              color: AppColors.primary)),
        ),
    ]);
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Beneficios del plan activo
// ═══════════════════════════════════════════════════════════════════════════════
class _BeneficiosActivos extends StatelessWidget {
  final bool esPro;
  const _BeneficiosActivos({required this.esPro});

  @override
  Widget build(BuildContext context) {
    final colorTop = esPro ? const Color(0xFFE6A817) : const Color(0xFF4A90D9);
    final basico = const [
      ('🛒', 'Punto de Venta (POS)'),
      ('📦', 'Gestión de inventario'),
      ('👥', 'Base de clientes'),
      ('📋', 'Fiado / crédito'),
      ('💸', 'Control de gastos'),
      ('📊', 'Reportes de ventas'),
      ('☁️', 'Sincronización en la nube'),
      ('📵', 'Funciona sin internet'),
    ];
    final pro = const [
      ('✅', 'Todo lo del plan Básico'),
      ('🏷️', 'Apartados de productos'),
      ('🧾', 'Cuadre de Caja'),
      ('🏪', 'Vitrina digital con QR'),
      ('🍽️', 'Carta Digital'),
      ('📝', 'Gestión de Encargos'),
      ('🖨️', 'Impresión térmica'),
      ('💬', 'Integración WhatsApp'),
      ('⭐', 'Soporte VIP prioritario'),
    ];
    final features = esPro ? pro : basico;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lo que incluye tu plan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700,
                fontSize: 13.5, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Text(f.$1, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(f.$2, style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textPrimary)),
            const Spacer(),
            Icon(Icons.check_circle_rounded, color: colorTop, size: 18),
          ]),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Plan selector (Básico / Pro chips)
// ═══════════════════════════════════════════════════════════════════════════════
class _PlanSelectorRow extends StatelessWidget {
  final int planIdx;
  final ValueChanged<int> onSelect;
  const _PlanSelectorRow({required this.planIdx, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final plans = [
      (Icons.store_outlined,           'Básico',    const Color(0xFF4A90D9), const Color(0xFF357ABD), null),
      (Icons.workspace_premium_rounded, 'Pro',       const Color(0xFFE6A817), const Color(0xFFC47F0A), 'POPULAR'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: List.generate(plans.length, (i) {
          final sel     = i == planIdx;
          final p       = plans[i];
          final colorT  = p.$3;
          final colorB  = p.$4;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: sel ? LinearGradient(
                    colors: [colorT, colorB],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ) : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: sel ? [BoxShadow(
                    color: colorT.withOpacity(0.35),
                    blurRadius: 10, offset: const Offset(0, 3),
                  )] : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(p.$1, size: 16,
                      color: sel ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(p.$2, style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppColors.textSecondary,
                  )),
                  if (p.$5 != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: sel
                            ? Colors.white.withOpacity(0.22)
                            : const Color(0xFFE6A817).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p.$5!, style: GoogleFonts.poppins(
                        fontSize: 7.5, fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: sel ? Colors.white : const Color(0xFFB07010),
                      )),
                    ),
                  ],
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Feature list compacta (para plan seleccionado)
// ═══════════════════════════════════════════════════════════════════════════════
class _FeatureListCompacta extends StatelessWidget {
  final bool esPro;
  const _FeatureListCompacta({required this.esPro});

  static const _basico = [
    ('🛒', 'Punto de Venta (POS)'),
    ('📦', 'Gestión de inventario'),
    ('👥', 'Base de clientes'),
    ('📋', 'Fiado / crédito'),
    ('💸', 'Control de gastos'),
    ('📊', 'Reportes de ventas'),
    ('☁️', 'Sincronización en la nube'),
    ('📵', 'Funciona sin internet'),
  ];
  static const _pro = [
    ('✅', 'Todo lo del plan Básico'),
    ('🏷️', 'Apartados de productos'),
    ('🧾', 'Cuadre de Caja'),
    ('🏪', 'Vitrina digital con QR'),
    ('🍽️', 'Carta Digital'),
    ('📝', 'Gestión de Encargos'),
    ('🖨️', 'Impresión térmica'),
    ('💬', 'Integración WhatsApp'),
    ('⭐', 'Soporte VIP prioritario'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorT    = esPro ? const Color(0xFFE6A817) : const Color(0xFF4A90D9);
    final features  = esPro ? _pro : _basico;
    final planName  = esPro ? 'Plan Pro' : 'Plan Básico';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(esPro ? Icons.workspace_premium_rounded : Icons.store_outlined,
              color: colorT, size: 16),
          const SizedBox(width: 6),
          Text('Incluye el $planName',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 12.5,
                color: AppColors.textPrimary,
              )),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5, runSpacing: 5,
          children: features.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: colorT.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorT.withOpacity(0.18)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(f.$1, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(f.$2, style: GoogleFonts.poppins(
                  fontSize: 10.5, color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
            ]),
          )).toList(),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Lista de períodos con radio buttons (todos visibles)
// ═══════════════════════════════════════════════════════════════════════════════
class _PeriodoRadioList extends StatelessWidget {
  final int periodoIdx;
  final int planIdx;
  final List<_Periodo> periodos;
  final String Function(String id, String fallback) getPrecio;
  final ValueChanged<int> onSelect;
  const _PeriodoRadioList({
    required this.periodoIdx, required this.planIdx,
    required this.periodos,   required this.getPrecio,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(periodos.length, (i) {
        final p      = periodos[i];
        final sel    = i == periodoIdx;
        final esPro  = planIdx == 1;
        final id     = esPro ? p.idPro : p.idBasico;
        final fb     = esPro ? p.precioProfallback : p.precioBasicoFallback;
        final precio = getPrecio(id, fb);
        final ahorro = esPro ? p.ahorroPro : p.ahorroBasico;
        final colorT = esPro ? const Color(0xFFE6A817) : const Color(0xFF4A90D9);
        final badgeColor = p.badge == 'POPULAR'
            ? const Color(0xFF00B894)
            : p.badge == 'MEJOR PRECIO'
                ? const Color(0xFFE6A817)
                : Colors.transparent;

        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? colorT.withOpacity(0.07) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? colorT : AppColors.cardBorder,
                width: sel ? 1.8 : 1,
              ),
            ),
            child: Row(children: [
              // Radio indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? colorT : AppColors.textSecondary.withOpacity(0.4),
                    width: 2,
                  ),
                  color: sel ? colorT : Colors.transparent,
                ),
                child: sel
                    ? const Icon(Icons.check, color: Colors.white, size: 12)
                    : null,
              ),
              const SizedBox(width: 10),

              // Label + badge
              Expanded(child: Row(children: [
                Text(p.label, style: GoogleFonts.poppins(
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                  color: sel ? colorT : AppColors.textPrimary,
                )),
                if (p.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(p.badge!, style: GoogleFonts.poppins(
                      fontSize: 8.5, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 0.3,
                    )),
                  ),
                ],
              ])),

              // Precio + ahorro alineados a la derecha
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(precio, style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: sel ? colorT : AppColors.textPrimary,
                )),
                if (ahorro != null)
                  Text(ahorro, style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  )),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Selector de período (extraído para reusar)
// ═══════════════════════════════════════════════════════════════════════════════
class _SelectorPeriodo extends StatelessWidget {
  final int periodoIdx;
  final List<_Periodo> periodos;
  final ValueChanged<int> onSelect;
  const _SelectorPeriodo({required this.periodoIdx, required this.periodos, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: List.generate(periodos.length, (i) {
          final sel = i == periodoIdx;
          final per = periodos[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(per.label, textAlign: TextAlign.center,
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
                            : const Color(0xFFE6A817).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(per.badge!, style: GoogleFonts.poppins(
                        fontSize: 7.5, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFFB07010),
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Banner plan activo
// ═══════════════════════════════════════════════════════════════════════════════
class _PlanActivoBanner extends StatelessWidget {
  final NivelPlan plan;
  final int? diasLeft;
  final VoidCallback onCancelar;
  const _PlanActivoBanner({required this.plan, required this.diasLeft, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final esPro    = plan == NivelPlan.pro;
    final colorTop = esPro ? const Color(0xFFE6A817) : const Color(0xFF4A90D9);
    final colorBg  = colorTop.withOpacity(0.08);
    final planName = esPro ? 'Pro' : 'Básico';
    final icono    = esPro ? Icons.workspace_premium_rounded : Icons.store_outlined;

    String diasTexto;
    Color  diasColor;
    if (diasLeft == null) {
      diasTexto = 'Activo';
      diasColor = AppColors.success;
    } else if (diasLeft! <= 0) {
      diasTexto = 'Vencido';
      diasColor = AppColors.danger;
    } else if (diasLeft! <= 5) {
      diasTexto = '⚠️ Vence en $diasLeft días';
      diasColor = const Color(0xFFE17055);
    } else {
      diasTexto = '$diasLeft días restantes';
      diasColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorTop.withOpacity(0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorTop.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icono, color: colorTop, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Plan $planName Activo',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14, color: colorTop)),
            Text(diasTexto,
                style: GoogleFonts.poppins(fontSize: 12, color: diasColor,
                    fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorTop.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('ACTIVO', style: GoogleFonts.poppins(
                color: colorTop, fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: onCancelar,
            icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 16),
            label: Text('Cancelar suscripción',
                style: GoogleFonts.poppins(
                    color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Upgrade a Pro (solo para usuarios con plan Básico)
// ═══════════════════════════════════════════════════════════════════════════════
class _UpgradeProCard extends StatefulWidget {
  final int periodoIdx;
  final List<_Periodo> periodos;
  final String Function(String, String) precio;
  final bool cargando;
  final void Function(String) onActivar;
  final bool mostrarSelector;

  const _UpgradeProCard({
    required this.periodoIdx, required this.periodos, required this.precio,
    required this.cargando, required this.onActivar,
    this.mostrarSelector = false,
  });

  @override
  State<_UpgradeProCard> createState() => _UpgradeProCardState();
}

class _UpgradeProCardState extends State<_UpgradeProCard> {
  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.periodoIdx;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.periodos[_idx];
    return Column(children: [
      // ── Banner upgrade ─────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFEFB0), Color(0xFFFFF8E1)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6A817).withOpacity(0.6), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6A817).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFB07010), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Actualiza a Pro', style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 15,
                color: const Color(0xFFB07010))),
            Text('Desbloquea todas las funciones premium',
                style: GoogleFonts.poppins(fontSize: 12,
                    color: const Color(0xFFB07010).withOpacity(0.75))),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Color(0xFFB07010), size: 16),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Selector de período (solo para Básico activo) ─────────
      if (widget.mostrarSelector) ...[
        _SelectorPeriodo(
          periodoIdx: _idx,
          periodos: widget.periodos,
          onSelect: (i) => setState(() => _idx = i),
        ),
        const SizedBox(height: 12),
      ],

      // ── Card Pro ───────────────────────────────────────────────
      _PlanCard(
        nombre: 'Pro',
        icono: Icons.workspace_premium_rounded,
        precio: widget.precio(p.idPro, p.precioProfallback),
        porMes: p.porMesPro,
        ahorro: p.ahorroPro,
        colorTop: const Color(0xFFE6A817),
        colorBottom: const Color(0xFFC47F0A),
        badge: 'POPULAR',
        features: const [
          ('✅', 'Todo Básico'), ('🏷️', 'Apartados'),
          ('🧾', 'Cuadre Caja'), ('🏪', 'Vitrina QR'),
          ('🍽️', 'Carta Digital'), ('📝', 'Encargos'),
          ('🖨️', 'Térmica'), ('💬', 'WhatsApp'), ('⭐', 'Soporte VIP'),
        ],
        cargando: widget.cargando,
        esActual: false,
        onActivar: () => widget.onActivar(p.idPro),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Trial Banner
// ═══════════════════════════════════════════════════════════════════════════════
class _TrialBanner extends StatelessWidget {
  final int dias;
  const _TrialBanner({required this.dias});
  @override
  Widget build(BuildContext context) {
    final urgente = dias <= 5;
    final color   = urgente ? const Color(0xFFE17055) : const Color(0xFF00B894);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
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
            dias <= 0 ? '¡Tu período de prueba ha vencido!'
                : dias == 1 ? '¡Te queda 1 día de prueba gratis!'
                : '🎉 Prueba gratuita activa — $dias días restantes',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            dias <= 0 ? 'Activa un plan para seguir usando NegocioPro.'
                : 'Estás usando el Plan Pro completo gratis.',
            style: GoogleFonts.poppins(fontSize: 11.5, color: color.withOpacity(0.8)),
          ),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: Header
// ═══════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1F36), Color(0xFF2D3561)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
        child: const Icon(Icons.store_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NegocioPro', style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        Text('Elige el plan que más te convenga',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
      ])),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: PlanCard
// ═══════════════════════════════════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final String nombre, precio, porMes;
  final String? ahorro, badge;
  final IconData icono;
  final Color colorTop, colorBottom;
  final List<(String, String)> features;
  final VoidCallback onActivar;
  final bool cargando, esActual;

  const _PlanCard({
    required this.nombre, required this.icono, required this.precio,
    required this.porMes, required this.colorTop, required this.colorBottom,
    required this.features, required this.onActivar,
    this.ahorro, this.badge, this.cargando = false, this.esActual = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: badge != null
            ? Border.all(color: colorTop.withOpacity(0.6), width: 2)
            : Border.all(color: AppColors.cardBorder),
        boxShadow: badge != null ? [BoxShadow(
            color: colorTop.withOpacity(0.18), blurRadius: 20,
            offset: const Offset(0, 6))] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(gradient: LinearGradient(
                colors: [colorTop, colorBottom],
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icono, color: Colors.white, size: 18),
                const SizedBox(width: 5),
                Flexible(child: Text(nombre, style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                if (badge != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!, style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 7.5,
                        fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              Text(precio, style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 21,
                  fontWeight: FontWeight.w800, height: 1)),
              Text(porMes, style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 9.5)),
              if (ahorro != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ahorro!, style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
          ),
          // Features + botón
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(children: [
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Text(f.$1, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(f.$2, style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500))),
                  Icon(Icons.check_circle_rounded, color: colorTop, size: 14),
                ]),
              )),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity, height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colorTop, colorBottom],
                        begin: Alignment.centerLeft, end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: colorBottom.withOpacity(0.45),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: cargando ? null : onActivar,
                    child: FittedBox(fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text('Suscribirse', style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ])),
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

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS: Garantía y Soporte
// ═══════════════════════════════════════════════════════════════════════════════
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
        Text('Cancela cuando quieras directamente desde Google Play.',
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
            color: const Color(0xFF25D366).withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 24),
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
