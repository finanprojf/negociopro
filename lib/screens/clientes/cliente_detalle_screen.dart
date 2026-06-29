import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import 'cliente_form_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
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
                await SupabaseService.client
                    .from('clientes')
                    .update({'activo': false})
                    .eq('id', cliente.id);
                Navigator.pop(context, true);
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
              Expanded(child: _AccionBtn(Icons.point_of_sale_rounded,
                  'Nueva venta', AppColors.colorVentas, () {})),
              const SizedBox(width: 10),
              Expanded(child: _AccionBtn(Icons.handshake_outlined,
                  'Nuevo fiado', AppColors.colorFiado, () {})),
              const SizedBox(width: 10),
              Expanded(child: _AccionBtn(Icons.bookmark_outlined,
                  'Apartado', AppColors.colorApartados, () {})),
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