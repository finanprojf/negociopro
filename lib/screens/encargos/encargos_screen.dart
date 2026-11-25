import 'package:flutter/material.dart';
import '../../services/venta_service.dart';
import '../../services/inventario_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/encargo_model.dart';
import '../../models/cliente_model.dart';
import '../../widgets/avatar_cliente.dart';
import '../../utils/formatters.dart';
import '../../services/encargo_service.dart';
import '../../services/cliente_service.dart';
import '../../services/recibo_service.dart';
import '../ventas/pos_screen.dart';
import '../../widgets/guia_modulo_banner.dart';
import '../../widgets/pro_gate.dart';

class EncargosScreen extends StatefulWidget {
  const EncargosScreen({super.key});

  @override
  State<EncargosScreen> createState() => _EncargosScreenState();
}

class _EncargosScreenState extends State<EncargosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const List<String> _categoriasPredef = [
    'Supermercado', 'Farmacia', 'Ferretería', 'Panadería',
    'Carnicería', 'Limpieza', 'Bebidas', 'Electrónica',
    'Ropa', 'Otro',
  ];
  List<EncargoModel> _encargos = [];
  List<EncargoModel> _lista = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// [silencioso] = recarga sin mostrar el círculo de carga (no "pestañea")
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _loading = true);
    try {
      final encargos = await EncargoService.getEncargos(esListaPropia: false);
      final lista = await EncargoService.getEncargos(esListaPropia: true);
      if (mounted) {
        setState(() {
          _encargos = encargos;
          _lista = lista;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudieron cargar los encargos: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  /// Marca/desmarca al instante en pantalla y guarda en segundo plano
  Future<void> _cambiarEstadoRapido(EncargoModel encargo, String nuevoEstado,
      {required bool esLista}) async {
    final lista = esLista ? _lista : _encargos;
    final idx = lista.indexWhere((e) => e.id == encargo.id);
    if (idx < 0) return;
    final anterior = lista[idx];
    setState(() => lista[idx] = anterior.conEstado(nuevoEstado));
    try {
      final ok = await EncargoService.actualizarEstado(encargo.id, nuevoEstado);
      if (ok == false) throw Exception('no guardado');
    } catch (_) {
      // Si falló, volver como estaba y avisar
      if (!mounted) return;
      final i2 = lista.indexWhere((e) => e.id == encargo.id);
      if (i2 >= 0) setState(() => lista[i2] = anterior);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo guardar el cambio'),
          backgroundColor: AppColors.danger));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HELPERS DE CLIENTE
  // ──────────────────────────────────────────────────────────────

  Future<void> _agregarClienteRapido(BuildContext ctx, StateSetter setModal,
      Function(String, String) onCreado) async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();

    final resultado = await showDialog<Map<String, String>>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Nuevo cliente',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombreCtrl,
            style: GoogleFonts.poppins(),
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(),
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'nombre': nombreCtrl.text.trim(),
                'telefono': telefonoCtrl.text.trim(),
              });
            },
            child: Text('Guardar',
                style: GoogleFonts.poppins(
                    color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (resultado != null) {
      try {
        await ClienteService.guardarCliente(ClienteModel(
          id: '',
          empresaId: '',
          nombre: resultado['nombre']!,
          telefono: resultado['telefono']!.isEmpty ? null : resultado['telefono'],
        ));
        final clientes = await ClienteService.getClientes();
        final nuevo = clientes.firstWhere(
            (c) => c.nombre == resultado['nombre'],
            orElse: () => clientes.last);
        setModal(() => onCreado(nuevo.id, nuevo.nombre));
      } catch (_) {}
    }
  }

  Widget _buildClienteSelector({
    required BuildContext ctx,
    required StateSetter setModal,
    required String? clienteNombre,
    required Function(String id, String nombre) onSeleccionado,
    bool requerido = false,
  }) {
    return GestureDetector(
      onTap: () async {
        final clientes = await ClienteService.getClientes();
        if (!ctx.mounted) return;
        final elegido = await showDialog<ClienteModel>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Seleccionar cliente',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: clientes.length,
                itemBuilder: (_, i) => ListTile(
                  leading: AvatarCliente(
                    iniciales: clientes[i].iniciales,
                    fotoUrl: clientes[i].fotoUrl,
                    radius: 20,
                  ),
                  title: Text(clientes[i].nombre,
                      style: GoogleFonts.poppins(fontSize: 14)),
                  onTap: () => Navigator.pop(ctx, clientes[i]),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancelar',
                    style: GoogleFonts.poppins(color: AppColors.textMuted))),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx, null);
                  await _agregarClienteRapido(ctx, setModal, onSeleccionado);
                },
                child: Text('+ Nuevo cliente',
                    style: GoogleFonts.poppins(
                        color: AppColors.primary, fontWeight: FontWeight.w700))),
            ],
          ),
        );
        if (elegido != null) {
          setModal(() => onSeleccionado(elegido.id, elegido.nombre));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (requerido && clienteNombre == null)
                ? AppColors.danger
                : AppColors.cardBorder,
          ),
        ),
        child: Row(children: [
          Icon(Icons.person_outline,
              color: requerido && clienteNombre == null
                  ? AppColors.danger
                  : AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              clienteNombre ??
                  (requerido ? 'Seleccionar cliente *' : 'Seleccionar cliente (opcional)'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: clienteNombre != null
                    ? AppColors.textPrimary
                    : (requerido ? AppColors.danger : AppColors.textMuted),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // FORMULARIO NUEVO / EDITAR
  // ──────────────────────────────────────────────────────────────


  void _mostrarFormulario({EncargoModel? editar}) {
    final esEdicion = editar != null;
    final descCtrl = TextEditingController(text: editar?.descripcion ?? '');
    final cantCtrl = TextEditingController(
        text: editar != null ? editar.cantidad.toStringAsFixed(0) : '1');
    final precioCtrl = TextEditingController(
        text: editar != null && editar.precioEstimado > 0
            ? editar.precioEstimado.toStringAsFixed(2)
            : '');
    final costoCtrl = TextEditingController(
        text: editar != null && editar.costoPedido > 0
            ? editar.costoPedido.toStringAsFixed(2)
            : '');
    final notasCtrl = TextEditingController(text: editar?.notas ?? '');
    String? clienteId = editar?.clienteId;
    String? clienteNombre = editar?.clienteNombre;
    bool esListaPropia = editar?.esListaPropia ?? (_tabCtrl.index == 1);
    String? categoriaSeleccionada = editar?.categoria;
    final categoriaCtrl = TextEditingController(
        text: editar?.categoria != null && !_categoriasPredef.contains(editar!.categoria)
            ? editar.categoria!
            : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
            top: 24, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      esEdicion
                          ? 'Editar encargo'
                          : (esListaPropia ? 'Agregar a lista' : 'Nuevo encargo'),
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  // Etiqueta de guardado rápido
                  if (!esEdicion)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Solo descripción requerida',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 20),

                // ── Descripción (único campo obligatorio) ──
                TextField(
                  controller: descCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Producto / descripción *',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Cantidad ──
                TextField(
                  controller: cantCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Precios (fila) ──
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: precioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Precio venta',
                        prefixText: 'RD\$ ',
                        prefixIcon: Icon(Icons.sell_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: costoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Costo pedido',
                        prefixText: 'RD\$ ',
                        prefixIcon: Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                // Hint de ganancia en tiempo real
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: precioCtrl,
                  builder: (_, __, ___) {
                    final venta = double.tryParse(precioCtrl.text) ?? 0;
                    final costo = double.tryParse(costoCtrl.text) ?? 0;
                    if (venta > 0 && costo > 0) {
                      final ganancia = venta - costo;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          'Ganancia: ${AppFormatters.moneda(ganancia)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: ganancia >= 0 ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 8),

                // ── Cliente (solo en encargos, no en lista) ──
                if (!esListaPropia) ...[
                  _buildClienteSelector(
                    ctx: ctx,
                    setModal: setModal,
                    clienteNombre: clienteNombre,
                    onSeleccionado: (id, nombre) {
                      clienteId = id;
                      clienteNombre = nombre;
                    },
                  ),
                  const SizedBox(height: 12),
                ],


                // ── Categoría ──
                Text('Categoría',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._categoriasPredef.map((cat) {
                      final esOtro = cat == 'Otro';
                      final seleccionado = esOtro
                          ? (categoriaSeleccionada != null &&
                              !_categoriasPredef
                                  .sublist(0, _categoriasPredef.length - 1)
                                  .contains(categoriaSeleccionada))
                          : categoriaSeleccionada == cat;
                      return GestureDetector(
                        onTap: () {
                          setModal(() {
                            if (esOtro) {
                              categoriaSeleccionada = categoriaCtrl.text.trim().isEmpty
                                  ? 'Otro' : categoriaCtrl.text.trim();
                            } else {
                              categoriaSeleccionada = seleccionado ? null : cat;
                              categoriaCtrl.clear();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: seleccionado ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: seleccionado ? AppColors.primary : AppColors.cardBorder,
                              width: seleccionado ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            esOtro ? '✏️ Otra' : _categoriaEmoji(cat) + ' ' + cat,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                              color: seleccionado ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                // Campo texto para categoría personalizada
                if (categoriaSeleccionada != null &&
                    !_categoriasPredef
                        .sublist(0, _categoriasPredef.length - 1)
                        .contains(categoriaSeleccionada)) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoriaCtrl,
                    style: GoogleFonts.poppins(fontSize: 14),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => setModal(() {
                      categoriaSeleccionada = v.trim().isEmpty ? 'Otro' : v.trim();
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Escribe la categoría',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                                // ── Notas ──
                TextField(
                  controller: notasCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Botón guardar ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await EncargoService.guardarEncargo(
                        EncargoModel(
                          id: esEdicion ? editar.id : '',
                          empresaId: '',
                          clienteId: clienteId,
                          clienteNombre: clienteNombre,
                          descripcion: descCtrl.text.trim(),
                          cantidad: double.tryParse(cantCtrl.text) ?? 1,
                          precioEstimado: double.tryParse(precioCtrl.text) ?? 0,
                          costoPedido: double.tryParse(costoCtrl.text) ?? 0,
                          esListaPropia: esListaPropia,
                          estado: esEdicion ? editar.estado : 'pendiente',
                          notas: notasCtrl.text.trim().isEmpty
                              ? null
                              : notasCtrl.text.trim(),
                          categoria: (categoriaSeleccionada == 'Otro' || categoriaSeleccionada == null)
                              ? (categoriaCtrl.text.trim().isEmpty ? null : categoriaCtrl.text.trim())
                              : categoriaSeleccionada,
                        ),
                        esNuevo: !esEdicion,
                      );
                      _cargar(silencioso: true);
                    },
                    child: Text(
                      esEdicion
                          ? 'Guardar cambios'
                          : (esListaPropia ? 'Agregar a lista' : 'Guardar encargo'),
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ENTREGA — preguntar si está en POS
  // ──────────────────────────────────────────────────────────────

  void _mostrarCobroEncargo(EncargoModel encargo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Entregar encargo',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('¿"${encargo.descripcion}" está en tu inventario (POS)?',
              style: GoogleFonts.poppins()),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Si está en inventario, el POS maneja el cobro.\n'
                  'Si no está, cobra directamente aquí.',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: AppColors.textMuted))),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _cobrarSinPOS(encargo);
            },
            icon: const Icon(Icons.payment_rounded, size: 16),
            label: Text('No → Cobrar aquí',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const PosScreen()));
              if (!mounted) return;
              final ventaRealizada = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('¿Se vendió el encargo?',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  content: Text('¿Marcar "${encargo.descripcion}" como entregado?',
                      style: GoogleFonts.poppins(fontSize: 14)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx, false),
                        child: Text('Todavía no', style: GoogleFonts.poppins(color: AppColors.textMuted))),
                    ElevatedButton(onPressed: () => Navigator.pop(dCtx, true),
                        child: Text('Sí, entregado', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (ventaRealizada == true) {
                await EncargoService.actualizarEstado(encargo.id, 'entregado');
                _cargar(silencioso: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('¡Encargo entregado!'),
                    backgroundColor: AppColors.success,
                  ));
                }
              }
            },
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text('Sí → POS',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // COBRO SIN POS — contado / fiado / mixto
  // ──────────────────────────────────────────────────────────────

  void _cobrarSinPOS(EncargoModel encargo) {
    String tipoPago = 'contado'; // 'contado' | 'fiado' | 'mixto'
    String? clienteId = encargo.clienteId;
    String? clienteNombre = encargo.clienteNombre;
    final adelantoCtrl = TextEditingController();
    final sinPrecio = encargo.precioEstimado <= 0;
    final precioCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final precio = sinPrecio
              ? (double.tryParse(precioCtrl.text) ?? 0)
              : encargo.precioEstimado;
          final adelanto = double.tryParse(adelantoCtrl.text) ?? 0;
          final saldoFiado =
              tipoPago == 'mixto' ? (precio - adelanto).clamp(0.0, double.infinity) : precio;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
              top: 24, left: 24, right: 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cobrar encargo',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(encargo.descripcion,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                  if (precio > 0) ...[
                    const SizedBox(height: 2),
                    Text(AppFormatters.moneda(precio),
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                  if (sinPrecio) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: precioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.poppins(fontSize: 14),
                      onChanged: (_) => setModal(() {}),
                      decoration: const InputDecoration(
                        labelText: '¿Cuánto cuesta el encargo?',
                        prefixText: 'RD\$ ',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Selector de tipo de pago ──
                  Text('¿Cómo paga el cliente?',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _tipoPagoChip(
                      label: '💵 Contado',
                      seleccionado: tipoPago == 'contado',
                      onTap: () => setModal(() => tipoPago = 'contado'),
                    ),
                    const SizedBox(width: 8),
                    _tipoPagoChip(
                      label: '📋 Fiado',
                      seleccionado: tipoPago == 'fiado',
                      onTap: () => setModal(() => tipoPago = 'fiado'),
                    ),
                    const SizedBox(width: 8),
                    _tipoPagoChip(
                      label: '🤝 Abono',
                      seleccionado: tipoPago == 'mixto',
                      onTap: () => setModal(() => tipoPago = 'mixto'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Cliente (requerido si fiado o mixto) ──
                  if (tipoPago != 'contado') ...[
                    _buildClienteSelector(
                      ctx: ctx,
                      setModal: setModal,
                      clienteNombre: clienteNombre,
                      requerido: true,
                      onSeleccionado: (id, nombre) {
                        clienteId = id;
                        clienteNombre = nombre;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Adelanto (solo si mixto) ──
                  if (tipoPago == 'mixto') ...[
                    TextField(
                      controller: adelantoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: GoogleFonts.poppins(fontSize: 14),
                      onChanged: (_) => setModal(() {}),
                      decoration: const InputDecoration(
                        labelText: '¿Cuánto abona al recibir?',
                        prefixText: 'RD\$ ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (saldoFiado > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.schedule_rounded,
                              size: 15, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text(
                            'Queda fiado: ${AppFormatters.moneda(saldoFiado)}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // ── Info de fiado completo ──
                  if (tipoPago == 'fiado' && precio > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.schedule_rounded,
                            size: 15, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Text(
                          'Todo fiado: ${AppFormatters.moneda(precio)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Botón confirmar ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (precio <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Escribe el precio del encargo',
                                style: GoogleFonts.poppins()),
                            backgroundColor: AppColors.danger,
                          ));
                          return;
                        }
                        if (tipoPago == 'mixto' && adelanto <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Escribe cuánto abona el cliente',
                                style: GoogleFonts.poppins()),
                            backgroundColor: AppColors.danger,
                          ));
                          return;
                        }
                        // Fiado/Abono requieren cliente
                        if (tipoPago != 'contado' && clienteId == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Selecciona un cliente para el fiado',
                                style: GoogleFonts.poppins()),
                            backgroundColor: AppColors.danger,
                          ));
                          return;
                        }
                        // Mixto: el adelanto no puede superar el precio
                        // Si abona todo, es contado
                        if (tipoPago == 'mixto' && adelanto >= precio) {
                          setModal(() => tipoPago = 'contado');
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Paga completo: se cambió a Contado. Toca confirmar.',
                                style: GoogleFonts.poppins()),
                          ));
                          return;
                        }
                        Navigator.pop(ctx);
                        await _procesarEntrega(
                          encargo: encargo,
                          tipoPago: tipoPago,
                          clienteId: clienteId,
                          clienteNombre: clienteNombre,
                          adelanto: adelanto,
                          precio: precio,
                        );
                      },
                      child: Text(
                        tipoPago == 'contado'
                            ? 'Confirmar entrega'
                            : tipoPago == 'fiado'
                                ? 'Crear fiado y entregar'
                                : 'Registrar adelanto y entregar',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tipoPagoChip({
    required String label,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.primary : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado ? AppColors.primary : AppColors.cardBorder,
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: seleccionado ? Colors.white : AppColors.textSecondary,
              )),
        ),
      ),
    );
  }

  Future<void> _procesarEntrega({
    required EncargoModel encargo,
    required String tipoPago,
    String? clienteId,
    String? clienteNombre,
    double adelanto = 0,
    required double precio,
  }) async {
    try {
      // 0. Inventario que se arma solo: el artículo queda guardado como producto
      final cant = encargo.cantidad > 0 ? encargo.cantidad : 1.0;
      final prod = await InventarioService.obtenerOCrear(
        nombre: encargo.descripcion,
        precio: precio / cant,
        costo: encargo.costoPedido > 0 ? encargo.costoPedido / cant : 0,
      );
      // 1. Registrar como VENTA (entra en Reportes, Caja, Inicio y Actividad)
      final ok = await VentaService.registrarVentaEncargo(
        productoId: prod?.id,
        descripcion: encargo.descripcion,
        cantidad: encargo.cantidad,
        precioTotal: precio,
        costoTotal: encargo.costoPedido,
        tipoPago: tipoPago,
        clienteId: clienteId,
        clienteNombre: clienteNombre,
        abono: tipoPago == 'mixto' ? adelanto : 0,
      );
      if (!ok) throw Exception('no se pudo registrar la venta');
      // 2. Marcar encargo como entregado
      await EncargoService.actualizarEstado(encargo.id, 'entregado');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudo entregar el encargo: $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }

    _cargar(silencioso: true);

    if (mounted) {
      final msg = tipoPago == 'contado'
          ? '¡Encargo entregado!'
          : tipoPago == 'fiado'
              ? '¡Encargo entregado y fiado creado!'
              : '¡Encargo entregado! Abono de ${AppFormatters.moneda(adelanto)} registrado.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.success,
      ));
      // Ofrecer recibo
      final saldoFiadoFinal = tipoPago == 'contado' ? 0.0
          : tipoPago == 'fiado' ? precio
          : (precio - adelanto).clamp(0.0, double.infinity);
      _ofrecerReciboEncargo(
        encargo: encargo,
        tipoPago: tipoPago,
        montoCobrado: tipoPago == 'mixto' ? adelanto : (tipoPago == 'contado' ? precio : 0),
        saldoFiado: saldoFiadoFinal,
        clienteNombre: clienteNombre,
      );
    }
  }

  void _ofrecerReciboEncargo({
    required EncargoModel encargo,
    required String tipoPago,
    required double montoCobrado,
    required double saldoFiado,
    String? clienteNombre,
  }) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetCtx2) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + MediaQuery.of(sheetCtx2).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2)),
          ),
          const Icon(Icons.receipt_long_rounded,
              color: AppColors.primary, size: 44),
          const SizedBox(height: 12),
          Text('Comprobante de entrega',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            tipoPago == 'contado' ? '✅ Pagado en contado' :
            tipoPago == 'fiado' ? 'Fiado: ${AppFormatters.moneda(saldoFiado)}' :
            'Saldo fiado: ${AppFormatters.moneda(saldoFiado)}',
            style: GoogleFonts.poppins(fontSize: 13,
                color: tipoPago == 'contado' ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: Text('Compartir por WhatsApp / SMS',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                Navigator.pop(context);
                ReciboService.compartirTextoEncargo(
                  encargo: encargo,
                  tipoPago: tipoPago,
                  montoCobrado: montoCobrado,
                  saldoFiado: saldoFiado,
                  clienteNombre: clienteNombre,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              icon: Icon(Icons.print_rounded, color: AppColors.primary),
              label: Text('Imprimir recibo',
                  style: GoogleFonts.poppins(fontSize: 14,
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                Navigator.pop(context);
                ReciboService.imprimirTextoEncargo(
                  encargo: encargo,
                  tipoPago: tipoPago,
                  montoCobrado: montoCobrado,
                  saldoFiado: saldoFiado,
                  clienteNombre: clienteNombre,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No, gracias',
                style: GoogleFonts.poppins(color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ProGate(
      nombreFuncion: 'Encargos',
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Encargos'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Encargos (${_encargos.length})'),
            Tab(text: 'Lista (${_lista.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildEncargos(),
                _buildLista(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: AppColors.primary,
        tooltip: 'Nuevo',
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    ));
  }

  Widget _buildEncargos() {
    if (_encargos.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Sin encargos',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Agrega los productos que\ntus clientes han encargado',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _encargos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _EncargoCard(
          encargo: _encargos[i],
          onEditar: () => _mostrarFormulario(editar: _encargos[i]),
          onEstado: (estado) =>
              _cambiarEstadoRapido(_encargos[i], estado, esLista: false),
          onEliminar: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('¿Eliminar encargo?',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                content: Text(
                    '¿Seguro que deseas eliminar "${_encargos[i].descripcion}"?',
                    style: GoogleFonts.poppins(fontSize: 14)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancelar',
                        style: GoogleFonts.poppins(color: AppColors.textMuted))),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Eliminar',
                        style: GoogleFonts.poppins(
                            color: AppColors.danger, fontWeight: FontWeight.w700))),
                ],
              ),
            );
            if (ok == true) {
              await EncargoService.eliminarEncargo(_encargos[i].id);
              _cargar(silencioso: true);
            }
          },
          onEntregar: () => _mostrarCobroEncargo(_encargos[i]),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_lista.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.checklist_rounded, size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Lista vacía',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Agrega los productos que\nnecesitas comprar',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
      ]));
    }

    // Agrupar por categoría manteniendo orden de inserción
    final Map<String, List<EncargoModel>> grupos = {};
    for (final item in _lista) {
      final cat = item.categoria ?? 'Sin categoría';
      grupos.putIfAbsent(cat, () => []).add(item);
    }

    // Construir lista plana de widgets
    final items = <_ListaItem>[];
    for (final cat in grupos.keys) {
      items.add(_ListaItem.header(cat));
      for (final enc in grupos[cat]!) {
        items.add(_ListaItem.encargo(enc));
      }
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          if (item.isHeader) {
            return _buildCategoriaHeader(item.categoria!);
          }
          final encargo = item.encargo!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ListaCard(
              encargo: encargo,
              onComprado: () {
                final nuevoEstado = encargo.estado == 'comprado' ? 'pendiente' : 'comprado';
                _cambiarEstadoRapido(encargo, nuevoEstado, esLista: true);
              },
              onEliminar: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('¿Eliminar item?',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    content: Text(
                        '¿Eliminar "${encargo.descripcion}"?',
                        style: GoogleFonts.poppins(fontSize: 14)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar',
                            style: GoogleFonts.poppins(color: AppColors.textMuted))),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Eliminar',
                            style: GoogleFonts.poppins(
                                color: AppColors.danger, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
                if (ok == true) {
                  await EncargoService.eliminarEncargo(encargo.id);
                  _cargar(silencioso: true);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriaHeader(String categoria) {
    final sinCat = categoria == 'Sin categoría';
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Row(children: [
        if (!sinCat) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_categoriaEmoji(categoria),
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(categoria,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ]),
          ),
        ] else ...[
          Text('General',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
        ],
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.cardBorder)),
      ]),
    );
  }
}

String _categoriaEmoji(String cat) {
  switch (cat) {
    case 'Supermercado': return '🛒';
    case 'Farmacia': return '💊';
    case 'Ferretería': return '🔧';
    case 'Panadería': return '🍞';
    case 'Carnicería': return '🥩';
    case 'Limpieza': return '🧹';
    case 'Bebidas': return '🧃';
    case 'Electrónica': return '💡';
    case 'Ropa': return '👕';
    default: return '📦';
  }
}

// ──────────────────────────────────────────────────────────────
// HELPER para lista agrupada
// ──────────────────────────────────────────────────────────────

class _ListaItem {
  final bool isHeader;
  final String? categoria;
  final EncargoModel? encargo;

  _ListaItem.header(this.categoria) : isHeader = true, encargo = null;
  _ListaItem.encargo(this.encargo) : isHeader = false, categoria = null;
}

// ──────────────────────────────────────────────────────────────
// CARD DE ENCARGO
// ──────────────────────────────────────────────────────────────

class _EncargoCard extends StatelessWidget {
  final EncargoModel encargo;
  final Function(String) onEstado;
  final VoidCallback onEliminar;
  final VoidCallback onEntregar;
  final VoidCallback onEditar;

  const _EncargoCard({
    required this.encargo,
    required this.onEstado,
    required this.onEliminar,
    required this.onEntregar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    Color bg;
    switch (encargo.estado) {
      case 'llego':
        color = AppColors.warning;
        bg = AppColors.warningSurface;
        label = '📦 Llegó';
        break;
      case 'entregado':
        color = AppColors.success;
        bg = AppColors.successSurface;
        label = '✓ Entregado';
        break;
      default:
        color = AppColors.colorFiado;
        bg = AppColors.accentSurface;
        label = '⏳ Pendiente';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Fila título + estado + acciones ──
            Row(children: [
              Expanded(
                child: Text(encargo.descripcion,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEditar,
                child: const Icon(Icons.edit_outlined,
                    color: AppColors.textMuted, size: 17),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEliminar,
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 17),
              ),
            ]),
            const SizedBox(height: 8),

            // ── Fila info (cliente, cantidad, precio) ──
            Wrap(spacing: 12, runSpacing: 4, children: [
              if (encargo.clienteNombre != null)
                _infoChip(Icons.person_outline, encargo.clienteNombre!),
              _infoChip(Icons.numbers_rounded, 'x${encargo.cantidad.toStringAsFixed(0)}'),
              if (encargo.precioEstimado > 0)
                _infoChip(Icons.sell_rounded,
                    AppFormatters.moneda(encargo.precioEstimado)),
              if (encargo.costoPedido > 0)
                _infoChip(Icons.shopping_cart_outlined,
                    'Costo: ${AppFormatters.moneda(encargo.costoPedido)}'),
            ]),

            // ── Ganancia ──
            if (encargo.gananciaEstimada != 0) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(
                  encargo.gananciaEstimada >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14,
                  color: encargo.gananciaEstimada >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ganancia: ${AppFormatters.moneda(encargo.gananciaEstimada)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: encargo.gananciaEstimada >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ]),
            ],

            if (encargo.categoria != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_categoriaEmoji(encargo.categoria!)} ${encargo.categoria}',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
              ),
            ],
            if (encargo.notas != null) ...[
              const SizedBox(height: 6),
              Text(encargo.notas!,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic)),
            ],
          ]),
        ),

        // ── Acciones de estado ──
        if (encargo.estado != 'entregado')
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.cardBorder))),
            child: Row(children: [
              if (encargo.estado == 'pendiente')
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => onEstado('llego'),
                    icon: const Icon(Icons.inventory_2_rounded,
                        size: 16, color: AppColors.warning),
                    label: Text('Llegó',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning)),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42)),
                  ),
                ),
              if (encargo.estado == 'llego')
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEntregar,
                    icon: const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.success),
                    label: Text('Entregar',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42)),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Text(texto,
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────
// CARD DE LISTA DE COMPRAS
// ──────────────────────────────────────────────────────────────

class _ListaCard extends StatelessWidget {
  final EncargoModel encargo;
  final VoidCallback onComprado;
  final VoidCallback onEliminar;

  const _ListaCard({
    required this.encargo,
    required this.onComprado,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final comprado = encargo.estado == 'comprado';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: comprado ? AppColors.successSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comprado
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onComprado,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: comprado ? AppColors.success : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: comprado ? AppColors.success : AppColors.textMuted,
                width: 2,
              ),
            ),
            child: comprado
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(encargo.descripcion,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: comprado ? AppColors.textMuted : AppColors.textPrimary,
                    decoration: comprado ? TextDecoration.lineThrough : null)),
            if (encargo.cantidad > 1 ||
                encargo.precioEstimado > 0 ||
                encargo.costoPedido > 0)
              Text(
                [
                  if (encargo.cantidad > 1)
                    'x${encargo.cantidad.toStringAsFixed(0)}',
                  if (encargo.costoPedido > 0)
                    AppFormatters.moneda(encargo.costoPedido),
                ].join('  '),
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
              ),
          ]),
        ),
        GestureDetector(
          onTap: onEliminar,
          child: const Icon(Icons.delete_outline_rounded,
              color: AppColors.textMuted, size: 18),
        ),
      ]),
    );
  }
}
