import 'package:flutter/material.dart';
import '../seguridad/pin_entrada_dialog.dart';
import '../../theme/app_colors.dart';
import '../../models/cliente_model.dart';
import '../../models/apartado_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar_cliente.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import '../../services/apartado_service.dart';
import 'abono_apartado_screen.dart';
import 'apartado_form_screen.dart';
import 'entregar_articulos_sheet.dart';

class ApartadosClienteScreen extends StatefulWidget {
  final ClienteModel cliente;
  const ApartadosClienteScreen({super.key, required this.cliente});

  @override
  State<ApartadosClienteScreen> createState() => _ApartadosClienteScreenState();
}

class _ApartadosClienteScreenState extends State<ApartadosClienteScreen> {
  List<ApartadoModel> _apartados = [];
  bool _loading = true;

  double get _totalPendiente => _apartados
      .where((a) => a.estado == 'activo')
      .fold(0, (s, a) => s + a.saldoPendiente);

  @override
  void initState() {
    super.initState();
    _cargar();
  }
void _mostrarHistorial() async {
    try {
      final List<Map<String, dynamic>> res = [];
      final Set<String> idsVistos = {};

      // 1. Cargar desde Supabase si hay internet
      if (await SupabaseService.isOnlineAsync) {
        try {
          final data = await SupabaseService.client
              .from('abonos_apartado')
              .select('*, apartados(descripcion, id)')
              .eq('cliente_id', widget.cliente.id)
              .order('created_at', ascending: false);
          for (final item in data) {
            res.add(Map<String, dynamic>.from(item));
            idsVistos.add(item['id'] as String);
          }
        } catch (_) {}
      }

      // 2. Siempre agregar abonos locales no incluidos en Supabase (offline/no sincronizados)
      final db = await LocalDatabase.database;
      final local = await db.query('abonos_apartado',
          where: 'cliente_id = ?',
          whereArgs: [widget.cliente.id],
          orderBy: 'created_at DESC');
      for (final m in local) {
        if (!idsVistos.contains(m['id'] as String)) {
          res.add(Map<String, dynamic>.from(m));
        }
      }
      res.sort((a, b) {
        final aD = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
        final bD = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
        return bD.compareTo(aD);
      });

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx2, setModal) => Container(
            height: MediaQuery.of(context).size.height * 0.62,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(children: [
                  const Icon(Icons.history_rounded, color: AppColors.colorApartados),
                  const SizedBox(width: 10),
                  const Text('Historial de pagos',
                      style: TextStyle(fontFamily: 'Poppins',
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${res.length} pagos',
                      style: const TextStyle(fontFamily: 'Poppins',
                          fontSize: 12, color: AppColors.textMuted)),
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = res[i];
                          final descripcion = p['apartados'] != null
                              ? p['apartados']['descripcion'] as String
                              : 'Apartado';
                          final apartadoId = p['apartados'] != null
                              ? p['apartados']['id'] as String
                              : (p['apartado_id'] as String? ?? '');
                          final esInicial = (p['tipo'] as String? ?? 'abono') == 'inicial';
                          return Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: esInicial
                                    ? AppColors.colorApartados.withValues(alpha: 0.12)
                                    : AppColors.accentSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                esInicial
                                    ? Icons.bookmark_added_rounded
                                    : Icons.payments_rounded,
                                color: AppColors.colorApartados, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Row(children: [
                                Expanded(child: Text(descripcion,
                                    style: const TextStyle(fontFamily: 'Poppins',
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: esInicial
                                        ? AppColors.colorApartados.withValues(alpha: 0.12)
                                        : AppColors.successSurface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(esInicial ? 'Inicial' : 'Abono',
                                      style: TextStyle(fontFamily: 'Poppins',
                                          fontSize: 10, fontWeight: FontWeight.w600,
                                          color: esInicial
                                              ? AppColors.colorApartados : AppColors.success)),
                                ),
                              ]),
                              Text(AppFormatters.fechaHora(
                                  DateTime.parse(p['created_at'])),
                                  style: const TextStyle(fontFamily: 'Poppins',
                                      fontSize: 11, color: AppColors.textMuted)),
                            ])),
                            Text(AppFormatters.moneda((p['monto'] as num).toDouble()),
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.colorApartados)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.danger, size: 20),
                              tooltip: 'Cancelar abono',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () async {
                                final montoAbono = (p['monto'] as num).toDouble();
                                final ok = await showDialog<bool>(
                                  context: ctx2,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Cancelar abono',
                                        style: TextStyle(fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w700)),
                                    content: Text(
                                        '¿Eliminar abono de ${AppFormatters.moneda(montoAbono)}?',
                                        style: const TextStyle(fontFamily: 'Poppins')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(_, false),
                                          child: const Text('No')),
                                      TextButton(onPressed: () => Navigator.pop(_, true),
                                          child: const Text('Eliminar',
                                              style: TextStyle(color: AppColors.danger))),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  final pinOkC = await mostrarDialogoPinRapido(context,
                                      titulo: 'Autorizar cancelación de abono');
                                  if (!pinOkC) return;
                                  await ApartadoService.cancelarAbono(
                                      p['id'] as String,
                                      apartadoId,
                                      (p['monto'] as num).toDouble());
                                  res.removeAt(i);
                                  setModal(() {});
                                  _cargar();
                                }
                              },
                            ),
                          ]);
                        },
                      ),
              ),
            ]),
          ),
        ),
      );
    } catch (_) {}
  }
  Future<void> _mostrarEntrega(ApartadoModel apartado) async {
    final lineas = await ApartadoService.getLineasApartado(apartado.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntregarArticulosSheet(
        apartado: apartado,
        lineas: lineas,
        onCambio: _cargar,
      ),
    );
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final db = await LocalDatabase.database;
      final local = await db.query('apartados',
          where: 'cliente_id = ?',
          whereArgs: [widget.cliente.id],
          orderBy: 'created_at DESC');
      var lista = local.map((m) => ApartadoModel.fromMap(m)).toList();

      if (await SupabaseService.isOnlineAsync) {
        try {
          final res = await SupabaseService.client
              .from('apartados')
              .select()
              .eq('cliente_id', widget.cliente.id)
              .order('created_at', ascending: false);

          // IDs con cambios locales pendientes — NO sobreescribir
          final abonosPend = await db.query('abonos_apartado',
              where: 'cliente_id = ? AND synced = 0',
              whereArgs: [widget.cliente.id]);
          final idsPendientes = <String>{
            ...local
                .where((m) => m['synced'] == 0)
                .map((m) => m['id'] as String),
            ...abonosPend.map((a) => a['apartado_id'] as String),
          };

          // Guardar en local solo si no hay cambios pendientes
          for (final m in res) {
            if (idsPendientes.contains(m['id'] as String?)) continue;
            final map = Map<String, dynamic>.from(m)..['synced'] = 1;
            try { await LocalDatabase.insertar('apartados', map); } catch (_) {}
          }

          // Construir lista: usar versión LOCAL para pendientes
          final localPendMap = Map.fromEntries(
            local
                .where((m) => idsPendientes.contains(m['id'] as String))
                .map((m) => MapEntry(m['id'] as String, ApartadoModel.fromMap(m))),
          );
          final idsOnline = res.map((m) => m['id'] as String).toSet();
          final soloLocales = lista.where((a) => !idsOnline.contains(a.id)).toList();
          lista = [
            ...res.map((m) => localPendMap[m['id']] ?? ApartadoModel.fromMap(m)),
            ...soloLocales,
          ];
        } catch (_) {}
      }

      if (mounted) setState(() { _apartados = lista; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
    appBar: AppBar(
        title: Text('Apartados — ${widget.cliente.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historial de pagos',
            onPressed: () => _mostrarHistorial(),
          ),
        ],
      ),
      body: Column(children: [
        // Resumen
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.colorApartados.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.colorApartados.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            AvatarCliente(iniciales: widget.cliente.iniciales, fotoUrl: widget.cliente.fotoUrl, radius: 28),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.cliente.nombre,
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Total pendiente: ${AppFormatters.moneda(_totalPendiente)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 13, color: AppColors.colorApartados,
                      fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _apartados.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.bookmark_border_rounded,
                          size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text('${widget.cliente.nombre} no tiene apartados',
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 16, color: AppColors.textMuted)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _apartados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ApartadoCard(
                        apartado: _apartados[i],
                        onAbonar: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  AbonoApartadoScreen(apartado: _apartados[i])));
                          _cargar();
                        },
                        onEntregar: () => _mostrarEntrega(_apartados[i]),
                      ),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ApartadoFormScreen()));
          _cargar();
        },
        backgroundColor: AppColors.colorApartados,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _ApartadoCard extends StatelessWidget {
  final ApartadoModel apartado;
  final VoidCallback onAbonar;
  final VoidCallback onEntregar;
  const _ApartadoCard({required this.apartado, required this.onAbonar, required this.onEntregar});

  @override
  Widget build(BuildContext context) {
    Color color; String label; Color bg;
    if (apartado.estaCompletado) {
      color = AppColors.success; bg = AppColors.successSurface; label = 'Completado';
    } else if (apartado.estaCancelado) {
      color = AppColors.danger; bg = AppColors.dangerSurface; label = 'Cancelado';
    } else {
      color = AppColors.colorApartados; bg = AppColors.accentSurface; label = 'Activo';
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(apartado.descripcion,
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: bg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(label, style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.textMuted)),
                Text(AppFormatters.moneda(apartado.montoTotal),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Text('Pagado', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.textMuted)),
                Text(AppFormatters.moneda(apartado.montoPagado),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.success)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Pendiente', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.textMuted)),
                Text(AppFormatters.moneda(apartado.saldoPendiente),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.colorApartados)),
              ]),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: apartado.porcentajePagado,
                backgroundColor: AppColors.cardBorder,
                color: apartado.estaCompletado
                    ? AppColors.success : AppColors.colorApartados,
                minHeight: 6,
              ),
            ),
            if (apartado.fechaEstimada != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('Fecha estimada: ${AppFormatters.fecha(apartado.fechaEstimada)}',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 11, color: AppColors.textMuted)),
              ]),
            ],
          ]),
        ),
        Container(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.cardBorder))),
          child: apartado.estaCompletado
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                    SizedBox(width: 6),
                    Text('¡Listo! Cliente puede retirar',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                            fontWeight: FontWeight.w600, color: AppColors.success)),
                  ]),
                )
              : apartado.estaCancelado
                  ? const SizedBox.shrink()
                  : Row(children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onAbonar,
                          icon: const Icon(Icons.payments_rounded,
                              size: 15, color: AppColors.colorApartados),
                          label: const Text('Abonar',
                              style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: AppColors.colorApartados)),
                          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.cardBorder),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onEntregar,
                          icon: const Icon(Icons.inventory_2_rounded,
                              size: 15, color: AppColors.success),
                          label: const Text('Entregar',
                              style: TextStyle(fontFamily: 'Poppins',
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: AppColors.success)),
                          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                        ),
                      ),
                    ]),
        ),
      ]),
    );
  }
}