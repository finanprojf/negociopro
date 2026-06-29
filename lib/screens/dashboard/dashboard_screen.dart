import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../ventas/pos_screen.dart';
import '../inventario/inventario_screen.dart';
import '../clientes/clientes_screen.dart';
import '../fiado/fiado_screen.dart';
import '../apartados/apartados_screen.dart';
import '../gastos/gastos_screen.dart';
import '../reportes/reportes_screen.dart';
import '../empresa/empresa_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
String _nombreNegocio = 'Mi Negocio';
String? _empresaId;
double _ventasHoy = 0;
double _gananciasHoy = 0;
int _productosLowStock = 0;
int _clientesConDeuda = 0;
int _productosSinStock = 0;
int _apartadosActivos = 0;
@override
 void initState() {
    super.initState();
    _cargarNombre();
    _cargarResumen();
  }

  Future<void> _cargarNombre() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId != null) {
        final res = await SupabaseService.client
            .from('empresas')
            .select('nombre')
            .eq('id', empresaId)
            .single();
        if (mounted) setState(() => _nombreNegocio = res['nombre'] ?? 'Mi Negocio');
      }
    } catch (e) {
      print('❌ Error nombre: $e');
    }
  }
  Future<void> _cargarResumen() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;
      _empresaId = empresaId;

      // Ventas hoy
    final hoy = DateTime.now().toUtc();
      final inicio = DateTime.utc(hoy.year, hoy.month, hoy.day).toIso8601String();
      final fin = DateTime.utc(hoy.year, hoy.month, hoy.day + 1).toIso8601String();

    final ventas = await SupabaseService.client
          .from('ventas')
          .select('total, tipo_pago')
          .eq('empresa_id', empresaId)
          .eq('estado', 'completada')
          .gte('created_at', inicio)
          .lt('created_at', fin);
          

     double totalVentas = 0;
      double totalFiado = 0;
      for (final v in ventas) {
        if (v['tipo_pago'] != 'fiado') {
          totalVentas += (v['total'] as num).toDouble();
        } else {
          totalFiado += (v['total'] as num).toDouble();
        }
      }

      // Stock bajo
     final stockBajo = await SupabaseService.client
          .from('productos')
          .select('id, stock_actual, stock_minimo')
          .eq('empresa_id', empresaId)
          .eq('activo', true);

      // Fiados activos
      final fiados = await SupabaseService.client
          .from('fiados')
          .select('id')
          .eq('empresa_id', empresaId)
          .eq('estado', 'activo');

      // Apartados activos
      final apartados = await SupabaseService.client
          .from('apartados')
          .select('id')
          .eq('empresa_id', empresaId)
          .eq('estado', 'activo');
