import 'package:flutter/material.dart';
import '../onboarding/catalogo_rapido_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'scanner_screen.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../utils/formatters.dart';
import 'producto_form_screen.dart';
import '../../services/inventario_service.dart';
import 'ajuste_stock_screen.dart';
import 'dart:io';
import '../../utils/responsive.dart';
import '../../widgets/guia_modulo_banner.dart';
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final _searchCtrl = TextEditingController();
  String _filtro = 'todos'; // todos | bajo_stock | sin_stock
  List<ProductoModel> _productos = [];
  List<ProductoModel> _filtrados = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

 Future<void> _cargarProductos() async {
    setState(() => _loading = true);
    try {
      final productos = await InventarioService.getProductos();
      if (mounted) {
        setState(() {
          _productos = productos;
          _aplicarFiltros();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudieron cargar los productos: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  void _aplicarFiltros() {
    var lista = List<ProductoModel>.from(_productos);
    final query = _searchCtrl.text.toLowerCase();
    if (query.isNotEmpty) {
      lista = lista.where((p) => p.nombre.toLowerCase().contains(query) ||
          (p.codigoBarras ?? '').toLowerCase().contains(query)).toList();
    }
    if (_filtro == 'bajo_stock') {
      lista = lista.where((p) => p.stockBajo && !p.sinStock).toList();
    } else if (_filtro == 'sin_stock') {
      lista = lista.where((p) => p.sinStock).toList();
    }
    _filtrados = lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Buscar por código',
            onPressed: () async {
              final codigo = await Navigator.push<String>(context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen(titulo: 'Buscar producto')));
              if (codigo != null && mounted) {
                setState(() {
                  _searchCtrl.text = codigo;
                  _aplicarFiltros();
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
            const GuiaModuloBanner(modulo: 'inventario'),
          _buildBuscadorYFiltros(),
          _buildResumenStock(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtrados.isEmpty
                    ? _buildEmpty()
                    : _buildLista(),
          ),
        ],
      ),
      floatingActionButton:FloatingActionButton(
        onPressed: () => _irAFormulario(),
        backgroundColor: AppColors.primary,
        tooltip: 'Agregar producto',
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildBuscadorYFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Buscador
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            onChanged: (_) => setState(_aplicarFiltros),
            decoration: InputDecoration(
              hintText: 'Buscar producto o código...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(_aplicarFiltros);
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          // Filtros rápidos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FiltroChip(label: 'Todos', value: 'todos', selected: _filtro,
                    onTap: (v) => setState(() { _filtro = v; _aplicarFiltros(); })),
                const SizedBox(width: 8),
                _FiltroChip(label: '⚠ Stock bajo', value: 'bajo_stock', selected: _filtro,
                    onTap: (v) => setState(() { _filtro = v; _aplicarFiltros(); }),
                    color: AppColors.warning),
                const SizedBox(width: 8),
                _FiltroChip(label: '✕ Sin stock', value: 'sin_stock', selected: _filtro,
                    onTap: (v) => setState(() { _filtro = v; _aplicarFiltros(); }),
                    color: AppColors.danger),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildResumenStock() {
    final total = _productos.length;
    final bajo = _productos.where((p) => p.stockBajo && !p.sinStock).length;
    final sinStock = _productos.where((p) => p.sinStock).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _ResumenItem(valor: '$total', label: 'Productos', color: AppColors.primary),
          _buildDividerV(),
          _ResumenItem(valor: '$bajo', label: 'Stock bajo', color: AppColors.warning),
          _buildDividerV(),
          _ResumenItem(valor: '$sinStock', label: 'Sin stock', color: AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildDividerV() {
    return Container(width: 1, height: 40, color: AppColors.cardBorder,
        margin: const EdgeInsets.symmetric(horizontal: 16));
  }

  Widget _buildLista() {
    if (R.isTablet(context)) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 8,
        ),
        itemCount: _filtrados.length,
        itemBuilder: (_, i) => _ProductoTile(
          producto: _filtrados[i],
          onTap: () => _irAFormulario(producto: _filtrados[i]),
          onAjusteStock: () => _irAjusteStock(_filtrados[i]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ProductoTile(
        producto: _filtrados[i],
        onTap: () => _irAFormulario(producto: _filtrados[i]),
        onAjusteStock: () => _irAjusteStock(_filtrados[i]),
      ),
    );
  }

  Widget _buildEmpty() {
    // Desplazable: nunca se desborda aunque la guía de arriba ocupe espacio
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 42, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tu inventario está vacío',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Empieza en segundos: marca los productos que vendes de nuestra lista, '
            'o agrégalos uno por uno.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          // Acción principal: carga rápida
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(context,
                    MaterialPageRoute(builder: (_) => const CatalogoRapidoScreen()));
                if (ok == true) _cargarProductos();
              },
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: const Text('Carga rápida de colmado',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Acción secundaria: uno por uno
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _irAFormulario(),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Agregar un producto',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _irAFormulario({ProductoModel? producto}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductoFormScreen(producto: producto)),
    );
    if (resultado == true) _cargarProductos();
  }

  void _irAjusteStock(ProductoModel producto) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AjusteStockScreen(producto: producto)),
    );
    if (resultado == true) _cargarProductos();
  }
}

// ============================================================
// WIDGETS INTERNOS
// ============================================================

class _FiltroChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;
  final Color color;

  const _FiltroChip({
    required this.label, required this.value,
    required this.selected, required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ResumenItem extends StatelessWidget {
  final String valor;
  final String label;
  final Color color;
  const _ResumenItem({required this.valor, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
              fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _ProductoTile extends StatelessWidget {
  final ProductoModel producto;
  final VoidCallback onTap;
  final VoidCallback onAjusteStock;
  const _ProductoTile({required this.producto, required this.onTap, required this.onAjusteStock});

  @override
  Widget build(BuildContext context) {
    Color estadoColor;
    String estadoLabel;
    Color estadoBg;

    if (producto.sinStock) {
      estadoColor = AppColors.danger;
      estadoBg = AppColors.dangerSurface;
      estadoLabel = 'Sin stock';
    } else if (producto.stockBajo) {
      estadoColor = AppColors.warning;
      estadoBg = AppColors.warningSurface;
      estadoLabel = 'Stock bajo';
    } else {
      estadoColor = AppColors.success;
      estadoBg = AppColors.successSurface;
      estadoLabel = 'En stock';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            // Foto / placeholder
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.colorInventario.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
             child: producto.fotoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: producto.fotoUrl!.startsWith('http')
                          ? CachedNetworkImage(imageUrl: producto.fotoUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              fadeInDuration: const Duration(milliseconds: 150),
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.inventory_2_rounded,
                                  color: AppColors.colorInventario, size: 26))
                          : Image.file(File(producto.fotoUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_rounded,
                                  color: AppColors.colorInventario, size: 26)),
                    )
                  : const Icon(Icons.inventory_2_rounded,
                      color: AppColors.colorInventario, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(producto.nombre,
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AppFormatters.stock(producto.stockActual, producto.unidad),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 12, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: estadoBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(estadoLabel,
                            style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: estadoColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppFormatters.moneda(producto.precioVenta),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Costo: ${AppFormatters.moneda(producto.precioCompra)}',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 10, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onAjusteStock,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.colorInventario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.colorInventario, size: 18),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}