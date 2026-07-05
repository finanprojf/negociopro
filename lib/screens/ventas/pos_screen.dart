import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/producto_model.dart';
import '../../utils/formatters.dart';
import '../../services/inventario_service.dart';
import '../../services/venta_service.dart';
import '../../services/cliente_service.dart';
import '../../models/cliente_model.dart';
import 'historial_ventas_screen.dart';
import 'dart:io';
class _ItemCarrito {
  final ProductoModel producto;
  double cantidad;

  _ItemCarrito({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precioVenta * cantidad;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  List<ProductoModel> _productos = [];
  List<ProductoModel> _filtrados = [];
  final List<_ItemCarrito> _carrito = [];
  bool _loading = true;
  String _tipoPago = 'efectivo';
String? _clienteSeleccionado;
List<Map<String, String>> _clientesFiltrados = [];
List<Map<String, String>> _clientesDemo = [];
  double get _total => _carrito.fold(0, (s, i) => s + i.subtotal);
  int get _totalItems => _carrito.fold(0, (s, i) => s + i.cantidad.toInt());
double _montoIngresadoTemp = 0;
  @override
 void initState() {
    super.initState();
    _cargarProductos();
    _clientesFiltrados = _clientesDemo;
    _cargarClientes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
Future<void> _agregarClienteRapido() async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo cliente',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombreCtrl,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontFamily: 'Poppins'),
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'nombre': nombreCtrl.text.trim(),
                'telefono': telefonoCtrl.text.trim(),
              });
            },
            child: const Text('Guardar',
                style: TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (resultado != null) {
      try {
        final cliente = await ClienteService.guardarCliente(ClienteModel(
          id: '',
          empresaId: '',
          nombre: resultado['nombre']!,
          telefono: resultado['telefono']!.isEmpty 
              ? null : resultado['telefono'],
        ));
       await _cargarClientes();
        // Seleccionar el cliente recién creado y continuar con la venta
        final clienteNuevo = _clientesDemo.firstWhere(
            (c) => c['nombre'] == resultado['nombre'],
            orElse: () => _clientesDemo.last);
       setState(() {
          _clienteSeleccionado = clienteNuevo['id'];
          _tipoPago = 'fiado';
        });
        // Registrar la venta automáticamente con el cliente nuevo
        await VentaService.registrarVenta(
          items: _carrito.map((i) => {
            'producto': i.producto,
            'cantidad': i.cantidad,
          }).toList(),
          tipoPago: 'fiado',
          clienteId: clienteNuevo['id'],
          montoPagado: _montoIngresadoTemp,
          descuento: 0,
        );
        setState(() {
          _carrito.clear();
          _clienteSeleccionado = null;
          _tipoPago = 'efectivo';
        });
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('¡Venta registrada! ${resultado['nombre']} debe RD${_total - _montoIngresadoTemp}'),
            backgroundColor: AppColors.success,
          ));
        }
    
      } catch (e) {
        print('❌ Error agregar cliente: $e');
      }
    }
  }
 Future<void> _cargarProductos() async {
    setState(() => _loading = true);
    try {
      final productos = await InventarioService.getProductos();
      if (mounted) {
        setState(() {
          _productos = productos;
          _filtrados = productos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _buscar(String q) {
    setState(() {
      _filtrados = q.isEmpty
          ? _productos
          : _productos.where((p) =>
              p.nombre.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  void _agregar(ProductoModel p) {
    setState(() {
      final idx = _carrito.indexWhere((i) => i.producto.id == p.id);
      if (idx >= 0) _carrito[idx].cantidad++;
      else _carrito.add(_ItemCarrito(producto: p));
    });
    HapticFeedback.lightImpact();
  }

  void _cambiarCantidad(int idx, double nueva) {
    setState(() {
      if (nueva <= 0) _carrito.removeAt(idx);
      else _carrito[idx].cantidad = nueva;
    });
  }
Future<void> _cargarClientes() async {
    try {
      final clientes = await ClienteService.getClientes();
      setState(() {
        _clientesDemo = clientes.map((c) => {
          'id': c.id,
          'nombre': c.nombre,
        }).toList();
        _clientesFiltrados = _clientesDemo;
      });
    } catch (e) {
      print('❌ Error clientes POS: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistorialVentasScreen())),
          ),
          if (_carrito.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _carrito.clear()),
              child: Text('Limpiar', style: GoogleFonts.poppins(
                  color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
          if (_carrito.isNotEmpty)
            TextButton.icon(
              onPressed: _verCarrito,
              icon: const Icon(Icons.shopping_cart_rounded, size: 18),
              label: Text('$_totalItems', style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
      body: Column(children: [
        _buildBuscador(),
        Expanded(child: _buildGridProductos()),
        if (_carrito.isNotEmpty) _buildFooter(),
      ]),
    );
  }

  void _verCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                Text('Carrito', style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$_totalItems items', style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textMuted)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _carrito.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _CarritoItem(
                item: _carrito[i],
                onCambiar: (n) {
                  setState(() {
                    if (n <= 0) _carrito.removeAt(i);
                    else _carrito[i].cantidad = n;
                  });
                  setModal(() {});
                },
                onEliminar: () {
                  setState(() => _carrito.removeAt(i));
                  setModal(() {});
                  if (_carrito.isEmpty) Navigator.pop(ctx);
                },
              ),
            )),
          ]),
        ),
      ),
    );
  }



  Widget _buildBuscador() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _buscar,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar...',
          hintStyle: GoogleFonts.poppins(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 20),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildGridProductos() {
    if (_loading) return const Center(
        child: CircularProgressIndicator(color: AppColors.primary));
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _filtrados.length,
    itemBuilder: (_, i) {
        final cantidad = _carrito
            .where((c) => c.producto.id == _filtrados[i].id)
            .fold(0, (s, c) => s + c.cantidad.toInt());
       return _ProdCard(
          producto: _filtrados[i],
          enCarrito: cantidad > 0,
          cantidadEnCarrito: cantidad,
          onTap: () => _agregar(_filtrados[i]),
          onMas: () => _agregar(_filtrados[i]),
          onMenos: () => _cambiarCantidad(
            _carrito.indexWhere((c) => c.producto.id == _filtrados[i].id),
            cantidad - 1,
          ),
        );
      },
    );
  }



  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Tipo de pago
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _PagoBtn('Efectivo', Icons.payments_outlined, 'efectivo', _tipoPago,
                (v) => setState(() => _tipoPago = v)),
            const SizedBox(width: 6),
            _PagoBtn('Tarjeta', Icons.credit_card_rounded, 'tarjeta', _tipoPago,
                (v) => setState(() => _tipoPago = v)),
            const SizedBox(width: 6),
            _PagoBtn('Transfer.', Icons.account_balance_rounded,
                'transferencia', _tipoPago,
                (v) => setState(() => _tipoPago = v)),
            const SizedBox(width: 6),
            _PagoBtn('Fiado', Icons.handshake_outlined, 'fiado', _tipoPago,
                (v) => setState(() => _tipoPago = v)),
          ]),
        ),
        const SizedBox(height: 10),
        // Total y cobrar
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total', style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textMuted)),
            Text(AppFormatters.moneda(_total), style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: AppColors.primary)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: SizedBox(
           height: 52,
            child: ElevatedButton(
              onPressed: () => _mostrarCobro(),
              child: Text('Cobrar', style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          )),
        ]),
      ]),
    );
  }

  void _mostrarCobro() {
    final ctrl = TextEditingController(
        text: _tipoPago == 'efectivo' ? _total.toStringAsFixed(2) : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2))),
            Text('Confirmar cobro', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text('Total a cobrar', style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.primary)),
                const SizedBox(height: 6),
                Text(AppFormatters.moneda(_total), style: GoogleFonts.poppins(
                    fontSize: 32, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
              ]),
            ),
           if (_tipoPago == 'fiado') ...[
  const SizedBox(height: 16),
  const Text('Seleccionar cliente',
      style: TextStyle(fontFamily: 'Poppins',
          fontSize: 14, fontWeight: FontWeight.w600)),
  const SizedBox(height: 8),
  TextField(
    decoration: const InputDecoration(
      hintText: 'Buscar cliente...',
      prefixIcon: Icon(Icons.search_rounded),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    onChanged: (q) => setModal(() {
      _clientesFiltrados = _clientesDemo.where((c) =>
          c['nombre']!.toLowerCase().contains(q.toLowerCase())).toList();
    }),
  ),
  const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  await _agregarClienteRapido();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person_add_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('+ Nuevo cliente',
                        style: GoogleFonts.poppins(fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
  const SizedBox(height: 8),
 SizedBox(
    height: 120,
    child: ListView.builder(
      itemCount: _clientesFiltrados.length,
      itemBuilder: (_, i) {
        final c = _clientesFiltrados[i];
        final sel = _clienteSeleccionado == c['id'];
        return GestureDetector(
          onTap: () => setModal(() => _clienteSeleccionado = c['id']),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.primarySurface : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? AppColors.primary : AppColors.cardBorder,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              CircleAvatar(radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(c['nombre']![0],
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary))),
              const SizedBox(width: 10),
              Expanded(child: Text(c['nombre']!,
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, fontWeight: FontWeight.w500))),
              if (sel) const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
            ]),
          ),
        );
      },
    ),
  ),
],
            if (_tipoPago == 'efectivo') ...[
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                onChanged: (_) => setModal(() {}),
                style: GoogleFonts.poppins(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Monto recibido',
                  prefixText: 'RD\$ ',
                ),
              ),
              const SizedBox(height: 10),
              Builder(builder: (_) {
                final recibido = double.tryParse(ctrl.text) ?? 0;
                final cambio = recibido - _total;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cambio >= 0
                        ? AppColors.successSurface : AppColors.dangerSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cambio', style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: cambio >= 0
                              ? AppColors.success : AppColors.danger)),
                      Text(AppFormatters.moneda(cambio >= 0 ? cambio : 0),
                          style: GoogleFonts.poppins(fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: cambio >= 0
                                  ? AppColors.success : AppColors.danger)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
              onPressed: () async {
                  final montoIngresado = double.tryParse(ctrl.text) ?? _total;
                  
                  // Si el monto es menor al total
                  if (_tipoPago == 'efectivo' && montoIngresado <= 0) {
                    // Monto 0 = regalo/descuento total
                    Navigator.pop(ctx);
                    final opcion = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('¿Cómo registrar esto?',
                            style: TextStyle(fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700)),
                        content: Text(
                          'El monto es RD\$0. ¿Es un regalo o va a fiado?',
                          style: const TextStyle(fontFamily: 'Poppins')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'cancelar'),
                            child: const Text('Cancelar',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'descuento'),
                            child: const Text('🎁 Regalo',
                                style: TextStyle(color: AppColors.warning,
                                    fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'fiado'),
                            child: const Text('🤝 Fiado',
                                style: TextStyle(color: AppColors.colorFiado,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (opcion == null || opcion == 'cancelar') return;
                    _montoIngresadoTemp = 0;
                    if (opcion == 'fiado') {
                      if (_clienteSeleccionado == null) {
                        // pedir cliente
                      }
                      setState(() => _tipoPago = 'fiado');
                    }
                    await VentaService.registrarVenta(
                      items: _carrito.map((i) => {
                        'producto': i.producto,
                        'cantidad': i.cantidad,
                      }).toList(),
                      tipoPago: opcion == 'fiado' ? 'fiado' : 'efectivo',
                      clienteId: _clienteSeleccionado,
                      montoPagado: 0,
                      descuento: opcion == 'descuento' ? _total : 0,
                    );
                    setState(() {
                      _carrito.clear();
                      _clienteSeleccionado = null;
                      _tipoPago = 'efectivo';
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(opcion == 'fiado'
                            ? '¡Registrado en fiado!'
                            : '¡Regalo registrado!'),
                        backgroundColor: AppColors.success,
                      ));
                    }
                    return;
                  } else if (_tipoPago == 'efectivo' && montoIngresado < _total) {
                    Navigator.pop(ctx);
                    final faltante = _total - montoIngresado;
                    _montoIngresadoTemp = montoIngresado;
                    final opcion = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Pago incompleto',
                            style: TextStyle(fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700)),
                        content: Text(
                          'Faltan ${AppFormatters.moneda(faltante)} para completar el pago.\n\n¿Qué deseas hacer?',
                          style: const TextStyle(fontFamily: 'Poppins')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'cancelar'),
                            child: const Text('Cancelar',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'descuento'),
                            child: const Text('Descuento',
                                style: TextStyle(color: AppColors.warning,
                                    fontWeight: FontWeight.w700)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'fiado'),
                            child: const Text('Fiado',
                                style: TextStyle(color: AppColors.colorFiado,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (opcion == null || opcion == 'cancelar') return;
                  if (opcion == 'fiado') {
      // Si no tiene cliente seleccionado, pedir que elija uno
      if (_clienteSeleccionado == null) {
        final clienteElegido = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Seleccionar cliente',
                style: TextStyle(fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: _clientesDemo.length,
                itemBuilder: (_, i) {
                  final c = _clientesDemo[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.colorFiado.withValues(alpha: 0.1),
                      child: Text(c['nombre']![0],
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              color: AppColors.colorFiado)),
                    ),
                    title: Text(c['nombre']!,
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(context, c['id']),
                  );
                },
              ),
            ),
           actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context, null);
                  await _agregarClienteRapido();
                },
                child: const Text('+ Nuevo cliente',
                    style: TextStyle(color: AppColors.primary,
                        fontWeight: FontWeight.w700))),
            ],
          ),
        );
        if (clienteElegido == null) return;
        _clienteSeleccionado = clienteElegido;
      }
      setState(() => _tipoPago = 'fiado');
    }
                    // Si es descuento, el monto ingresado es el total a cobrar
                    await VentaService.registrarVenta(
                      items: _carrito.map((i) => {
                        'producto': i.producto,
                        'cantidad': i.cantidad,
                      }).toList(),
                      tipoPago: opcion == 'fiado' ? 'fiado' : 'efectivo',
                      clienteId: _clienteSeleccionado,
                      montoPagado: montoIngresado,
                      descuento: opcion == 'descuento' ? faltante : 0,
                    );
                    setState(() {
                      _carrito.clear();
                      _clienteSeleccionado = null;
                      _tipoPago = 'efectivo';
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(opcion == 'fiado'
                            ? '¡Venta registrada en fiado!'
                            : '¡Venta con descuento registrada!'),
                        backgroundColor: AppColors.success,
                      ));
                      Navigator.pop(context);
                    }
                    return;
                  }

                  Navigator.pop(ctx);
                await VentaService.registrarVenta(
                    items: _carrito.map((i) => {
                      'producto': i.producto,
                      'cantidad': i.cantidad,
                    }).toList(),
                    tipoPago: _tipoPago,
                    clienteId: _clienteSeleccionado,
                    montoPagado: _tipoPago == 'fiado' ? 0 : (double.tryParse(ctrl.text) ?? _total),
                  );
                  setState(() {
                    _carrito.clear();
                    _clienteSeleccionado = null;
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('¡Venta registrada!',
                          style: GoogleFonts.poppins()),
                      backgroundColor: AppColors.success,
                    ));
                    Navigator.pop(context);
                  }
                },
                child: Text('Confirmar venta', style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================

class _ProdCard extends StatelessWidget {
  final ProductoModel producto;
  final bool enCarrito;
  final int cantidadEnCarrito;
  final VoidCallback onTap;
  final VoidCallback onMas;
  final VoidCallback onMenos;
  const _ProdCard({required this.producto,
      required this.enCarrito,
      required this.cantidadEnCarrito,
      required this.onTap,
      required this.onMas,
      required this.onMenos});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: producto.sinStock ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enCarrito ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enCarrito ? AppColors.primary : AppColors.cardBorder,
            width: enCarrito ? 1.5 : 1,
          ),
        ),
        child: Stack(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Container(width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.colorVentas.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7)),
                    child: producto.fotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.file(File(producto.fotoUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory_2_rounded,
                                    color: AppColors.colorVentas, size: 16)))
                        : const Icon(Icons.inventory_2_rounded,
                            color: AppColors.colorVentas, size: 16)),
                const Spacer(),
                if (producto.sinStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.dangerSurface,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('Agotado', style: GoogleFonts.poppins(
                        fontSize: 8, color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(producto.nombre,
                  style: GoogleFonts.poppins(fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: producto.sinStock
                          ? AppColors.textMuted : AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(AppFormatters.moneda(producto.precioVenta),
                  style: GoogleFonts.poppins(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: producto.sinStock
                          ? AppColors.textMuted : AppColors.primary)),
              if (enCarrito) ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  GestureDetector(
                    onTap: onMenos,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.remove_rounded,
                          color: AppColors.danger, size: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('${cantidadEnCarrito}x',
                        style: GoogleFonts.poppins(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                  GestureDetector(
                    onTap: onMas,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.primary, size: 16),
                    ),
                  ),
                ]),
              ],
            ],
          ),
          // Stock en esquina superior derecha
          Positioned(top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: producto.sinStock
                    ? AppColors.danger
                    : producto.stockBajo
                        ? AppColors.warning
                        : AppColors.textMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${producto.stockActual.toInt()}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: Colors.white)),
            )),
        ]),
      ),
    );
  }
}

