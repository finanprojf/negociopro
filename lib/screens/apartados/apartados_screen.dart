import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/apartado_model.dart';
import '../../utils/formatters.dart';
import 'apartado_form_screen.dart';
import 'abono_apartado_screen.dart';
import '../../services/apartado_service.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import 'package:google_fonts/google_fonts.dart';
class ApartadosScreen extends StatefulWidget {
  const ApartadosScreen({super.key});

  @override
  State<ApartadosScreen> createState() => _ApartadosScreenState();
}

class _ApartadosScreenState extends State<ApartadosScreen> {
  String _filtro = 'activo';
  List<ApartadoModel> _apartados = [];
  List<ApartadoModel> _filtrados = [];
  bool _loading = true;

  double get _totalPendiente => _filtrados
      .where((a) => a.estado == 'activo')
      .fold(0, (s, a) => s + a.saldoPendiente);

  @override
  void initState() { super.initState(); _cargar(); }

Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final apartados = await ApartadoService.getApartados();
      if (mounted) setState(() {
        _apartados = apartados;
        _aplicarFiltros();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _aplicarFiltros() {
    if (_filtro == 'todos') { _filtrados = List.from(_apartados); return; }
    _filtrados = _apartados.where((a) => a.estado == _filtro).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Apartados')),
      body: Column(children: [
        _buildResumen(),
        _buildFiltros(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filtrados.isEmpty ? _buildEmpty() : _buildLista(),
        ),
      ]),
    floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const ApartadoFormScreen()));
          if (ok == true) _cargar();
        },
        backgroundColor: AppColors.primary,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 20),
            Text('Apartar', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    final activos = _apartados.where((a) => a.estado == 'activo').length;
    final completados = _apartados.where((a) => a.estado == 'completado').length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.colorApartados.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.colorApartados.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        _Col(AppFormatters.moneda(_totalPendiente), 'Por cobrar', AppColors.colorApartados),
        _Div(),
        _Col('$activos', 'Activos', AppColors.warning),
        _Div(),
        _Col('$completados', 'Completados', AppColors.success),
      ]),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FChip('Activos', 'activo', _filtro, AppColors.warning),
          const SizedBox(width: 8),
          _FChip('Completados', 'completado', _filtro, AppColors.success),
          const SizedBox(width: 8),
          _FChip('Cancelados', 'cancelado', _filtro, AppColors.danger),
          const SizedBox(width: 8),
          _FChip('Todos', 'todos', _filtro, AppColors.primary),
        ].map((w) => w is _FChip ? GestureDetector(
          onTap: () => setState(() { _filtro = (w as _FChip).value; _aplicarFiltros(); }),
          child: w,
        ) : w).toList()),
      ),
    );
  }

  Future<void> _mostrarHistorialApartado(ApartadoModel apartado) async {
    List<Map<String, dynamic>> abonos = [];
    if (await SupabaseService.isOnlineAsync) {
      try {
        final data = await SupabaseService.client
            .from('abonos_apartado')
            .select()
            .eq('apartado_id', apartado.id)
            .order('created_at', ascending: false);
        abonos = List<Map<String, dynamic>>.from(data);
      } catch (_) {}
    }
    if (abonos.isEmpty) {
      final db = await LocalDatabase.database;
      abonos = await db.query('abonos_apartado',
          where: 'apartado_id = ?', whereArgs: [apartado.id],
          orderBy: 'created_at DESC');
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.55,
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
                Expanded(child: Text(apartado.descripcion,
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(abonos.isEmpty ? 'Sin abonos' : 'Abonado: ${AppFormatters.moneda(abonos.fold(0.0, (s, a) => s + (a["monto"] as num).toDouble()))}',
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: abonos.isEmpty
                  ? const Center(child: Text('Sin abonos registrados',
                      style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: abonos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final ab = abonos[i];
                        return Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.accentSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_rounded,
                                color: AppColors.colorApartados, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(AppFormatters.moneda((ab['monto'] as num).toDouble()),
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.colorApartados)),
                            Text(AppFormatters.fechaHora(DateTime.parse(ab['created_at'])),
                                style: const TextStyle(fontFamily: 'Poppins',
                                    fontSize: 11, color: AppColors.textMuted)),
                          ])),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.danger, size: 20),
                            tooltip: 'Cancelar abono',
                            onPressed: () async {
                              final monto = (ab['monto'] as num).toDouble();
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (_) => AlertDialog(
                                  title: const Text('Cancelar abono',
                                      style: TextStyle(fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w700)),
                                  content: Text(
                                      '¿Eliminar el abono de ${AppFormatters.moneda(monto)}?',
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
                                await ApartadoService.cancelarAbono(
                                    ab['id'] as String,
                                    apartado.id,
                                    monto);
                                abonos.removeAt(i);
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
  }

  Widget _buildLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ApartadoCard(
        apartado: _filtrados[i],
        onAbonar: () async {
          final ok = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) =>
                  AbonoApartadoScreen(apartado: _filtrados[i])));
          if (ok == true) _cargar();
        },
        onHistorial: () => _mostrarHistorialApartado(_filtrados[i]),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.bookmark_border_rounded, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Sin apartados', style: TextStyle(fontFamily: 'Poppins',
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Los apartados permiten que tu cliente\nreserve un producto pagando por partes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMuted)),
    ]),
  );
}

