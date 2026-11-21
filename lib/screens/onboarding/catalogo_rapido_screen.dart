import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_palette.dart';
import '../../models/producto_model.dart';
import '../../services/inventario_service.dart';

/// Carga rápida: el usuario marca los productos típicos de colmado que vende,
/// pone precio y cantidad, y se guardan todos de una vez.
class CatalogoRapidoScreen extends StatefulWidget {
  const CatalogoRapidoScreen({super.key});

  @override
  State<CatalogoRapidoScreen> createState() => _CatalogoRapidoScreenState();
}

class _ItemCatalogo {
  final String nombre;
  final String unidad;
  bool marcado = false;
  final precioCtrl = TextEditingController();
  final cantCtrl = TextEditingController();
  _ItemCatalogo(this.nombre, [this.unidad = 'unidad']);

  double get precio => double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
  double get cantidad => double.tryParse(cantCtrl.text.replaceAll(',', '.')) ?? 0;
  void dispose() { precioCtrl.dispose(); cantCtrl.dispose(); }
}

class _CatalogoRapidoScreenState extends State<CatalogoRapidoScreen> {
  // Productos típicos de colmado dominicano, por categoría
  final Map<String, List<_ItemCatalogo>> _catalogo = {
    '🍺 Bebidas': [
      _ItemCatalogo('Cerveza Presidente'), _ItemCatalogo('Cerveza Presidente Light'),
      _ItemCatalogo('Refresco Coca-Cola'), _ItemCatalogo('Refresco Pepsi'),
      _ItemCatalogo('Refresco Country Club'), _ItemCatalogo('Malta Morena'),
      _ItemCatalogo('Agua Planeta Azul'), _ItemCatalogo('Jugo Rica'),
      _ItemCatalogo('Ron Brugal', 'botella'), _ItemCatalogo('Ron Barceló', 'botella'),
    ],
    '🍚 Despensa': [
      _ItemCatalogo('Arroz', 'libra'), _ItemCatalogo('Habichuelas', 'libra'),
      _ItemCatalogo('Azúcar', 'libra'), _ItemCatalogo('Sal', 'paquete'),
      _ItemCatalogo('Aceite', 'botella'), _ItemCatalogo('Espaguetis', 'paquete'),
      _ItemCatalogo('Sopita (cubito)'), _ItemCatalogo('Sazón', 'paquete'),
      _ItemCatalogo('Salsa de tomate'), _ItemCatalogo('Café', 'paquete'),
      _ItemCatalogo('Avena', 'paquete'), _ItemCatalogo('Harina', 'libra'),
      _ItemCatalogo('Sardinas'), _ItemCatalogo('Arenque'),
    ],
    '🥚 Frescos': [
      _ItemCatalogo('Huevos'), _ItemCatalogo('Salami', 'libra'),
      _ItemCatalogo('Queso de freír', 'libra'), _ItemCatalogo('Pan de agua'),
      _ItemCatalogo('Leche', 'litro'), _ItemCatalogo('Plátanos'),
      _ItemCatalogo('Cebolla', 'libra'), _ItemCatalogo('Ajo'),
    ],
    '🧼 Limpieza': [
      _ItemCatalogo('Jabón de cuaba'), _ItemCatalogo('Detergente', 'paquete'),
      _ItemCatalogo('Cloro', 'galón'), _ItemCatalogo('Papel de baño'),
      _ItemCatalogo('Jabón de baño'), _ItemCatalogo('Pasta de dientes'),
    ],
    '🍬 Picaderas': [
      _ItemCatalogo('Galletas'), _ItemCatalogo('Papitas'),
      _ItemCatalogo('Chicles'), _ItemCatalogo('Caramelos'),
      _ItemCatalogo('Platanitos'),
    ],
    '🔌 Otros': [
      _ItemCatalogo('Tarjeta de recarga'), _ItemCatalogo('Fósforos'),
      _ItemCatalogo('Velas'), _ItemCatalogo('Funda plástica'),
      _ItemCatalogo('Hielo', 'funda'),
    ],
  };

