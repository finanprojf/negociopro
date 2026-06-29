import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../services/supabase_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
 String _periodo = 'hoy';
  bool _loadingDatos = false;

  Map<String, Map<String, double>> _datos = {
    'hoy':    {'ventas': 0, 'gastos': 0, 'ganancia': 0},
    'semana': {'ventas': 0, 'gastos': 0, 'ganancia': 0},
    'mes':    {'ventas': 0, 'gastos': 0, 'ganancia': 0},
  };

  Map<String, double> get _actual => _datos[_periodo]!;
@override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loadingDatos = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      final ahora = DateTime.now().toUtc();

      // Fechas
      final inicioHoy = DateTime.utc(ahora.year, ahora.month, ahora.day);
      final inicioSemana = inicioHoy.subtract(Duration(days: ahora.weekday - 1));
      final inicioMes = DateTime.utc(ahora.year, ahora.month, 1);
      final fin = inicioHoy.add(const Duration(days: 1));

      for (final periodo in ['hoy', 'semana', 'mes']) {
        final inicio = periodo == 'hoy' ? inicioHoy
            : periodo == 'semana' ? inicioSemana : inicioMes;

        final ventas = await SupabaseService.client
            .from('ventas')
            .select('total')
            .eq('empresa_id', empresaId)
            .eq('estado', 'completada')
            .gte('created_at', inicio.toIso8601String())
            .lt('created_at', fin.toIso8601String());

        final gastos = await SupabaseService.client
            .from('gastos')
            .select('monto')
            .eq('empresa_id', empresaId)
            .gte('created_at', inicio.toIso8601String())
            .lt('created_at', fin.toIso8601String());

        double totalVentas = 0;
        for (final v in ventas) {
          totalVentas += (v['total'] as num).toDouble();
        }

        double totalGastos = 0;
        for (final g in gastos) {
          totalGastos += (g['monto'] as num).toDouble();
        }

        _datos[periodo] = {
          'ventas': totalVentas,
          'gastos': totalGastos,
          'ganancia': totalVentas - totalGastos,
        };
      }

      if (mounted) setState(() => _loadingDatos = false);
    } catch (e) {
      print('❌ Error reportes: $e');
      if (mounted) setState(() => _loadingDatos = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reportes')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSelectorPeriodo(),
          const SizedBox(height: 20),
          _buildKPIs(),
          const SizedBox(height: 20),
          _buildBarrasSimples(),
          const SizedBox(height: 20),
          _buildProductosTop(),
          const SizedBox(height: 20),
          _buildClientesTop(),
        ]),
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
    final opciones = [
      {'id': 'hoy', 'label': 'Hoy'},
      {'id': 'semana', 'label': 'Semana'},
      {'id': 'mes', 'label': 'Mes'},
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: opciones.map((o) {
          final sel = _periodo == o['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _periodo = o['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4, offset: const Offset(0, 2))] : null,
                ),
                child: Text(o['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      color: sel ? AppColors.textPrimary : AppColors.textMuted,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKPIs() {
    return Column(children: [
      Row(children: [
        Expanded(child: _KPICard('Ventas totales',
            AppFormatters.moneda(_actual['ventas']!),
            Icons.trending_up_rounded, AppColors.colorVentas)),
        const SizedBox(width: 12),
        Expanded(child: _KPICard('Ganancias',
            AppFormatters.moneda(_actual['ganancia']!),
            Icons.account_balance_wallet_rounded, AppColors.primary)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _KPICard('Gastos',
            AppFormatters.moneda(_actual['gastos']!),
            Icons.receipt_long_rounded, AppColors.colorGastos)),
        const SizedBox(width: 12),
        Expanded(child: _KPICard('Margen',
            '${((_actual['ganancia']! / (_actual['ventas']! == 0 ? 1 : _actual['ventas']!)) * 100).toStringAsFixed(1)}%',
            Icons.pie_chart_outline_rounded, AppColors.colorReportes)),
      ]),
    ]);
  }

  Widget _buildBarrasSimples() {
    final total = _actual['ventas']! + _actual['gastos']!;
    final pVentas = total > 0 ? _actual['ventas']! / total : 0.0;
    final pGastos = total > 0 ? _actual['gastos']! / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Distribución', style: TextStyle(fontFamily: 'Poppins',
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _BarraItem('Ventas', pVentas, AppColors.colorVentas,
            AppFormatters.moneda(_actual['ventas']!)),
        const SizedBox(height: 12),
        _BarraItem('Gastos', pGastos, AppColors.colorGastos,
            AppFormatters.moneda(_actual['gastos']!)),
        const SizedBox(height: 12),
        _BarraItem('Ganancia neta', pVentas - pGastos > 0 ? pVentas - pGastos : 0,
            AppColors.primary, AppFormatters.moneda(_actual['ganancia']!)),
      ]),
    );
  }

 Widget _buildProductosTop() {
    final productos = <Map<String, dynamic>>[];
    return _SeccionLista('Productos más vendidos', Icons.star_rounded,
        AppColors.accent, productos.map((p) =>
            _ItemLista(p['nombre'] as String, p['cantidad'] as String,
                AppFormatters.moneda(p['monto'] as double))).toList());
  }

  Widget _buildClientesTop() {
    final clientes = <Map<String, dynamic>>[];
    return _SeccionLista('Mejores clientes', Icons.people_rounded,
        AppColors.colorClientes, clientes.map((c) =>
            _ItemLista(c['nombre'] as String, c['info'] as String,
                AppFormatters.moneda(c['monto'] as double))).toList());
  }
}

// ============================================================
// WIDGETS
// ============================================================

class _KPICard extends StatelessWidget {
  final String label; final String valor;
  final IconData icon; final Color color;
  const _KPICard(this.label, this.valor, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
      const SizedBox(height: 12),
      Text(label, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 11, color: AppColors.textMuted)),
      const SizedBox(height: 4),
      Text(valor, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    ]),
  );
}

class _BarraItem extends StatelessWidget {
  final String label; final double valor;
  final Color color; final String texto;
  const _BarraItem(this.label, this.valor, this.color, this.texto);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 12, color: AppColors.textSecondary)),
      Text(texto, style: TextStyle(fontFamily: 'Poppins',
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]),
    const SizedBox(height: 6),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        backgroundColor: AppColors.surfaceAlt,
        color: color, minHeight: 8,
      ),
    ),
  ]);
}

class _SeccionLista extends StatelessWidget {
  final String titulo; final IconData icon;
  final Color color; final List<Widget> items;
  const _SeccionLista(this.titulo, this.icon, this.color, this.items);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(titulo, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
      const SizedBox(height: 14),
      ...items,
    ]),
  );
}

class _ItemLista extends StatelessWidget {
  final String nombre; final String info; final String monto;
  const _ItemLista(this.nombre, this.info, this.monto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nombre, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        Text(info, style: const TextStyle(fontFamily: 'Poppins',
            fontSize: 11, color: AppColors.textMuted)),
      ])),
      Text(monto, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    ]),
  );
}