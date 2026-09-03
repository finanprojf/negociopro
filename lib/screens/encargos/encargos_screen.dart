import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/encargo_model.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import '../../services/encargo_service.dart';
import '../../services/cliente_service.dart';
import '../ventas/pos_screen.dart';

class EncargosScreen extends StatefulWidget {
  const EncargosScreen({super.key});

  @override
  State<EncargosScreen> createState() => _EncargosScreenState();
}

class _EncargosScreenState extends State<EncargosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
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

  Future<void> _cargar() async {
    setState(() => _loading = true);
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
      if (mounted) setState(() => _loading = false);
    }
  }

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

 void _mostrarCobroEncargo(EncargoModel encargo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Entregar encargo',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('¿El producto "${encargo.descripcion}" está en tu inventario?',
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
              Expanded(child: Text(
                'Se abrirá el POS. Busca el producto, cobra y regresa para confirmar la entrega.',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.poppins(
                color: AppColors.textMuted))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final ventaRealizada = await Navigator.push<bool>(context,
                  MaterialPageRoute(builder: (_) => const PosScreen()));
              if (ventaRealizada == true) {
                await EncargoService.actualizarEstado(encargo.id, 'entregado');
                _cargar();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('¡Encargo entregado!'),
                    backgroundColor: AppColors.success,
                  ));
                }
              }
            },
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text('Abrir POS', style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          Text('Nuevo',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildEncargos() {
    if (_encargos.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
        const Icon(Icons.shopping_bag_outlined,
            size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Sin encargos',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Agrega los productos que\ntus clientes han encargado',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _encargos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _EncargoCard(
          encargo: _encargos[i],
          onEstado: (estado) async {
            await EncargoService.actualizarEstado(_encargos[i].id, estado);
            _cargar();
          },
          onEliminar: () async {
            await EncargoService.eliminarEncargo(_encargos[i].id);
            _cargar();
          },
          onEntregar: () => _mostrarCobroEncargo(_encargos[i]),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_lista.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
        const Icon(Icons.checklist_rounded,
            size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Lista vacía',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Agrega los productos que\nnecesitas comprar',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ListaCard(
          encargo: _lista[i],
          onComprado: () async {
            final nuevoEstado =
                _lista[i].estado == 'comprado' ? 'pendiente' : 'comprado';
            await EncargoService.actualizarEstado(_lista[i].id, nuevoEstado);
            _cargar();
          },
          onEliminar: () async {
            await EncargoService.eliminarEncargo(_lista[i].id);
            _cargar();
          },
        ),
      ),
    );
  }

  void _mostrarFormulario() {
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: '1');
    final precioCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String? clienteId;
    String? clienteNombre;
    bool esListaPropia = _tabCtrl.index == 1;

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
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(esListaPropia ? 'Agregar a lista' : 'Nuevo encargo',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: descCtrl,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Producto / descripción *',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: cantCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                controller: precioCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Precio est.',
                  prefixText: 'RD\$ ',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            if (!esListaPropia) ...[
              GestureDetector(
                onTap: () async {
                  final clientes = await ClienteService.getClientes();
                  if (!ctx.mounted) return;
                  final elegido = await showDialog<ClienteModel>(
                    context: ctx,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Seleccionar cliente',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700)),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 300,
                        child: ListView.builder(
                          itemCount: clientes.length,
                          itemBuilder: (_, i) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.colorClientes
                                  .withValues(alpha: 0.1),
                              child: Text(clientes[i].iniciales,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.colorClientes)),
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
                              style: GoogleFonts.poppins(
                                  color: AppColors.textMuted))),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx, null);
                            await _agregarClienteRapido(ctx, setModal,
                                (id, nombre) {
                              clienteId = id;
                              clienteNombre = nombre;
                            });
                          },
                          child: Text('+ Nuevo cliente',
                              style: GoogleFonts.poppins(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700))),
                      ],
                    ),
                  );
                  if (elegido != null) {
                    setModal(() {
                      clienteId = elegido.id;
                      clienteNombre = elegido.nombre;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person_outline,
                        color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Text(
                        clienteNombre ?? 'Seleccionar cliente (opcional)',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: clienteNombre != null
                                ? AppColors.textPrimary
                                : AppColors.textMuted)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await EncargoService.guardarEncargo(EncargoModel(
                    id: '',
                    empresaId: '',
                    clienteId: clienteId,
                    descripcion: descCtrl.text.trim(),
                    cantidad: double.tryParse(cantCtrl.text) ?? 1,
                    precioEstimado: double.tryParse(precioCtrl.text) ?? 0,
                    esListaPropia: esListaPropia,
                    notas: notasCtrl.text.trim().isEmpty
                        ? null
                        : notasCtrl.text.trim(),
                  ));
                  _cargar();
                },
                child: Text(
                    esListaPropia ? 'Agregar a lista' : 'Guardar encargo',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EncargoCard extends StatelessWidget {
  final EncargoModel encargo;
  final Function(String) onEstado;
  final VoidCallback onEliminar;
  final VoidCallback onEntregar;

  const _EncargoCard({
    required this.encargo,
    required this.onEstado,
    required this.onEliminar,
    required this.onEntregar,
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
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Expanded(
                  child: Text(encargo.descripcion,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEliminar,
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (encargo.clienteNombre != null) ...[
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(encargo.clienteNombre!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.numbers_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('x${encargo.cantidad.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
              if (encargo.precioEstimado > 0) ...[
                const SizedBox(width: 12),
                const Icon(Icons.attach_money_rounded,
                    size: 14, color: AppColors.textMuted),
                Text(AppFormatters.moneda(encargo.precioEstimado),
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ]),
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
        if (encargo.estado != 'entregado')
          Container(
            decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.cardBorder))),
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
                )),
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
                )),
            ]),
          ),
      ]),
    );
  }
}

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
                color:
                    comprado ? AppColors.success : AppColors.textMuted,
                width: 2,
              ),
            ),
            child: comprado
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(encargo.descripcion,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: comprado
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  decoration:
                      comprado ? TextDecoration.lineThrough : null)),
          if (encargo.cantidad > 1 || encargo.precioEstimado > 0)
            Text(
              '${encargo.cantidad > 1 ? 'x${encargo.cantidad.toStringAsFixed(0)}' : ''}'
              '${encargo.precioEstimado > 0 ? '  ${AppFormatters.moneda(encargo.precioEstimado)}' : ''}',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textMuted),
            ),
        ])),
        GestureDetector(
          onTap: onEliminar,
          child: const Icon(Icons.delete_outline_rounded,
              color: AppColors.textMuted, size: 18),
        ),
      ]),
    );
  }
}