// Calcular ganancias (ventas - gastos del día)
      final gastos = await SupabaseService.client
          .from('gastos')
          .select('monto')
          .eq('empresa_id', empresaId)
          .gte('created_at', inicio)
          .lt('created_at', fin);

      double totalGastos = 0;
      for (final g in gastos) {
        totalGastos += (g['monto'] as num).toDouble();
      }

     if (mounted) {
        setState(() {
          _ventasHoy = totalVentas;
          _gananciasHoy = totalVentas - totalGastos;
        _productosLowStock = (stockBajo as List).where((p) =>
              (p['stock_actual'] as num) > 0 &&
              (p['stock_actual'] as num) <= (p['stock_minimo'] as num)).length;
          _clientesConDeuda = (fiados as List).length;
          _apartadosActivos = (apartados as List).length;
          _productosSinStock = (stockBajo as List).where((p) =>
              (p['stock_actual'] as num) <= 0).length;
        });
      }
    
    } catch (e) {
      print('❌ Error resumen: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0 ? _buildDashboard() : _buildOtrasPantallas(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedIndex == 0
          ?FloatingActionButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PosScreen())),
              backgroundColor: AppColors.primary,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 20),
                  Text('Venta', style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 9)),
                ],
              ),
            )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      
    );
  }

  Widget _buildDashboard() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildGreeting(),
              const SizedBox(height: 20),
              _buildStatCards(),
              const SizedBox(height: 24),
              _buildAlertSection(),
              const SizedBox(height: 24),
              _buildModulesGrid(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
            ]),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text('NegocioPro', style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.textSecondary),
          onPressed: () {},
        ),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const EmpresaScreen())),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySurface,
              child: Icon(Icons.person_outline,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? 'Buenos días'
        : hora < 18 ? 'Buenas tardes' : 'Buenas noches';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(saludo, style: GoogleFonts.poppins(
          fontSize: 14, color: AppColors.textMuted)),
      const SizedBox(height: 2),
      Row(children: [
   Expanded(child: Text(_nombreNegocio,
    style: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.successSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('● Plan Pro', style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.success)),
        ),
      ]),
      const SizedBox(height: 4),
      Text(AppFormatters.fechaHora(DateTime.now()),
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }

  Widget _buildStatCards() {
    return Row(children: [
    Expanded(child: _StatCard(
        label: 'Ventas hoy',
        value: AppFormatters.moneda(_ventasHoy),
        icon: Icons.trending_up_rounded,
        color: AppColors.colorVentas,
        trend: 'Hoy', trendPositive: true,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        label: 'Ganancias hoy',
        value: AppFormatters.moneda(_gananciasHoy),
        icon: Icons.account_balance_wallet_rounded,
        color: AppColors.primary,
        trend: 'Hoy', trendPositive: true,
      )),
    ]);
  }

  Widget _buildAlertSection() {
    final alerts = <Map<String, dynamic>>[];
   if (_productosLowStock > 0) {
      alerts.add({
        'icon': Icons.inventory_2_outlined,
        'color': AppColors.warning, 'bg': AppColors.warningSurface,
        'text': '$_productosLowStock productos con stock bajo',
        'screen': const InventarioScreen(),
      });
    }
    if (_productosSinStock > 0) {
      alerts.add({
        'icon': Icons.remove_shopping_cart_rounded,
        'color': AppColors.danger, 'bg': AppColors.dangerSurface,
        'text': '$_productosSinStock productos sin stock',
        'screen': const InventarioScreen(),
      });
    }
  
    if (_apartadosActivos > 0) {
      alerts.add({
        'icon': Icons.bookmark_outlined,
        'color': AppColors.colorApartados, 'bg': AppColors.accentSurface,
        'text': '$_apartadosActivos apartados activos',
        'screen': const ApartadosScreen(),
      });
    }
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Alertas', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      ...alerts.map((a) => _AlertTile(
        icon: a['icon'] as IconData,
        color: a['color'] as Color,
        bg: a['bg'] as Color,
        text: a['text'] as String,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => a['screen'] as Widget)),
      )),
    ]);
  }

  Widget _buildModulesGrid() {
    final modules = [
      _ModuleItem('Inventario', Icons.inventory_2_rounded,
          AppColors.colorInventario, const InventarioScreen()),
      _ModuleItem('Clientes', Icons.people_rounded,
          AppColors.colorClientes, const ClientesScreen()),
      _ModuleItem('Fiado', Icons.account_balance_wallet_rounded,
          AppColors.colorFiado, const FiadoScreen()),
      _ModuleItem('Apartados', Icons.bookmark_rounded,
          AppColors.colorApartados, const ApartadosScreen()),
      _ModuleItem('Gastos', Icons.receipt_long_rounded,
          AppColors.colorGastos, const GastosScreen()),
      _ModuleItem('Reportes', Icons.bar_chart_rounded,
          AppColors.colorReportes, const ReportesScreen()),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Módulos', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: modules.map((m) => GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => m.screen)),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: m.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(m.icon, color: m.color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(m.name, style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        )).toList(),
      ),
    ]);
  }

 Widget _buildRecentActivity() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Actividad reciente', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      FutureBuilder(
        future: SupabaseService.client
            .from('ventas')
            .select('numero_venta, total, tipo_pago, created_at')
            .eq('empresa_id', _empresaId ?? '')
            .order('created_at', ascending: false)
            .limit(5),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final ventas = snapshot.data as List;
          if (ventas.isEmpty) {
            return Center(child: Text('Sin actividad reciente',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppColors.textMuted)));
          }
          return Column(
            children: ventas.map((v) => _ActivityTile(
              icon: Icons.shopping_cart_rounded,
              color: AppColors.colorVentas,
              title: 'Venta #${v['numero_venta']}',
              subtitle: AppFormatters.tiempoRelativo(
                  DateTime.parse(v['created_at'])),
              amount: '+${AppFormatters.moneda((v['total'] as num).toDouble())}',
              positive: true,
            )).toList(),
          );
        },
      ),
    ]);
  }

  Widget _buildOtrasPantallas() {
    final pantallas = [
      const DashboardScreen(),
      const InventarioScreen(),
      const ClientesScreen(),
      const ReportesScreen(),
    ];
    return pantallas[_selectedIndex];
  }

 Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio'),
        BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventario'),
        BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Clientes'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reportes'),
      ],
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, selected;
  final Function(int) onTap;
  const _NavItem(this.icon, this.activeIcon, this.label,
      this.index, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = selected == index;
    return Expanded(child: InkWell(
      onTap: () => onTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(sel ? activeIcon : icon,
              color: sel ? AppColors.primary : AppColors.textMuted, size: 24),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? AppColors.primary : AppColors.textMuted)),
        ]),
      ),
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, trend;
  final IconData icon;
  final Color color;
  final bool trendPositive;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color,
      required this.trend, required this.trendPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: trendPositive
                  ? AppColors.successSurface : AppColors.dangerSurface,
              borderRadius: BorderRadius.circular(20)),
            child: Text(trend, style: GoogleFonts.poppins(fontSize: 11,
                fontWeight: FontWeight.w600,
                color: trendPositive ? AppColors.success : AppColors.danger)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 17,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String text;
  final VoidCallback onTap;
  const _AlertTile({required this.icon, required this.color,
      required this.bg, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w500, color: color))),
          Text('Ver', style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

class _ModuleItem {
  final String name;
  final IconData icon;
  final Color color;
  final Widget screen;
  _ModuleItem(this.name, this.icon, this.color, this.screen);
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, amount;
  final bool positive;
  const _ActivityTile({required this.icon, required this.color,
      required this.title, required this.subtitle,
      required this.amount, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(subtitle, style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textMuted)),
        ])),
        Text(amount, style: GoogleFonts.poppins(fontSize: 14,
            fontWeight: FontWeight.w700,
            color: positive ? AppColors.success : AppColors.danger)),
      ]),
    );
  }
}