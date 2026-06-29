import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../models/fiado_model.dart';
import '../../utils/formatters.dart';
import '../../services/fiado_service.dart';
import '../../services/supabase_service.dart';

class FiadoClienteScreen extends StatefulWidget {
  final ClienteModel cliente;
  const FiadoClienteScreen({super.key, required this.cliente});

  @override
  State<FiadoClienteScreen> createState() => _FiadoClienteScreenState();
}

class _FiadoClienteScreenState extends State<FiadoClienteScreen> {
  List<FiadoModel> _fiados = [];
  bool _loading = true;

  double get _totalPendiente => _fiados
      .where((f) => f.estado == 'activo')
      .fold(0, (s, f) => s + f.saldoPendiente);

  bool get _tienePendiente => _totalPendiente > 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.client
          .from('fiados')
          .select()
          .eq('cliente_id', widget.cliente.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _fiados = res.map((m) => FiadoModel.fromMap(m)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
void _mostrarHistorial() async {
    try {
      final res = await SupabaseService.client
          .from('abonos_fiado')
          .select()
          .eq('cliente_id', widget.cliente.id)
          .order('created_at', ascending: false);

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
                        return Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.successSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_rounded,
                                color: AppColors.success, size: 20),
                          ),
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
                          Text(AppFormatters.moneda(
                              (p['monto'] as num).toDouble()),
                              style: const TextStyle(fontFamily: 'Poppins',
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.success)),
                        ]);
                      },
                    ),
            ),
          ]),
        ),
      );
    } catch (e) {
      print('❌ Error historial: $e');
    }
  }
  Future<void> _eliminarFiado(FiadoModel fiado) async {
    // Si tiene deuda pendiente advertir
    if (!fiado.estaPagado) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('⚠ Fiado con deuda',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          content: Text(
            'Este fiado aún tiene ${AppFormatters.moneda(fiado.saldoPendiente)} pendiente.\n\n¿Deseas eliminarlo de todas formas?',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
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
      if (confirmar != true) return;
    } else {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Eliminar fiado',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          content: const Text('Este fiado ya está pagado. ¿Deseas eliminarlo?',
              style: TextStyle(fontFamily: 'Poppins')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('No')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, eliminar',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    try {
      await SupabaseService.client
          .from('fiados')
          .delete()
          .eq('id', fiado.id);
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
      itemBuilder: (_, i) => _FiadoCard(
        fiado: _fiados[i],
        onAbonar: () => _mostrarAbonoFiado(_fiados[i]),
        onEliminar: () => _eliminarFiado(_fiados[i]),
      ),
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

  // Abono general (salda todos los fiados activos)
  void _mostrarAbono({double? monto}) {
    final ctrl = TextEditingController(
        text: monto != null ? monto.toStringAsFixed(2) : '');

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
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(monto != null ? 'Saldar todo' : 'Registrar abono',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Total pendiente: ${AppFormatters.moneda(_totalPendiente)}',
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              autofocus: monto == null,
              onChanged: (_) => setModal(() {}),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 24,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: 'RD\$ ',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final montoAbono = double.tryParse(ctrl.text) ?? 0;
                  if (montoAbono <= 0) return;
                  Navigator.pop(ctx);

                  // Abonar a todos los fiados activos en orden
                  double restante = montoAbono;
                  final fiadosActivos = _fiados
                      .where((f) => f.estado == 'activo')
                      .toList();

                  for (final f in fiadosActivos) {
                    if (restante <= 0) break;
                    final abonoEste = restante >= f.saldoPendiente
                        ? f.saldoPendiente : restante;
                    await FiadoService.registrarAbono(
                        f.id, f.clienteId, abonoEste, 'efectivo');
                    restante -= abonoEste;
                  }

                  _cargar();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(monto != null
                          ? '¡Deuda saldada completamente!'
                          : 'Abono registrado'),
                      backgroundColor: AppColors.success,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colorFiado),
                child: Text(monto != null ? 'Confirmar — saldar todo' : 'Confirmar abono',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // Abono a un fiado específico
  void _mostrarAbonoFiado(FiadoModel fiado) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
          const SizedBox(height: 6),
          Text('Pendiente: ${AppFormatters.moneda(fiado.saldoPendiente)}',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            autofocus: true,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 20,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Monto del abono',
              prefixText: 'RD\$ ',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => ctrl.text =
                  (fiado.saldoPendiente * 0.5).toStringAsFixed(2),
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
              onTap: () => ctrl.text = fiado.saldoPendiente.toStringAsFixed(2),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FiadoService.registrarAbono(
                  fiado.id, fiado.clienteId,
                  double.tryParse(ctrl.text) ?? 0, 'efectivo',
                );
                _cargar();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorFiado),
              child: const Text('Confirmar abono',
                  style: TextStyle(fontFamily: 'Poppins',
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FiadoCard extends StatelessWidget {
  final FiadoModel fiado;
  final VoidCallback onAbonar;
  final VoidCallback onEliminar;
  const _FiadoCard({required this.fiado,
      required this.onAbonar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    Color color; String label; Color bg;
    if (fiado.estaPagado) {
      color = AppColors.success; bg = AppColors.successSurface; label = '✓ Pagado';
    } else if (fiado.estaVencido) {
      color = AppColors.danger; bg = AppColors.dangerSurface; label = '⚠ Vencido';
    } else {
      color = AppColors.colorFiado; bg = AppColors.dangerSurface.withValues(alpha: 0.2);
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
              Text(AppFormatters.fecha(fiado.createdAt),
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
                onTap: onEliminar,
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 18),
              ),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _Col('Original', AppFormatters.moneda(fiado.montoOriginal),
                  AppColors.textPrimary),
              _Col('Pagado', AppFormatters.moneda(fiado.montoPagado),
                  AppColors.success),
              _Col('Pendiente', AppFormatters.moneda(fiado.saldoPendiente),
                  AppColors.colorFiado),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fiado.porcentajePagado,
                backgroundColor: AppColors.cardBorder,
                color: fiado.estaPagado ? AppColors.success : AppColors.colorFiado,
                minHeight: 6,
              ),
            ),
          ]),
        ),
        if (!fiado.estaPagado)
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.cardBorder))),
            child: TextButton.icon(
              onPressed: onAbonar,
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