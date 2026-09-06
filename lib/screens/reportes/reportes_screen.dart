import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  String _periodo = 'hoy';
  bool _loading = false;

  // Estructura de datos por período
  Map<String, _DatosPeriodo> _datos = {
    'hoy':    _DatosPeriodo(),
    'semana': _DatosPeriodo(),
    'mes':    _DatosPeriodo(),
  };

  List<Map<String, dynamic>> _productosTop = [];

  _DatosPeriodo get _d => _datos[_periodo]!;

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
      if (await SupabaseService.isOnlineAsync) {
        await _cargarOnline(empresaId);
      } else {
        await _cargarOffline(empresaId);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarOnline(String empresaId) async {
    try {
      final ahora = DateTime.now();
      final inicioHoy    = DateTime(ahora.year, ahora.month, ahora.day);
      final inicioSemana = inicioHoy.subtract(Duration(days: ahora.weekday - 1));
      final inicioMes    = DateTime(ahora.year, ahora.month, 1);

      for (final periodo in ['hoy', 'semana', 'mes']) {
        final inicio = periodo == 'hoy' ? inicioHoy
            : periodo == 'semana' ? inicioSemana : inicioMes;
        final inicioUtc = inicio.toUtc().toIso8601String();
        final finUtc    = ahora.add(const Duration(minutes: 1)).toUtc().toIso8601String();

        // 1. Ventas
        final ventas = await SupabaseService.client
            .from('ventas').select('id, total, tipo_pago')
            .eq('empresa_id', empresaId).eq('estado', 'completada')
            .gte('created_at', inicioUtc).lt('created_at', finUtc);

        double ventasContado = 0, ventasFiado = 0;
        final ventasIds = <String>[];
        for (final v in ventas) {
          final t = (v['total'] as num).toDouble();
          if (v['tipo_pago'] == 'fiado') { ventasFiado += t; }
          else { ventasContado += t; }
          ventasIds.add(v['id'] as String);
        }

        // 2. Ganancia bruta real (precio_venta - precio_compra) × cantidad
        double gananciaBruta = 0;
        if (ventasIds.isNotEmpty) {
          final detalles = await SupabaseService.client
              .from('detalle_ventas')
              .select('cantidad, precio_unitario, productos(precio_compra)')
              .inFilter('venta_id', ventasIds);
          for (final d in detalles) {
            final pv = (d['precio_unitario'] as num).toDouble();
            final pc = d['productos'] != null
                ? (d['productos']['precio_compra'] as num? ?? 0).toDouble()
                : 0.0;
            gananciaBruta += (pv - pc) * (d['cantidad'] as num).toDouble();
          }
        }

        // 3. Gastos
        final gastosRes = await SupabaseService.client
            .from('gastos').select('monto')
            .eq('empresa_id', empresaId)
            .gte('created_at', inicioUtc).lt('created_at', finUtc);
        double gastos = 0;
        for (final g in gastosRes) gastos += (g['monto'] as num).toDouble();
        // Sumar gastos locales no sincronizados (pueden no estar en Supabase aún)
        try {
          final db = await LocalDatabase.database;
          final gastosLocales = await db.query('gastos',
              where: 'empresa_id = ? AND synced = 0 AND created_at >= ?',
              whereArgs: [empresaId, inicioUtc]);
          for (final g in gastosLocales) gastos += (g['monto'] as num).toDouble();
        } catch (_) {}

        // 4. Cobros de fiado
        final abonosFiado = await SupabaseService.client
            .from('abonos_fiado').select('monto')
            .eq('empresa_id', empresaId)
            .gte('created_at', inicioUtc).lt('created_at', finUtc);
        double cobradoFiado = 0;
        for (final a in abonosFiado) cobradoFiado += (a['monto'] as num).toDouble();

        // 5. Cobros de apartado
        final abonosApartado = await SupabaseService.client
            .from('abonos_apartado').select('monto')
            .eq('empresa_id', empresaId)
            .gte('created_at', inicioUtc).lt('created_at', finUtc);
        double cobradoApartado = 0;
        for (final a in abonosApartado) cobradoApartado += (a['monto'] as num).toDouble();

        _datos[periodo] = _DatosPeriodo(
          ventasContado:    ventasContado,
          ventasFiado:      ventasFiado,
          gananciaBruta:    gananciaBruta,
          gastos:           gastos,
          cobradoFiado:     cobradoFiado,
          cobradoApartado:  cobradoApartado,
        );
      }

      // Productos más vendidos (del período seleccionado)
      final inicio = _periodo == 'hoy' ? DateTime(ahora.year, ahora.month, ahora.day)
          : _periodo == 'semana'
              ? DateTime(ahora.year, ahora.month, ahora.day)
                  .subtract(Duration(days: ahora.weekday - 1))
              : DateTime(ahora.year, ahora.month, 1);
      final allVentas = await SupabaseService.client
          .from('ventas').select('id')
          .eq('empresa_id', empresaId).eq('estado', 'completada')
          .gte('created_at', inicio.toUtc().toIso8601String());
      final allIds = (allVentas as List).map((v) => v['id'] as String).toList();
      if (allIds.isNotEmpty) {
        final detallesAll = await SupabaseService.client
            .from('detalle_ventas')
            .select('nombre_producto, cantidad, precio_unitario')
            .inFilter('venta_id', allIds);
        _productosTop = _calcularTop(detallesAll);
      } else {
        _productosTop = [];
      }
    } catch (_) {
      await _cargarOffline(empresaId);
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarOffline(String empresaId) async {
    final db = await LocalDatabase.database;
    final ahora = DateTime.now();
    final inicioHoy    = DateTime(ahora.year, ahora.month, ahora.day);
    final inicioSemana = inicioHoy.subtract(Duration(days: ahora.weekday - 1));
    final inicioMes    = DateTime(ahora.year, ahora.month, 1);

    for (final periodo in ['hoy', 'semana', 'mes']) {
      final inicio    = periodo == 'hoy' ? inicioHoy
          : periodo == 'semana' ? inicioSemana : inicioMes;
      final inicioStr = inicio.toUtc().toIso8601String();

      final ventas = await db.query('ventas',
          where: 'empresa_id = ? AND estado = ? AND created_at >= ?',
          whereArgs: [empresaId, 'completada', inicioStr]);

      double ventasContado = 0, ventasFiado = 0, gananciaBruta = 0;
      for (final v in ventas) {
        final total = (v['total'] as num).toDouble();
        if (v['tipo_pago'] == 'fiado') { ventasFiado += total; }
        else { ventasContado += total; }
        final detalles = await db.query('detalle_ventas',
            where: 'venta_id = ?', whereArgs: [v['id']]);
        for (final d in detalles) {
          final pv = (d['precio_unitario'] as num).toDouble();
          final pc = (d['precio_compra'] as num? ?? 0).toDouble();
          gananciaBruta += (pv - pc) * (d['cantidad'] as num).toDouble();
        }
      }

      final gastosRes = await db.query('gastos',
          where: 'empresa_id = ? AND created_at >= ?',
          whereArgs: [empresaId, inicioStr]);
      double gastos = 0;
      for (final g in gastosRes) gastos += (g['monto'] as num).toDouble();

      final abonosFiado = await db.query('abonos_fiado',
          where: 'empresa_id = ? AND created_at >= ?',
          whereArgs: [empresaId, inicioStr]);
      double cobradoFiado = 0;
      for (final a in abonosFiado) cobradoFiado += (a['monto'] as num).toDouble();

      final abonosApartado = await db.query('abonos_apartado',
          where: 'empresa_id = ? AND created_at >= ?',
          whereArgs: [empresaId, inicioStr]);
      double cobradoApartado = 0;
      for (final a in abonosApartado) cobradoApartado += (a['monto'] as num).toDouble();

      _datos[periodo] = _DatosPeriodo(
        ventasContado:   ventasContado,
        ventasFiado:     ventasFiado,
        gananciaBruta:   gananciaBruta,
        gastos:          gastos,
        cobradoFiado:    cobradoFiado,
        cobradoApartado: cobradoApartado,
      );
    }

    final todosDetalles = await db.query('detalle_ventas');
    _productosTop = _calcularTop(todosDetalles);
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _calcularTop(List<dynamic> detalles) {
    final Map<String, Map<String, dynamic>> map = {};
    for (final d in detalles) {
      final nombre  = d['nombre_producto'] as String;
      final cantidad = (d['cantidad'] as num).toDouble();
      final monto   = (d['precio_unitario'] as num).toDouble() * cantidad;
      if (map.containsKey(nombre)) {
        map[nombre]!['cantidad'] += cantidad;
        map[nombre]!['monto']   += monto;
      } else {
        map[nombre] = {'nombre': nombre, 'cantidad': cantidad, 'monto': monto};
      }
    }
    return (map.values.toList()
      ..sort((a, b) => (b['cantidad'] as double).compareTo(a['cantidad'] as double)))
        .take(5).toList();
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
                  _buildCajaCard(),
                  const SizedBox(height: 12),
                  _buildGananciaCard(),
                  const SizedBox(height: 24),
                  _buildGrafico(),
                  const SizedBox(height: 24),
                  Text('📈 Más vendidos',
                      style: GoogleFonts.poppins(fontSize: 15,
                          fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _buildProductosTop(),
                ]),
              ),
            ),
    );
  }

  Widget _buildSelectorPeriodo() {
    final opciones = {'hoy': 'Hoy', 'semana': 'Semana', 'mes': 'Mes'};
    return Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: opciones.entries.map((e) {
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
    final ganancia   = _d.gananciaNeta;
    final margen     = _d.ventasContado > 0
        ? (_d.gananciaBruta / _d.ventasContado * 100) : 0.0;
    final margenColor = margen >= 20 ? AppColors.success
        : margen >= 10 ? AppColors.warning : AppColors.danger;

    return Row(children: [
      Expanded(child: _KPICard(
          label: 'Vendido', valor: _corto(_d.totalVendido),
          sub: 'contado + fiado', icon: Icons.shopping_bag_rounded,
          color: AppColors.colorVentas)),
      const SizedBox(width: 8),
      Expanded(child: _KPICard(
          label: 'Ganancia', valor: _corto(ganancia),
          sub: 'neta del período', icon: Icons.account_balance_wallet_rounded,
          color: ganancia >= 0 ? AppColors.success : AppColors.danger)),
      const SizedBox(width: 8),
      Expanded(child: _KPICard(
          label: 'Gastos', valor: _corto(_d.gastos),
          sub: 'del período', icon: Icons.receipt_long_rounded,
          color: AppColors.colorGastos)),
      const SizedBox(width: 8),
      Expanded(child: _KPICard(
          label: 'Margen', valor: '${margen.toStringAsFixed(1)}%',
          sub: 'rentabilidad', icon: Icons.pie_chart_rounded,
          color: margenColor)),
    ]);
  }

  /// Cuadre de caja: lo que físicamente debe haber de efectivo
  Widget _buildCajaCard() {
    final contado   = _d.ventasContado;
    final cobFiado  = _d.cobradoFiado;
    final cobApart  = _d.cobradoApartado;
    final gastos    = _d.gastos;
    final enCaja    = contado + cobFiado + cobApart - gastos;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.savings_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('Lo que debe haber en caja',
              style: GoogleFonts.poppins(fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 16),
        _Fila('💵 Ventas contado', contado, AppColors.colorVentas),
        if (cobFiado > 0) ...[
          const SizedBox(height: 8),
          _Fila('🤝 Cobros de fiado', cobFiado, AppColors.success),
        ],
        if (cobApart > 0) ...[
          const SizedBox(height: 8),
          _Fila('📦 Cobros de apartado', cobApart, AppColors.colorApartados),
        ],
        if (gastos > 0) ...[
          const SizedBox(height: 8),
          _Fila('💸 Gastos pagados', -gastos, AppColors.colorGastos),
        ],
        if (_d.ventasFiado > 0) ...[
          const SizedBox(height: 8),
          _Fila('🤲 Fiado dado (no entra)', _d.ventasFiado, AppColors.textMuted,
              nota: 'pendiente de cobro'),
        ],
        const Divider(height: 24),
        _Fila('💰 Total esperado en caja', enCaja, AppColors.primary, grande: true),
      ]),
    );
  }

  /// Ganancia real = margen bruto − gastos
  Widget _buildGananciaCard() {
    final bruta  = _d.gananciaBruta;
    final gastos = _d.gastos;
    final neta   = _d.gananciaNeta;
    final esPos  = neta >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esPos ? AppColors.successSurface : AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (esPos ? AppColors.success : AppColors.danger)
                .withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(esPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: esPos ? AppColors.success : AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Text('Ganancia real del período',
              style: GoogleFonts.poppins(fontSize: 14,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 16),
        _Fila('📊 Margen bruto', bruta, AppColors.success,
            nota: 'precio venta − costo por unidad'),
        if (gastos > 0) ...[
          const SizedBox(height: 8),
          _Fila('💸 Gastos', -gastos, AppColors.colorGastos),
        ],
        const Divider(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('✅ Ganancia neta',
              style: GoogleFonts.poppins(fontSize: 15,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text((neta < 0 ? "-" : "") + AppFormatters.moneda(neta.abs()),
              style: GoogleFonts.poppins(fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: esPos ? AppColors.success : AppColors.danger)),
        ]),
      ]),
    );
  }

  Widget _buildGrafico() {
    final ventas   = _d.ventasContado;
    final gastos   = _d.gastos;
    final ganancia = _d.gananciaNeta;
    final fiado    = _d.ventasFiado;
    final maxVal   = [ventas, gastos, ganancia.abs(), fiado]
        .reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resumen visual',
            style: GoogleFonts.poppins(fontSize: 14,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 20),
        SizedBox(height: 160, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.25,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                  AppFormatters.moneda(rod.toY),
                  GoogleFonts.poppins(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final labels = ['Contado', 'Fiado', 'Gastos', 'Ganancia'];
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
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.cardBorder, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            _bar(0, ventas,           AppColors.colorVentas),
            _bar(1, fiado,            AppColors.colorFiado),
            _bar(2, gastos,           AppColors.colorGastos),
            _bar(3, ganancia.abs(),   ganancia >= 0 ? AppColors.success : AppColors.danger),
          ],
        ))),
      ]),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
    x: x,
    barRods: [BarChartRodData(toY: y, color: color, width: 26,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
  );

  Widget _buildProductosTop() {
    if (_productosTop.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder)),
        child: Center(child: Text('Sin ventas en este período',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted))),
      );
    }
    final max = (_productosTop.first['cantidad'] as double);
    return Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(children: _productosTop.asMap().entries.map((e) {
        final i = e.key; final p = e.value;
        final pct = max > 0 ? (p['cantidad'] as double) / max : 0.0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: i < _productosTop.length - 1
              ? const Border(bottom: BorderSide(color: AppColors.cardBorder)) : null),
          child: Row(children: [
            Container(width: 28, height: 28,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${i + 1}',
                    style: GoogleFonts.poppins(fontSize: 13,
                        fontWeight: FontWeight.w700, color: AppColors.primary)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(p['nombre'] as String,
                  style: GoogleFonts.poppins(fontSize: 13,
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct,
                      backgroundColor: AppColors.cardBorder,
                      color: AppColors.primary, minHeight: 5)),
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

  String _corto(double v) {
    if (v >= 1000000) return 'RD\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'RD\$ ${(v / 1000).toStringAsFixed(1)}k';
    return AppFormatters.moneda(v);
  }
}

// ─── Modelo de datos por período ──────────────────────────────────────────────
class _DatosPeriodo {
  final double ventasContado;
  final double ventasFiado;
  final double gananciaBruta;   // (precio_venta − precio_compra) × cantidad
  final double gastos;
  final double cobradoFiado;
  final double cobradoApartado;

  _DatosPeriodo({
    this.ventasContado   = 0,
    this.ventasFiado     = 0,
    this.gananciaBruta   = 0,
    this.gastos          = 0,
    this.cobradoFiado    = 0,
    this.cobradoApartado = 0,
  });

  double get totalVendido  => ventasContado + ventasFiado;
  /// Ganancia neta = margen real de los productos − gastos del período
  double get gananciaNeta  => gananciaBruta - gastos;
  /// Efectivo esperado en caja = contado + cobros − gastos
  double get cajaEsperada  => ventasContado + cobradoFiado + cobradoApartado - gastos;
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────
class _KPICard extends StatelessWidget {
  final String label, valor, sub;
  final IconData icon;
  final Color color;
  const _KPICard({required this.label, required this.valor,
      required this.sub, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
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
      Text(sub, style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted)),
    ]),
  );
}

class _Fila extends StatelessWidget {
  final String label;
  final double valor;
  final Color color;
  final bool grande;
  final String? nota;
  const _Fila(this.label, this.valor, this.color,
      {this.grande = false, this.nota});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(label, style: GoogleFonts.poppins(
            fontSize: grande ? 14 : 13,
            fontWeight: grande ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary)),
        if (nota != null)
          Text(nota!, style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textMuted)),
      ])),
      Text(valor < 0
              ? '−${AppFormatters.moneda(valor.abs())}'
              : AppFormatters.moneda(valor),
          style: GoogleFonts.poppins(
              fontSize: grande ? 16 : 14,
              fontWeight: FontWeight.w700,
              color: color)),
    ],
  );
}
