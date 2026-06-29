import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/fiado_model.dart';
import '../../utils/formatters.dart';
import 'fiado_detalle_screen.dart';
import '../../services/fiado_service.dart';
class FiadoScreen extends StatefulWidget {
  const FiadoScreen({super.key});

  @override
  State<FiadoScreen> createState() => _FiadoScreenState();
}

class _FiadoScreenState extends State<FiadoScreen> {
  final _searchCtrl = TextEditingController();
  String _filtro = 'activo';
  List<FiadoModel> _fiados = [];
  List<FiadoModel> _filtrados = [];
  bool _loading = true;

  double get _totalDeuda => _filtrados
      .where((f) => f.estado == 'activo')
      .fold(0, (s, f) => s + f.saldoPendiente);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final fiados = await FiadoService.getFiados();
      if (mounted) setState(() {
        _fiados = fiados;
        _aplicarFiltros();
        _loading = false;
      });
    } catch (e) {
      print('❌ Error fiados: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _aplicarFiltros() {
    var lista = List<FiadoModel>.from(_fiados);
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      lista = lista.where((f) =>
          (f.clienteNombre ?? '').toLowerCase().contains(q)).toList();
    }
    if (_filtro != 'todos') lista = lista.where((f) => f.estado == _filtro).toList();
    _filtrados = lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fiado / Crédito')),
      body: Column(children: [
        _buildResumen(),
        _buildFiltros(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filtrados.isEmpty ? _buildEmpty() : _buildLista(),
        ),
      ]),
    );
  }

  Widget _buildResumen() {
    final activos = _fiados.where((f) => f.estado == 'activo').length;
    final vencidos = _fiados.where((f) => f.estaVencido).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        _StatCol(AppFormatters.moneda(_totalDeuda), 'Total pendiente', AppColors.colorFiado),
        _Div(),
        _StatCol('$activos', 'Activos', AppColors.warning),
        _Div(),
        _StatCol('$vencidos', 'Vencidos', AppColors.danger),
      ]),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(_aplicarFiltros),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Buscar cliente...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FChip('Activos', 'activo', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); }), AppColors.warning),
            const SizedBox(width: 8),
            _FChip('Vencidos', 'vencido', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); }), AppColors.danger),
            const SizedBox(width: 8),
            _FChip('Pagados', 'pagado', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); }), AppColors.success),
            const SizedBox(width: 8),
            _FChip('Todos', 'todos', _filtro, (v) => setState(() { _filtro = v; _aplicarFiltros(); }), AppColors.primary),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _filtrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _FiadoTile(
        fiado: _filtrados[i],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FiadoDetalleScreen(fiado: _filtrados[i]))),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.handshake_outlined, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Sin fiados', style: TextStyle(fontFamily: 'Poppins',
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ]),
  );
}

// ============================================================
// WIDGETS
// ============================================================

class _StatCol extends StatelessWidget {
  final String valor; final String label; final Color color;
  const _StatCol(this.valor, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(valor, style: TextStyle(fontFamily: 'Poppins', fontSize: 16,
        fontWeight: FontWeight.w700, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontFamily: 'Poppins',
        fontSize: 11, color: AppColors.textMuted)),
  ]));
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 40, color: AppColors.cardBorder,
      margin: const EdgeInsets.symmetric(horizontal: 12));
}

class _FChip extends StatelessWidget {
  final String label; final String value; final String selected;
  final Function(String) onTap; final Color color;
  const _FChip(this.label, this.value, this.selected, this.onTap, this.color);
  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
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
      ),
    );
  }
}

class _FiadoTile extends StatelessWidget {
  final FiadoModel fiado; final VoidCallback onTap;
  const _FiadoTile({required this.fiado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color color; String label; Color bg;
    if (fiado.estaPagado) { color = AppColors.success; bg = AppColors.successSurface; label = 'Pagado'; }
    else if (fiado.estaVencido) { color = AppColors.danger; bg = AppColors.dangerSurface; label = 'Vencido'; }
    else { color = AppColors.warning; bg = AppColors.warningSurface; label = 'Activo'; }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fiado.estaVencido ? AppColors.danger.withValues(alpha: 0.3) : AppColors.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 20,
                backgroundColor: AppColors.colorFiado.withValues(alpha: 0.1),
                child: Text((fiado.clienteNombre ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, color: AppColors.colorFiado))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fiado.clienteNombre ?? 'Cliente',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (fiado.fechaLimite != null)
                Text('Vence: ${AppFormatters.fecha(fiado.fechaLimite)}',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                        color: fiado.estaVencido ? AppColors.danger : AppColors.textMuted)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ),
          ]),
          const SizedBox(height: 12),
          // Barra de progreso
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Pagado: ${AppFormatters.moneda(fiado.montoPagado)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMuted)),
              Text('Pendiente: ${AppFormatters.moneda(fiado.saldoPendiente)}',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      fontWeight: FontWeight.w700, color: AppColors.colorFiado)),
            ]),
            const SizedBox(height: 6),
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
        ]),
      ),
    );
  }
}