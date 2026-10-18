import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../services/printer_service.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../services/inventario_service.dart';
import '../../models/categoria_model.dart';
import '../../widgets/guia_modulo_banner.dart';
import '../../widgets/pro_gate.dart';
import '../vitrina/vitrina_qr_screen.dart';

class CartaDigitalScreen extends StatelessWidget {
  const CartaDigitalScreen({super.key});

  @override
  Widget build(BuildContext context) => ProGate(
    nombreFuncion: 'Carta Digital',
    child: const _CartaDigitalBody(),
  );
}

class _CartaDigitalBody extends StatefulWidget {
  const _CartaDigitalBody();

  @override
  State<_CartaDigitalBody> createState() => _CartaDigitalBodyState();
}

class _CartaDigitalBodyState extends State<_CartaDigitalBody>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _empresaId = '';
  String _empresaNombre = '';
  String _slug = '';
  bool _cartaActiva = false;
  bool _mostrarPrecios = true;
  bool _permitirWS     = true;
  // ── Cocina ──
  List<Map<String, dynamic>> _cola = [];
  bool _cargandoCola = false;
  bool _imprimiendo  = false;
  String _printerMode = 'wifi'; // 'wifi' | 'bluetooth'
  Timer? _pollingTimer;
  bool _permitirCocina = true;
  bool _permitirMesero = true;

  List<CategoriaModel> _categorias = [];
  List<Map<String, dynamic>> _productos = [];
  // productId -> disponible hoy (true = disponible, false = agotado)
  Map<String, bool> _disponibilidad = {};

  late TabController _tabs;

  static const String _baseUrl = 'https://vitrina-web-beta.vercel.app/t/';

  String get _linkCarta {
    final id = _slug.isNotEmpty ? _slug : _empresaId;
    return '$_baseUrl$id?carta=1';
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _cargar();
    _tabs.addListener(() {
      if (_tabs.index == 2 && _cola.isEmpty) _cargarCola();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      // Empresa info
      final empresa = await SupabaseService.client
          .from('empresas')
          .select('nombre')
          .eq('id', empresaId)
          .maybeSingle();

      // Vitrina config (slug + carta config)
      final config = await SupabaseService.client
          .from('vitrina_config')
          .select('slug, carta_activa, carta_mostrar_precios, carta_permitir_ws, carta_permitir_cocina, carta_permitir_mesero')
          .eq('empresa_id', empresaId)
          .maybeSingle();

      // Categorias
      final cats = await SupabaseService.client
          .from('categorias')
          .select()
          .eq('empresa_id', empresaId)
          .order('nombre');

      // Productos en vitrina
      final prods = await SupabaseService.client
          .from('productos')
          .select('id, nombre, precio_venta, categoria_id, carta_disponible, stock_actual, foto_url')
          .eq('empresa_id', empresaId)
          .eq('carta_disponible', true)
          .order('nombre');

      if (mounted) {
        setState(() {
          _empresaId = empresaId;
          _empresaNombre = empresa?['nombre'] ?? 'Mi Negocio';
          _slug = config?['slug'] ?? '';
          _cartaActiva = config?['carta_activa'] == true;
          _mostrarPrecios  = config?['carta_mostrar_precios'] != false;
          _permitirWS      = config?['carta_permitir_ws'] != false;
          _permitirCocina  = config?['carta_permitir_cocina'] != false;
          _permitirMesero  = config?['carta_permitir_mesero'] != false;
          _categorias = (cats as List)
              .map((c) => CategoriaModel.fromMap(c))
              .toList();
          _productos = List<Map<String, dynamic>>.from(prods as List);
          // disponibilidad automática por stock_actual
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Carta] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleCartaActiva(bool val) async {
    setState(() => _cartaActiva = val);
    try {
      final config = await SupabaseService.client
          .from('vitrina_config')
          .select('id')
          .eq('empresa_id', _empresaId)
          .maybeSingle();

      if (config != null) {
        await SupabaseService.client
            .from('vitrina_config')
            .update({'carta_activa': val})
            .eq('empresa_id', _empresaId);
      } else {
        await SupabaseService.client
            .from('vitrina_config')
            .insert({'empresa_id': _empresaId, 'activa': false, 'carta_activa': val});
      }
    } catch (e) {
      debugPrint('[Carta] toggle error: $e');
    }
  }

  Future<void> _toggleMostrarPrecios(bool val) async {
    setState(() => _mostrarPrecios = val);
    try {
      await SupabaseService.client
          .from('vitrina_config')
          .update({'carta_mostrar_precios': val})
          .eq('empresa_id', _empresaId);
    } catch (e) {
      debugPrint('[Carta] precios toggle error: \$e');
    }
  }

  Future<void> _toggleBoolConfig(String field, bool val, Function(bool) setter) async {
    setState(() => setter(val));
    try {
      await SupabaseService.client
          .from('vitrina_config')
          .update({field: val})
          .eq('empresa_id', _empresaId);
    } catch (e) {
      debugPrint('[Carta] toggle $field error: $e');
    }
  }

  Future<void> _toggleDisponible(String productId, bool val) async {
    setState(() => _disponibilidad[productId] = val);
    try {
      await SupabaseService.client
          .from('productos')
          .update({'carta_disponible': val})
          .eq('id', productId);
    } catch (e) {
      debugPrint('[Carta] disponible error: $e');
    }
  }

  Future<void> _marcarTodos(bool val) async {
    final ids = _productos.map((p) => p['id'] as String).toList();
    setState(() {
      for (final id in ids) _disponibilidad[id] = val;
    });
    try {
      await SupabaseService.client
          .from('productos')
          .update({'carta_disponible': val})
          .inFilter('id', ids);
    } catch (e) {
      debugPrint('[Carta] marcar todos error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Carta Digital',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu_rounded), text: 'Carta'),
            Tab(icon: Icon(Icons.qr_code_rounded), text: 'QR'),
            Tab(icon: Icon(Icons.kitchen_rounded), text: 'Cocina'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_tabCarta(), _tabQr(), _tabCocina()],
            ),
    );
  }

  // ── TAB 1: Carta ────────────────────────────────────────────────
  Widget _tabCarta() {
    return Column(children: [
      const GuiaModuloBanner(modulo: 'carta_digital'),
      // Toggle activa
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _cartaActiva
              ? AppColors.success.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _cartaActiva
                ? AppColors.success.withOpacity(0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(children: [
          Icon(
            _cartaActiva
                ? Icons.restaurant_menu_rounded
                : Icons.no_meals_rounded,
            color: _cartaActiva ? AppColors.success : AppColors.textMuted,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Carta Digital',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            Text(
              _cartaActiva
                  ? 'Visible para tus clientes al escanear el QR'
                  : 'Actívala para que los clientes vean tu menú',
              style: GoogleFonts.poppins(
                  fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ])),
          Switch(
            value: _cartaActiva,
            onChanged: _toggleCartaActiva,
            activeColor: AppColors.success,
          ),
        ]),
      ),
      // Toggle mostrar precios
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          const Icon(Icons.attach_money_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('Mostrar precios al cliente',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          const Spacer(),
          Switch(
            value: _mostrarPrecios,
            onChanged: _toggleMostrarPrecios,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
      // Toggle WhatsApp
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          const Icon(Icons.chat_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('Permitir envío por WhatsApp',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          const Spacer(),
          Switch(
            value: _permitirWS,
            onChanged: (v) => _toggleBoolConfig('carta_permitir_ws', v, (x) => _permitirWS = x),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
      // Toggle Enviar a cocina
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          const Icon(Icons.print_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('Permitir envío a cocina / imprimir',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          const Spacer(),
          Switch(
            value: _permitirCocina,
            onChanged: (v) => _toggleBoolConfig('carta_permitir_cocina', v, (x) => _permitirCocina = x),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
      // Toggle Mostrar al mesero
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('Permitir "Mostrar al mesero"',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          const Spacer(),
          Switch(
            value: _permitirMesero,
            onChanged: (v) => _toggleBoolConfig('carta_permitir_mesero', v, (x) => _permitirMesero = x),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ),
      const SizedBox(height: 4),
      // Lista por categoría
      Expanded(child: _productos.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: _buildListaPorCategoria(),
            )),
    ]);
  }

  List<Widget> _buildListaPorCategoria() {
    final sinCategoria = _productos
        .where((p) => p['categoria_id'] == null)
        .toList();
    final result = <Widget>[];

    // Productos sin categoría
    if (sinCategoria.isNotEmpty) {
      result.add(_seccionHeader('Sin categoría', Icons.category_outlined));
      result.addAll(sinCategoria.map(_buildProductoTile));
    }

    // Por categoría
    for (final cat in _categorias) {
      final prods = _productos
          .where((p) => p['categoria_id'] == cat.id)
          .toList();
      if (prods.isEmpty) continue;
      result.add(_seccionHeader(cat.nombre, Icons.label_outline_rounded));
      result.addAll(prods.map(_buildProductoTile));
    }

    return result;
  }

  Widget _seccionHeader(String nombre, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(nombre.toUpperCase(),
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.8)),
    ]),
  );

  Widget _buildProductoTile(Map<String, dynamic> p) {
    final stock = (p['stock_actual'] as num?)?.toDouble() ?? 1;
    final disponible = stock > 0;
    final precio = (p['precio_venta'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: disponible
              ? AppColors.cardBorder
              : AppColors.danger.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: disponible
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            disponible
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: disponible ? AppColors.success : AppColors.danger,
            size: 22,
          ),
        ),
        title: Text(p['nombre'] ?? '',
            style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: disponible
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
                decoration: disponible
                    ? TextDecoration.none
                    : TextDecoration.lineThrough)),
        subtitle: Text(
          disponible ? 'Disponible hoy' : 'Agotado',
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: disponible ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w500),
        ),
        trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (_mostrarPrecios)
            Text('RD\$${precio.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          Text('${stock.toStringAsFixed(0)} uds',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: disponible ? AppColors.success : AppColors.danger)),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.restaurant_menu_rounded,
            size: 64, color: AppColors.textMuted.withOpacity(0.4)),
        const SizedBox(height: 16),
        Text('Sin productos en Carta Digital',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Activa la Carta en productos desde Vitrina → toca un producto → activa "En Carta Digital". Aparecerán aquí con disponibilidad automática según su stock.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary),
        ),
      ]),
    ),
  );

  // ── TAB 2: QR ────────────────────────────────────────────────────
  Widget _tabQr() {
    if (!_cartaActiva) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.qr_code_rounded,
                size: 64, color: AppColors.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Activa tu Carta primero',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Ve a la pestaña Carta y activa el interruptor para generar el QR.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // QR Code
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(children: [
            QrImageView(
              data: _linkCarta,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(_empresaNombre,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.restaurant_menu_rounded,
                    size: 14, color: Color(0xFFFF6B35)),
                const SizedBox(width: 5),
                Text('Carta Digital',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF6B35))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Instrucción
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Imprime este QR y ponlo en las mesas, en la entrada o donde quieras. Los clientes lo escanean y ven tu carta al instante.',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Link
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _linkCarta));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copiado')));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(children: [
              const Icon(Icons.link_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_linkCarta,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: AppColors.primary),
                    overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.copy_rounded,
                  size: 18, color: AppColors.textMuted),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Botones
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _linkCarta));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copiado')));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text('Copiar link',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Share.share(
                  '🍽️ Escanea el QR para ver la carta de $_empresaNombre:\n$_linkCarta',
                );
              },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text('Compartir',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // Ver carta
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VitrinaQrScreen(
                  url: _linkCarta,
                  empresaNombre: _empresaNombre,
                ),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text('Ver QR completo / imprimir',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TAB 3: COCINA — Cola de pedidos
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _cargarCola() async {
    if (_cargandoCola || _empresaId.isEmpty) return;
    setState(() => _cargandoCola = true);
    try {
      final data = await SupabaseService.client
          .from('pedidos_carta')
          .select()
          .eq('empresa_id', _empresaId)
          .inFilter('estado', ['pendiente', 'preparando'])
          .order('created_at');
      if (mounted) {
        setState(() {
          _cola = List<Map<String, dynamic>>.from(data as List);
          _cargandoCola = false;
        });
        // Auto-polling cada 15 seg mientras esté en el tab
        _pollingTimer?.cancel();
        _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (_tabs.index == 2) _cargarCola();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoCola = false);
    }
  }

  Future<void> _cambiarEstado(String pedidoId, String estado) async {
    try {
      await SupabaseService.client
          .from('pedidos_carta')
          .update({'estado': estado})
          .eq('id', pedidoId);
      await _cargarCola();
    } catch (e) {
      debugPrint('[Cocina] cambiar estado error: \$e');
    }
  }

  Future<void> _imprimirPedido(Map<String, dynamic> pedido) async {
    if (_imprimiendo) return;
    setState(() => _imprimiendo = true);
    try {
      final items = (pedido['items'] as List? ?? []);
      final mesa  = pedido['mesa'] ?? 'Sin mesa';
      final notas = pedido['notas'] ?? '';
      final total = pedido['total'] ?? 0;
      final hora  = DateTime.parse(pedido['created_at']).toLocal();
      final horaStr = '${hora.hour.toString().padLeft(2,'0')}:${hora.minute.toString().padLeft(2,'0')}';

      if (_printerMode == 'bluetooth' && PrinterService.hasPrinter) {
        await _imprimirBluetooth(items, mesa, notas, total, horaStr);
      } else {
        await _imprimirWifi(items, mesa, notas, total, horaStr);
      }
      await _cambiarEstado(pedido['id'], 'preparando');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al imprimir: \$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  Future<void> _imprimirWifi(List items, String mesa, String notas, dynamic total, String hora) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text(_empresaNombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
        pw.Center(child: pw.Text('Mesa: \$mesa  ·  \$hora', style: const pw.TextStyle(fontSize: 10))),
        pw.Divider(),
        ...items.map((it) {
          final nome = it['nombre'] ?? '';
          final cant = it['cantidad'] ?? 1;
          final prec = ((it['precio'] ?? 0) * cant).toStringAsFixed(0);
          return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('$nome x$cant', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('RD\$$prec', style: const pw.TextStyle(fontSize: 11)),
          ]);
        }).toList(),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.Text('RD\$\${total.toString()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ]),
        if (notas.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Nota: \$notas', style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Text('--- Gracias ---', style: const pw.TextStyle(fontSize: 10))),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _imprimirBluetooth(List items, String mesa, String notas, dynamic total, String hora) async {
    final List<int> bytes = [];
    // ESC/POS helpers
    void cmd(List<int> b) => bytes.addAll(b);
    void line(String s) { bytes.addAll(s.codeUnits); bytes.add(10); }
    void boldOn()  => cmd([0x1B, 0x45, 0x01]);
    void boldOff() => cmd([0x1B, 0x45, 0x00]);
    void center()  => cmd([0x1B, 0x61, 0x01]);
    void left()    => cmd([0x1B, 0x61, 0x00]);

    cmd([0x1B, 0x40]); // init
    center(); boldOn();
    line(_empresaNombre);
    boldOff();
    line('Mesa: $mesa   $hora');
    left();
    line('================================');
    line('PRODUCTO           CANT   PRECIO');
    line('================================');
    for (final it in items) {
      final nombre = (it['nombre'] ?? '').toString();
      final cant   = (it['cantidad'] ?? 1).toString();
      final precio = ((it['precio'] ?? 0) * (it['cantidad'] ?? 1)).toStringAsFixed(0);
      final nom = nombre.length > 16 ? nombre.substring(0, 16) : nombre.padRight(16);
      final cantStr = cant.padLeft(4);
      final precStr = ('RD\$$precio').padLeft(9);
      line('$nom$cantStr$precStr');
    }
    line('--------------------------------');
    boldOn();
    line('TOTAL:              RD\$$total');
    boldOff();
    if (notas.isNotEmpty) {
      line('');
      line('Nota: $notas');
    }
    line('================================');
    center();
    line('  Gracias por su visita  ');
    left();
    cmd([0x0A, 0x0A, 0x0A]);
    cmd([0x1D, 0x56, 0x00]); // corte parcial
    await PrintBluetoothThermal.writeBytes(Uint8List.fromList(bytes));
  }

  Future<void> _conectarBluetooth() async {
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    if (!mounted) return;
    // Verificar cuál está realmente conectada ahora mismo
    final bool currentlyConnected = await PrintBluetoothThermal.connectionStatus;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: Text('Selecciona impresora', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16))),
              if (PrinterService.hasPrinter)
                TextButton.icon(
                  onPressed: () async {
                    await PrinterService.forget();
                    setBS(() {});
                    if (mounted) setState(() => _printerMode = 'wifi');
                  },
                  icon: const Icon(Icons.bluetooth_disabled_rounded, size: 16),
                  label: const Text('Olvidar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ]),
            const SizedBox(height: 4),
            if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No hay dispositivos Bluetooth emparejados',
                    style: GoogleFonts.poppins(color: Colors.grey))),
              ),
            ...devices.map((d) {
              final isSelected = PrinterService.address == d.macAdress;
              final isConnected = isSelected && currentlyConnected;
              return ListTile(
                leading: Icon(
                  isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                  color: isConnected ? AppColors.success : (isSelected ? AppColors.primary : Colors.grey),
                ),
                title: Text(d.name ?? 'Desconocido', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  isConnected ? '✅ Conectada' : (isSelected ? '⚠️ Sin señal — toca para reconectar' : d.macAdress ?? ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected ? AppColors.success : (isSelected ? AppColors.warning : Colors.grey),
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Conectando a \${d.name ?? d.macAdress}...'), duration: const Duration(seconds: 2)));
                  final ok = await PrinterService.select(d.macAdress ?? '', d.name ?? 'Impresora');
                  if (mounted) {
                    setState(() => _printerMode = ok ? 'bluetooth' : _printerMode);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? '✅ Conectado a \${d.name}' : '❌ No se pudo conectar. ¿El Bluetooth está activo y la impresora encendida?'),
                      backgroundColor: ok ? AppColors.success : Colors.red,
                      duration: const Duration(seconds: 3),
                    ));
                  }
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _tabCocina() {
    return Column(children: [
      // ── Barra de herramientas ──────────────────────────────────────
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          // Modo impresora
          Expanded(child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'wifi',      icon: Icon(Icons.wifi_rounded, size: 16),      label: Text('WiFi/USB')),
              ButtonSegment(value: 'bluetooth', icon: Icon(Icons.bluetooth_rounded, size: 16), label: Text('Bluetooth')),
            ],
            selected: {_printerMode},
            onSelectionChanged: (s) => setState(() => _printerMode = s.first),
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(GoogleFonts.poppins(fontSize: 11)),
            ),
          )),
          if (_printerMode == 'bluetooth') ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _conectarBluetooth,
              icon: Icon(
                PrinterService.hasPrinter ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
                color: PrinterService.hasPrinter ? AppColors.primary : Colors.grey,
              ),
              tooltip: PrinterService.name ?? 'Conectar impresora',
            ),
          ],
          const SizedBox(width: 8),
          IconButton(
            onPressed: _cargarCola,
            icon: _cargandoCola
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ]),
      ),

      // ── Lista de pedidos ─────────────────────────────────────────
      Expanded(child: _cola.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('Sin pedidos pendientes', style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _cargarCola,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar'),
            ),
          ]))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _cola.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final pedido  = _cola[i];
              final items   = (pedido['items'] as List? ?? []);
              final mesa    = pedido['mesa'] ?? 'Sin mesa';
              final notas   = pedido['notas'] ?? '';
              final estado  = pedido['estado'] ?? 'pendiente';
              final hora    = DateTime.parse(pedido['created_at']).toLocal();
              final horaStr = '${hora.hour.toString().padLeft(2,'0')}:${hora.minute.toString().padLeft(2,'0')}';
              final isPrimero = i == 0;

              return Container(
                decoration: BoxDecoration(
                  color: isPrimero
                      ? AppColors.primary.withOpacity(0.06)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPrimero ? AppColors.primary : AppColors.cardBorder,
                    width: isPrimero ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Header
                    Row(children: [
                      if (isPrimero) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('EN TURNO', style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                      if (!isPrimero) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('EN ESPERA', style: GoogleFonts.poppins(
                            fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      Text('🪑 Mesa \$mesa', style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      Text(horaStr, style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 10),
                    // Items
                    ...items.map((it) {
                      final nome = it['nombre'] ?? '';
                      final cant = it['cantidad'] ?? 1;
                      final prec = ((it['precio'] ?? 0) * cant).toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(children: [
                          Text('• ', style: TextStyle(color: AppColors.primary)),
                          Expanded(child: Text(
                            '$nome x$cant',
                            style: GoogleFonts.poppins(fontSize: 13),
                          )),
                          Text(
                            'RD\$$prec',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ]),
                      );
                    }).toList(),
                    // Notas
                    if (notas.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(children: [
                          const Text('📝 ', style: TextStyle(fontSize: 13)),
                          Expanded(child: Text(notas,
                              style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Botones
                    Row(children: [
                      if (isPrimero) Expanded(child: ElevatedButton.icon(
                        onPressed: _imprimiendo ? null : () => _imprimirPedido(pedido),
                        icon: _imprimiendo
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print_rounded, size: 16),
                        label: Text(_imprimiendo ? 'Imprimiendo…' : 'Imprimir',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      )),
                      if (isPrimero) const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => _cambiarEstado(pedido['id'],
                            estado == 'pendiente' ? 'preparando' : 'listo'),
                        icon: Icon(
                          estado == 'pendiente' ? Icons.local_fire_department_rounded : Icons.check_rounded,
                          size: 16,
                        ),
                        label: Text(
                          estado == 'pendiente' ? 'Preparando' : 'Listo ✓',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: estado == 'pendiente' ? Colors.orange : AppColors.success,
                          side: BorderSide(color: estado == 'pendiente' ? Colors.orange : AppColors.success),
                        ),
                      )),
                    ]),
                  ]),
                ),
              );
            },
          )),
    ]);
  }
}
