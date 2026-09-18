import 'package:flutter/material.dart';
import 'scanner_screen.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../models/categoria_model.dart';
import '../../utils/formatters.dart';
import '../../services/inventario_service.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import '../../services/gasto_service.dart';
import '../../models/gasto_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProductoFormScreen extends StatefulWidget {
  final ProductoModel? producto;
  const ProductoFormScreen({super.key, this.producto});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _nombreCtrl        = TextEditingController();
  final _descripcionCtrl   = TextEditingController();
  final _codigoCtrl        = TextEditingController();
  final _precioCompraCtrl  = TextEditingController();
  final _precioVentaCtrl   = TextEditingController();
  final _stockActualCtrl   = TextEditingController();
  final _stockMinimoCtrl   = TextEditingController();
  // Elaborado
  final _costoTotalCtrl    = TextEditingController();
  final _unidadesProdCtrl  = TextEditingController();

  String _unidad      = 'unidad';
  bool   _loading     = false;
  String? _categoriaId;
  List<CategoriaModel> _categorias = [];
  bool   _esElaborado = false;

  File?   _imagenSeleccionada;
  String? _rutaImagenGuardada;
  final   _picker = ImagePicker();

  bool get _esEdicion => widget.producto != null;

  final List<String> _unidades = [
    'unidad', 'vaso', 'porción', 'paquete', 'caja',
    'botella', 'lata', 'kg', 'libra', 'litro', 'docena', 'par', 'otro'
  ];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _costoTotalCtrl.addListener(_recalcular);
    _unidadesProdCtrl.addListener(_recalcular);
    _precioCompraCtrl.addListener(() => setState(() {}));
    _precioVentaCtrl.addListener(() => setState(() {}));

    if (_esEdicion) {
      final p = widget.producto!;
      _nombreCtrl.text       = p.nombre;
      _descripcionCtrl.text  = p.descripcion ?? '';
      _codigoCtrl.text       = p.codigoBarras ?? '';
      _precioVentaCtrl.text  = p.precioVenta.toString();
      _stockActualCtrl.text  = p.stockActual.toString();
      _stockMinimoCtrl.text  = p.stockMinimo.toString();
      _unidad                = p.unidad;
      _esElaborado           = p.esElaborado;
      if (p.esElaborado) {
        _costoTotalCtrl.text    = p.costoProduccion.toString();
        _unidadesProdCtrl.text  = p.unidadesProducidas.toString();
      } else {
        _precioCompraCtrl.text  = p.precioCompra.toString();
      }
      _categoriaId = p.categoriaId;
      if (p.fotoUrl != null) _rutaImagenGuardada = p.fotoUrl;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();       _descripcionCtrl.dispose();
    _codigoCtrl.dispose();       _precioCompraCtrl.dispose();
    _precioVentaCtrl.dispose();  _stockActualCtrl.dispose();
    _stockMinimoCtrl.dispose();  _costoTotalCtrl.dispose();
    _unidadesProdCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final cats = await InventarioService.getCategorias();
      if (mounted) setState(() => _categorias = cats);
    } catch (_) {}
  }

  void _recalcular() => setState(() {});

  // ── Getters de cálculo ──────────────────────────────────────
  double get _costoTotal     => double.tryParse(_costoTotalCtrl.text) ?? 0;
  double get _unidadesProd   => double.tryParse(_unidadesProdCtrl.text) ?? 1;
  double get _costoUnitario  => _unidadesProd > 0 ? _costoTotal / _unidadesProd : 0;
  double get _precioVenta    => double.tryParse(_precioVentaCtrl.text) ?? 0;
  double get _precioCompra   => double.tryParse(_precioCompraCtrl.text) ?? 0;

  double get _costoBase      => _esElaborado ? _costoUnitario : _precioCompra;
  double get _ganancia       => _precioVenta - _costoBase;
  double get _margen         => _costoBase > 0 ? (_ganancia / _costoBase) * 100 : 0;

  double get _sugerido50     => _costoUnitario * 1.50;
  double get _sugerido100    => _costoUnitario * 2.00;
  double get _sugerido150    => _costoUnitario * 2.50;

  // ── Guardar ─────────────────────────────────────────────────
  Future<void> _ofrecerRegistrarGasto(String productoId) async {
    if (!mounted) return;
    final nombre = _nombreCtrl.text.trim();

    if (_esElaborado && _costoTotal > 0) {
      // Producto elaborado: ofrecer registrar inversión de producción
      final u = _unidadesProd > 0 ? _unidadesProd.toStringAsFixed(0) : '1';
      final descripcion = 'Inversión de $nombre';
      final monto = _costoTotal;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('¿Registrar inversión?',
                style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Se agregó un producto elaborado. ¿Deseas registrar el costo de producción como gasto?',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📦 $descripcion',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$u ${_unidad}s producidas',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(AppFormatters.moneda(monto),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
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
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Sí, registrar',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700))),
          ],
        ),
      );
      if (confirmar == true) {
        await GastoService.guardarGasto(GastoModel(
          id: '', empresaId: '', categoria: 'produccion',
          descripcion: descripcion, monto: monto, fecha: DateTime.now(),
          notas: 'origen:producto:$productoId',
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Inversión registrada en gastos'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ));
        }
      }
    } else {
      // Producto normal: ofrecer registrar compra de inventario
      final stock = double.tryParse(_stockActualCtrl.text) ?? 0;
      if (stock <= 0 || _precioCompra <= 0) return;
      final monto = stock * _precioCompra;
      final descripcion = 'Compra de $nombre';
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
                Text('${stock.toStringAsFixed(0)} ${_unidad}s × ${AppFormatters.moneda(_precioCompra)}',
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
      if (confirmar == true) {
        await GastoService.guardarGasto(GastoModel(
          id: '', empresaId: '', categoria: 'mercancia',
          descripcion: descripcion, monto: monto, fecha: DateTime.now(),
          notas: 'origen:producto:$productoId',
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Compra registrada en gastos'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ));
        }
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Subir foto si hay una nueva
      final String nuevoId = _esEdicion ? widget.producto!.id : const Uuid().v4();
      String? fotoUrlFinal = _rutaImagenGuardada;
      if (_imagenSeleccionada != null) {
        final urlPublica = await InventarioService.uploadFoto(
            _imagenSeleccionada!.path, nuevoId);
        fotoUrlFinal = urlPublica ?? _imagenSeleccionada!.path;
      }

      await InventarioService.guardarProducto(
        ProductoModel(
          id:                nuevoId,
          empresaId:         '',
          fotoUrl:           fotoUrlFinal,
          nombre:            _nombreCtrl.text.trim(),
          descripcion:       _descripcionCtrl.text.trim().isEmpty
                                 ? null : _descripcionCtrl.text.trim(),
          precioCompra:      _esElaborado ? _costoUnitario : _precioCompra,
          precioVenta:       _precioVenta,
          stockActual:       double.tryParse(_stockActualCtrl.text) ?? 0,
          stockMinimo:       double.tryParse(_stockMinimoCtrl.text) ?? 5,
          unidad:            _unidad,
          esElaborado:       _esElaborado,
          costoProduccion:   _esElaborado ? _costoTotal : 0,
          unidadesProducidas:_esElaborado ? _unidadesProd : 1,
          codigoBarras:      _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
          categoriaId:       _categoriaId,
        ),
        esNuevo: !_esEdicion,
      );

      if (mounted) {
        // Preguntar si registrar gasto ANTES de cerrar la pantalla
        if (!_esEdicion) {
          await _ofrecerRegistrarGasto(nuevoId);
        }
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_esEdicion ? 'Producto actualizado' : 'Producto agregado'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _buildFoto(),
          const SizedBox(height: 20),

          // ── Toggle elaborado ──────────────────────────────
          _buildToggleElaborado(),
          const SizedBox(height: 20),

          // ── Info básica ───────────────────────────────────
          _buildSeccion('Información básica'),
          const SizedBox(height: 12),
          _buildCampoTexto(_nombreCtrl, 'Nombre del producto *',
              Icons.label_outline, 'Ej: Jugo de chinola'),
          const SizedBox(height: 12),
          _buildCampoTexto(_descripcionCtrl, 'Descripción (opcional)',
              Icons.notes_rounded, 'Detalles del producto', requerido: false),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildCampoTexto(_codigoCtrl, 'Código de barras (opcional)',
                Icons.qr_code_rounded, 'Escanear o ingresar', requerido: false)),
            const SizedBox(width: 8),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              onPressed: () async {
                final codigo = await Navigator.push<String>(context,
                    MaterialPageRoute(builder: (_) => const ScannerScreen(titulo: 'Código de barras')));
                if (codigo != null && mounted) {
                  _codigoCtrl.text = codigo;
                }
              },
            ),
          ]),
          const SizedBox(height: 20),

          // ── Costos ────────────────────────────────────────
          _esElaborado
              ? _buildSeccionElaborado()
              : _buildSeccionRevendido(),
          const SizedBox(height: 20),

          // ── Precio de venta + indicador ───────────────────
          _buildSeccion('Precio de venta'),
          const SizedBox(height: 12),
          _buildCampoNumerico(_precioVentaCtrl,
              'Precio de venta *', 'RD\$', requerido: true),
          if (_precioVenta > 0 && _costoBase > 0) ...[
            const SizedBox(height: 12),
            _buildIndicadorGanancia(),
          ],
          const SizedBox(height: 20),

          // ── Stock ─────────────────────────────────────────
          _buildSeccion('Stock'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildCampoNumerico(_stockActualCtrl,
                'Stock actual', '', esDecimal: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildCampoNumerico(_stockMinimoCtrl,
                'Stock mínimo', '', esDecimal: true)),
          ]),
          const SizedBox(height: 12),
          _buildSelectorUnidad(),
          const SizedBox(height: 12),
          _buildSelectorCategoria(),
          const SizedBox(height: 32),

          _buildBotonGuardar(),
        ]),
      ),
    ),
  );

  // ── Toggle elaborado ─────────────────────────────────────────
  Widget _buildToggleElaborado() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _esElaborado
          ? AppColors.accentSurface
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: _esElaborado
              ? AppColors.accent
              : AppColors.cardBorder),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _esElaborado
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.textMuted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.blender_rounded,
            color: _esElaborado ? AppColors.accent : AppColors.textMuted,
            size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Producto elaborado',
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _esElaborado ? AppColors.accent : AppColors.textPrimary,
            )),
        Text(
          _esElaborado
              ? 'Jugo, comida, preparado — calculas tú el costo'
              : 'Activa si produces o preparas este producto',
          style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 11, color: AppColors.textMuted),
        ),
      ])),
      Switch(
        value: _esElaborado,
        activeColor: AppColors.accent,
        onChanged: (v) => setState(() {
          _esElaborado = v;
          if (!v) {
            _costoTotalCtrl.clear();
            _unidadesProdCtrl.clear();
          } else {
            _precioCompraCtrl.clear();
          }
        }),
      ),
    ]),
  );

  // ── Sección producto elaborado ───────────────────────────────
  Widget _buildSeccionElaborado() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSeccion('Costo de producción'),
      const SizedBox(height: 6),
      Text(
        'Ingresa cuánto gastaste en total y cuántas unidades produjiste.',
        style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 12, color: AppColors.textMuted),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _buildCampoNumerico(_costoTotalCtrl,
            'Total gastado *', 'RD\$', requerido: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildCampoNumerico(_unidadesProdCtrl,
            'Unidades producidas *', '', requerido: true, esDecimal: true)),
      ]),

      if (_costoTotal > 0 && _unidadesProd > 0) ...[
        const SizedBox(height: 12),
        // Costo por unidad calculado
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.calculate_rounded,
                color: AppColors.info, size: 18),
            const SizedBox(width: 8),
            Text(
              'Costo por unidad: ${AppFormatters.moneda(_costoUnitario)}',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.info),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Precios sugeridos
        _buildSeccion('Precio sugerido de venta'),
        const SizedBox(height: 8),
        Text('Toca uno para aplicarlo o escribe el tuyo abajo.',
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Row(children: [
          _chipPrecio('50% margen', _sugerido50, AppColors.warning),
          const SizedBox(width: 8),
          _chipPrecio('100% margen', _sugerido100, AppColors.success, recomendado: true),
          const SizedBox(width: 8),
          _chipPrecio('150% margen', _sugerido150, AppColors.primary),
        ]),
      ],
    ],
  );

  Widget _chipPrecio(String label, double precio, Color color,
      {bool recomendado = false}) {
    final seleccionado = _precioVentaCtrl.text ==
        precio.toStringAsFixed(precio.truncateToDouble() == precio ? 0 : 2);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _precioVentaCtrl.text = precio % 1 == 0
                ? precio.toInt().toString()
                : precio.toStringAsFixed(2);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: seleccionado
                ? color.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado ? color : AppColors.cardBorder,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Column(children: [
            if (recomendado)
              Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(20)),
                child: const Text('⭐ Ideal',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 8, color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            Text(AppFormatters.moneda(precio),
                style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 13, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 9, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  // ── Sección producto revendido ───────────────────────────────
  Widget _buildSeccionRevendido() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSeccion('Precio de compra'),
      const SizedBox(height: 12),
      _buildCampoNumerico(_precioCompraCtrl,
          'Precio de compra (opcional)', 'RD\$'),
    ],
  );

  // ── Indicador ganancia ───────────────────────────────────────
  Widget _buildIndicadorGanancia() {
    final ok = _ganancia >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? AppColors.successSurface : AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(
          ok ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: ok ? AppColors.success : AppColors.danger, size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              ok
                  ? 'Ganas ${AppFormatters.moneda(_ganancia)} por ${_unidad}'
                  : '⚠️ Vendes por debajo del costo',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ok ? AppColors.success : AppColors.danger),
            ),
            Text(
              'Margen: ${_margen.toStringAsFixed(1)}%  •  Costo: ${AppFormatters.moneda(_costoBase)}',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  color: ok ? AppColors.success : AppColors.danger),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Foto ─────────────────────────────────────────────────────
  Widget _buildFoto() => Center(
    child: GestureDetector(
      onTap: _elegirFoto,
      child: Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
          color: AppColors.colorInventario.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.colorInventario.withValues(alpha: 0.3), width: 2),
        ),
        child: _imagenSeleccionada != null
            ? ClipRRect(borderRadius: BorderRadius.circular(18),
                child: Image.file(_imagenSeleccionada!, fit: BoxFit.cover))
            : _rutaImagenGuardada != null
                ? ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: _rutaImagenGuardada!.startsWith('http')
                        ? Image.network(_rutaImagenGuardada!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _iconoFoto())
                        : Image.file(File(_rutaImagenGuardada!), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _iconoFoto()))
                : _iconoFoto(),
      ),
    ),
  );

  Widget _iconoFoto() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.add_photo_alternate_outlined,
          color: AppColors.colorInventario, size: 32),
      const SizedBox(height: 6),
      const Text('Agregar foto',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
              color: AppColors.colorInventario, fontWeight: FontWeight.w500)),
    ],
  );

  Future<void> _elegirFoto() async {
    final opcion = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: const Text('Tomar foto',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: const Text('Elegir de galería',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (_rutaImagenGuardada != null || _imagenSeleccionada != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Quitar foto',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600, color: AppColors.danger)),
              onTap: () {
                setState(() { _imagenSeleccionada = null; _rutaImagenGuardada = null; });
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
    if (opcion == null) return;
    final foto = await _picker.pickImage(
        source: opcion, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (foto != null) {
      final dir    = await getApplicationDocumentsDirectory();
      final nombre = 'producto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rutaP  = path.join(dir.path, nombre);
      final ff     = await File(foto.path).copy(rutaP);
      setState(() { _imagenSeleccionada = ff; _rutaImagenGuardada = ff.path; });
    }
  }

  // ── Helpers UI ───────────────────────────────────────────────
  Widget _buildSeccion(String t) => Text(t.toUpperCase(),
    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
        fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1));

  Widget _buildCampoTexto(TextEditingController ctrl, String label,
      IconData icon, String hint, {bool requerido = true}) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        ),
        validator: requerido
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      );

  Widget _buildCampoNumerico(TextEditingController ctrl, String label,
      String prefijo, {bool requerido = false, bool esDecimal = false}) =>
      TextFormField(
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
                if ((double.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
                return null;
              }
            : null,
      );


  static const _presetCategorias = [
    'Bebidas', 'Snacks', 'Aseo', 'Repostería', 'Limpieza',
    'Carnes', 'Lácteos', 'Panadería', 'Confitería', 'Otros',
  ];

  Widget _buildSelectorCategoria() {
    final catNombre = _categoriaId == null
        ? null
        : _categorias.firstWhere((c) => c.id == _categoriaId,
            orElse: () => _categorias.first).nombre;

    return GestureDetector(
      onTap: _abrirSelectorCategoria,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                catNombre ?? 'Categoría (opcional)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: catNombre != null ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            if (_categoriaId != null)
              GestureDetector(
                onTap: () => setState(() => _categoriaId = null),
                child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
              )
            else
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSelectorCategoria() async {
    final existingNames = _categorias.map((c) => c.nombre.toLowerCase()).toSet();
    final presets = _presetCategorias
        .where((p) => !existingNames.contains(p.toLowerCase()))
        .toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('Categoría',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                        tooltip: 'Nueva categoría',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _agregarNuevaCategoria();
                          await _abrirSelectorCategoria();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.block, size: 18, color: AppColors.textSecondary),
                  title: const Text('Sin categoría',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textSecondary)),
                  onTap: () {
                    setState(() => _categoriaId = null);
                    Navigator.pop(ctx);
                  },
                ),
                if (_categorias.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tus categorías',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                              color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  ..._categorias.map((c) => ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      child: const Icon(Icons.label, size: 12, color: AppColors.primary),
                    ),
                    title: Text(c.nombre,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                    trailing: _categoriaId == c.id
                        ? const Icon(Icons.check, color: AppColors.primary, size: 18)
                        : null,
                    onTap: () {
                      setState(() => _categoriaId = c.id);
                      Navigator.pop(ctx);
                    },
                  )),
                ],
                if (presets.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Sugerencias',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                              color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  ...presets.map((nombre) => ListTile(
                    leading: const Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                    title: Text(nombre,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                            color: AppColors.textSecondary)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final nueva = await InventarioService.crearCategoria(nombre);
                      if (nueva != null && mounted) {
                        await _cargarCategorias();
                        setState(() => _categoriaId = nueva.id);
                      }
                    },
                  )),
                ],
                SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _agregarNuevaCategoria() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva categoría',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej: Bebidas',
            hintStyle: const TextStyle(fontFamily: 'Poppins'),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          style: const TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nombre = controller.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(ctx);
              final nueva = await InventarioService.crearCategoria(nombre);
              if (nueva != null && mounted) {
                await _cargarCategorias();
                setState(() => _categoriaId = nueva.id);
              }
            },
            child: const Text('Crear', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorUnidad() => DropdownButtonFormField<String>(
    value: _unidad,
    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textPrimary),
    decoration: const InputDecoration(
      labelText: 'Unidad de medida',
      prefixIcon: Icon(Icons.scale_outlined, color: AppColors.textMuted, size: 20),
    ),
    items: _unidades.map((u) => DropdownMenuItem(
        value: u, child: Text(u, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)))
    ).toList(),
    onChanged: (v) => setState(() => _unidad = v ?? 'unidad'),
  );

  Widget _buildBotonGuardar() => SizedBox(
    width: double.infinity, height: 54,
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

  void _confirmarEliminar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que quieres eliminar "${widget.producto!.nombre}"?',
            style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final pid = widget.producto!.id;
                await LocalDatabase.actualizar('productos',
                    {'activo': 0, 'synced': 0,
                     'updated_at': DateTime.now().toIso8601String()},
                    'id', pid);
                if (await SupabaseService.isOnlineAsync) {
                  await SupabaseService.client.from('productos')
                      .update({'activo': false}).eq('id', pid);
                  await LocalDatabase.marcarSynced('productos', pid);
                }
                // Revertir gastos vinculados a este producto
                await GastoService.eliminarGastosPorProducto(pid);
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (context.mounted) Navigator.pop(context, true);
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
