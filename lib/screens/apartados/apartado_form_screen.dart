import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../services/apartado_service.dart';
import '../../services/cliente_service.dart';
import '../../services/inventario_service.dart';
import '../../models/cliente_model.dart';

// ─── Item de línea dentro del apartado ────────────────────────────────────────
class _LineaApartado {
  String? productoId;
  String nombre;
  double precio;
  double cantidad;
  double? costoUnitario; // opcional, solo si el usuario lo indicó

  _LineaApartado({
    this.productoId,
    required this.nombre,
    required this.precio,
    this.cantidad = 1,
    this.costoUnitario,
  });

  double get subtotal => precio * cantidad;
}

class ApartadoFormScreen extends StatefulWidget {
  const ApartadoFormScreen({super.key});

  @override
  State<ApartadoFormScreen> createState() => _ApartadoFormScreenState();
}

class _ApartadoFormScreenState extends State<ApartadoFormScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _abonoCtrl      = TextEditingController();
  final _notasCtrl      = TextEditingController();
  DateTime? _fechaEstimada;
  String?   _clienteId;
  bool      _loading    = false;

  List<Map<String, String>> _clientes  = [];
  List<ProductoModel>        _productos = [];
  final List<_LineaApartado> _lineas   = [];

  double get _montoTotal    => _lineas.fold(0, (s, l) => s + l.subtotal);
  double get _abonoInicial  => double.tryParse(_abonoCtrl.text) ?? 0;
  double get _saldoPendiente => _montoTotal - _abonoInicial;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final clientes  = await ClienteService.getClientes();
    final productos = await InventarioService.getProductos();
    if (!mounted) return;
    setState(() {
      _clientes  = clientes.map((c) => {'id': c.id, 'nombre': c.nombre}).toList();
      _productos = productos;
    });
  }

  @override
  void dispose() {
    _abonoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  // ─── Selector de producto desde inventario ───────────────────────────────
  Future<void> _abrirSelectorProducto() async {
    final result = await showModalBottomSheet<_LineaApartado>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductoPicker(productos: _productos),
    );
    if (result != null) setState(() => _lineas.add(result));
  }

  // ─── Agregar artículo manual (no está en inventario) ────────────────────
  Future<void> _agregarManual() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final costoCtrl  = TextEditingController();
    bool  pedirCosto = false;
    bool  guardando  = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nuevo artículo',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre del artículo *',
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Precio de venta *',
                  prefixText: 'RD\$ ',
                  filled: true, fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              // Pregunta de costo
              Row(children: [
                Checkbox(
                  value: pedirCosto,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setSt(() => pedirCosto = v ?? false),
                ),
                const Expanded(
                  child: Text('¿Desea registrar lo que costó este artículo?',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                ),
              ]),
              if (pedirCosto) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: costoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Costo del artículo',
                    prefixText: 'RD\$ ',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: guardando ? null : () {
                final nombre = nombreCtrl.text.trim();
                final precio = double.tryParse(precioCtrl.text) ?? 0;
                if (nombre.isEmpty || precio <= 0) return;
                final costo = pedirCosto ? double.tryParse(costoCtrl.text) : null;
                Navigator.pop(ctx);
                setState(() => _lineas.add(_LineaApartado(
                  nombre: nombre,
                  precio: precio,
                  costoUnitario: costo,
                )));
              },
              child: const Text('Agregar',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Guardar apartado ────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona un cliente'),
          backgroundColor: AppColors.danger));
      return;
    }
    if (_lineas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Agrega al menos un artículo'),
          backgroundColor: AppColors.danger));
      return;
    }
    if (_abonoInicial > _montoTotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El abono no puede superar el total'),
          backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _loading = true);

    // Descripción automática
    final desc = _lineas.length == 1
        ? _lineas.first.nombre
        : '${_lineas.first.nombre} y ${_lineas.length - 1} artículo(s) más';

    await ApartadoService.crearApartado(
      clienteId:    _clienteId!,
      descripcion:  desc,
      montoTotal:   _montoTotal,
      abonoInicial: _abonoInicial,
      fechaEstimada: _fechaEstimada,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      lineas: _lineas.map((l) => {
        'producto_id': l.productoId,
        'nombre': l.nombre,
        'cantidad': l.cantidad,
        'precio': l.precio,
        'costo': l.costoUnitario,
      }).toList(),
    );

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Apartado creado exitosamente'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nuevo apartado')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.colorApartados.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.colorApartados.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.colorApartados, size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text(
                  'El producto quedará reservado hasta que el cliente complete el pago.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.colorApartados),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            // Cliente
            _seccion('Cliente'),
            const SizedBox(height: 12),
            _buildSelectorCliente(),
            const SizedBox(height: 20),

            // Artículos
            _seccion('Artículos'),
            const SizedBox(height: 12),
            ..._lineas.asMap().entries.map((e) => _buildLineaCard(e.key, e.value)),

            // Botones agregar
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Del inventario',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _abrirSelectorProducto,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Agregar nuevo',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.textSecondary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _agregarManual,
                ),
              ),
            ]),

            // Resumen total
            if (_lineas.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                          fontWeight: FontWeight.w600, color: AppColors.primary)),
                  Text('RD\$ ${_montoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 18,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // Abono
            _seccion('Abono inicial'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _abonoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Abono inicial (opcional)',
                prefixText: 'RD\$ ',
              ),
            ),

            // Saldo pendiente
            if (_montoTotal > 0 && _lineas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Saldo pendiente',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary)),
                    Text('RD\$ ${_saldoPendiente.toStringAsFixed(2)}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                            fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('% inicial',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary)),
                    Text(_montoTotal > 0
                        ? '${(_abonoInicial / _montoTotal * 100).toStringAsFixed(0)}%'
                        : '0%',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                            fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // Fecha estimada
            _seccion('Fecha estimada de pago'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (fecha != null) setState(() => _fechaEstimada = fecha);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _fechaEstimada != null
                        ? _fechaEstimada!.toLocal().toString().split(' ')[0]
                        : 'Seleccionar fecha (opcional)',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                        color: _fechaEstimada != null ? AppColors.textPrimary : AppColors.textMuted),
                  ),
                  const Spacer(),
                  if (_fechaEstimada != null)
                    GestureDetector(
                      onTap: () => setState(() => _fechaEstimada = null),
                      child: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Notas
            _seccion('Notas'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: const InputDecoration(hintText: 'Notas adicionales (opcional)...'),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _guardar,
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Crear apartado',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLineaCard(int idx, _LineaApartado linea) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(linea.nombre,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('RD\$ ${linea.precio.toStringAsFixed(2)} × ${linea.cantidad.toStringAsFixed(linea.cantidad % 1 == 0 ? 0 : 1)}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary)),
          if (linea.costoUnitario != null)
            Text('Costo: RD\$ ${linea.costoUnitario!.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMuted)),
        ])),
        Text('RD\$ ${linea.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _lineas.removeAt(idx)),
          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
        ),
      ]),
    );
  }

  Widget _seccion(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 1));

  Widget _buildSelectorCliente() {
    return DropdownButtonFormField<String>(
      value: _clienteId,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Seleccionar cliente',
        prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
      ),
      items: _clientes.map((c) => DropdownMenuItem(
        value: c['id'],
        child: Text(c['nombre']!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
      )).toList(),
      onChanged: (v) => setState(() => _clienteId = v),
    );
  }
}

// ─── Bottom sheet: picker de productos del inventario ────────────────────────
class _ProductoPicker extends StatefulWidget {
  final List<ProductoModel> productos;
  const _ProductoPicker({required this.productos});

  @override
  State<_ProductoPicker> createState() => _ProductoPickerState();
}

class _ProductoPickerState extends State<_ProductoPicker> {
  String _busqueda = '';

  List<ProductoModel> get _filtrados => widget.productos
      .where((p) => p.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Seleccionar producto',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: const TextStyle(fontFamily: 'Poppins'),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true, fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Flexible(
            child: _filtrados.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Sin resultados',
                          style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMuted)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtrados.length,
                    itemBuilder: (_, i) {
                      final p = _filtrados[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primarySurface,
                          child: const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                        ),
                        title: Text(p.nombre,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('RD\$ ${p.precioVenta.toStringAsFixed(2)}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary)),
                        trailing: Text('Stock: ${p.stockActual.toStringAsFixed(0)}',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMuted)),
                        onTap: () => Navigator.pop(
                          context,
                          _LineaApartado(
                            productoId: p.id,
                            nombre: p.nombre,
                            precio: p.precioVenta,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
