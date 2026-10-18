import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/plan_service.dart';
import '../screens/suscripcion/suscripcion_screen.dart';
import '../theme/app_colors.dart';

class ProGate extends StatelessWidget {
  final Widget child;
  final String? nombreFuncion;
  const ProGate({super.key, required this.child, this.nombreFuncion});

  @override
  Widget build(BuildContext context) {
    if (PlanService.esPro) return child;
    return _UpgradeScreen(funcion: nombreFuncion);
  }
}

class _UpgradeScreen extends StatelessWidget {
  final String? funcion;
  const _UpgradeScreen({this.funcion});

  static const _descripciones = {
    'Vitrina Digital':
        'Comparte tu catálogo con un enlace o QR. Tus clientes ven precios y fotos desde su celular — sin descargar nada.',
    'Carta Digital':
        'Convierte tu menú en una experiencia digital. Tus clientes escanean el QR de la mesa, agregan lo que quieren al carrito y envían el pedido directo a cocina — tú ves todo en orden, sin gritos ni papeles.',
    'Apartados':
        'Tus clientes reservan con un pago inicial y retiran después. Tú controlas lo que deben en todo momento.',
    'Encargos':
        'Registra pedidos especiales con fecha y monto. Sin papel, sin olvidos — todo organizado y a la mano.',
    'Impresora Térmica':
        'Imprime recibos físicos al instante con tu impresora Bluetooth. Proyecta confianza y profesionalismo.',
    'Recibos WhatsApp':
        'Envía comprobantes directamente al WhatsApp de tus clientes con un toque. Rápido y sin costo extra.',
  };

  @override
  Widget build(BuildContext context) {
    final desc = funcion != null && _descripciones.containsKey(funcion)
        ? _descripciones[funcion]!
        : 'Todo lo que necesitas para llevar tu negocio al siguiente nivel.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.textPrimary,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Ícono ──────────────────────────────────────────────
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.35), blurRadius: 20, spreadRadius: 2)],
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 14),

              // ── Título ─────────────────────────────────────────────
              Text(
                funcion != null ? '$funcion es exclusivo\ndel Plan Pro' : 'Función exclusiva\ndel Plan Pro',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25),
              ),
              const SizedBox(height: 8),

              // ── Descripción ────────────────────────────────────────
              Text(
                desc,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),

              // ── Lista compacta ─────────────────────────────────────
              Expanded(child: _BeneficiosCard()),
              const SizedBox(height: 14),

              // ── Botón CTA ──────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuscripcionScreen())),
                    icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                    label: Text('Ver Plan Pro', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeneficiosCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const beneficios = [
      ('🏷️', 'Apartados',          'Reservas con pagos parciales'),
      ('🍽️', 'Carta Digital',       'Menú interactivo con pedidos a cocina'),
      ('🏪', 'Vitrina Digital',     'Catálogo en línea con código QR'),
      ('📝', 'Encargos',            'Pedidos especiales de tus clientes'),
      ('🖨️', 'Impresora Térmica',  'Imprime recibos al instante'),
      ('💬', 'Recibos WhatsApp',    'Comparte comprobantes al momento'),
      ('⭐', 'Soporte Prioritario', 'Atención directa por WhatsApp'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Con el Plan Pro desbloqueas:',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: beneficios.map((b) => Row(children: [
                Text(b.$1, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.$2, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(b.$3, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                )),
                const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFFFD700)),
              ])).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
