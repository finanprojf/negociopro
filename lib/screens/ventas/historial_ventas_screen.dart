import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/venta_model.dart';
import '../../utils/formatters.dart';
import '../../services/venta_service.dart';
import 'detalle_venta_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
class HistorialVentasScreen extends StatefulWidget {
  const HistorialVentasScreen({super.key});

  @override
  State<HistorialVentasScreen> createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen> {
  List<VentaModel> _ventas = [];
  bool _loading = true;
  String _filtro = 'hoy';

  double get _totalFiltrado =>
      _ventas.where((v) => v.estado == 'completada')
          .fold(0, (s, v) => s + v.total);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    DateTime? fecha;
    if (_filtro == 'hoy') fecha = DateTime.now();
    var ventas = await VentaService.getVentas(fecha: fecha);

    // Filtro semana: últimos 7 días
    if (_filtro == 'semana') {
      final inicio = DateTime.now().subtract(const Duration(days: 7));
      ventas = ventas.where((v) =>
          v.createdAt != null && v.createdAt!.isAfter(inicio)).toList();
    }

    if (mounted) setState(() { _ventas = ventas; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Historial de ventas')),
      body: Column(children: [
        _buildFiltros(),
        _buildResumen(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary))
              : _ventas.isEmpty
                  ? _buildEmpty()
                  : _buildLista(),
        ),
      ]),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(12),
      child: Row(children: ['hoy', 'semana', 'todas'].map((f) {
        final labels = {'hoy': 'Hoy', 'semana': 'Esta semana', 'todas': 'Todas'};
        final sel = _filtro == f;
        return Expanded(child: GestureDetector(
          onTap: () { setState(() => _filtro = f); _cargar(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(labels[f]!, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ));
      }).toList()),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.colorVentas.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.colorVentas.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(child: Column(children: [
          Text('${_ventas.length}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 24,
                  fontWeight: FontWeight.w700, color: AppColors.colorVentas)),
          const Text('Ventas', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 12, color: AppColors.textMuted)),
        ])),
        Container(width: 1, height: 40, color: AppColors.colorVentas.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16)),
        Expanded(child: Column(children: [
          Text(AppFormatters.moneda(_totalFiltrado),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 16,
                  fontWeight: FontWeight.w700, color: AppColors.colorVentas)),
          const Text('Total', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 12, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }

  Widget _buildLista() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _ventas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
     itemBuilder: (_, i) => _VentaTile(
        venta: _ventas[i],
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) =>
                DetalleVentaScreen(venta: _ventas[i]))),
        onEliminar: () => _cargar(),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Sin ventas', style: TextStyle(fontFamily: 'Poppins',
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('No hay ventas en este período',
          style: TextStyle(fontFamily: 'Poppins',
              fontSize: 14, color: AppColors.textMuted)),
    ]),
  );
}

class _VentaTile extends StatelessWidget {
  final VentaModel venta; final VoidCallback onTap; final VoidCallback onEliminar;
  const _VentaTile({required this.venta, required this.onTap, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: venta.anulada
              ? AppColors.dangerSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: venta.anulada
              ? AppColors.danger.withValues(alpha: 0.2) : AppColors.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.colorVentas.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: AppColors.colorVentas, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(venta.numeroFormateado,
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(
              venta.clienteNombre != null
                  ? '${venta.clienteNombre} · ${AppFormatters.tiempoRelativo(venta.createdAt!)}'
                  : AppFormatters.tiempoRelativo(venta.createdAt!),
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ])),
         Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppFormatters.moneda(venta.tipoPago == 'fiado'
                    ? venta.montoPagado : venta.total),
                style: const TextStyle(fontFamily: 'Poppins',
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (venta.tipoPago == 'fiado' && venta.total > venta.montoPagado)
              Text('Fiado: ${AppFormatters.moneda(venta.total - venta.montoPagado)}',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 10, color: AppColors.colorFiado)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: venta.anulada
                    ? AppColors.dangerSurface : AppColors.successSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                venta.anulada ? 'Anulada' : venta.tipoPago,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: venta.anulada
                        ? AppColors.danger : AppColors.success),
              ),
            ),
          ]),
          const SizedBox(width: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger, size: 20),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Eliminar venta',
                          style: TextStyle(fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700)),
                      content: Text(
                        '¿Seguro que quieres eliminar la venta ${venta.numeroFormateado}?',
                        style: const TextStyle(fontFamily: 'Poppins')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Eliminar',
                              style: TextStyle(color: AppColors.danger,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Actualizar local primero (funciona offline)
                    await LocalDatabase.actualizar(
                      'ventas',
                      {'estado': 'anulada', 'synced': 0},
                      'id', venta.id,
                    );
                    // Sincronizar si hay internet
                    if (await SupabaseService.isOnlineAsync) {
                      await SupabaseService.client
                          .from('ventas')
                          .update({'estado': 'anulada'})
                          .eq('id', venta.id);
                      await LocalDatabase.marcarSynced('ventas', venta.id);
                    }
                    onEliminar();
                  }
                },
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18),
            ]),
        ]),
      ),
    );
  }
}