class _CarritoItem extends StatelessWidget {
  final _ItemCarrito item;
  final Function(double) onCambiar;
  final VoidCallback onEliminar;
  const _CarritoItem({required this.item,
      required this.onCambiar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.producto.nombre,
              style: GoogleFonts.poppins(fontSize: 12,
                  fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          GestureDetector(onTap: onEliminar,
              child: const Icon(Icons.close_rounded,
                  color: AppColors.textMuted, size: 16)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            _Btn(Icons.remove_rounded, () => onCambiar(item.cantidad - 1)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${item.cantidad.toInt()}',
                  style: GoogleFonts.poppins(fontSize: 14,
                      fontWeight: FontWeight.w700))),
            _Btn(Icons.add_rounded, () => onCambiar(item.cantidad + 1)),
          ]),
          Text(AppFormatters.moneda(item.subtotal),
              style: GoogleFonts.poppins(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _Btn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 24, height: 24,
        decoration: BoxDecoration(color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.cardBorder)),
        child: Icon(icon, size: 14, color: AppColors.textPrimary)),
  );
}

class _PagoBtn extends StatelessWidget {
  final String label; final IconData icon;
  final String value, selected;
  final Function(String) onTap;
  const _PagoBtn(this.label, this.icon, this.value,
      this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: sel ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 11,
              fontWeight: FontWeight.w600,
              color: sel ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}