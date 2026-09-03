import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/venta_model.dart';
import '../../utils/formatters.dart';

class DetalleVentaScreen extends StatelessWidget {
  final VentaModel venta;
  const DetalleVentaScreen({super.key, required this.venta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(venta.numeroFormateado),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {}, // TODO: compartir recibo
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Estado de la venta
          _buildHeader(),
          const SizedBox(height: 16),
          // Productos
          _buildProductos(),
          const SizedBox(height: 16),
          // Totales
          _buildTotales(),
          const SizedBox(height: 16),
          // Info de pago
          _buildInfoPago(),
          if (venta.anulada) ...[
            const SizedBox(height: 16),
            _buildAnuladaBanner(),
          ],
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: venta.anulada
                ? AppColors.dangerSurface
                : AppColors.successSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            venta.anulada
                ? Icons.cancel_rounded
                : Icons.check_circle_rounded,
            color: venta.anulada ? AppColors.danger : AppColors.success,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        Text(venta.numeroFormateado,
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 22, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(AppFormatters.fechaHora(venta.createdAt),
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: AppColors.textMuted)),
        if (venta.clienteNombre != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(venta.clienteNombre!,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildProductos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Productos', style: TextStyle(fontFamily: 'Poppins',
            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...venta.detalles.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.nombreProducto, style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13,
                  fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              Text('${d.cantidad.toInt()} x ${AppFormatters.moneda(d.precioUnitario)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 11, color: AppColors.textMuted)),
            ])),
            Text(AppFormatters.moneda(d.subtotal),
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildTotales() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        _FilaTotales('Subtotal', AppFormatters.moneda(venta.subtotal)),
        if (venta.descuento > 0)
          _FilaTotales('Descuento', '-${AppFormatters.moneda(venta.descuento)}',
              color: AppColors.danger),
        if (venta.itbis > 0)
          _FilaTotales('ITBIS (18%)', AppFormatters.moneda(venta.itbis)),
        const Divider(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(AppFormatters.moneda(venta.total),
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      ]),
    );
  }

  Widget _buildInfoPago() {
    final tiposLabel = {
      'efectivo': 'Efectivo',
      'tarjeta': 'Tarjeta',
      'transferencia': 'Transferencia',
      'fiado': 'Fiado',
      'mixto': 'Mixto',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        _FilaTotales('Método de pago',
            tiposLabel[venta.tipoPago] ?? venta.tipoPago),
        if (venta.montoPagado > 0)
          _FilaTotales('Monto recibido', AppFormatters.moneda(venta.montoPagado)),
        if (venta.cambio > 0)
          _FilaTotales('Cambio', AppFormatters.moneda(venta.cambio),
              color: AppColors.success),
      ]),
    );
  }

  Widget _buildAnuladaBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: const Row(children: [
        Icon(Icons.warning_rounded, color: AppColors.danger),
        SizedBox(width: 10),
        Text('Esta venta fue anulada',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                fontWeight: FontWeight.w600, color: AppColors.danger)),
      ]),
    );
  }
}

class _FilaTotales extends StatelessWidget {
  final String label; final String valor; final Color? color;
  const _FilaTotales(this.label, this.valor, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 13, color: AppColors.textSecondary)),
      Text(valor, style: TextStyle(fontFamily: 'Poppins',
          fontSize: 13, fontWeight: FontWeight.w600,
          color: color ?? AppColors.textPrimary)),
    ]),
  );
}