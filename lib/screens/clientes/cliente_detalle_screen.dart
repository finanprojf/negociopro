import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import 'cliente_form_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import '../fiado/fiado_cliente_screen.dart';
import '../apartados/apartados_cliente_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class ClienteDetalleScreen extends StatelessWidget {
  final ClienteModel cliente;
  const ClienteDetalleScreen({super.key, required this.cliente});

  void _copiar(BuildContext context, String valor) {
    Clipboard.setData(ClipboardData(text: valor));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copiado: $valor'),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _contactar(BuildContext context) async {
    if (cliente.telefono == null || cliente.telefono!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Este cliente no tiene teléfono registrado'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final telefono = cliente.telefono!.replaceAll(RegExp(r'[^0-9]'), '');
    final telInt = telefono.startsWith('1') ? telefono : '1$telefono';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2))),
          Text('Contactar a ${cliente.nombre}',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(cliente.telefono!,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFF25D366).withValues(alpha: 0.08),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF25D366),
              child: Icon(Icons.chat_rounded, color: Colors.white, size: 20),
            ),
            title: Text('Abrir en WhatsApp',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await launchUrl(Uri.parse('whatsapp://send?phone=$telInt'),
                    mode: LaunchMode.externalApplication);
              } catch (_) {
                try {
                  await launchUrl(Uri.parse('https://wa.me/$telInt'),
                      mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppColors.colorVentas.withValues(alpha: 0.08),
            leading: CircleAvatar(
              backgroundColor: AppColors.colorVentas,
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
            ),
            title: Text('Llamar directo',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await launchUrl(Uri.parse('tel:${cliente.telefono}'),
                    mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle de cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: cliente))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('Eliminar cliente',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  content: Text('¿Seguro que quieres eliminar a ${cliente.nombre}?',
                      style: GoogleFonts.poppins()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar',
                            style: TextStyle(color: AppColors.danger,
                                fontWeight: FontWeight.w700))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await LocalDatabase.actualizar('clientes',
                    {'activo': 0, 'synced': 0,
                      'updated_at': DateTime.now().toIso8601String()},
                    'id', cliente.id);
                if (await SupabaseService.isOnlineAsync) {
                  await SupabaseService.client.from('clientes')
                      .update({'activo': false}).eq('id', cliente.id);
                  await LocalDatabase.marcarSynced('clientes', cliente.id);
                }
                if (context.mounted) Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ── Header card ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(children: [
              // Foto o iniciales
              CircleAvatar(
                radius: 46,
                backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
                backgroundImage: cliente.fotoUrl != null
                    ? NetworkImage(cliente.fotoUrl!) : null,
                child: cliente.fotoUrl == null
                    ? Text(cliente.iniciales, style: GoogleFonts.poppins(
                        fontSize: 30, fontWeight: FontWeight.w700,
                        color: AppColors.colorClientes))
                    : null,
              ),
              const SizedBox(height: 14),
              Text(cliente.nombre, style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              // Teléfono + ícono WhatsApp
              if (cliente.telefono != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _contactar(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cliente.telefono!, style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_rounded,
                          color: Color(0xFF25D366), size: 16),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (cliente.tieneDeuda)
                  _Badge('Deuda: ${AppFormatters.moneda(cliente.saldoFiado!)}',
                      AppColors.danger, AppColors.dangerSurface),
                if (cliente.tienePuntos) ...[
                  const SizedBox(width: 8),
                  _Badge('${cliente.puntosFidelidad} puntos',
                      AppColors.colorFidelizacion,
                      AppColors.colorFidelizacion.withValues(alpha: 0.1)),
                ],
              ]),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Acciones rápidas ─────────────────────────────────────
          Row(children: [
            Expanded(child: _AccionBtn(Icons.phone_rounded,
                'Contactar', AppColors.colorVentas, () => _contactar(context))),
            const SizedBox(width: 10),
            Expanded(child: _AccionBtn(Icons.handshake_outlined,
                'Fiado', AppColors.colorFiado, () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => FiadoClienteScreen(cliente: cliente))))),
            const SizedBox(width: 10),
            Expanded(child: _AccionBtn(Icons.bookmark_outlined,
                'Apartados', AppColors.colorApartados, () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ApartadosClienteScreen(cliente: cliente))))),
          ]),

          const SizedBox(height: 12),

          // ── Información ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.colorClientes.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.colorClientes, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Información', style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 14),
              if (cliente.cedula != null)
                _InfoFila('Cédula', cliente.cedula!, Icons.badge_outlined,
                    onCopiar: () => _copiar(context, cliente.cedula!)),
              if (cliente.correo != null)
                _InfoFila('Correo', cliente.correo!, Icons.email_outlined,
                    onCopiar: () => _copiar(context, cliente.correo!)),
              if (cliente.direccion != null)
                _InfoFila('Dirección', cliente.direccion!, Icons.location_on_outlined,
                    onCopiar: () => _copiar(context, cliente.direccion!)),
              _InfoFila('Cliente desde',
                  AppFormatters.fecha(cliente.createdAt), Icons.calendar_today_outlined),
              if (cliente.telefono != null)
                _InfoFila('Teléfono', cliente.telefono!, Icons.phone_outlined,
                    onCopiar: () => _copiar(context, cliente.telefono!)),
            ]),
          ),

          // ── Notas ────────────────────────────────────────────────
          if (cliente.notas != null && cliente.notas!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sticky_note_2_outlined,
                        color: AppColors.warning, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Notas', style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(cliente.notas!, style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text; final Color color; final Color bg;
  const _Badge(this.text, this.color, this.bg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
        fontWeight: FontWeight.w600, color: color)),
  );
}

class _AccionBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _AccionBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
            fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}

class _InfoFila extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final VoidCallback? onCopiar;
  const _InfoFila(this.label, this.valor, this.icon, {this.onCopiar});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, size: 15, color: AppColors.textMuted),
      const SizedBox(width: 10),
      SizedBox(width: 80, child: Text(label, style: GoogleFonts.poppins(
          fontSize: 12, color: AppColors.textMuted))),
      Expanded(child: Text(valor, style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textPrimary,
          fontWeight: FontWeight.w500))),
      if (onCopiar != null)
        GestureDetector(
          onTap: onCopiar,
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
          ),
        ),
    ]),
  );
}
