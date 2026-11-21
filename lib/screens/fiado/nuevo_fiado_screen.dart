import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../models/cliente_model.dart';
import '../../models/producto_model.dart';
import '../../services/cliente_service.dart';
import '../../services/fiado_service.dart';
import '../../services/inventario_service.dart';
import '../../services/recibo_service.dart';
import '../../utils/formatters.dart';
import '../../services/modo_service.dart';

class NuevoFiadoScreen extends StatefulWidget {
  final ClienteModel? clienteInicial;
  const NuevoFiadoScreen({super.key, this.clienteInicial});

  @override
  State<NuevoFiadoScreen> createState() => _NuevoFiadoScreenState();
}

class _Item {
  final TextEditingController nombreCtrl;
  final TextEditingController cantCtrl;
  final TextEditingController precioCtrl;
  String? productoId;

  _Item()
      : nombreCtrl = TextEditingController(),
        cantCtrl = TextEditingController(text: '1'),
        precioCtrl = TextEditingController();

  void dispose() {
    nombreCtrl.dispose();
    cantCtrl.dispose();
    precioCtrl.dispose();
  }

  double get cantidad => double.tryParse(cantCtrl.text.replaceAll(',', '.')) ?? 1;
  double get precio => double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
  double get subtotal => cantidad * precio;
  bool get valido => nombreCtrl.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'nombre': nombreCtrl.text.trim(),
        'cantidad': cantidad,
        'precio': precio,
        if (productoId != null) 'producto_id': productoId,
      };
}

class _NuevoFiadoScreenState extends State<NuevoFiadoScreen> {
  final _notasCtrl = TextEditingController();
  ClienteModel? _clienteSeleccionado;
  final _clienteBusqCtrl = TextEditingController();
  List<ClienteModel> _clientes = [];
  List<ClienteModel> _clientesFiltrados = [];
  List<_Item> _items = [_Item()];
  List<ProductoModel> _productos = [];
  bool _cargando = false;
  bool _mostrarBuscadorCliente = false;
  DateTime? _fechaLimite;

  @override
  void initState() {
    super.initState();
    _clienteSeleccionado = widget.clienteInicial;
    if (widget.clienteInicial != null) {
      _clienteBusqCtrl.text = widget.clienteInicial!.nombre;
    }
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final clientes = await ClienteService.getClientes();
    final prods = await InventarioService.getProductos();
    if (mounted) setState(() { _clientes = clientes; _productos = prods; });
  }

  void _filtrarClientes(String q) {
    setState(() {
      _clientesFiltrados = q.isEmpty
          ? []
          : _clientes
              .where((c) => c.nombre.toLowerCase().contains(q.toLowerCase()))
              .take(6)
              .toList();
    });
  }

  double get _total => _items.fold(0, (s, i) => s + i.subtotal);

  void _agregarItem() => setState(() => _items.add(_Item()));

  void _eliminarItem(int i) {
    if (_items.length <= 1) return;
    _items[i].dispose();
    setState(() => _items.removeAt(i));
  }

