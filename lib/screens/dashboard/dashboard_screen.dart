import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../utils/formatters.dart';
import '../ventas/pos_screen.dart';
import '../inventario/inventario_screen.dart';
import '../clientes/clientes_screen.dart';
import '../fiado/fiado_screen.dart';
import '../apartados/apartados_screen.dart';
import '../gastos/gastos_screen.dart';
import '../reportes/reportes_screen.dart';
import '../empresa/empresa_screen.dart';
import '../seguridad/pin_configuracion_screen.dart';
import '../vitrina/vitrina_config_screen.dart';
import '../vitrina/vitrina_qr_screen.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../../services/supabase_service.dart';
import 'dart:async';
import '../../services/local_database.dart';
import '../../services/venta_service.dart';
import '../suscripcion/suscripcion_screen.dart';
import '../encargos/encargos_screen.dart';
import '../reportes/cierre_dia_screen.dart';
import '../auth/login_screen.dart';
import '../recordatorios/recordatorios_screen.dart';
import '../../services/plan_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _nombreNegocio = 'Mi Negocio';
  String? _empresaId;
  String _appVersion = '';
  double _ventasHoy = 0;
  double _gananciasHoy = 0;
  int _productosLowStock = 0;
  int _productosSinStock = 0;
  int _apartadosActivos = 0;
  int _diasRestantes = 999;
  bool _suscripcionVencida = false;
  bool _vitrinaActiva = false;
  String _vitrinaUrl = '';
  List<Map<String, dynamic>> _recordatoriosHoy = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarNombre();
    _cargarResumen();
    _cargarVersion();
    _cargarRecordatoriosHoy();
    _cargarVitrina();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _cargarResumen();
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refrescar al volver la app a primer plano — captura cambios de otros dispositivos
    if (state == AppLifecycleState.resumed && mounted) {
      _cargarResumen();
      _cargarRecordatoriosHoy();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

Future<void> _cargarVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = 'v${info.version}');
  }

  DateTime _toLocal(String dateStr) {
    try {
      final utcStr = dateStr
          .replaceAll('+00:00', 'Z')
          .replaceAll('+0000', 'Z');
      return DateTime.parse(utcStr).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
  Future<void> _cargarNombre() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      // 1. Mostrar inmediatamente lo que hay en SQLite (local-first)
      final db = await LocalDatabase.database;
      final rows = await db.query('empresas', where: 'id = ?', whereArgs: [empresaId]);
      if (rows.isNotEmpty && mounted) {
        final nombreLocal = rows.first['nombre'] as String? ?? '';
        if (nombreLocal.isNotEmpty) {
          setState(() => _nombreNegocio = nombreLocal);
        }
      }

      // 2. Siempre actualizar desde Supabase para tener el nombre correcto
      if (await SupabaseService.isOnlineAsync) {
        final res = await SupabaseService.client
            .from('empresas')
            .select('id, nombre, telefono, whatsapp, correo, direccion, moneda, logo_url, lema, mensaje_recibo')
            .eq('id', empresaId)
            .maybeSingle();
        if (res != null) {
          final nombre = res['nombre'] as String? ?? 'Mi Negocio';
          // Cachear en SQLite para uso offline
          final map = Map<String, dynamic>.from(res);
          map['synced'] = 1;
          try { await LocalDatabase.insertar('empresas', map); } catch (_) {}
          if (mounted) setState(() => _nombreNegocio = nombre);
        }
      }
    } catch (_) {}
  }

 Future<void> _cargarResumen() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;
      _empresaId = empresaId;
      // Sincronizar ventas pendientes
      await VentaService.sincronizarPendientes();
      final online = await SupabaseService.isOnlineAsync;
