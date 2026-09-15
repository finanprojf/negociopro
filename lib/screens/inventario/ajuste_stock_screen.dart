import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../utils/formatters.dart';
import '../../services/inventario_service.dart';
import '../../services/gasto_service.dart';
import '../../models/gasto_model.dart';

class AjusteStockScreen extends StatefulWidget {
  final ProductoModel producto;
  const AjusteStockScreen({super.key, required this.producto});

  @override
  State<AjusteStockScreen> createState() => _AjusteStockScreenState();
}

class _AjusteStockScreenState extends State<AjusteStockScreen> {
  final _cantidadCtrl = TextEditingController();
  String _tipo = 'entrada';
  bool _loading = false;

  double get _cantidad => double.tryParse(_cantidadCtrl.text) ?? 0;
  double get _nuevoStock {
    if (_tipo == 'entrada') return widget.producto.stockActual + _cantidad;
    if (_tipo == 'salida') return (widget.producto.stockActual - _cantidad).clamp(0, double.infinity);
    return _cantidad;
  }

  Future<void> _guardar() async {
    if (_cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa una cantidad válida'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _loading = true);
    final ok = await InventarioService.actualizarStock(
        widget.producto.id, _nuevoStock, tipo: _tipo);
    if (mounted) {
      if (ok) {
        // Ofrecer registrar gasto ANTES de cerrar la pantalla
        if (_tipo == 'entrada' && widget.producto.precioCompra > 0) {
          await _ofrecerRegistrarGasto();
        }
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stock actualizado correctamente'),
          backgroundColor: AppColors.success,
        ));
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar el stock'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<void> _ofrecerRegistrarGasto() async {
    if (!mounted) return;
    final monto = _cantidad * widget.producto.precioCompra;
    final descripcion = 'Compra de ${widget.producto.nombre}';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.colorInventario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: AppColors.colorInventario, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('¿Registrar compra?',
              style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Se agregó inventario nuevo. ¿Deseas registrar el costo como gasto de mercancía?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.colorInventario.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🛍️ $descripcion',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_cantidad.toStringAsFixed(0)} ${widget.producto.unidad}s × ${AppFormatters.moneda(widget.producto.precioCompra)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(AppFormatters.moneda(monto),
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.colorInventario)),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No registrar',
                style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.colorInventario,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Sí, registrar',
                style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await GastoService.guardarGasto(GastoModel(
        id: '', empresaId: '', categoria: 'mercancia',
        descripcion: descripcion,
        monto: monto,
        fecha: DateTime.now(),
      ));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Gasto de mercancía registrado'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajuste de stock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Info del producto
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.colorInventario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppColors.colorInventario, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.producto.nombre,
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Stock actual: ${AppFormatters.stock(widget.producto.stockActual, widget.producto.unidad)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          // Tipo de ajuste
          _seccion('Tipo de ajuste'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _TipoBtn(
              'Entrada', Icons.add_circle_outline_rounded,
              AppColors.success, _tipo == 'entrada',
              () => setState(() => _tipo = 'entrada'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TipoBtn(
              'Salida', Icons.remove_circle_outline_rounded,
              AppColors.danger, _tipo == 'salida',
              () => setState(() => _tipo = 'salida'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TipoBtn(
              'Ajuste', Icons.tune_rounded,
              AppColors.colorInventario, _tipo == 'ajuste',
              () => setState(() => _tipo = 'ajuste'),
            )),
          ]),
          const SizedBox(height: 20),

          // Cantidad
          _seccion(_tipo == 'ajuste' ? 'Nuevo stock total' : 'Cantidad'),
          const SizedBox(height: 12),
          TextField(
            controller: _cantidadCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 28, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: _tipo == 'ajuste'
                  ? 'Nuevo stock total'
                  : 'Cantidad a ${_tipo == "entrada" ? "agregar" : "restar"}',
              suffixText: widget.producto.unidad,
            ),
          ),
          const SizedBox(height: 16),

          // Preview
          if (_cantidad > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Stock resultante',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 13, color: AppColors.primary)),
                  Text(
                    AppFormatters.stock(_nuevoStock, widget.producto.unidad),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _guardar,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Guardar ajuste',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _seccion(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t.toUpperCase(),
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 1)),
  );
}

class _TipoBtn extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final bool selected;
  final VoidCallback onTap;
  const _TipoBtn(this.label, this.icon, this.color, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.1) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? color : AppColors.cardBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        Icon(icon, color: selected ? color : AppColors.textMuted, size: 22),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : AppColors.textSecondary)),
      ]),
    ),
  );
}