  Future<void> _mostrarSelectorProducto(int idx) async {
    final prod = await showModalBottomSheet<ProductoModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductoSelector(productos: _productos),
    );
    if (prod != null) {
      setState(() {
        _items[idx].nombreCtrl.text = prod.nombre;
        _items[idx].precioCtrl.text = prod.precioVenta.toStringAsFixed(2);
        _items[idx].productoId = prod.id;
      });
    }
  }

  Future<void> _guardar() async {
    final itemsValidos = _items.where((i) => i.valido).toList();
    if (itemsValidos.isEmpty) {
      _snack('Agrega al menos un artículo');
      return;
    }
    if (_clienteSeleccionado == null) {
      _snack('Selecciona un cliente');
      return;
    }
    if (_total <= 0) {
      _snack('El total debe ser mayor a 0');
      return;
    }

    setState(() => _cargando = true);
    final itemsMaps = itemsValidos.map((i) => i.toMap()).toList();

    final ok = await FiadoService.crearFiado(
      clienteId: _clienteSeleccionado!.id,
      clienteNombre: _clienteSeleccionado!.nombre,
      montoOriginal: _total,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      items: itemsMaps,
      fechaLimite: _fechaLimite,
    );
    setState(() => _cargando = false);

    if (!ok) {
      _snack('Error al guardar. Intenta de nuevo.');
      return;
    }

    if (!mounted) return;
    _mostrarOpciones(itemsMaps);
  }

  void _mostrarOpciones(List<Map<String, dynamic>> itemsMaps) {
    final pal = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: pal.cardBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
          ),
          const SizedBox(height: 12),
          Text('¡Fiado registrado!',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: pal.textPrimary)),
          Text('Total: ${AppFormatters.moneda(_total)}',
              style: GoogleFonts.poppins(fontSize: 14, color: pal.textSecondary)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await ReciboService.compartirTextoNuevoFiado(
                    clienteNombre: _clienteSeleccionado!.nombre,
                    clienteTelefono: _clienteSeleccionado!.telefono,
                    items: itemsMaps,
                    total: _total,
                    notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
                  );
                  if (mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.share_rounded),
                label: Text('Compartir', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check_rounded),
                label: Text('Listo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pal.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.colorFiado));
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _clienteBusqCtrl.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Nuevo Fiado',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: pal.textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: pal.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // ── CLIENTE ─────────────────────────────────────────
            _seccion(pal, 'Cliente', Icons.person_rounded),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _mostrarBuscadorCliente = !_mostrarBuscadorCliente),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: pal.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _clienteSeleccionado != null ? pal.primary.withValues(alpha: 0.5) : pal.cardBorder,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.person_outline_rounded, color: pal.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _clienteSeleccionado?.nombre ?? 'Seleccionar cliente...',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: _clienteSeleccionado != null ? pal.textPrimary : pal.textMuted,
                        fontWeight: _clienteSeleccionado != null ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: pal.textMuted),
                ]),
              ),
            ),
            if (_mostrarBuscadorCliente) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _clienteBusqCtrl,
                autofocus: true,
                onChanged: _filtrarClientes,
                style: GoogleFonts.poppins(fontSize: 14, color: pal.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar cliente...',
                  hintStyle: GoogleFonts.poppins(color: pal.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: pal.textMuted),
                  filled: true,
                  fillColor: pal.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.primary)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
                ),
              ),
              if (_clientesFiltrados.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: pal.surfaceAlt, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.cardBorder),
                  ),
                  child: Column(
                    children: _clientesFiltrados.map((c) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: pal.primary.withValues(alpha: 0.1),
                        child: Text(c.nombre[0].toUpperCase(), style: TextStyle(color: pal.primary, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(c.nombre, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: pal.textPrimary)),
                      subtitle: c.telefono != null ? Text(c.telefono!, style: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted)) : null,
                      onTap: () => setState(() {
                        _clienteSeleccionado = c;
                        _clienteBusqCtrl.text = c.nombre;
                        _clientesFiltrados = [];
                        _mostrarBuscadorCliente = false;
                      }),
                    )).toList(),
                  ),
                ),
            ],
            const SizedBox(height: 20),

            // ── ARTÍCULOS ─────────────────────────────────────
            Row(children: [
              Expanded(child: _seccion(pal, 'Artículos', Icons.shopping_cart_outlined)),
              if (_productos.isNotEmpty && !ModoService.sinInventario.value)
                TextButton.icon(
                  onPressed: () => _mostrarSelectorProducto(_items.length - 1),
                  icon: Icon(Icons.inventory_2_outlined, size: 16, color: pal.primary),
                  label: Text('Del inventario', style: GoogleFonts.poppins(fontSize: 12, color: pal.primary, fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 8),

            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return _ItemRow(
                key: ValueKey(idx),
                item: item,
                index: idx,
                total: _items.length,
                pal: pal,
                onDelete: () => _eliminarItem(idx),
                onInventario: (_productos.isNotEmpty && !ModoService.sinInventario.value) ? () => _mostrarSelectorProducto(idx) : null,
                onChanged: () => setState(() {}),
              );
            }),

            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _agregarItem,
              icon: const Icon(Icons.add_rounded),
              label: Text('Agregar artículo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: pal.primary,
                side: BorderSide(color: pal.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // ── FECHA LÍMITE ──────────────────────────────────
            _seccion(pal, 'Fecha límite de pago (opcional)', Icons.event_rounded),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final hoy = DateTime.now();
                final f = await showDatePicker(
                  context: context,
                  initialDate: _fechaLimite ?? hoy.add(const Duration(days: 15)),
                  firstDate: hoy,
                  lastDate: hoy.add(const Duration(days: 365)),
                );
                if (f != null) setState(() => _fechaLimite = f);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: pal.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.cardBorder),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: pal.textMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _fechaLimite == null ? 'Sin fecha límite' : AppFormatters.fecha(_fechaLimite!),
                    style: GoogleFonts.poppins(fontSize: 14,
                        color: _fechaLimite == null ? pal.textMuted : pal.textPrimary),
                  )),
                  if (_fechaLimite != null)
                    GestureDetector(
                      onTap: () => setState(() => _fechaLimite = null),
                      child: Icon(Icons.close_rounded, size: 18, color: pal.textMuted),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ── NOTAS ─────────────────────────────────────────
            _seccion(pal, 'Notas (opcional)', Icons.notes_rounded),
            const SizedBox(height: 8),
            TextField(
              controller: _notasCtrl,
              maxLines: 2,
              style: GoogleFonts.poppins(fontSize: 14, color: pal.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ej: Crédito de esta semana...',
                hintStyle: GoogleFonts.poppins(color: pal.textMuted, fontSize: 13),
                filled: true, fillColor: pal.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.primary)),
              ),
            ),
            const SizedBox(height: 90),
          ]),
        ),

        // ── TOTAL + BOTÓN ────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: pal.surface,
            border: Border(top: BorderSide(color: pal.cardBorder, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total fiado', style: GoogleFonts.poppins(fontSize: 14, color: pal.textSecondary, fontWeight: FontWeight.w500)),
                Text(AppFormatters.moneda(_total),
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.colorFiado)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorFiado,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _cargando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Registrar Fiado', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _seccion(AppPalette pal, String titulo, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: pal.primary),
      const SizedBox(width: 6),
      Text(titulo, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: pal.textPrimary)),
    ]);
  }
}