// ============================================================
// WIDGETS
// ============================================================

class _Col extends StatelessWidget {
  final String v; final String l; final Color c;
  const _Col(this.v, this.l, this.c);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(fontFamily: 'Poppins', fontSize: 15,
        fontWeight: FontWeight.w700, color: c)),
    const SizedBox(height: 2),
    Text(l, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 11, color: AppColors.textMuted)),
  ]));
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 36, color: AppColors.colorApartados.withValues(alpha: 0.2),
      margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _FChip extends StatelessWidget {
  final String label; final String value;
  final String selected; final Color color;
  const _FChip(this.label, this.value, this.selected, this.color);

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: sel ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? color : AppColors.cardBorder, width: sel ? 1.5 : 1),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
          color: sel ? color : AppColors.textSecondary)),
    );
  }
}

class _ApartadoCard extends StatelessWidget {
  final ApartadoModel apartado;
  final VoidCallback onAbonar;
  final VoidCallback onHistorial;
  const _ApartadoCard({required this.apartado, required this.onAbonar, required this.onHistorial});

  @override
  Widget build(BuildContext context) {
    Color estadoColor; String estadoLabel; Color estadoBg;
    if (apartado.estaCompletado) {
      estadoColor = AppColors.success; estadoBg = AppColors.successSurface; estadoLabel = 'Completado';
    } else if (apartado.estaCancelado) {
      estadoColor = AppColors.danger; estadoBg = AppColors.dangerSurface; estadoLabel = 'Cancelado';
    } else {
      estadoColor = AppColors.colorApartados; estadoBg = AppColors.accentSurface; estadoLabel = 'Activo';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.colorApartados.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bookmark_rounded,
                    color: AppColors.colorApartados, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(apartado.numeroFormateado,
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 11, color: AppColors.textMuted)),
                Text(apartado.descripcion,
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: estadoBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(estadoLabel, style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 10, fontWeight: FontWeight.w600, color: estadoColor)),
              ),
            ]),
            const SizedBox(height: 12),
            // Cliente
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(apartado.clienteNombre ?? '',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 12, color: AppColors.textSecondary)),
              if (apartado.fechaEstimada != null) ...[
                const Spacer(),
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(AppFormatters.fecha(apartado.fechaEstimada),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ]),
            const SizedBox(height: 14),
            // Barra de progreso
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Pagado: ${AppFormatters.moneda(apartado.montoPagado)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 11, color: AppColors.textMuted)),
              Text('Pendiente: ${AppFormatters.moneda(apartado.saldoPendiente)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      fontWeight: FontWeight.w700, color: AppColors.colorApartados)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: apartado.porcentajePagado,
                backgroundColor: AppColors.surfaceAlt,
                color: apartado.estaCompletado ? AppColors.success : AppColors.colorApartados,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(apartado.porcentajePagado * 100).toStringAsFixed(0)}% completado',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 10, color: AppColors.textMuted)),
              Text('Total: ${AppFormatters.moneda(apartado.montoTotal)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 10, color: AppColors.textMuted)),
            ]),
          ]),
        ),
        // Botón inferior
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: apartado.estaCompletado
              ? Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: const BoxDecoration(
                      color: AppColors.successSurface,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      SizedBox(width: 6),
                      Text('¡Listo! Cliente puede retirar',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                              fontWeight: FontWeight.w600, color: AppColors.success)),
                    ]),
                  ),
                ])
              : apartado.estaCancelado
                  ? TextButton.icon(
                      onPressed: onHistorial,
                      icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.textMuted),
                      label: const Text('Ver historial',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMuted)),
                      style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
                    )
                  : Row(children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onAbonar,
                          icon: const Icon(Icons.payments_rounded, size: 16, color: AppColors.colorApartados),
                          label: const Text('Abonar',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                                  fontWeight: FontWeight.w600, color: AppColors.colorApartados)),
                          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppColors.cardBorder),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onHistorial,
                          icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.textMuted),
                          label: const Text('Historial',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                                  fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                        ),
                      ),
                    ]),
        ),
      ]),
    );
  }
}