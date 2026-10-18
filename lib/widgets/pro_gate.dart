import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/plan_service.dart';
import '../screens/suscripcion/suscripcion_screen.dart';
import '../theme/app_colors.dart';

/// Envuelve cualquier pantalla o sección.
/// Si el usuario tiene Plan Pro → muestra [child] normal.
/// Si tiene Plan Básico       → muestra pantalla de upgrade elegante.
class ProGate extends StatelessWidget {
  final Widget child;
  final String? nombreFuncion; // ej: 'Vitrina Digital'

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // ── Ícono premium ──────────────────────────────────────
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.35),
                      blurRadius: 28, spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 52),
              ),
              const SizedBox(height: 28),

              // ── Título ─────────────────────────────────────────────
              Text(
                funcion != null
                    ? '$funcion es exclusivo\ndel Plan Pro'
                    : 'Función exclusiva\ndel Plan Pro',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // ── Subtítulo ──────────────────────────────────────────
              Text(
                'Lleva tu negocio al siguiente nivel.\nTodo lo que necesitas para crecer, en un solo lugar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.5, color: AppColors.textSecondary, height: 1.55,
                ),
              ),
              const SizedBox(height: 32),

              // ── Lista de beneficios Pro ────────────────────────────
              _BeneficiosCard(),
              const SizedBox(height: 32),

              // ── Botón CTA ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.4),
                        blurRadius: 16, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SuscripcionScreen())),
                    icon: const Icon(Icons.rocket_launch_rounded,
                        color: Colors.white, size: 20),
                    label: Text('Ver Plan Pro',
                        style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Volver ─────────────────────────────────────────────
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Volver al inicio',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 13,
                    )),
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
      ('🏷️', 'Apartados', 'Reservas con pagos parciales'),
      ('🧾', 'Cuadre de Caja', 'Cierre del día con resumen completo'),
      ('🏪', 'Vitrina Digital', 'Catálogo en línea con código QR'),
      ('📝', 'Encargos', 'Pedidos especiales de tus clientes'),
      ('🖨️', 'Impresora Térmica', 'Imprime recibos al instante'),
      ('💬', 'Recibos WhatsApp', 'Comparte comprobantes al momento'),
      ('⭐', 'Soporte Prioritario', 'Atención directa por WhatsApp'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Con el Plan Pro desbloqueas:',
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 12),
          ...beneficios.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Text(b.$1, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.$2, style: GoogleFonts.poppins(
                    fontSize: 13.5, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
                  Text(b.$3, style: GoogleFonts.poppins(
                    fontSize: 11.5, color: AppColors.textSecondary,
                  )),
                ],
              )),
              const Icon(Icons.lock_rounded, size: 16, color: Color(0xFFFFD700)),
            ]),
          )),
        ],
      ),
    );
  }
}
