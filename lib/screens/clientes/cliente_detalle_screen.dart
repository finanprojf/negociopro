import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import 'cliente_form_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import '../fiado/fiado_cliente_screen.dart';
import '../apartados/apartados_cliente_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ClienteDetalleScreen extends StatelessWidget {
  final ClienteModel cliente;
  const ClienteDetalleScreen({super.key, required this.cliente});

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
                  title: const Text('Eliminar cliente',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                  content: Text('¿Seguro que quieres eliminar a ${cliente.nombre}?',
                      style: const TextStyle(fontFamily: 'Poppins')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar',
                            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                // Desactivar local primero (funciona offline)
                await LocalDatabase.actualizar(
                  'clientes',
                  {'activo': 0, 'synced': 0, 'updated_at': DateTime.now().toIso8601String()},
                  'id', cliente.id,
                );
                // Sincronizar si hay internet
                if (await SupabaseService.isOnlineAsync) {
                  await SupabaseService.client
                      .from('clientes')
                      .update({'activo': false})
                      .eq('id', cliente.id);
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
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
                  child: Text(cliente.iniciales, style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 28,
                      fontWeight: FontWeight.w700, color: AppColors.colorClientes)),
                ),
                const SizedBox(height: 14),
                Text(cliente.nombre, style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (cliente.telefono != null) ...[
                  const SizedBox(height: 4),
                  Text(cliente.telefono!, style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 14, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (cliente.tieneDeuda)
                    _InfoBadge('Deuda: ${AppFormatters.moneda(cliente.saldoFiado!)}',
                        AppColors.danger, AppColors.dangerSurface),
                  if (cliente.tienePuntos) ...[
                    const SizedBox(width: 8),
                    _InfoBadge('${cliente.puntosFidelidad} puntos',
                        AppColors.colorFidelizacion,
                        AppColors.colorFidelizacion.withValues(alpha: 0.1)),
                  ],
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // Acciones rápidas
            Row(children: [
            Expanded(child: _AccionBtn(Icons.phone_rounded,
                  'Contactar', AppColors.colorVentas, () async {
                    if (cliente.telefono == null || cliente.telefono!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Este cliente no tiene teléfono registrado'),
                        backgroundColor: Colors.orange,
                      ));
                      return;
                    }
                    final telefono = cliente.telefono!.replaceAll(RegExp(r'[^0-9]'), '');
                    // Formato internacional RD: +1 + número
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
                              style: const TextStyle(fontFamily: 'Poppins',
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(cliente.telefono!,
                              style: const TextStyle(fontFamily: 'Poppins',
                                  fontSize: 13, color: AppColors.textMuted)),
                          const SizedBox(height: 16),
                          ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            tileColor: const Color(0xFF25D366).withValues(alpha: 0.08),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF25D366),
                              child: Icon(Icons.chat_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            title: const Text('Abrir en WhatsApp',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600)),
                            subtitle: const Text('Lleva al chat — tú decides si llamar o escribir',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                            onTap: () async {
                              Navigator.pop(context);
                              try {
                                // Intentar abrir WhatsApp directo
                                final uriApp = Uri.parse('whatsapp://send?phone=$telInt');
                                await launchUrl(uriApp, mode: LaunchMode.externalApplication);
                              } catch (_) {
                                try {
                                  // Fallback: wa.me en navegador
                                  final uriWeb = Uri.parse('https://wa.me/$telInt');
                                  await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            tileColor: AppColors.colorVentas.withValues(alpha: 0.08),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.colorVentas,
                              child: const Icon(Icons.call_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            title: const Text('Llamar directo',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600)),
                            subtitle: const Text('Abre el marcador del teléfono',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                            onTap: () async {
                              Navigator.pop(context);
                              try {
                                final uri = Uri.parse('tel:${cliente.telefono}');
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (_) {}
                            },
                          ),
                        ]),
                      ),
                    );
                  })),
              const SizedBox(width: 10),
            Expanded(child: _AccionBtn(Icons.handshake_outlined,
                  'Fiado', AppColors.colorFiado, () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => FiadoClienteScreen(
                            cliente: cliente)));
                  })),
              const SizedBox(width: 10),
            Expanded(child: _AccionBtn(Icons.bookmark_outlined,
                  'Apartados', AppColors.colorApartados, () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ApartadosClienteScreen(
                            cliente: cliente)));
                  })),
            ]),
            const SizedBox(height: 16),
            // Info adicional
            _InfoCard('Información', [
              if (cliente.cedula != null) _InfoRow('Cédula', cliente.cedula!),
              if (cliente.correo != null) _InfoRow('Correo', cliente.correo!),
              if (cliente.direccion != null) _InfoRow('Dirección', cliente.direccion!),
              _InfoRow('Cliente desde', AppFormatters.fecha(cliente.createdAt)),
            ]),
            if (cliente.notas != null && cliente.notas!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoCard('Notas', [_InfoRow('', cliente.notas!)]),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text; final Color color; final Color bg;
  const _InfoBadge(this.text, this.color, this.bg);
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
            fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String titulo; final List<Widget> filas;
  const _InfoCard(this.titulo, this.filas);
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
          fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      ...filas,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label; final String valor;
  const _InfoRow(this.label, this.valor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty) ...[
        SizedBox(width: 90, child: Text(label, style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted))),
      ],
      Expanded(child: Text(valor, style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 13, color: AppColors.textPrimary))),
    ]),
  );
}