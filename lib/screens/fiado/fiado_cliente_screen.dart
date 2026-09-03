import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../utils/formatters.dart';
import '../../services/fiado_service.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
class FiadoClienteScreen extends StatefulWidget {
  final ClienteModel cliente;
  const FiadoClienteScreen({super.key, required this.cliente});

  @override
  State<FiadoClienteScreen> createState() => _FiadoClienteScreenState();
}

class _FiadoClienteScreenState extends State<FiadoClienteScreen> {
  List<Map<String, dynamic>> _fiados = [];
  bool _loading = true;

  double get _totalPendiente => _fiados
      .where((f) => f['estado'] == 'activo')
      .fold(0, (s, f) => s + (f['saldo_pendiente'] as num).toDouble());

  bool get _tienePendiente => _totalPendiente > 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

 Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      // Cargar local primero
      final db = await LocalDatabase.database;
      final localFiados = await db.query('fiados',
          where: 'cliente_id = ?',
          whereArgs: [widget.cliente.id],
          orderBy: 'created_at DESC');

      if (await SupabaseService.isOnlineAsync) {
        try {
          final res = await SupabaseService.client
              .from('fiados')
              .select('''
                *,
                ventas(
                  numero_venta,
                  detalle_ventas(nombre_producto, cantidad, precio_unitario)
                )
              ''')
              .eq('cliente_id', widget.cliente.id)
              .order('created_at', ascending: false);

          // Guardar en local
          for (final m in res) {
            final map = Map<String, dynamic>.from(m);
            map.remove('ventas');
            map['synced'] = 1;
            try { await LocalDatabase.insertar('fiados', map); } catch (_) {}
          }

        // Combinar online con locales no sincronizados
          final idsOnline = res.map((m) => m['id'] as String).toSet();
          final localesPendientes = localFiados
              .where((m) => !idsOnline.contains(m['id'] as String))
              .toList();
         // Agregar detalles de venta a los locales pendientes
          final pendientesConDetalles = await Future.wait(
            localesPendientes.map((f) async {
              final map = Map<String, dynamic>.from(f);
              final ventaId = f['venta_id'] as String?;
              if (ventaId != null) {
                final db = await LocalDatabase.database;
                final detalles = await db.query('detalle_ventas',
                    where: 'venta_id = ?', whereArgs: [ventaId]);
                if (detalles.isNotEmpty) {
                  map['ventas'] = {
                    'numero_venta': null,
                    'detalle_ventas': detalles,
                  };
                }
              }
              return map;
            }).toList(),
          );

          final combinados = [
            ...List<Map<String, dynamic>>.from(res),
            ...pendientesConDetalles,
          ];
          if (mounted) {
            setState(() {
              _fiados = combinados;
              _loading = false;
            });
          }
          return;
        } catch (_) {}
      }

    // Sin internet usar local con detalles de venta
      final fiadosConDetalles = await Future.wait(
        localFiados.map((f) async {
          final map = Map<String, dynamic>.from(f);
          final ventaId = f['venta_id'] as String?;
          if (ventaId != null) {
            final db = await LocalDatabase.database;
            final detalles = await db.query('detalle_ventas',
                where: 'venta_id = ?', whereArgs: [ventaId]);
            if (detalles.isNotEmpty) {
              map['ventas'] = {
                'numero_venta': null,
                'detalle_ventas': detalles,
              };
            }
          }
          return map;
        }).toList(),
      );

