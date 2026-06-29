import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../utils/formatters.dart';
import '../../services/inventario_service.dart';
import '../../services/supabase_service.dart';
import '../../services/gasto_service.dart';
import '../../models/gasto_model.dart';
class ProductoFormScreen extends StatefulWidget {
  final ProductoModel? producto;
  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _precioCompraCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();
  final _stockActualCtrl = TextEditingController();
  final _stockMinimoCtrl = TextEditingController();
  String _unidad = 'unidad';
  bool _loading = false;
  bool get _esEdicion => widget.producto != null;

  final List<String> _unidades = [
    'unidad', 'paquete', 'caja', 'botella', 'lata',
    'kg', 'libra', 'litro', 'docena', 'par', 'otro'
  ];

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final p = widget.producto!;
      _nombreCtrl.text = p.nombre;
      _descripcionCtrl.text = p.descripcion ?? '';
      _codigoCtrl.text = p.codigoBarras ?? '';
      _precioCompraCtrl.text = p.precioCompra.toString();
      _precioVentaCtrl.text = p.precioVenta.toString();
      _stockActualCtrl.text = p.stockActual.toString();
      _stockMinimoCtrl.text = p.stockMinimo.toString();
      _unidad = p.unidad;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _descripcionCtrl.dispose();
    _codigoCtrl.dispose(); _precioCompraCtrl.dispose();
    _precioVentaCtrl.dispose(); _stockActualCtrl.dispose();
    _stockMinimoCtrl.dispose();
    super.dispose();
  }

  double get _ganancia {
    final compra = double.tryParse(_precioCompraCtrl.text) ?? 0;
    final venta = double.tryParse(_precioVentaCtrl.text) ?? 0;
    return venta - compra;
  }

  double get _margen {
    final compra = double.tryParse(_precioCompraCtrl.text) ?? 0;
    if (compra == 0) return 0;
    return (_ganancia / compra) * 100;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
   // Si es producto nuevo con stock, registrar como gasto automático
      if (!_esEdicion) {
        final stock = double.tryParse(_stockActualCtrl.text) ?? 0;
        final costo = double.tryParse(_precioCompraCtrl.text) ?? 0;
        if (stock > 0 && costo > 0) {
          await GastoService.guardarGasto(GastoModel(
            id: '',
            empresaId: '',
            categoria: 'mercancia',
            descripcion: '${_nombreCtrl.text.trim()} — $stock ${_unidad}s',
            monto: stock * costo,
            fecha: DateTime.now(),
          ));
        }
      }
    await InventarioService.guardarProducto(
        ProductoModel(
          id: _esEdicion ? widget.producto!.id : '',
          empresaId: '',
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
          precioCompra: double.tryParse(_precioCompraCtrl.text) ?? 0,
          precioVenta: double.tryParse(_precioVentaCtrl.text) ?? 0,
          stockActual: double.tryParse(_stockActualCtrl.text) ?? 0,
          stockMinimo: double.tryParse(_stockMinimoCtrl.text) ?? 5,
          unidad: _unidad,
        ),
        esNuevo: !_esEdicion,
      );
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_esEdicion ? 'Producto actualizado' : 'Producto agregado'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      print('❌ ERROR: ${e.toString()}');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          if (_esEdicion)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: _confirmarEliminar,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFoto(),
              const SizedBox(height: 20),
              _buildSeccion('Información básica'),
              const SizedBox(height: 12),
              _buildCampoTexto(_nombreCtrl, 'Nombre del producto *',
                  Icons.label_outline, 'Ej: Arroz Molina 5lb'),
              const SizedBox(height: 12),
              _buildCampoTexto(_descripcionCtrl, 'Descripción (opcional)',
                  Icons.notes_rounded, 'Detalles del producto', requerido: false),
              const SizedBox(height: 12),
              _buildCampoTexto(_codigoCtrl, 'Código de barras (opcional)',
                  Icons.qr_code_rounded, 'Escanear o ingresar', requerido: false),
              const SizedBox(height: 20),
              _buildSeccion('Precios'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCampoNumerico(_precioCompraCtrl,
                      'Precio de compra', 'RD\$')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCampoNumerico(_precioVentaCtrl,
                      'Precio de venta *', 'RD\$', requerido: true)),
                ],
              ),
              if (_ganancia != 0) ...[
                const SizedBox(height: 12),
                _buildIndicadorGanancia(),
              ],
              const SizedBox(height: 20),
              _buildSeccion('Stock'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCampoNumerico(_stockActualCtrl,
                      'Stock actual', '', esDecimal: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCampoNumerico(_stockMinimoCtrl,
                      'Stock mínimo', '', esDecimal: true)),
                ],
              ),
              const SizedBox(height: 12),
              _buildSelectorUnidad(),
              const SizedBox(height: 32),
              _buildBotonGuardar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoto() {
    return Center(
      child: GestureDetector(
        onTap: () {}, // TODO: image_picker
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.colorInventario.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.colorInventario.withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.colorInventario, size: 32),
              const SizedBox(height: 6),
              const Text('Agregar foto',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                      color: AppColors.colorInventario, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccion(String titulo) {
    return Text(titulo.toUpperCase(),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1));
  }

  Widget _buildCampoTexto(
    TextEditingController ctrl, String label, IconData icon, String hint,
    {bool requerido = true}
  ) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      ),
      validator: requerido
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }

  Widget _buildCampoNumerico(
    TextEditingController ctrl, String label, String prefijo,
    {bool requerido = false, bool esDecimal = false}
  ) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefijo.isNotEmpty ? '$prefijo ' : null,
        prefixStyle: const TextStyle(fontFamily: 'Poppins',
            color: AppColors.textSecondary, fontSize: 14),
      ),
      validator: requerido
          ? (v) {
              if (v == null || v.isEmpty) return 'Requerido';
              if (double.tryParse(v) == null) return 'Número inválido';
              return null;
            }
          : null,
    );
  }

  Widget _buildIndicadorGanancia() {
    final positivo = _ganancia >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: positivo ? AppColors.successSurface : AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            positivo ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: positivo ? AppColors.success : AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ganancia por unidad: ${AppFormatters.moneda(_ganancia)}',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600,
                  color: positivo ? AppColors.success : AppColors.danger,
                ),
              ),
              Text(
                'Margen: ${_margen.toStringAsFixed(1)}%',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                    color: positivo ? AppColors.success : AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorUnidad() {
    return DropdownButtonFormField<String>(
      value: _unidad,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Unidad de medida',
        prefixIcon: Icon(Icons.scale_outlined, color: AppColors.textMuted, size: 20),
      ),
      items: _unidades.map((u) => DropdownMenuItem(value: u,
          child: Text(u, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)))).toList(),
      onChanged: (v) => setState(() => _unidad = v ?? 'unidad'),
    );
  }

  Widget _buildBotonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _guardar,
        child: _loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(
                _esEdicion ? 'Guardar cambios' : 'Agregar producto',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  void _confirmarEliminar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(
          '¿Seguro que quieres eliminar "${widget.producto!.nombre}"?',
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
          onPressed: () async {
              Navigator.pop(context);
              try {
                await SupabaseService.client
                    .from('productos')
                    .update({'activo': false})
                    .eq('id', widget.producto!.id);
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                print('❌ Error eliminar: $e');
              }
            },
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}