// ── FILA DE ITEM ────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final _Item item;
  final int index;
  final int total;
  final AppPalette pal;
  final VoidCallback onDelete;
  final VoidCallback? onInventario;
  final VoidCallback onChanged;

  const _ItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.pal,
    required this.onDelete,
    this.onInventario,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.cardBorder),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.nombreCtrl,
              onChanged: (_) => onChanged(),
              style: GoogleFonts.poppins(fontSize: 14, color: pal.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nombre del artículo',
                hintStyle: GoogleFonts.poppins(color: pal.textMuted, fontSize: 13),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true, fillColor: pal.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.primary)),
              ),
            ),
          ),
          if (onInventario != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onInventario,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pal.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2_outlined, size: 18, color: pal.primary),
              ),
            ),
          ],
          const SizedBox(width: 6),
          if (total > 1)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: item.cantCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 14, color: pal.textPrimary),
              decoration: InputDecoration(
                labelText: 'Cant.',
                labelStyle: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true, fillColor: pal.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.primary)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.precioCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 14, color: pal.textPrimary),
              decoration: InputDecoration(
                labelText: 'Precio unit.',
                labelStyle: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true, fillColor: pal.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: pal.primary)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Subtotal', style: GoogleFonts.poppins(fontSize: 10, color: pal.textMuted)),
            Text(AppFormatters.moneda(item.subtotal),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.colorFiado)),
          ]),
        ]),
      ]),
    );
  }
}

// ── SELECTOR DE PRODUCTO ─────────────────────────────────────

class _ProductoSelector extends StatefulWidget {
  final List<ProductoModel> productos;
  const _ProductoSelector({required this.productos});

  @override
  State<_ProductoSelector> createState() => _ProductoSelectorState();
}

class _ProductoSelectorState extends State<_ProductoSelector> {
  final _searchCtrl = TextEditingController();
  List<ProductoModel> _filtrados = [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.productos;
  }

  void _filtrar(String q) {
    setState(() {
      _filtrados = q.isEmpty
          ? widget.productos
          : widget.productos.where((p) => p.nombre.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: pal.cardBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: _filtrar,
            style: GoogleFonts.poppins(fontSize: 14, color: pal.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              hintStyle: GoogleFonts.poppins(color: pal.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: pal.textMuted),
              filled: true, fillColor: pal.surfaceAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.primary)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtrados.length,
            itemBuilder: (_, i) {
              final p = _filtrados[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: pal.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.inventory_2_outlined, color: pal.primary, size: 20),
                ),
                title: Text(p.nombre, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: pal.textPrimary)),
                subtitle: Text('Stock: ${p.stockActual.toStringAsFixed(0)} • ${AppFormatters.moneda(p.precioVenta)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted)),
                trailing: Icon(Icons.add_circle_rounded, color: pal.primary),
                onTap: () => Navigator.pop(context, p),
              );
            },
          ),
        ),
      ]),
    );
  }
}