      if (mounted) {
        setState(() {
          _fiados = fiadosConDetalles;
          _loading = false;
        });
      }
    } catch (e) {
      // Error cargando fiados
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _eliminarFiado(Map<String, dynamic> fiado) async {
    final saldo = (fiado['saldo_pendiente'] as num).toDouble();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(saldo > 0 ? '⚠ Fiado con deuda' : 'Eliminar fiado',
            style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Text(saldo > 0
            ? 'Este fiado aún tiene ${AppFormatters.moneda(saldo)} pendiente.\n\n¿Deseas eliminarlo de todas formas?'
            : '¿Deseas eliminar este fiado?',
            style: const TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('No, cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Local primero (funciona offline)
      await LocalDatabase.eliminar('fiados', 'id', fiado['id'] as String);
      if (await SupabaseService.isOnlineAsync) {
        await SupabaseService.client.from('fiados').delete().eq('id', fiado['id']);
      }
      _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fiado eliminado'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al eliminar'),
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
        title: Text('Fiado — ${widget.cliente.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historial de pagos',
            onPressed: () => _mostrarHistorial(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _fiados.isEmpty
              ? _buildEmpty()
              : Column(children: [
                  _buildResumenTop(),
                  Expanded(child: _buildLista()),
                ]),
    );
  }

  Widget _buildResumenTop() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _tienePendiente
            ? AppColors.colorFiado.withValues(alpha: 0.08)
            : AppColors.successSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _tienePendiente
              ? AppColors.colorFiado.withValues(alpha: 0.2)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.colorClientes.withValues(alpha: 0.12),
            child: Text(widget.cliente.iniciales,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.colorClientes)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.cliente.nombre,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (widget.cliente.telefono != null)
              Text(widget.cliente.telefono!,
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.moneda(_totalPendiente),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _tienePendiente
                        ? AppColors.colorFiado : AppColors.success)),
            Text(_tienePendiente ? 'pendiente' : '¡Al día!',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    color: _tienePendiente
                        ? AppColors.colorFiado : AppColors.success)),
          ]),
        ]),
        if (_tienePendiente) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _mostrarAbono(monto: null),
                icon: const Icon(Icons.payments_rounded,
                    color: AppColors.colorFiado, size: 18),
                label: const Text('Abonar',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600, color: AppColors.colorFiado)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.colorFiado),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _mostrarAbono(monto: _totalPendiente),
                icon: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Saldar todo',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorFiado,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _fiados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final f = _fiados[i];
        final estado = f['estado'] as String;
        final saldo = (f['saldo_pendiente'] as num).toDouble();
      final original = ((f['monto_original'] ?? f['saldo_pendiente'] ?? 0) as num).toDouble();
        final pagado = original - saldo;
        final porcentaje = original > 0 ? pagado / original : 0.0;

        // Obtener productos de la venta
        final venta = f['ventas'] as Map<String, dynamic>?;
        final detalles = venta != null
            ? (venta['detalle_ventas'] as List? ?? [])
            : [];

        Color color; String label; Color bg;
        if (estado == 'pagado') {
          color = AppColors.success; bg = AppColors.successSurface; label = '✓ Pagado';
        } else if (estado == 'vencido') {
          color = AppColors.danger; bg = AppColors.dangerSurface; label = '⚠ Vencido';
        } else {
          color = AppColors.colorFiado;
          bg = AppColors.dangerSurface.withValues(alpha: 0.2);
          label = 'Activo';
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
              child: Column(children: [
                Row(children: [
                  Text(AppFormatters.fecha(DateTime.parse(f['created_at'])),
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 12, color: AppColors.textMuted)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(label, style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _eliminarFiado(f),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.textMuted, size: 18),
                  ),
                ]),
                // Productos
                if (detalles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: detalles.map((d) {
                        final nombre = d['nombre_producto'] as String;
                        final cantidad = (d['cantidad'] as num).toDouble();
                        final precio = (d['precio_unitario'] as num).toDouble();
                        return Text(
                          '• $nombre x${cantidad.toStringAsFixed(0)} — ${AppFormatters.moneda(precio * cantidad)}',
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 11, color: AppColors.textSecondary),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _Col('Original', AppFormatters.moneda(original), AppColors.textPrimary),
                  _Col('Pagado', AppFormatters.moneda(pagado), AppColors.success),
                  _Col('Pendiente', AppFormatters.moneda(saldo), AppColors.colorFiado),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: porcentaje.toDouble(),
                    backgroundColor: AppColors.cardBorder,
                    color: estado == 'pagado' ? AppColors.success : AppColors.colorFiado,
                    minHeight: 6,
                  ),
                ),
              ]),
            ),
            if (estado == 'activo')
              Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.cardBorder))),
                child: TextButton.icon(
                  onPressed: () => _mostrarAbonoFiado(f),
                  icon: const Icon(Icons.payments_rounded,
                      size: 16, color: AppColors.colorFiado),
                  label: const Text('Abonar a este',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.colorFiado)),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 42)),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.handshake_outlined, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      Text('${widget.cliente.nombre} no tiene fiados',
          style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 16, color: AppColors.textMuted)),
    ]));
  }

  void _mostrarAbono({double? monto}) {
    final ctrl = TextEditingController(
        text: monto != null ? monto.toStringAsFixed(2) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final ingresado = double.tryParse(ctrl.text) ?? 0;
          final montoReal = ingresado.clamp(0.0, _totalPendiente);
          final quedan = (_totalPendiente - montoReal).clamp(0.0, double.infinity);
          final vuelto = ingresado > _totalPendiente ? ingresado - _totalPendiente : 0.0;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24, left: 24, right: 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(monto != null ? 'Saldar todo' : 'Registrar abono',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Total pendiente: ${AppFormatters.moneda(_totalPendiente)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                autofocus: monto == null,
                onChanged: (_) => setModal(() {}),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 28,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Monto', prefixText: 'RD\$ '),
              ),
              const SizedBox(height: 14),
              // Preview en tiempo real
              if (ingresado > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Se aplica a deuda',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 13, color: AppColors.primary)),
                      Text(AppFormatters.moneda(montoReal),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Le quedan al cliente',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        quedan <= 0 ? 'Deuda saldada ✓' : AppFormatters.moneda(quedan),
                        style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: quedan <= 0 ? AppColors.success : AppColors.colorFiado),
                      ),
                    ]),
                  ]),
                ),
                if (vuelto > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Row(children: [
                        Icon(Icons.currency_exchange_rounded,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Text('Vuelto al cliente',
                            style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                      ]),
                      Text(AppFormatters.moneda(vuelto),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: AppColors.success)),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: ingresado <= 0 ? null : () async {
                    Navigator.pop(ctx);
                    double restante = montoReal;
                    final fiadosActivos = _fiados
                        .where((f) => f['estado'] == 'activo')
                        .toList();
                    for (final f in fiadosActivos) {
                      if (restante <= 0) break;
                      final saldo = (f['saldo_pendiente'] as num).toDouble();
                      final abonoEste = restante >= saldo ? saldo : restante;
                      await FiadoService.registrarAbono(
                          f['id'], f['cliente_id'], abonoEste, 'efectivo');
                      restante -= abonoEste;
                    }
                    _cargar();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(quedan <= 0 ? '¡Deuda saldada!' : 'Abono registrado'),
                        backgroundColor: AppColors.success,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorFiado),
                  child: Text(quedan <= 0 ? 'Confirmar — saldar todo' : 'Confirmar abono',
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _mostrarAbonoFiado(Map<String, dynamic> fiado) {
    final ctrl = TextEditingController();
    final saldo = (fiado['saldo_pendiente'] as num).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final ingresado = double.tryParse(ctrl.text) ?? 0;
          final montoReal = ingresado.clamp(0.0, saldo) as double;
          final quedan = (saldo - montoReal).clamp(0.0, double.infinity);
          final vuelto = ingresado > saldo ? ingresado - saldo : 0.0;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              top: 24, left: 24, right: 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Abonar a este fiado',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Pendiente: ${AppFormatters.moneda(saldo)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                autofocus: true,
                onChanged: (_) => setModal(() {}),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 28,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                    labelText: 'Monto del abono', prefixText: 'RD\$ '),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () { ctrl.text = (saldo * 0.5).toStringAsFixed(2); setModal(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder)),
                    child: const Center(child: Text('50%',
                        style: TextStyle(fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () { ctrl.text = saldo.toStringAsFixed(2); setModal(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder)),
                    child: const Center(child: Text('Todo',
                        style: TextStyle(fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              // Preview en tiempo real
              if (ingresado > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Se aplica a deuda',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 13, color: AppColors.primary)),
                      Text(AppFormatters.moneda(montoReal),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Le quedan al cliente',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        quedan <= 0 ? 'Deuda saldada ✓' : AppFormatters.moneda(quedan),
                        style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: quedan <= 0 ? AppColors.success : AppColors.colorFiado),
                      ),
                    ]),
                  ]),
                ),
                if (vuelto > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Row(children: [
                        Icon(Icons.currency_exchange_rounded,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Text('Vuelto al cliente',
                            style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                      ]),
                      Text(AppFormatters.moneda(vuelto),
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: AppColors.success)),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: ingresado <= 0 ? null : () async {
                    Navigator.pop(ctx);
                    await FiadoService.registrarAbono(
                      fiado['id'], fiado['cliente_id'], montoReal, 'efectivo',
                    );
                    _cargar();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorFiado),
                  child: const Text('Confirmar abono',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _mostrarHistorial() async {
    try {
      List<Map<String, dynamic>> res = [];

      if (await SupabaseService.isOnlineAsync) {
        try {
          final data = await SupabaseService.client
              .from('abonos_fiado')
              .select()
              .eq('cliente_id', widget.cliente.id)
              .order('created_at', ascending: false);
          res = List<Map<String, dynamic>>.from(data);
        } catch (_) {}
      }

      // Fallback SQLite
      if (res.isEmpty) {
        final empresaId = await SupabaseService.getEmpresaId();
        if (empresaId != null) {
          final local = await LocalDatabase.consultar('abonos_fiado', empresaId);
          res = local
              .where((m) => m['cliente_id'] == widget.cliente.id)
              .toList();
        }
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.history_rounded, color: AppColors.colorFiado),
                const SizedBox(width: 10),
                const Text('Historial de pagos',
                    style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${res.length} pagos',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 13, color: AppColors.textMuted)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: res.isEmpty
                  ? const Center(child: Text('Sin pagos registrados',
                      style: TextStyle(fontFamily: 'Poppins',
                          color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: res.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final p = res[i];
                        final monto = (p['monto'] as num).toDouble();
                        return Row(children: [
                          Container(width: 40, height: 40,
                              decoration: BoxDecoration(
                                  color: AppColors.successSurface,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.payments_rounded,
                                  color: AppColors.success, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(AppFormatters.fechaHora(
                                DateTime.parse(p['created_at'])),
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 12, color: AppColors.textMuted)),
                            Text(p['metodo_pago'] ?? 'efectivo',
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ])),
                          Text(AppFormatters.moneda(monto),
                              style: const TextStyle(fontFamily: 'Poppins',
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.success)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Cancelar abono',
                                      style: TextStyle(fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w700)),
                                  content: Text(
                                    '¿Cancelar el abono de ${AppFormatters.moneda(monto)}? La deuda volverá a su estado anterior.',
                                    style: const TextStyle(fontFamily: 'Poppins')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('No')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Sí, cancelar',
                                          style: TextStyle(color: AppColors.danger,
                                              fontWeight: FontWeight.w700))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await FiadoService.cancelarAbono(
                                  p['id'] as String,
                                  p['fiado_id'] as String,
                                  monto,
                                );
                                Navigator.pop(context);
                                _cargar();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.undo_rounded,
                                  color: AppColors.danger, size: 16),
                            ),
                          ),
                        ]);
                      },
                    ),
            ),
          ]),
        ),
      );
    } catch (_) {}
  }
}

class _Col extends StatelessWidget {
  final String label; final String valor; final Color color;
  const _Col(this.label, this.valor, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 11, color: AppColors.textMuted)),
    const SizedBox(height: 2),
    Text(valor, style: TextStyle(fontFamily: 'Poppins',
        fontSize: 13, fontWeight: FontWeight.w600, color: color)),
  ]);
}