import 'package:flutter/material.dart';
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
    _tabs = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
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
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_tabCarta(), _tabQr()],
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
          const Icon(Icons.whatsapp_rounded, size: 16, color: AppColors.textMuted),
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
}
