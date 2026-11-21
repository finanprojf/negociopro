import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_palette.dart';
import '../../services/supabase_service.dart';
import '../fiado/nuevo_fiado_screen.dart';
import '../ventas/pos_screen.dart';
import 'catalogo_rapido_screen.dart';

/// Pantalla que aparece UNA vez: "¿Qué quieres hacer primero?"
/// Objetivo: que el usuario vea el valor de la app en menos de 1 minuto.
class PrimerPasoScreen extends StatelessWidget {
  const PrimerPasoScreen({super.key});

  // Se guarda POR NEGOCIO: si en el mismo teléfono se entra con otra cuenta nueva,
  // también le aparece.
  static Future<String> _key() async {
    final eid = await SupabaseService.getEmpresaId();
    return 'primer_paso_visto_${eid ?? ''}';
  }

  /// ¿Hay que mostrarla? (solo si este negocio nunca la vio)
  static Future<bool> debeMostrarse() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(await _key()) ?? false);
  }

  static Future<void> marcarVista() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(await _key(), true);
  }

  Future<void> _ir(BuildContext context, Widget destino) async {
    await marcarVista();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destino));
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Scaffold(
      backgroundColor: pal.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('👋 ¡Bienvenido!',
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: pal.textPrimary)),
            const SizedBox(height: 6),
            Text('¿Qué quieres hacer primero?',
                style: GoogleFonts.poppins(fontSize: 16, color: pal.textSecondary)),
            const SizedBox(height: 28),

            _Opcion(
              emoji: '📒',
              titulo: 'Anotar un fiado',
              subtitulo: 'Tu libreta de fiado en el celular. Sin cargar productos.',
              color: pal.colorFiado,
              recomendado: true,
              onTap: () => _ir(context, const NuevoFiadoScreen()),
            ),
            const SizedBox(height: 14),
            _Opcion(
              emoji: '📦',
              titulo: 'Cargar mis productos rápido',
              subtitulo: 'Marca los que vendes de una lista de productos de colmado.',
              color: pal.colorInventario,
              onTap: () => _ir(context, const CatalogoRapidoScreen()),
            ),
            const SizedBox(height: 14),
            _Opcion(
              emoji: '🛒',
              titulo: 'Hacer una venta',
              subtitulo: 'Si ya tienes productos cargados.',
              color: pal.colorVentas,
              onTap: () => _ir(context, const PosScreen()),
            ),

            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () async {
                  await marcarVista();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text('Explorar la app por mi cuenta',
                    style: GoogleFonts.poppins(fontSize: 13, color: pal.textMuted)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final String emoji, titulo, subtitulo;
  final Color color;
  final bool recomendado;
  final VoidCallback onTap;
  const _Opcion({required this.emoji, required this.titulo, required this.subtitulo,
      required this.color, required this.onTap, this.recomendado = false});

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Material(
      color: pal.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: recomendado ? color.withValues(alpha: 0.5) : pal.cardBorder,
                width: recomendado ? 1.5 : 1),
          ),
          child: Row(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(titulo,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: pal.textPrimary))),
                if (recomendado) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: Text('Empieza aquí',
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(subtitulo, style: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted, height: 1.35)),
            ])),
            Icon(Icons.chevron_right_rounded, color: pal.textMuted),
          ]),
        ),
      ),
    );
  }
}
