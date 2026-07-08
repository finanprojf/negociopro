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
import 'dart:async';
import '../../services/local_database.dart';
import '../../services/venta_service.dart';
import '../suscripcion/suscripcion_screen.dart';
import '../encargos/encargos_screen.dart';
import '../auth/login_screen.dart';

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
  int _productosSinStock = 0;
  int _apartadosActivos = 0;
  int _diasRestantes = 999;
  bool _suscripcionVencida = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    _cargarResumen();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _cargarResumen();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

DateTime _toLocal(String dateStr) {
    try {
      final utcStr = dateStr
          .replaceAll('+00:00', 'Z')
          .replaceAll('+0000', 'Z');
      return DateTime.parse(utcStr);
    } catch (_) {
      return DateTime.now().toUtc();
    }
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
      // Sincronizar ventas pendientes
      await VentaService.sincronizarPendientes();
// Verificar suscripción
      if (await SupabaseService.isOnlineAsync) {
        final sus = await SupabaseService.getSuscripcion();
        print('📅 Suscripcion: $sus');
        if (sus != null && sus['suscripcion_vence'] != null) {
          final vence = DateTime.parse(sus['suscripcion_vence']);
          final dias = vence.difference(DateTime.now()).inDays;
          if (mounted) {
            setState(() {
              _diasRestantes = dias;
              _suscripcionVencida = dias < 0;
            });
          }
        }
      }
    // Si no hay internet cargar desde SQLite
      if (!await SupabaseService.isOnlineAsync) {
        final db = await LocalDatabase.database;
        final ahoraLocal = DateTime.now();
        final inicioLocal = DateTime(ahoraLocal.year, ahoraLocal.month, ahoraLocal.day);
        final finLocal = inicioLocal.add(const Duration(days: 1));
        final inicioUtc = inicioLocal.toUtc().toIso8601String();
        final finUtc = finLocal.toUtc().toIso8601String();

        final ventasHoy = await db.query('ventas',
            where: 'empresa_id = ? AND created_at >= ? AND created_at < ? AND estado = ? AND tipo_pago != ?',
            whereArgs: [empresaId, inicioUtc, finUtc, 'completada', 'fiado']);

        double totalVentas = 0;
        double gananciaReal = 0;

        for (final v in ventasHoy) {
          totalVentas += (v['total'] as num).toDouble();
          final detalles = await db.query('detalle_ventas',
              where: 'venta_id = ?', whereArgs: [v['id']]);
          for (final d in detalles) {
            final productos = await db.query('productos',
                where: 'id = ?', whereArgs: [d['producto_id']]);
            if (productos.isNotEmpty) {
              final precioVenta = (d['precio_unitario'] as num).toDouble();
              final precioCompra = (productos.first['precio_compra'] as num).toDouble();
              final cantidad = (d['cantidad'] as num).toDouble();
              gananciaReal += (precioVenta - precioCompra) * cantidad;
            }
          }
        }

        // Stock
        final stockBajo = await db.query('productos',
            where: 'empresa_id = ? AND activo = ?',
            whereArgs: [empresaId, 1]);

        if (mounted) {
          setState(() {
            _ventasHoy = totalVentas;
            _gananciasHoy = gananciaReal;
            _productosLowStock = stockBajo.where((p) =>
                (p['stock_actual'] as num) > 0 &&
                (p['stock_actual'] as num) <= (p['stock_minimo'] as num)).length;
            _productosSinStock = stockBajo.where((p) =>
                (p['stock_actual'] as num) <= 0).length;
          });
        }
        return;
      }

      final ahoraLocal = DateTime.now();
      final inicioLocal = DateTime(ahoraLocal.year, ahoraLocal.month, ahoraLocal.day);
      final finLocal = inicioLocal.add(const Duration(days: 1));
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
      final ventasIds = <String>[];
    // También incluir ventas locales no sincronizadas
      final db = await LocalDatabase.database;
      final ventasLocalHoy = await db.query('ventas',
          where: 'empresa_id = ? AND created_at >= ? AND created_at < ? AND estado = ? AND synced = ?',
          whereArgs: [empresaId, inicioUtc, finUtc, 'completada', 0]);

      final idsOnline = (ventas as List).map((v) => v['id'] as String).toSet();
      final ventasLocalPendientes = ventasLocalHoy
          .where((v) => !idsOnline.contains(v['id'] as String))
          .toList();

      final todasVentas = [...ventas, ...ventasLocalPendientes];

      for (final v in todasVentas) {
        if (v['tipo_pago'] != 'fiado') {
          totalVentas += (v['total'] as num).toDouble();
          ventasIds.add(v['id'] as String);
        }
      }

    double gananciaReal = 0;
      if (ventasIds.isNotEmpty) {
        // IDs de ventas online
        final idsOnlineVentas = (ventas as List).map((v) => v['id'] as String).toSet();
        final idsOffline = ventasIds.where((id) => !idsOnlineVentas.contains(id)).toList();

        // Ganancias de ventas online
        if (idsOnlineVentas.isNotEmpty) {
          final detalles = await SupabaseService.client
              .from('detalle_ventas')
              .select('cantidad, precio_unitario, productos(precio_compra)')
              .inFilter('venta_id', idsOnlineVentas.toList());

          for (final d in detalles) {
            final precioVenta = (d['precio_unitario'] as num).toDouble();
            final precioCompra = d['productos'] != null
                ? (d['productos']['precio_compra'] as num).toDouble()
                : 0.0;
            final cantidad = (d['cantidad'] as num).toDouble();
            gananciaReal += (precioVenta - precioCompra) * cantidad;
          }
        }

        // Ganancias de ventas offline
        if (idsOffline.isNotEmpty) {
          for (final ventaId in idsOffline) {
            final detalles = await db.query('detalle_ventas',
                where: 'venta_id = ?', whereArgs: [ventaId]);
            for (final d in detalles) {
              final productos = await db.query('productos',
                  where: 'id = ?', whereArgs: [d['producto_id']]);
              if (productos.isNotEmpty) {
                final precioVenta = (d['precio_unitario'] as num).toDouble();
                final precioCompra = (productos.first['precio_compra'] as num).toDouble();
                final cantidad = (d['cantidad'] as num).toDouble();
                gananciaReal += (precioVenta - precioCompra) * cantidad;
              }
            }
          }
        }
      }

      final stockBajo = await SupabaseService.client
          .from('productos')
          .select('id, stock_actual, stock_minimo')
          .eq('empresa_id', empresaId)
          .eq('activo', true);

      final apartados = await SupabaseService.client
          .from('apartados')
          .select('id')
          .eq('empresa_id', empresaId)
          .eq('estado', 'activo');

      if (mounted) {
        setState(() {
          _ventasHoy = totalVentas;
          _gananciasHoy = gananciaReal;
          _productosLowStock = (stockBajo as List).where((p) =>
              (p['stock_actual'] as num) > 0 &&
              (p['stock_actual'] as num) <= (p['stock_minimo'] as num)).length;
          _productosSinStock = (stockBajo as List).where((p) =>
              (p['stock_actual'] as num) <= 0).length;
          _apartadosActivos = (apartados as List).length;
        });
      }
    } catch (e) {
      print('❌ Error resumen: $e');
    }
  }

 @override
  Widget build(BuildContext context) {
    if (_suscripcionVencida) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_rounded,
                    size: 80, color: AppColors.danger),
                const SizedBox(height: 24),
                Text('Suscripción vencida', style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Text('Tu acceso a NegocioPro ha expirado. Renueva tu plan para continuar.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => SuscripcionScreen())),
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: Text('Ver planes', style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.textMuted),
                    label: Text('Cerrar sesión', style: GoogleFonts.poppins(
                        color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _selectedIndex == 0 ? _buildDashboard() : _buildOtrasPantallas(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
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
Widget _buildBannerVencida() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SuscripcionScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.danger,
        child: Row(children: [
          const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Suscripción vencida', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Toca aquí para renovar tu plan',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _buildBannerAviso() {
    final color = _diasRestantes <= 3 ? AppColors.danger : AppColors.warning;
    final texto = _diasRestantes <= 0
        ? 'Tu suscripción vence hoy'
        : 'Tu suscripción vence en $_diasRestantes día${_diasRestantes == 1 ? '' : 's'}';
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SuscripcionScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: color,
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(texto, style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Toca aquí para renovar tu plan',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
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
             if (_suscripcionVencida) _buildBannerVencida(),
              if (!_suscripcionVencida && _diasRestantes <= 7)
                _buildBannerAviso(),
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
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          onPressed: () { _cargarNombre(); _cargarResumen(); setState(() {}); },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
          onPressed: () {},
        ),
      GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: const Icon(Icons.store_rounded, color: AppColors.primary),
                  title: Text('Mi empresa', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmpresaScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded, color: AppColors.colorVentas),
                  title: Text('Suscripción', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuscripcionScreen()));
                  },
                ),
              ]),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySurface,
              child: Icon(Icons.person_outline, color: AppColors.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días'
        : hora < 18 ? 'Buenas tardes' : 'Buenas noches';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(saludo, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
      const SizedBox(height: 2),
      Row(children: [
        Expanded(child: Text(_nombreNegocio, style: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.successSurface, borderRadius: BorderRadius.circular(20)),
          child: Text('● Plan Pro', style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
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
        label: 'Ventas hoy', value: AppFormatters.moneda(_ventasHoy),
        icon: Icons.trending_up_rounded, color: AppColors.colorVentas,
        trend: 'Hoy', trendPositive: true,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        label: 'Ganancias hoy', value: AppFormatters.moneda(_gananciasHoy),
        icon: Icons.account_balance_wallet_rounded, color: AppColors.primary,
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
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Alertas', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95,
        children: modules.map((m) => GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => m.screen)),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
                child: Icon(m.icon, color: m.color, size: 26)),
              const SizedBox(height: 10),
              Text(m.name, style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary), textAlign: TextAlign.center),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }

  Widget _buildRecentActivity() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Actividad reciente', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      if (_empresaId != null)
        FutureBuilder(
          future: Future.wait([
          SupabaseService.client
                .from('ventas')
                .select('id, numero_venta, total, tipo_pago, monto_pagado, created_at')
                .eq('empresa_id', _empresaId!)
                .eq('estado', 'completada')
                .order('created_at', ascending: false)
                .limit(5),
            SupabaseService.client
                .from('gastos')
                .select('id, descripcion, monto, created_at')
                .eq('empresa_id', _empresaId!)
                .order('created_at', ascending: false)
                .limit(5),
            SupabaseService.client
                .from('abonos_fiado')
                .select('id, monto, created_at, clientes(nombre)')
                .eq('empresa_id', _empresaId!)
                .order('created_at', ascending: false)
                .limit(5),
            SupabaseService.client
                .from('abonos_apartado')
                .select('id, monto, created_at, apartados(descripcion)')
                .eq('empresa_id', _empresaId!)
                .order('created_at', ascending: false)
                .limit(5),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: Text('Sin actividad reciente',
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)));
            }
            final results = snapshot.data!;
            final List<Map<String, dynamic>> actividad = [];

           for (final v in results[0] as List) {
              final esCredito = v['tipo_pago'] == 'fiado';
              final montoMostrar = esCredito
                  ? (v['monto_pagado'] as num).toDouble()
                  : (v['total'] as num).toDouble();
              final saldoFiado = esCredito
                  ? (v['total'] as num).toDouble() - (v['monto_pagado'] as num).toDouble()
                  : 0.0;
              actividad.add({
                'tipo': 'venta',
                'titulo': saldoFiado > 0
                    ? 'Venta #${v['numero_venta']} (+${AppFormatters.moneda(saldoFiado)} fiado)'
                    : 'Venta #${v['numero_venta']}',
                'monto': montoMostrar,
                'fecha': _toLocal(v['created_at'] as String),
                'positivo': true,
              });
            }
            for (final g in results[1] as List) {
              actividad.add({
                'tipo': 'gasto',
                'titulo': g['descripcion'] as String,
                'monto': (g['monto'] as num).toDouble(),
                'fecha': _toLocal(g['created_at'] as String),
                'positivo': false,
              });
            }
            for (final f in results[2] as List) {
              final nombre = f['clientes'] != null
                  ? f['clientes']['nombre'] as String : 'Cliente';
              actividad.add({
                'tipo': 'fiado',
                'titulo': 'Abono fiado — $nombre',
                'monto': (f['monto'] as num).toDouble(),
                'fecha': _toLocal(f['created_at'] as String),
                'positivo': true,
              });
            }
            for (final a in results[3] as List) {
              final desc = a['apartados'] != null
                  ? a['apartados']['descripcion'] as String : 'Apartado';
              actividad.add({
                'tipo': 'apartado',
                'titulo': 'Abono apartado — $desc',
                'monto': (a['monto'] as num).toDouble(),
                'fecha': _toLocal(a['created_at'] as String),
                'positivo': true,
              });
            }

        actividad.sort((a, b) =>
    (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));

            if (actividad.isEmpty) {
              return Center(child: Text('Sin actividad reciente',
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)));
            }

            return Column(
              children: actividad.take(8).map((item) {
                IconData icon; Color color;
                switch (item['tipo']) {
                  case 'venta': icon = Icons.shopping_cart_rounded;
                      color = AppColors.colorVentas; break;
                  case 'gasto': icon = Icons.receipt_long_rounded;
                      color = AppColors.colorGastos; break;
                  case 'fiado': icon = Icons.handshake_outlined;
                      color = AppColors.colorFiado; break;
                  case 'apartado': icon = Icons.bookmark_rounded;
                      color = AppColors.colorApartados; break;
                  default: icon = Icons.circle; color = AppColors.primary;
                }
                return _ActivityTile(
                  icon: icon, color: color,
                  title: item['titulo'] as String,
             subtitle: AppFormatters.tiempoRelativo(item['fecha'] as DateTime),
                  amount: '${item['positivo'] ? '+' : '-'}${AppFormatters.moneda(item['monto'] as double)}',
                  positive: item['positivo'] as bool,
                );
              }).toList(),
            );
          },
        )
      else
        Center(child: Text('Sin actividad reciente',
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted))),
    ]);
  }

 Widget _buildOtrasPantallas() {
    final pantallas = [
      const DashboardScreen(),
      const InventarioScreen(),
      const EncargosScreen(),
      const ReportesScreen(),
    ];
    return pantallas[_selectedIndex];
  }

 Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded), label: 'Inventario'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag_rounded), label: 'Encargos'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded), label: 'Reportes'),
      ],
    );
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
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: trendPositive ? AppColors.successSurface : AppColors.dangerSurface,
              borderRadius: BorderRadius.circular(20)),
            child: Text(trend, style: GoogleFonts.poppins(fontSize: 11,
                fontWeight: FontWeight.w600,
                color: trendPositive ? AppColors.success : AppColors.danger)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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