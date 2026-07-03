import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
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
  bool _loading = false;

  Map<String, Map<String, double>> _datos = {
    'hoy':    {'ventas': 0, 'gastos': 0, 'ganancia': 0, 'fiado': 0, 'apartados': 0},
    'semana': {'ventas': 0, 'gastos': 0, 'ganancia': 0, 'fiado': 0, 'apartados': 0},
    'mes':    {'ventas': 0, 'gastos': 0, 'ganancia': 0, 'fiado': 0, 'apartados': 0},
  };

  List<Map<String, dynamic>> _productosTop = [];
  List<Map<String, dynamic>> _productosMenos = [];

  Map<String, double> get _actual => _datos[_periodo]!;

  double get _margen {
    final ventas = _actual['ventas'] ?? 0;
    final ganancia = _actual['ganancia'] ?? 0;
    if (ventas == 0) return 0;
    return (ganancia / ventas) * 100;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _loading = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      // Usar hora LOCAL del dispositivo (RD) para definir los rangos.
      final ahoraLocal = DateTime.now();
      final inicioHoyLocal = DateTime(ahoraLocal.year, ahoraLocal.month, ahoraLocal.day);
      final inicioSemanaLocal = inicioHoyLocal.subtract(Duration(days: ahoraLocal.weekday - 1));
      final inicioMesLocal = DateTime(ahoraLocal.year, ahoraLocal.month, 1);
      final finHoyLocal = inicioHoyLocal.add(const Duration(days: 1));

      for (final periodo in ['hoy', 'semana', 'mes']) {
        final inicioLocal = periodo == 'hoy' ? inicioHoyLocal
            : periodo == 'semana' ? inicioSemanaLocal : inicioMesLocal;
        // El fin siempre es "ahora" excepto para hoy, que es el final del día actual
        final finLocal = periodo == 'hoy' ? finHoyLocal : ahoraLocal.add(const Duration(minutes: 1));

        final inicioUtc = inicioLocal.toUtc().toIso8601String();
        final finUtc = finLocal.toUtc().toIso8601String();

        final ventas = await SupabaseService.client
            .from('ventas')
            .select('id, total, tipo_pago')
            .eq('empresa_id', empresaId)
            .eq('estado', 'completada')
            .gte('created_at', inicioUtc)
            .lt('created_at', finUtc);

        double totalVentas = 0;
        double totalFiado = 0;
        final ventasIds = <String>[];
        for (final v in ventas) {
          if (v['tipo_pago'] != 'fiado') {
            totalVentas += (v['total'] as num).toDouble();
            ventasIds.add(v['id'] as String);
          } else {
            totalFiado += (v['total'] as num).toDouble();
          }
        }

        double gananciaReal = 0;
        if (ventasIds.isNotEmpty) {
          final detalles = await SupabaseService.client
              .from('detalle_ventas')
              .select('cantidad, precio_unitario, productos(precio_compra)')
              .inFilter('venta_id', ventasIds);

          for (final d in detalles) {
            final precioVenta = (d['precio_unitario'] as num).toDouble();
            final precioCompra = d['productos'] != null
                ? (d['productos']['precio_compra'] as num).toDouble()
                : 0.0;
            final cantidad = (d['cantidad'] as num).toDouble();
            gananciaReal += (precioVenta - precioCompra) * cantidad;
          }
        }

        final gastos = await SupabaseService.client
            .from('gastos')
            .select('monto')
            .eq('empresa_id', empresaId)
            .gte('created_at', inicioUtc)
            .lt('created_at', finUtc);

        double totalGastos = 0;
        for (final g in gastos) {
          totalGastos += (g['monto'] as num).toDouble();
        }

        final abonos = await SupabaseService.client
            .from('abonos_apartado')
            .select('monto')
            .eq('empresa_id', empresaId)
            .gte('created_at', inicioUtc)
            .lt('created_at', finUtc);

        double totalApartados = 0;
        for (final a in abonos) {
          totalApartados += (a['monto'] as num).toDouble();
        }

        _datos[periodo] = {
          'ventas': totalVentas,
          'gastos': totalGastos,
          'ganancia': gananciaReal,
          'fiado': totalFiado,
          'apartados': totalApartados,
        };
      }

      // Productos
      final allVentasIds = await _getVentasIds(empresaId);
      if (allVentasIds.isNotEmpty) {
        final detallesAll = await SupabaseService.client
            .from('detalle_ventas')
            .select('nombre_producto, cantidad, precio_unitario')
            .inFilter('venta_id', allVentasIds);

        final Map<String, Map<String, dynamic>> prodMap = {};
        for (final d in detallesAll) {
          final nombre = d['nombre_producto'] as String;
          final cantidad = (d['cantidad'] as num).toDouble();
          final monto = (d['precio_unitario'] as num).toDouble() * cantidad;

          if (prodMap.containsKey(nombre)) {
            prodMap[nombre]!['cantidad'] += cantidad;
            prodMap[nombre]!['monto'] += monto;
          } else {
            prodMap[nombre] = {'nombre': nombre, 'cantidad': cantidad, 'monto': monto};
          }
        }

        final sorted = prodMap.values.toList()
          ..sort((a, b) => (b['cantidad'] as double).compareTo(a['cantidad'] as double));

        if (mounted) {
          setState(() {
            _productosTop = sorted.take(5).toList();
            _productosMenos = sorted.length > 5
                ? sorted.reversed.take(5).toList()
                : sorted.reversed.toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      print('❌ Error reportes: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<String>> _getVentasIds(String empresaId) async {
    final ventas = await SupabaseService.client
        .from('ventas').select('id')
        .eq('empresa_id', empresaId).eq('estado', 'completada');
    return (ventas as List).map((v) => v['id'] as String).toList();
  }

  String _corto(double valor) {
    if (valor >= 1000000) return 'RD\$ ${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return 'RD\$ ${(valor / 1000).toStringAsFixed(1)}k';
    return AppFormatters.moneda(valor);
  }
Widget _buildGananciaReal() {
    final ventas = _actual['ventas'] ?? 0;
    final gastos = _actual['gastos'] ?? 0;
    final neto = ventas - gastos;
    final esPositivo = neto >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esPositivo 
            ? AppColors.successSurface 
            : AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPositivo 
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        Icon(esPositivo 
            ? Icons.trending_up_rounded 
            : Icons.trending_down_rounded,
            color: esPositivo ? AppColors.success : AppColors.danger,
            size: 32),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ganancia neta real',
              style: GoogleFonts.poppins(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          Text('Ventas − Gastos del período',
              style: GoogleFonts.poppins(fontSize: 11,
                  color: AppColors.textMuted)),
        ])),
        Text(AppFormatters.moneda(neto.abs()),
            style: GoogleFonts.poppins(fontSize: 20,
                fontWeight: FontWeight.w700,
                color: esPositivo ? AppColors.success : AppColors.danger)),
        if (!esPositivo)
          Text(' 📉', style: GoogleFonts.poppins(fontSize: 16)),
      ]),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargarDatos),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSelectorPeriodo(),
                  const SizedBox(height: 20),
                _buildKPIs(),
                  const SizedBox(height: 12),
                  _buildGananciaReal(),
                  const SizedBox(height: 24),
                  _buildGraficoBarras(),
                  const SizedBox(height: 24),
                  _buildGraficoPie(),
                  const SizedBox(height: 24),
                  _buildSeccion('📈 Más vendidos'),
                  const SizedBox(height: 12),
                  _buildProductosList(_productosTop, top: true),
                ]),
              ),
            ),
    );
  }

  Widget _buildSelectorPeriodo() {
    final periodos = {'hoy': 'Hoy', 'semana': 'Semana', 'mes': 'Mes'};
    return Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: periodos.entries.map((e) {
        final sel = _periodo == e.key;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _periodo = e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
            child: Text(e.value, textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ));
      }).toList()),
    );
  }

  Widget _buildKPIs() {
    final margenColor = _margen >= 20 ? AppColors.success
        : _margen >= 10 ? AppColors.warning : AppColors.danger;

    return Row(children: [
      Expanded(child: _KPICard(label: 'Ventas',
          valor: _corto(_actual['ventas'] ?? 0),
          sub: 'contado', icon: Icons.trending_up_rounded,
          color: AppColors.colorVentas)),
      const SizedBox(width: 8),
      Expanded(child: _KPICard(label: 'Ganancia',
          valor: _corto(_actual['ganancia'] ?? 0),
          sub: 'neta', icon: Icons.account_balance_wallet_rounded,
          color: AppColors.success)),
      const SizedBox(width: 8),
      Expanded(child: _KPICard(label: 'Gastos',
          valor: _corto(_actual['gastos'] ?? 0),
          sub: 'total', icon: Icons.receipt_long_rounded,
          color: AppColors.colorGastos)),
      const SizedBox(width: 8),
    Expanded(child: _KPICard(label: 'Margen',
          valor: '${_margen.toStringAsFixed(1)}%',
          sub: 'rentabilidad', icon: Icons.pie_chart_rounded,
          color: margenColor)),
    ]);
  }

  Widget _buildGraficoBarras() {
    final ventas = _actual['ventas'] ?? 0;
    final gastos = _actual['gastos'] ?? 0;
    final ganancia = _actual['ganancia'] ?? 0;
    final fiado = _actual['fiado'] ?? 0;
    final apartados = _actual['apartados'] ?? 0;
    final maxVal = [ventas, gastos, ganancia, fiado, apartados]
        .reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resumen del período', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.textPrimary,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(AppFormatters.moneda(rod.toY),
                        GoogleFonts.poppins(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final labels = ['Ventas', 'Gastos', 'Ganancia', 'Fiado', 'Apartados'];
                  if (val.toInt() >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[val.toInt()],
                        style: GoogleFonts.poppins(fontSize: 9,
                            color: AppColors.textMuted)),
                  );
                },
              )),
            ),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.cardBorder, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              _bar(0, ventas, AppColors.colorVentas),
              _bar(1, gastos, AppColors.colorGastos),
              _bar(2, ganancia, AppColors.success),
              _bar(3, fiado, AppColors.colorFiado),
              _bar(4, apartados, AppColors.colorApartados),
            ],
          )),
        ),
      ]),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(toY: y, color: color, width: 26,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
    ]);
  }

  Widget _buildGraficoPie() {
    final ventas = _actual['ventas'] ?? 0;
    final fiado = _actual['fiado'] ?? 0;
    final gastos = _actual['gastos'] ?? 0;
    final apartados = _actual['apartados'] ?? 0;
    final total = ventas + fiado + gastos + apartados;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Distribución', style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 140, height: 140,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                if (ventas > 0) PieChartSectionData(
                    value: ventas, color: AppColors.colorVentas,
                    title: '${(ventas / total * 100).toStringAsFixed(0)}%',
                    titleStyle: GoogleFonts.poppins(fontSize: 10,
                        fontWeight: FontWeight.w700, color: Colors.white),
                    radius: 50),
                if (fiado > 0) PieChartSectionData(
                    value: fiado, color: AppColors.colorFiado,
                    title: '${(fiado / total * 100).toStringAsFixed(0)}%',
                    titleStyle: GoogleFonts.poppins(fontSize: 10,
                        fontWeight: FontWeight.w700, color: Colors.white),
                    radius: 50),
                if (gastos > 0) PieChartSectionData(
                    value: gastos, color: AppColors.colorGastos,
                    title: '${(gastos / total * 100).toStringAsFixed(0)}%',
                    titleStyle: GoogleFonts.poppins(fontSize: 10,
                        fontWeight: FontWeight.w700, color: Colors.white),
                    radius: 50),
                if (apartados > 0) PieChartSectionData(
                    value: apartados, color: AppColors.colorApartados,
                    title: '${(apartados / total * 100).toStringAsFixed(0)}%',
                    titleStyle: GoogleFonts.poppins(fontSize: 10,
                        fontWeight: FontWeight.w700, color: Colors.white),
                    radius: 50),
              ],
            )),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Leyenda('Ventas', AppColors.colorVentas,
                AppFormatters.moneda(ventas)),
            const SizedBox(height: 8),
            _Leyenda('Fiado', AppColors.colorFiado,
                AppFormatters.moneda(fiado)),
            const SizedBox(height: 8),
            _Leyenda('Gastos', AppColors.colorGastos,
                AppFormatters.moneda(gastos)),
            const SizedBox(height: 8),
            _Leyenda('Apartados', AppColors.colorApartados,
                AppFormatters.moneda(apartados)),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildSeccion(String titulo) => Text(titulo,
      style: GoogleFonts.poppins(fontSize: 15,
          fontWeight: FontWeight.w700, color: AppColors.textPrimary));

  Widget _buildProductosList(List<Map<String, dynamic>> productos,
      {required bool top}) {
    if (productos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder)),
        child: Center(child: Text('Sin datos disponibles',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted))),
      );
    }
    final color = top ? AppColors.primary : AppColors.colorGastos;
    final maxCantidad = (productos.first['cantidad'] as double);

    return Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: productos.asMap().entries.map((e) {
        final i = e.key; final p = e.value;
        final pct = maxCantidad > 0 ? (p['cantidad'] as double) / maxCantidad : 0.0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: i < productos.length - 1
              ? const Border(bottom: BorderSide(color: AppColors.cardBorder))
              : null),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${i + 1}',
                  style: GoogleFonts.poppins(fontSize: 13,
                      fontWeight: FontWeight.w700, color: color)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['nombre'] as String,
                  style: GoogleFonts.poppins(fontSize: 13,
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct,
                      backgroundColor: AppColors.cardBorder,
                      color: color, minHeight: 5)),
              const SizedBox(height: 2),
              Text('${(p['cantidad'] as double).toStringAsFixed(0)} unidades',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
            ])),
            const SizedBox(width: 12),
            Text(AppFormatters.moneda(p['monto'] as double),
                style: GoogleFonts.poppins(fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
        );
      }).toList()),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String label, valor, sub;
  final IconData icon;
  final Color color;
  const _KPICard({required this.label, required this.valor,
      required this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(valor, style: GoogleFonts.poppins(fontSize: 13,
            fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10,
            color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        Text(sub, style: GoogleFonts.poppins(
            fontSize: 9, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final String label; final Color color; final String valor;
  const _Leyenda(this.label, this.color, this.valor);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(
          fontSize: 10, color: AppColors.textMuted)),
      Text(valor, style: GoogleFonts.poppins(fontSize: 11,
          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ])),
  ]);
}