  bool _guardando = false;
  final _buscarCtrl = TextEditingController();

  List<_ItemCatalogo> get _todos => _catalogo.values.expand((l) => l).toList();
  List<_ItemCatalogo> get _marcados => _todos.where((i) => i.marcado).toList();

  @override
  void dispose() {
    for (final i in _todos) { i.dispose(); }
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final marcados = _marcados;
    if (marcados.isEmpty) return;
    final sinPrecio = marcados.where((i) => i.precio <= 0).toList();
    if (sinPrecio.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ponle precio a: ${sinPrecio.map((i) => i.nombre).take(3).join(', ')}'
            '${sinPrecio.length > 3 ? '…' : ''}'),
        backgroundColor: Colors.orange.shade700,
      ));
      return;
    }
    final sinCantidad = marcados.where((i) => i.cantidad <= 0).toList();
    if (sinCantidad.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pon cuántos tienes de: ${sinCantidad.map((i) => i.nombre).take(3).join(', ')}'
            '${sinCantidad.length > 3 ? '…' : ''}'),
        backgroundColor: Colors.orange.shade700,
      ));
      return;
    }
    setState(() => _guardando = true);
    int ok = 0;
    for (final i in marcados) {
      final guardado = await InventarioService.guardarProducto(ProductoModel(
        id: '',
        empresaId: '',
        nombre: i.nombre,
        precioVenta: i.precio,
        stockActual: i.cantidad,
        unidad: i.unidad,
      ));
      if (guardado) ok++;
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('¡Listo! $ok producto${ok == 1 ? '' : 's'} agregado${ok == 1 ? '' : 's'} a tu inventario 🎉'),
      backgroundColor: Colors.green.shade700,
    ));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    final q = _buscarCtrl.text.toLowerCase().trim();
    final n = _marcados.length;

    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        title: Text('Carga rápida', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Marca los productos que vendes y ponles precio. '
              'Después puedes agregar más, con foto, desde Inventario.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: pal.textSecondary, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _buscarCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar producto…',
              prefixIcon: Icon(Icons.search_rounded, color: pal.textMuted),
              filled: true, fillColor: pal.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            children: [
              for (final entry in _catalogo.entries) ...(() {
                final items = entry.value.where((i) => q.isEmpty || i.nombre.toLowerCase().contains(q)).toList();
                if (items.isEmpty) return <Widget>[];
                return <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                    child: Text(entry.key,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: pal.textPrimary)),
                  ),
                  ...items.map((i) => _fila(pal, i)),
                ];
              })(),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (n == 0 || _guardando) ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: pal.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _guardando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(n == 0 ? 'Marca los productos que vendes' : 'Agregar $n producto${n == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fila(AppPalette pal, _ItemCatalogo i) {
    final fmt = [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))];
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(fontSize: 11, color: pal.textMuted),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          filled: true, fillColor: pal.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
        );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: i.marcado ? pal.primary.withValues(alpha: 0.5) : pal.cardBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => i.marcado = !i.marcado),
          borderRadius: BorderRadius.circular(12),
          child: Row(children: [
            Checkbox(
              value: i.marcado,
              activeColor: pal.primary,
              onChanged: (v) => setState(() => i.marcado = v ?? false),
            ),
            Expanded(child: Text(i.nombre,
                style: GoogleFonts.poppins(fontSize: 14,
                    fontWeight: i.marcado ? FontWeight.w600 : FontWeight.w500,
                    color: pal.textPrimary))),
            Text(i.unidad, style: GoogleFonts.poppins(fontSize: 11, color: pal.textMuted)),
          ]),
        ),
        if (i.marcado)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 0, 10),
            child: Row(children: [
              Expanded(child: TextField(
                controller: i.precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: fmt,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: deco('Precio RD\$'),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: i.cantCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: fmt,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: deco('¿Cuántos tienes?'),
              )),
            ]),
          ),
      ]),
    );
  }
}
