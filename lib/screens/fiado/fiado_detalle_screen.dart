import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/fiado_model.dart';
import '../../utils/formatters.dart';
import '../../services/fiado_service.dart';
class FiadoDetalleScreen extends StatefulWidget {
  final FiadoModel fiado;
  const FiadoDetalleScreen({super.key, required this.fiado});

  @override
  State<FiadoDetalleScreen> createState() => _FiadoDetalleScreenState();
}

class _FiadoDetalleScreenState extends State<FiadoDetalleScreen> {
  @override
  Widget build(BuildContext context) {
    final f = widget.fiado;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(f.clienteNombre ?? 'Fiado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Resumen del fiado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: f.estaVencido ? AppColors.dangerSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: f.estaVencido
                  ? AppColors.danger.withValues(alpha: 0.3) : AppColors.cardBorder),
            ),
            child: Column(children: [
              Text(f.clienteNombre ?? '',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              if (f.clienteTelefono != null)
                Text(f.clienteTelefono!, style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Text(AppFormatters.moneda(f.saldoPendiente),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 32,
                      fontWeight: FontWeight.w700, color: AppColors.colorFiado)),
              const Text('Saldo pendiente', style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: f.porcentajePagado,
                  backgroundColor: AppColors.cardBorder,
                  color: AppColors.colorFiado,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Pagado: ${AppFormatters.moneda(f.montoPagado)}',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 12, color: AppColors.textMuted)),
                Text('Original: ${AppFormatters.moneda(f.montoOriginal)}',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 12, color: AppColors.textMuted)),
              ]),
              if (f.fechaLimite != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: f.estaVencido ? AppColors.dangerSurface : AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    f.estaVencido
                        ? 'Vencido el ${AppFormatters.fecha(f.fechaLimite)}'
                        : 'Vence el ${AppFormatters.fecha(f.fechaLimite)}',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: f.estaVencido ? AppColors.danger : AppColors.warning),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          // Botones de acción
          if (!f.estaPagado)
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarModalAbono(context),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Registrar abono',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _compartirWhatsApp(context),
                child: const Icon(Icons.chat_rounded, color: AppColors.success),
              ),
            ]),
          const SizedBox(height: 16),
          // Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Detalles', style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _fila('Fecha inicio', AppFormatters.fecha(f.createdAt)),
              _fila('Monto original', AppFormatters.moneda(f.montoOriginal)),
              _fila('Total pagado', AppFormatters.moneda(f.montoPagado)),
              _fila('Saldo pendiente', AppFormatters.moneda(f.saldoPendiente)),
              if (f.notas != null) _fila('Notas', f.notas!),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _fila(String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted))),
      Expanded(child: Text(valor, style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500,
          color: AppColors.textPrimary))),
    ]),
  );

  void _mostrarModalAbono(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24, left: 24, right: 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Registrar abono', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Pendiente: ${AppFormatters.moneda(widget.fiado.saldoPendiente)}',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            autofocus: true,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Monto del abono',
              prefixText: 'RD\$ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
            onPressed: () async {
                Navigator.pop(ctx);
                await FiadoService.registrarAbono(
                  widget.fiado.id,
                  widget.fiado.clienteId,
                  double.tryParse(ctrl.text) ?? 0,
                  'efectivo',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Abono registrado'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Confirmar abono', style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  void _compartirWhatsApp(BuildContext context) {
    // TODO: url_launcher para WhatsApp
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo WhatsApp...')),
    );
  }
}