// Verificar suscripción y cargar plan
      await PlanService.cargar(); // usa Supabase si hay internet, caché si no
      if (online) {
        final sus = await SupabaseService.getSuscripcion();
        if (sus != null && sus['suscripcion_vence'] != null) {
          final vence = DateTime.parse(sus['suscripcion_vence'].toString().replaceAll('+00:00', 'Z'));
          final dias = vence.difference(DateTime.now()).inDays;
          if (mounted) {
            setState(() {
              _diasRestantes = dias;
              _suscripcionVencida = dias < 0;
            });
          }
        }
      } else {
        // Sin internet: usar fecha de vencimiento guardada localmente
        final cached = await PlanService.diasRestantesOffline();
        if (cached.dias != null && mounted) {
          setState(() {
            _diasRestantes = cached.dias!;
            _suscripcionVencida = cached.vencida;
          });
        }
      }
    // Si no hay internet cargar desde SQLite
      if (!online) {
        final db = await LocalDatabase.database;

        // Filtrar desde el último cierre (no desde medianoche)
        String? desdeCierre;
        final cierresOff = await db.query('cierres_dia',
            where: 'empresa_id = ?', whereArgs: [empresaId],
            orderBy: 'created_at DESC', limit: 1);
        if (cierresOff.isNotEmpty) {
          desdeCierre = cierresOff.first['created_at'] as String?;
        }
        final desdeStr = desdeCierre ?? '2000-01-01T00:00:00.000Z';

        final ventasHoy = await db.query('ventas',
            where: 'empresa_id = ? AND created_at >= ? AND estado = ? AND tipo_pago != ?',
            whereArgs: [empresaId, desdeStr, 'completada', 'fiado']);

        double totalVentas = 0;
        double gananciaReal = 0;

        // Batch load: 1 query for all detalles, 1 query for all productos
        for (final v in ventasHoy) {
          totalVentas += (v['total'] as num).toDouble();
        }
        if (ventasHoy.isNotEmpty) {
          final ventaIds = ventasHoy.map((v) => "'${v['id']}'").join(',');
          final todosDetalles = await db.rawQuery(
              'SELECT dv.cantidad, dv.precio_unitario, '
              '  CASE WHEN dv.precio_compra > 0 THEN dv.precio_compra '
              '       ELSE COALESCE(p.precio_compra, 0) END AS precio_compra '
              'FROM detalle_ventas dv '
              'LEFT JOIN productos p ON p.id = dv.producto_id '
              'WHERE dv.venta_id IN ($ventaIds)');
          for (final d in todosDetalles) {
            final pc = (d['precio_compra'] as num? ?? 0).toDouble();
            if (pc > 0) {
              final precioVenta = (d['precio_unitario'] as num).toDouble();
              final cantidad = (d['cantidad'] as num).toDouble();
              gananciaReal += (precioVenta - pc) * cantidad;
            }
          }
        }

        // Stock
        final stockBajo = await db.query('productos',
            where: 'empresa_id = ? AND activo = ?',
            whereArgs: [empresaId, 1]);

        final apartadosOffline = await db.query('apartados',
            where: 'empresa_id = ? AND estado = ?',
            whereArgs: [empresaId, 'activo']);
        if (mounted) {
          setState(() {
            _ventasHoy = totalVentas;
            _gananciasHoy = gananciaReal;
            _productosLowStock = stockBajo.where((p) =>
                (p['stock_actual'] as num) > 0 &&
                (p['stock_actual'] as num) <= (p['stock_minimo'] as num)).length;
            _productosSinStock = stockBajo.where((p) =>
                (p['stock_actual'] as num) <= 0).length;
            _apartadosActivos = apartadosOffline.length;
          });
        }
        return;
      }

      // Filtrar desde el último cierre (no desde medianoche)
      // ── Sincronizar último cierre desde Supabase antes de leer local ──
      // Esto evita que un 2do dispositivo muestre "sin cuadre" hasta sync.
      final db = await LocalDatabase.database;
      try {
        final remoto = await SupabaseService.client
            .from('cierres_dia')
            .select('id, created_at, fecha, total_ventas, cantidad_ventas, '
                    'total_gastos, ganancia, ganancia_real, efectivo_esperado, '
                    'efectivo_contado, diferencia, notas')
            .eq('empresa_id', empresaId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        if (remoto != null) {
          final m = Map<String, dynamic>.from(remoto as Map);
          m['synced'] = 1;
          await db.insert('cierres_dia', m,
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } catch (_) {
        // Si falla, continuar con lo que hay en local
      }
      String? desdeCierre;
      final cierresOn = await db.query('cierres_dia',
          where: 'empresa_id = ?', whereArgs: [empresaId],
          orderBy: 'created_at DESC', limit: 1);
      if (cierresOn.isNotEmpty) {
        desdeCierre = cierresOn.first['created_at'] as String?;
      }
      final desdeStr = desdeCierre ?? '2000-01-01T00:00:00.000Z';

      var qVentas = SupabaseService.client
          .from('ventas')
          .select('id, total, subtotal, descuento, tipo_pago, monto_pagado, numero_venta, created_at')
          .eq('empresa_id', empresaId)
          .eq('estado', 'completada')
          .gte('created_at', desdeStr);
      final ventas = await qVentas;

      // Cachear ventas en SQLite para uso offline
      for (final v in ventas as List) {
        try {
          final vid = v['id'] as String;
          await db.insert('ventas', {
            'id': vid,
            'empresa_id': empresaId,
            'numero_venta': v['numero_venta'],
            'total': (v['total'] as num).toDouble(),
            'subtotal': (v['subtotal'] as num? ?? v['total'] as num).toDouble(),
            'descuento': (v['descuento'] as num? ?? 0).toDouble(),
            'monto_pagado': (v['monto_pagado'] as num? ?? 0).toDouble(),
            'tipo_pago': v['tipo_pago'] as String? ?? 'efectivo',
            'estado': 'completada',
            'created_at': v['created_at'] as String,
            'synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          // Actualizar numero_venta si la fila ya existía sin él
          if (v['numero_venta'] != null) {
            await db.update('ventas', {'numero_venta': v['numero_venta']},
                where: 'id = ? AND numero_venta IS NULL', whereArgs: [vid]);
          }
        } catch (_) {}
      }

      // Cachear detalle_ventas de Supabase en SQLite para que ganancias funcione
      if ((ventas as List).isNotEmpty) {
        final ids = ventas.map((v) => v['id'] as String).toList();
        try {
          final detallesRemoto = await SupabaseService.client
              .from('detalle_ventas')
              .select()
              .inFilter('venta_id', ids);
          for (final d in detallesRemoto as List) {
            try {
              await db.insert('detalle_ventas', Map<String, dynamic>.from(d),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            } catch (_) {}
          }

          // Backfill: cachear productos con precio_compra y rellenar detalle_ventas
          // Esto resuelve ganancia = 0 en dispositivos nuevos donde productos no está local
          try {
            final prodIds = (detallesRemoto as List)
                .where((d) => d['producto_id'] != null)
                .map((d) => d['producto_id'] as String)
                .toSet().toList();
            if (prodIds.isNotEmpty) {
              final prods = await SupabaseService.client
                  .from('productos')
                  .select('id, nombre, precio_compra, precio_venta, stock_actual, stock_minimo, activo, empresa_id')
                  .inFilter('id', prodIds);
              for (final p in prods as List) {
                try {
                  final map = Map<String, dynamic>.from(p);
                  map['synced'] = 1;
                  await db.insert('productos', map,
                      conflictAlgorithm: ConflictAlgorithm.ignore);
                } catch (_) {}
                // Actualizar precio_compra si el producto ya existía con valor 0
                final pc = (p['precio_compra'] as num? ?? 0).toDouble();
                if (pc > 0) {
                  await db.update('productos', {'precio_compra': pc},
                      where: 'id = ? AND (precio_compra IS NULL OR precio_compra = 0)',
                      whereArgs: [p['id']]);
                }
              }
              // Propagar precio_compra a detalle_ventas locales
              await LocalDatabase.backfillPrecioCompra();
            }
          } catch (_) {}
        } catch (_) {}
      }

      double totalVentas = 0;
      final ventasIds = <String>[];
      // También incluir ventas locales no sincronizadas
      final ventasLocalHoy = await db.query('ventas',
          where: 'empresa_id = ? AND created_at >= ? AND estado = ? AND synced = ?',
          whereArgs: [empresaId, desdeStr, 'completada', 0]);

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
      // Calcular ganancias usando precio_compra guardado en detalle_ventas.
      // Fallback: JOIN con productos para ventas viejas que no tengan el campo.
      if (ventasIds.isNotEmpty) {
        final allIds = ventasIds.map((id) => "'$id'").join(',');
        final todosDetalles = await db.rawQuery(
            'SELECT dv.cantidad, dv.precio_unitario, '
            '  CASE WHEN dv.precio_compra > 0 THEN dv.precio_compra '
            '       ELSE COALESCE(p.precio_compra, 0) END AS precio_compra '
            'FROM detalle_ventas dv '
            'LEFT JOIN productos p ON p.id = dv.producto_id '
            'WHERE dv.venta_id IN ($allIds)');
        for (final d in todosDetalles) {
          final pc = (d['precio_compra'] as num? ?? 0).toDouble();
          if (pc > 0) {
            final precioVenta = (d['precio_unitario'] as num).toDouble();
            final cantidad = (d['cantidad'] as num).toDouble();
            gananciaReal += (precioVenta - pc) * cantidad;
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
    } catch (_) {}
  }

  Future<void> _cargarVitrina() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;
      // Siempre mostramos el widget, URL por defecto con empresaId
      final defaultUrl = 'https://vitrina-web-beta.vercel.app/t/$empresaId';
      if (mounted) setState(() => _vitrinaUrl = defaultUrl);

      if (await SupabaseService.isOnlineAsync) {
        final res = await SupabaseService.client
            .from('vitrina_config')
            .select()
            .eq('empresa_id', empresaId)
            .maybeSingle();
        if (res != null && mounted) {
          final slug = res['slug'] as String? ?? '';
          final activa = res['activa'] == true;
          final url = 'https://vitrina-web-beta.vercel.app/t/${slug.isNotEmpty ? slug : empresaId}';
          setState(() {
            _vitrinaActiva = activa;
            _vitrinaUrl = url;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarRecordatoriosHoy() async {
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;
      final hoy = DateTime.now();
      final fechaStr =
          '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
      final db = await LocalDatabase.database;
      final rows = await db.query(
        'recordatorios',
        where: 'empresa_id = ? AND fecha = ? AND completado = 0',
        whereArgs: [empresaId, fechaStr],
        orderBy: 'hora ASC',
      );
      if (mounted) setState(() => _recordatoriosHoy = rows);
    } catch (_) {}
  }

 @override
  Widget build(BuildContext context) {
    final pal = AppPalette.of(context);
    if (_suscripcionVencida) {
      return Scaffold(
        backgroundColor: pal.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_rounded,
                    size: 80, color: pal.danger),
                const SizedBox(height: 24),
                Text('Suscripción vencida', style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: pal.textPrimary)),
                const SizedBox(height: 12),
                Text('Tu acceso a NegocioPro ha expirado. Renueva tu plan para continuar.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: pal.textSecondary)),
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
                    icon: Icon(Icons.logout_rounded,
                        color: pal.textMuted),
                    label: Text('Cerrar sesión', style: GoogleFonts.poppins(
                        color: pal.textMuted, fontWeight: FontWeight.w600)),
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
              backgroundColor: pal.primary,
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
Widget _buildVitrinaWidget() {
    final pal = AppPalette.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VitrinaConfigScreen()))
              .then((_) => _cargarVitrina()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _vitrinaActiva
                ? [const Color(0xFF0F7B5B), const Color(0xFF0A5C44)]
                : [pal.surfaceAlt, pal.surfaceAlt],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: _vitrinaActiva
              ? null
              : Border.all(color: pal.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _vitrinaActiva
                  ? Colors.white.withValues(alpha: 0.2)
                  : pal.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.storefront_rounded,
                color: _vitrinaActiva ? Colors.white : pal.primary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vitrina Online',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _vitrinaActiva ? Colors.white : pal.textPrimary)),
              Text(_vitrinaActiva ? 'Tu tienda está activa y visible' : 'Tu tienda está desactivada',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: _vitrinaActiva
                          ? Colors.white.withValues(alpha: 0.75)
                          : pal.textMuted)),
            ],
          )),
          // Botones rápidos
          if (_vitrinaActiva) ...[
            _miniBtn(
              icon: Icons.qr_code_rounded,
              tooltip: 'Ver QR',
              light: true,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => VitrinaQrScreen(
                    url: _vitrinaUrl,
                    empresaNombre: _nombreNegocio,
                  ))),
            ),
            const SizedBox(width: 6),
            _miniBtn(
              icon: Icons.share_rounded,
              tooltip: 'Compartir',
              light: true,
              onTap: () => Share.share(
                '🛍️ Mira el catálogo de $_nombreNegocio:\n$_vitrinaUrl',
                subject: 'Catálogo de $_nombreNegocio',
              ),
            ),
          ] else ...[
            Icon(Icons.chevron_right_rounded,
                color: pal.textMuted, size: 20),
          ],
        ]),
      ),
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool light = false,
  }) {
    final pal = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: 0.2)
                : pal.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon,
              color: light ? Colors.white : pal.primary, size: 17),
        ),
      ),
    );
  }

  Widget _buildBannerVencida() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SuscripcionScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: pal.danger,
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
    final pal = AppPalette.of(context);
    final color = _diasRestantes <= 3 ? pal.danger : pal.warning;
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
              const SizedBox(height: 16),
              if (_recordatoriosHoy.isNotEmpty) ...[
                _buildRecordatoriosHoy(),
                const SizedBox(height: 16),
              ],
              _buildStatCards(),
              const SizedBox(height: 16),
              _buildAlertSection(),
              const SizedBox(height: 16),
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
    final pal = AppPalette.of(context);
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: pal.surface,
      elevation: 0,
      title: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: pal.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text('NegocioPro', style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: pal.textPrimary)),
      ]),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: pal.textSecondary),
          onPressed: () { _cargarNombre(); _cargarResumen(); setState(() {}); },
        ),
        GestureDetector(
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RecordatoriosScreen()));
            _cargarRecordatoriosHoy();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_outlined, color: pal.textSecondary, size: 24),
                    Text('Recordatorios',
                      style: TextStyle(
                        fontSize: 7.5,
                        color: pal.textSecondary,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      )),
                  ],
                ),
            if (_recordatoriosHoy.isNotEmpty)
              Positioned(
                top: 6, right: 6,
                child: IgnorePointer(
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: pal.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.surface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _recordatoriosHoy.length > 9 ? '9+' : '${_recordatoriosHoy.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: Icon(Icons.store_rounded, color: pal.primary),
                  title: Text('Mi empresa', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmpresaScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.storefront_rounded, color: pal.colorApartados),
                  title: Text('Mi Vitrina Digital', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text('Catálogo público para clientes',
                      style: GoogleFonts.poppins(fontSize: 11, color: pal.textMuted)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VitrinaConfigScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.workspace_premium_rounded, color: pal.colorVentas),
                  title: Text('Suscripción', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SuscripcionScreen()));
                  },
                ),
                ListTile(
                  leading: Icon(Icons.lock_rounded, color: pal.textSecondary),
                  title: Text('Seguridad y PIN', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Text('PIN de acceso y acciones rápidas',
                      style: GoogleFonts.poppins(fontSize: 11, color: pal.textMuted)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PinConfiguracionScreen()));
                  },
                ),
              ]),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: pal.primarySurface,
              child: Icon(Icons.person_outline, color: pal.primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordatoriosHoy() {
    final pal = AppPalette.of(context);
    final count = _recordatoriosHoy.length;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecordatoriosScreen()),
      ).then((_) => _cargarRecordatoriosHoy()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: pal.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pal.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: pal.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.notifications_active_rounded,
                  size: 18, color: pal.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 recordatorio para hoy'
                        : '$count recordatorios para hoy',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ..._recordatoriosHoy.take(2).map((r) {
                    final titulo = r['titulo'] as String? ?? '';
                    final clienteNombre = r['cliente_nombre'] as String?;
                    final hora = r['hora'] as String?;
                    final horaLabel = hora != null ? ' · ${_hora12dash(hora)}' : '';
                    final label = clienteNombre != null && clienteNombre.isNotEmpty
                        ? '$titulo — $clienteNombre$horaLabel'
                        : '$titulo$horaLabel';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        '• $label',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: pal.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                  if (count > 2)
                    Text(
                      '+ ${count - 2} más...',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: pal.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: pal.primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  String _hora12dash(String hora24) {
    try {
      final parts = hora24.split(':');
      final h24 = int.parse(parts[0]);
      final min = parts[1].padLeft(2, '0');
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      final periodo = h24 < 12 ? 'AM' : 'PM';
      return '$h12:$min $periodo';
    } catch (_) { return hora24; }
  }

  Widget _buildGreeting() {
    final pal = AppPalette.of(context);
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días'
        : hora < 18 ? 'Buenas tardes' : 'Buenas noches';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(saludo, style: GoogleFonts.poppins(fontSize: 14, color: pal.textMuted)),
      const SizedBox(height: 2),
      Row(children: [
        Expanded(child: Text(_nombreNegocio, style: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w700, color: pal.textPrimary))),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const VitrinaConfigScreen()))
                  .then((_) => _cargarVitrina()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _vitrinaActiva
                  ? pal.primary.withValues(alpha: 0.1)
                  : pal.cardBorder,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.storefront_rounded, size: 11,
                  color: _vitrinaActiva ? pal.primary : pal.textMuted),
              const SizedBox(width: 4),
              Text(_vitrinaActiva ? '● Vitrina activa' : '○ Vitrina inactiva',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _vitrinaActiva ? pal.primary : pal.textMuted)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: Text(AppFormatters.fechaHora(DateTime.now()),
            style: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted))),
        if (_vitrinaActiva) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => VitrinaQrScreen(
                  url: _vitrinaUrl,
                  empresaNombre: _nombreNegocio,
                ))),
            child: Icon(Icons.qr_code_rounded, size: 16, color: pal.primary),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Share.share(
              '🛍️ Mira el catálogo de $_nombreNegocio:\n$_vitrinaUrl',
              subject: 'Catálogo de $_nombreNegocio',
            ),
            child: Icon(Icons.share_rounded, size: 16, color: pal.primary),
          ),
        ],
      ]),
    ]);
  }

  Widget _buildStatCards() {
    final pal = AppPalette.of(context);
    return Row(children: [
      Expanded(child: _StatCard(
        label: 'Ventas hoy', value: AppFormatters.moneda(_ventasHoy),
        icon: Icons.trending_up_rounded, color: pal.colorVentas,
        trend: 'Hoy', trendPositive: true,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        label: 'Ganancias hoy', value: AppFormatters.moneda(_gananciasHoy),
        icon: Icons.account_balance_wallet_rounded, color: pal.primary,
        trend: 'Hoy', trendPositive: true,
      )),
    ]);
  }

  Widget _buildAlertSection() {
    final pal = AppPalette.of(context);
    final alerts = <Map<String, dynamic>>[];
    if (_productosLowStock > 0) {
      alerts.add({
        'icon': Icons.inventory_2_outlined,
        'color': pal.warning, 'bg': pal.warningSurface,
        'text': '$_productosLowStock productos con stock bajo',
        'screen': const InventarioScreen(),
      });
    }
    if (_productosSinStock > 0) {
      alerts.add({
        'icon': Icons.remove_shopping_cart_rounded,
        'color': pal.danger, 'bg': pal.dangerSurface,
        'text': '$_productosSinStock productos sin stock',
        'screen': const InventarioScreen(),
      });
    }
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Alertas', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: pal.textPrimary)),
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
    final pal = AppPalette.of(context);
    final modules = [
      _ModuleItem('Inventario', Icons.inventory_2_rounded,
          pal.colorInventario, const InventarioScreen()),
      _ModuleItem('Clientes', Icons.people_rounded,
          pal.colorClientes, const ClientesScreen()),
      _ModuleItem('Fiado', Icons.account_balance_wallet_rounded,
          pal.colorFiado, const FiadoScreen()),
      _ModuleItem('Apartados', Icons.bookmark_rounded,
          pal.colorApartados, const ApartadosScreen()),
      _ModuleItem('Gastos', Icons.receipt_long_rounded,
          pal.colorGastos, const GastosScreen()),
      _ModuleItem('Reportes', Icons.bar_chart_rounded,
          pal.colorReportes, const ReportesScreen()),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Módulos', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: pal.textPrimary)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05,
        children: modules.map((m) => GestureDetector(
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => m.screen));
            if (mounted) { _cargarResumen(); setState(() {}); }
          },
          child: Container(
            decoration: BoxDecoration(color: pal.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.cardBorder)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(m.icon, color: m.color, size: 24)),
              const SizedBox(height: 6),
              Text(m.name, style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: pal.textPrimary), textAlign: TextAlign.center),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }

  Widget _buildRecentActivity() {
    final pal = AppPalette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Actividad reciente', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: pal.textPrimary)),
      const SizedBox(height: 8),
      if (_empresaId != null)
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchActividad(_empresaId!),
          builder: (context, snapshot) {
            final pal2 = AppPalette.of(context);
            if (!snapshot.hasData) {
              return Center(child: Text('Cargando...',
                  style: GoogleFonts.poppins(fontSize: 14, color: pal2.textMuted)));
            }
            final actividad = snapshot.data!;
            if (actividad.isEmpty) {
              return Center(child: Text('Sin actividad reciente',
                  style: GoogleFonts.poppins(fontSize: 14, color: pal2.textMuted)));
            }
            return Column(
              children: actividad.take(8).map((item) {
                IconData icon; Color color;
                switch (item['tipo']) {
                  case 'venta': icon = Icons.shopping_cart_rounded; color = pal2.colorVentas; break;
                  case 'gasto': icon = Icons.receipt_long_rounded; color = pal2.colorGastos; break;
                  case 'fiado': icon = Icons.handshake_outlined; color = pal2.colorFiado; break;
                  case 'apartado': icon = Icons.bookmark_rounded; color = pal2.colorApartados; break;
                  default: icon = Icons.circle; color = pal2.primary;
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
            style: GoogleFonts.poppins(fontSize: 14, color: pal.textMuted))),
      const SizedBox(height: 24),
      Center(
        child: Text(
          'NegocioPro $_appVersion · FinanPro Solutions',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: pal.textMuted,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Future<List<Map<String, dynamic>>> _fetchActividad(String empresaId) async {
    final List<Map<String, dynamic>> actividad = [];

    // Obtener fecha del último cierre — solo mostrar actividad posterior
    String? desdeCierre;
    try {
      final db = await LocalDatabase.database;
      final cierres = await db.query('cierres_dia',
          where: 'empresa_id = ?', whereArgs: [empresaId],
          orderBy: 'created_at DESC', limit: 1);
      if (cierres.isNotEmpty) {
        desdeCierre = cierres.first['created_at'] as String?;
      }
    } catch (_) {}

    if (await SupabaseService.isOnlineAsync) {
      try {
        final db2 = await LocalDatabase.database;
        var qVentas   = SupabaseService.client.from('ventas')
            .select('id, numero_venta, total, subtotal, descuento, tipo_pago, monto_pagado, created_at')
            .eq('empresa_id', empresaId).eq('estado', 'completada');
        var qGastos   = SupabaseService.client.from('gastos')
            .select('id, descripcion, categoria, monto, created_at')
            .eq('empresa_id', empresaId);
        var qFiado    = SupabaseService.client.from('abonos_fiado')
            .select('id, monto, created_at, clientes(nombre)')
            .eq('empresa_id', empresaId);
        var qApartado = SupabaseService.client.from('abonos_apartado')
            .select('id, monto, created_at, apartados(descripcion)')
            .eq('empresa_id', empresaId);
        var qApartadoNew = SupabaseService.client.from('apartados')
            .select('id, descripcion, monto_total, created_at')
            .eq('empresa_id', empresaId);

        if (desdeCierre != null) {
          qVentas       = qVentas.gte('created_at', desdeCierre);
          qGastos       = qGastos.gte('created_at', desdeCierre);
          qFiado        = qFiado.gte('created_at', desdeCierre);
          qApartado     = qApartado.gte('created_at', desdeCierre);
          qApartadoNew  = qApartadoNew.gte('created_at', desdeCierre);
        }

        final results = await Future.wait([
          qVentas.order('created_at', ascending: false).limit(10),
          qGastos.order('created_at', ascending: false).limit(10),
          qFiado.order('created_at', ascending: false).limit(10),
          qApartado.order('created_at', ascending: false).limit(10),
          qApartadoNew.order('created_at', ascending: false).limit(10),
        ]);
        // Cachear ventas en SQLite para uso offline
        for (final v in results[0] as List) {
          try {
            final ventaId = v['id'] as String;
            await db2.insert('ventas', {
              'id': ventaId,
              'empresa_id': empresaId,
              'numero_venta': v['numero_venta'],
              'total': (v['total'] as num).toDouble(),
              'subtotal': (v['subtotal'] as num? ?? v['total'] as num).toDouble(),
              'descuento': (v['descuento'] as num? ?? 0).toDouble(),
              'monto_pagado': (v['monto_pagado'] as num? ?? 0).toDouble(),
              'tipo_pago': v['tipo_pago'] as String? ?? 'efectivo',
              'estado': 'completada',
              'created_at': v['created_at'] as String,
              'synced': 1,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            // Si la fila ya existía (ignore), actualizar numero_venta
            // (puede ser nulo para ventas creadas offline antes de este fix)
            if (v['numero_venta'] != null) {
              await db2.update('ventas', {'numero_venta': v['numero_venta']},
                  where: 'id = ? AND numero_venta IS NULL', whereArgs: [ventaId]);
            }
          } catch (_) {}
        }
        // Cachear gastos en SQLite para uso offline
        for (final g in results[1] as List) {
          try {
            await db2.insert('gastos', {
              'id': g['id'] as String,
              'empresa_id': empresaId,
              'descripcion': g['descripcion'] as String? ?? '',
              'categoria': g['categoria'] as String? ?? 'general',
              'monto': (g['monto'] as num).toDouble(),
              'created_at': g['created_at'] as String,
              'synced': 1,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } catch (_) {}
        }

        for (final v in results[0] as List) {
          final esCredito = v['tipo_pago'] == 'fiado';
          final montoMostrar = esCredito
              ? (v['monto_pagado'] as num).toDouble()
              : (v['total'] as num).toDouble();
          final saldoFiado = esCredito
              ? (v['total'] as num).toDouble() - (v['monto_pagado'] as num).toDouble()
              : 0.0;
          final numVenta = v['numero_venta']?.toString() ?? '—';
          actividad.add({
            'tipo': 'venta',
            'titulo': saldoFiado > 0
                ? 'Venta #$numVenta (+${AppFormatters.moneda(saldoFiado)} fiado)'
                : 'Venta #$numVenta',
            'monto': montoMostrar, 'fecha': _toLocal(v['created_at'] as String), 'positivo': true,
          });
        }
        for (final g in results[1] as List) {
          actividad.add({'tipo': 'gasto', 'titulo': g['descripcion'] as String,
              'monto': (g['monto'] as num).toDouble(),
              'fecha': _toLocal(g['created_at'] as String), 'positivo': false});
        }
        // Abonos fiado desde Supabase
        final idsAbonosFiadoOnline = <String>{};
        for (final f in results[2] as List) {
          idsAbonosFiadoOnline.add(f['id'] as String);
          actividad.add({'tipo': 'fiado',
              'titulo': 'Abono fiado — ${f['clientes']?['nombre'] ?? 'Cliente'}',
              'monto': (f['monto'] as num).toDouble(),
              'fecha': _toLocal(f['created_at'] as String), 'positivo': true});
        }
        // Abonos apartado desde Supabase
        final idsAbonosApartadoOnline = <String>{};
        for (final a in results[3] as List) {
          idsAbonosApartadoOnline.add(a['id'] as String);
          actividad.add({'tipo': 'apartado',
              'titulo': 'Abono apartado — ${a['apartados']?['descripcion'] ?? 'Apartado'}',
              'monto': (a['monto'] as num).toDouble(),
              'fecha': _toLocal(a['created_at'] as String), 'positivo': true});
        }
        // Nuevos apartados creados
        final idsApartadosOnline = <String>{};
        for (final a in results[4] as List) {
          idsApartadosOnline.add(a['id'] as String);
          actividad.add({'tipo': 'apartado',
              'titulo': 'Nuevo apartado — ${a['descripcion'] ?? ''}',
              'monto': (a['monto_total'] as num).toDouble(),
              'fecha': _toLocal(a['created_at'] as String), 'positivo': true});
        }

        // Merge abonos pendientes (offline) no incluidos en Supabase aún.
        // Aplicar desdeCierre también aquí — sin esto, items offline viejos
        // siguen apareciendo hasta que sincronizan (que puede ser "al otro día").
        final whereLocal = desdeCierre != null
            ? 'empresa_id = ? AND synced = 0 AND created_at >= ?'
            : 'empresa_id = ? AND synced = 0';
        final argsLocal = desdeCierre != null
            ? [empresaId, desdeCierre]
            : [empresaId];

        final abonosFiadoLocal = await db2.query('abonos_fiado',
            where: whereLocal, whereArgs: argsLocal,
            orderBy: 'created_at DESC', limit: 10);
        for (final f in abonosFiadoLocal) {
          if (idsAbonosFiadoOnline.contains(f['id'] as String)) continue;
          actividad.add({'tipo': 'fiado', 'titulo': 'Abono fiado',
              'monto': (f['monto'] as num).toDouble(),
              'fecha': _toLocal(f['created_at'] as String), 'positivo': true});
        }
        final abonosApartadoLocal = await db2.query('abonos_apartado',
            where: whereLocal, whereArgs: argsLocal,
            orderBy: 'created_at DESC', limit: 10);
        for (final a in abonosApartadoLocal) {
          if (idsAbonosApartadoOnline.contains(a['id'] as String)) continue;
          actividad.add({'tipo': 'apartado', 'titulo': 'Abono apartado',
              'monto': (a['monto'] as num).toDouble(),
              'fecha': _toLocal(a['created_at'] as String), 'positivo': true});
        }
        // Apartados locales pendientes
        final apartadosLocal = await db2.query('apartados',
            where: whereLocal, whereArgs: argsLocal,
            orderBy: 'created_at DESC', limit: 10);
        for (final a in apartadosLocal) {
          if (idsApartadosOnline.contains(a['id'] as String)) continue;
          actividad.add({'tipo': 'apartado',
              'titulo': 'Nuevo apartado — ${a['descripcion'] ?? ''}',
              'monto': (a['monto_total'] as num? ?? 0).toDouble(),
              'fecha': _toLocal(a['created_at'] as String), 'positivo': true});
        }

        actividad.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));
        return actividad;
      } catch (_) {}
    }

    // Offline: leer de SQLite
    final db = await LocalDatabase.database;
    final whereVentas = desdeCierre != null
        ? 'empresa_id = ? AND estado = ? AND created_at > ?'
        : 'empresa_id = ? AND estado = ?';
    final argsVentas = desdeCierre != null
        ? [empresaId, 'completada', desdeCierre]
        : [empresaId, 'completada'];
    final ventas = await db.query('ventas',
        where: whereVentas, whereArgs: argsVentas,
        orderBy: 'created_at DESC', limit: 10);
    for (final v in ventas) {
      final esCredito = v['tipo_pago'] == 'fiado';
      final total = (v['total'] as num).toDouble();
      final pagado = (v['monto_pagado'] as num? ?? total).toDouble();
      final numVenta = v['numero_venta']?.toString() ?? '—';
      actividad.add({'tipo': 'venta',
          'titulo': 'Venta #$numVenta',
          'monto': esCredito ? pagado : total,
          'fecha': _toLocal(v['created_at'] as String), 'positivo': true});
    }
    final whereOtros = desdeCierre != null
        ? 'empresa_id = ? AND created_at > ?' : 'empresa_id = ?';
    final argsOtros = desdeCierre != null ? [empresaId, desdeCierre] : [empresaId];

    final gastos = await db.query('gastos',
        where: whereOtros, whereArgs: argsOtros,
        orderBy: 'created_at DESC', limit: 10);
    for (final g in gastos) {
      actividad.add({'tipo': 'gasto', 'titulo': g['descripcion'] as String? ?? 'Gasto',
          'monto': (g['monto'] as num).toDouble(),
          'fecha': _toLocal(g['created_at'] as String), 'positivo': false});
    }
    final abonosFiado = await db.query('abonos_fiado',
        where: whereOtros, whereArgs: argsOtros,
        orderBy: 'created_at DESC', limit: 10);
    for (final f in abonosFiado) {
      actividad.add({'tipo': 'fiado', 'titulo': 'Abono fiado',
          'monto': (f['monto'] as num).toDouble(),
          'fecha': _toLocal(f['created_at'] as String), 'positivo': true});
    }
    final abonosApartado = await db.query('abonos_apartado',
        where: whereOtros, whereArgs: argsOtros,
        orderBy: 'created_at DESC', limit: 10);
    for (final a in abonosApartado) {
      actividad.add({'tipo': 'apartado', 'titulo': 'Abono apartado',
          'monto': (a['monto'] as num).toDouble(),
          'fecha': _toLocal(a['created_at'] as String), 'positivo': true});
    }
    // Nuevos apartados creados (offline)
    final apartadosOff = await db.query('apartados',
        where: whereOtros, whereArgs: argsOtros,
        orderBy: 'created_at DESC', limit: 10);
    for (final a in apartadosOff) {
      actividad.add({'tipo': 'apartado',
          'titulo': 'Nuevo apartado — ${a['descripcion'] ?? ''}',
          'monto': (a['monto_total'] as num? ?? 0).toDouble(),
          'fecha': _toLocal(a['created_at'] as String), 'positivo': true});
    }
    actividad.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha'] as DateTime));
    return actividad;
  }

 Widget _buildOtrasPantallas() {
    final pantallas = [
      const DashboardScreen(),
      const EncargosScreen(),
      const CierreDiaScreen(),
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
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag_rounded), label: 'Encargos'),
        BottomNavigationBarItem(icon: Icon(Icons.lock_clock_outlined),
            activeIcon: Icon(Icons.lock_clock_rounded), label: 'Cuadre de Caja'),
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
    final pal = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: pal.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: trendPositive ? pal.successSurface : pal.dangerSurface,
              borderRadius: BorderRadius.circular(20)),
            child: Text(trend, style: GoogleFonts.poppins(fontSize: 11,
                fontWeight: FontWeight.w600,
                color: trendPositive ? pal.success : pal.danger)),
          ),
        ]),
        const SizedBox(height: 14),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: pal.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 17,
            fontWeight: FontWeight.w700, color: pal.textPrimary)),
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
    final pal = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: pal.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.cardBorder)),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 13,
              fontWeight: FontWeight.w600, color: pal.textPrimary)),
          Text(subtitle, style: GoogleFonts.poppins(
              fontSize: 11, color: pal.textMuted)),
        ])),
        Text(amount, style: GoogleFonts.poppins(fontSize: 14,
            fontWeight: FontWeight.w700,
            color: positive ? pal.success : pal.danger)),
      ]),
    );
  }
}