import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import 'vitrina_qr_screen.dart';
import 'dart:io';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import '../../services/inventario_service.dart';
import '../../utils/constants.dart';
import '../../models/categoria_model.dart';
import 'vitrina_producto_config_screen.dart';
import 'vitrina_resenas_screen.dart';
import '../../widgets/guia_modulo_banner.dart';
import '../../widgets/pro_gate.dart';
import '../carta/carta_digital_screen.dart';

class VitrinaConfigScreen extends StatefulWidget {
  const VitrinaConfigScreen({super.key});

  @override
  State<VitrinaConfigScreen> createState() => _VitrinaConfigScreenState();
}

class _VitrinaConfigScreenState extends State<VitrinaConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  bool _saving = false;
  bool _sincronizando = false;
  int _fotosSincronizadas = 0;
  int _fotosTotal = 0;

  // Config
  bool _activa = false;
  bool _deliveryDisponible = false;
  double _precioDelivery = 0;
  String _slug = '';
  String _zonaDelivery = '';
  String _horario = '';
  String _mensajeBienvenida = '';
  String _empresaId = '';
  String _empresaNombre = '';
  String? _configId;
  String _colorTema = '#6366f1';

  // Productos en vitrina
  List<Map<String, dynamic>> _productos = [];
  List<CategoriaModel> _categorias = [];
  String? _categoriaFiltro; // null = todas

  final _slugCtrl = TextEditingController();
  final _precioDeliveryCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  static const String _baseUrl = 'https://vitrina-web-beta.vercel.app/t/';

  String get _linkCompleto => '$_baseUrl${_slug.isNotEmpty ? _slug : _empresaId}';
  String get _linkCarta    => '$_linkCompleto?carta=1';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _precioDeliveryCtrl.dispose();
    _zonaCtrl.dispose();
    _horarioCtrl.dispose();
    _mensajeCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;
      _empresaId = empresaId;

      // Cargar nombre empresa
      final emp = await SupabaseService.client
          .from('empresas')
          .select('nombre')
          .eq('id', empresaId)
          .single();
      _empresaNombre = emp['nombre'] ?? '';

      // Cargar config vitrina
      final configs = await SupabaseService.client
          .from('vitrina_config')
          .select()
          .eq('empresa_id', empresaId);

      if (configs.isNotEmpty) {
        final c = configs.first;
        _configId = c['id'];
        _activa = c['activa'] == true;
        _deliveryDisponible = c['delivery_disponible'] == true;
        _precioDelivery = (c['precio_delivery'] ?? 0).toDouble();
        _slug = c['slug'] ?? '';
        _zonaDelivery = c['zona_delivery'] ?? '';
        _horario = c['horario'] ?? '';
        _mensajeBienvenida = c['mensaje_bienvenida'] ?? '';
        _slugCtrl.text = _slug;
        _precioDeliveryCtrl.text = _precioDelivery > 0 ? _precioDelivery.toStringAsFixed(0) : '';
        _zonaCtrl.text = _zonaDelivery;
        _horarioCtrl.text = _horario;
        _mensajeCtrl.text = _mensajeBienvenida;
        _colorTema = c['color_tema'] ?? '#6366f1';
      }

      // Cargar categorías
      try {
        final cats = await SupabaseService.client
            .from('categorias')
            .select()
            .eq('empresa_id', empresaId)
            .order('nombre');
        _categorias = (cats as List).map((c) => CategoriaModel.fromMap(c)).toList();
      } catch (_) {}

      // Cargar productos con estado vitrina
      final prods = await SupabaseService.client
          .from('productos')
          .select('id, nombre, precio_venta, stock_actual, foto_url, activo, categoria_id, carta_disponible')
          .eq('empresa_id', empresaId)
          .eq('activo', true)
          .order('nombre');

      // Cargar vitrina_productos — con fallback si las columnas nuevas no existen aún
      Map<String, Map<String, dynamic>> vitrinaMap = {};
      try {
        final vitrinaProds = await SupabaseService.client
            .from('vitrina_productos')
            .select('producto_id, visible, precio_oferta, descuento_porcentaje, disponibilidad, fecha_disponibilidad, permitir_resenas')
            .eq('empresa_id', empresaId);
        vitrinaMap = {
          for (final v in vitrinaProds)
            v['producto_id'] as String: v as Map<String, dynamic>
        };
      } catch (_) {
        // Columnas nuevas aún no existen: cargar solo visible
        try {
          final vitrinaProds = await SupabaseService.client
              .from('vitrina_productos')
              .select('producto_id, visible')
              .eq('empresa_id', empresaId);
          vitrinaMap = {
            for (final v in vitrinaProds)
              v['producto_id'] as String: v as Map<String, dynamic>
          };
        } catch (_) {}
      }

      _productos = (prods as List).map((p) {
        final vp = vitrinaMap[p['id'] as String];
        return {
          ...Map<String, dynamic>.from(p),
          'en_vitrina':           vp?['visible'] ?? true,
          'precio_oferta':        vp?['precio_oferta'],
          'descuento_porcentaje': vp?['descuento_porcentaje'],
          'disponibilidad':       vp?['disponibilidad'] ?? 'stock',
          'fecha_disponibilidad': vp?['fecha_disponibilidad'],
          'permitir_resenas':     vp?['permitir_resenas'] ?? false,
          'carta_disponible':     p['carta_disponible'] == true || p['carta_disponible'] == 1,
        };
      }).toList();

    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      final slug = _slugCtrl.text.trim().toLowerCase()
          .replaceAll(' ', '-')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');

      final data = {
        'empresa_id': _empresaId,
        'activa': _activa,
        'slug': slug.isNotEmpty ? slug : null,
        'delivery_disponible': _deliveryDisponible,
        'precio_delivery': double.tryParse(_precioDeliveryCtrl.text) ?? 0,
        'zona_delivery': _zonaCtrl.text.trim(),
        'horario': _horarioCtrl.text.trim(),
        'mensaje_bienvenida': _mensajeCtrl.text.trim(),
        'color_tema': _colorTema,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_configId != null) {
        await SupabaseService.client
            .from('vitrina_config')
            .update(data)
            .eq('id', _configId!);
      } else {
        final res = await SupabaseService.client
            .from('vitrina_config')
            .insert(data)
            .select()
            .single();
        _configId = res['id'];
      }

      // Guardar estado de productos en vitrina
      for (final p in _productos) {
        await SupabaseService.client
            .from('vitrina_productos')
            .upsert({
              'empresa_id':           _empresaId,
              'producto_id':          p['id'],
              'visible':              p['en_vitrina'],
              'precio_oferta':        p['precio_oferta'],
              'descuento_porcentaje': p['descuento_porcentaje'],
              'disponibilidad':       p['disponibilidad'] ?? 'stock',
              'fecha_disponibilidad': p['fecha_disponibilidad'],
              'permitir_resenas':     p['permitir_resenas'] ?? false,
            }, onConflict: 'empresa_id,producto_id');
      }

      // Guardar carta_disponible en tabla productos
      for (final p in _productos) {
        try {
          await SupabaseService.client
              .from('productos')
              .update({'carta_disponible': p['carta_disponible'] ?? false})
              .eq('id', p['id'] as String);
        } catch (_) {}
      }

      setState(() => _slug = slug);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Vitrina guardada!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 8),
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _sincronizarFotos() async {
    if (!await SupabaseService.isOnlineAsync) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Necesitas internet para sincronizar fotos'),
          backgroundColor: AppColors.warning,
        ));
      }
      return;
    }

    setState(() { _sincronizando = true; _fotosSincronizadas = 0; _fotosTotal = 0; });

    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      final db = await LocalDatabase.database;
      final productos = await db.query('productos',
          where: "empresa_id = ? AND foto_url IS NOT NULL AND activo = 1",
          whereArgs: [empresaId]);

      // Solo los que tienen ruta local (no URL pública)
      final locales = productos.where((p) {
        final url = p['foto_url'] as String? ?? '';
        return url.isNotEmpty && !url.startsWith('http');
      }).toList();

      setState(() => _fotosTotal = locales.length);
      if (locales.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Todas las fotos ya están sincronizadas ✅'),
            backgroundColor: AppColors.success,
          ));
        }
        setState(() => _sincronizando = false);
        return;
      }

      int subidas = 0;
      for (final p in locales) {
        final id      = p['id'] as String;
        final ruta    = p['foto_url'] as String;
        final archivo = File(ruta);
        if (!archivo.existsSync()) continue;

        final urlPublica = await InventarioService.uploadFoto(ruta, id);
        if (urlPublica != null) {
          // Actualizar en local
          await db.update('productos', {'foto_url': urlPublica, 'synced': 0},
              where: 'id = ?', whereArgs: [id]);
          // Actualizar en Supabase
          try {
            await SupabaseService.client.from('productos')
                .update({'foto_url': urlPublica}).eq('id', id);
          } catch (_) {}
          subidas++;
        }
        setState(() => _fotosSincronizadas = subidas);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$subidas foto(s) sincronizada(s) con la vitrina ✅'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
    if (mounted) setState(() => _sincronizando = false);
  }

  void _copiarLink() {
    Clipboard.setData(ClipboardData(text: _linkCompleto));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('¡Link copiado!'),
      backgroundColor: AppColors.success,
      duration: Duration(seconds: 2),
    ));
  }

  void _compartirLink() {
    Share.share(
      '🛍️ Mira el catálogo de $_empresaNombre:\n$_linkCompleto',
      subject: 'Catálogo de $_empresaNombre',
    );
  }

  void _copiarLinkCarta() {
    Clipboard.setData(ClipboardData(text: _linkCarta));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link de carta copiado'), duration: Duration(seconds: 2)));
  }

  void _compartirLinkCarta() {
    Share.share(
      '🍽️ Ve la carta digital de $_empresaNombre:\n$_linkCarta',
      subject: '$_empresaNombre — Carta Digital',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProGate(
      nombreFuncion: 'Vitrina Digital',
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Vitrina Digital'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Vitrina'),
            Tab(icon: Icon(Icons.restaurant_menu_rounded), text: 'Carta / Cocina'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ── Tab 1: Vitrina ─────────────────────────────────────
          _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
            const GuiaModuloBanner(modulo: 'vitrina'),
                // Toggle principal
                _buildCard(child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_activa ? AppColors.success : AppColors.textMuted)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront_rounded,
                        color: _activa ? AppColors.success : AppColors.textMuted, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Vitrina activa', style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                    Text(_activa ? 'Visible al público' : 'Oculta al público',
                        style: GoogleFonts.poppins(fontSize: 12,
                            color: _activa ? AppColors.success : AppColors.textMuted)),
                  ])),
                  Switch(
                    value: _activa,
                    onChanged: (v) => setState(() => _activa = v),
                    activeColor: AppColors.success,
                  ),
                ])),

                const SizedBox(height: 12),

                // Link de la vitrina
                if (_activa) ...[
                  _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Compartir', style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    const SizedBox(height: 12),

                    // ── Vitrina ──────────────────────────────────────
                    Row(children: [
                      Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Vitrina / Tienda', style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(_linkCompleto,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _copiarLink,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copiar'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(
                        onPressed: _compartirLink,
                        icon: const Icon(Icons.share_rounded, size: 15),
                        label: const Text('Compartir'),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      )),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => VitrinaQrScreen(
                            url: _linkCompleto, empresaNombre: _empresaNombre))),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.all(9)),
                        child: const Icon(Icons.qr_code_rounded, size: 20),
                      ),
                    ]),

                    const Divider(height: 20),

                    // ── Carta Digital ────────────────────────────────
                    Row(children: [
                      const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text('Carta Digital', style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                    ]),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Text(_linkCarta,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: _copiarLinkCarta,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copiar'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFFCD34D)),
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(
                        onPressed: _compartirLinkCarta,
                        icon: const Icon(Icons.share_rounded, size: 15),
                        label: const Text('Compartir'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8)),
                      )),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => VitrinaQrScreen(
                            url: _linkCarta, empresaNombre: '$_empresaNombre — Carta'))),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFFCD34D)),
                            padding: const EdgeInsets.all(9)),
                        child: const Icon(Icons.qr_code_rounded, size: 20),
                      ),
                    ]),
                  ])),
                  const SizedBox(height: 12),
                ],

                // Slug personalizado
                _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Link personalizado', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _slugCtrl,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      prefixText: 'negociopro.vercel.app/t/',
                      prefixStyle: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textMuted),
                      hintText: 'mi-colmado',
                      helperText: 'Solo letras, números y guiones',
                    ),
                  ),
                ])),

                const SizedBox(height: 12),

                // Delivery
                _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Delivery disponible', style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                    Switch(
                      value: _deliveryDisponible,
                      onChanged: (v) => setState(() => _deliveryDisponible = v),
                      activeColor: AppColors.primary,
                    ),
                  ]),
                  if (_deliveryDisponible) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _precioDeliveryCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Precio del delivery',
                        prefixText: 'RD\$ ',
                        prefixIcon: Icon(Icons.delivery_dining_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _zonaCtrl,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Zona de cobertura',
                        hintText: 'Ej: Solo sector Los Mina',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                  ],
                ])),

                const SizedBox(height: 12),

                // Info adicional
                _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Información para tus clientes', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _horarioCtrl,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Horario',
                      hintText: 'Ej: Lun-Sáb 8am-8pm',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mensajeCtrl,
                    style: GoogleFonts.poppins(fontSize: 14),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mensaje de bienvenida',
                      hintText: 'Ej: ¡Bienvenido! Hacemos delivery gratis los sábados.',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                  ),
                ])),

                const SizedBox(height: 12),

                // Color del tema
                _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Color del tema', style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text('Elige el color principal de tu vitrina',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _colorChip('#ec4899', 'Rosado'),
                    _colorChip('#f43f5e', 'Rojo rosa'),
                    _colorChip('#6366f1', 'Morado'),
                    _colorChip('#3b82f6', 'Azul'),
                    _colorChip('#0F7B5B', 'Verde'),
                    _colorChip('#f97316', 'Naranja'),
                    _colorChip('#eab308', 'Amarillo'),
                    _colorChip('#8b5cf6', 'Violeta'),
                    _colorChip('#ef4444', 'Rojo'),
                    _colorChip('#1f2937', 'Negro'),
                  ]),
                ])),

                const SizedBox(height: 12),

                // Productos en vitrina
                _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Productos en vitrina', style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    Text('${_productos.where((p) => p['en_vitrina'] == true).length}/${_productos.length}',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Toca un producto para configurar oferta y disponibilidad',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),

                  // Filtro por categoría
                  if (_categorias.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _CatChip(
                          label: 'Todas',
                          color: AppColors.primary,
                          selected: _categoriaFiltro == null,
                          onTap: () => setState(() => _categoriaFiltro = null),
                        ),
                        ..._categorias.map((cat) {
                          final catColor = Color(int.parse(
                              '0xFF${cat.color.replaceFirst('#', '')}'));
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _CatChip(
                              label: cat.nombre,
                              color: catColor,
                              selected: _categoriaFiltro == cat.id,
                              onTap: () => setState(() =>
                                  _categoriaFiltro = _categoriaFiltro == cat.id ? null : cat.id),
                            ),
                          );
                        }),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 10),
                  ...(_categoriaFiltro == null
                      ? _productos
                      : _productos.where((p) => p['categoria_id'] == _categoriaFiltro).toList()
                  ).map((p) => _ProductoVitrinaRow(
                    producto: p,
                    onChanged: (v) => setState(() => p['en_vitrina'] = v),
                    onChangedResenas: (v) => setState(() => p['permitir_resenas'] = v),
                    onChangedCarta: (v) => setState(() => p['carta_disponible'] = v),
                    onTap: () => _abrirConfigProducto(p),
                  )),
                ])),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _guardar,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Guardar vitrina', style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón sincronizar fotos
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _sincronizando ? null : _sincronizarFotos,
                    icon: _sincronizando
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2,
                                color: AppColors.primary))
                        : const Icon(Icons.cloud_upload_rounded,
                            color: AppColors.primary),
                    label: _sincronizando
                        ? Text(
                            _fotosTotal > 0
                                ? 'Subiendo fotos (\$_fotosSincronizadas/\$_fotosTotal)...'
                                : 'Revisando fotos...',
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: AppColors.primary))
                        : Text('Sincronizar fotos con vitrina',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sube las fotos de tus productos al servidor para que aparezcan en la vitrina.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Botón ver reseñas
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const VitrinaResenasScreen())),
                    icon: const Icon(Icons.star_rounded,
                        color: Color(0xFFf59e0b)),
                    label: Text('Ver reseñas de clientes',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFf59e0b)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          // ── Tab 2: Carta / Cocina ──────────────────────────────
          const CartaDigitalScreen(),
        ],
      ),
    ));
  }

  void _abrirConfigProducto(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VitrinaProductoConfigSheet(
        producto: p,
        onSave: (updated) {
          final idx = _productos.indexWhere((x) => x['id'] == updated['id']);
          if (idx != -1) setState(() => _productos[idx] = updated);
        },
      ),
    );
  }

  Widget _colorChip(String hex, String label) {
    final color = Color(int.parse('0xFF${hex.substring(1)}'));
    final selected = _colorTema == hex;
    return GestureDetector(
      onTap: () => setState(() => _colorTema = hex),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.black : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)] : [],
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _buildCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: child,
  );
}

class _ProductoVitrinaRow extends StatelessWidget {
  final Map<String, dynamic> producto;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool> onChangedResenas;
  final ValueChanged<bool> onChangedCarta;
  final VoidCallback onTap;

  const _ProductoVitrinaRow({
    required this.producto,
    required this.onChanged,
    required this.onChangedResenas,
    required this.onChangedCarta,
    required this.onTap,
  });

  static const _dispLabels = {
    'stock':  null,
    'hoy':    'Disponible hoy',
    'manana': 'Disponible mañana',
    'pronto': 'Disponible pronto',
    'fecha':  null,
  };
  static const _dispColors = {
    'hoy':    Color(0xFF3b82f6),
    'manana': Color(0xFFf97316),
    'pronto': Color(0xFF8b5cf6),
    'fecha':  Color(0xFFec4899),
  };

  @override
  Widget build(BuildContext context) {
    final nombre          = producto['nombre'] as String? ?? '';
    final precio          = (producto['precio_venta'] as num?)?.toDouble() ?? 0;
    final stock           = (producto['stock_actual'] as num?)?.toDouble() ?? 0;
    final visible         = producto['en_vitrina'] as bool? ?? true;
    final permitirResenas = producto['permitir_resenas'] as bool? ?? false;
    final enCarta         = producto['carta_disponible'] as bool? ?? false;
    final enOferta  = producto['precio_oferta'] != null;
    final pct       = (producto['descuento_porcentaje'] as num?)?.toDouble();
    final disp      = producto['disponibilidad'] as String? ?? 'stock';
    final fechaStr  = producto['fecha_disponibilidad'] as String?;

    String dispLabel = '';
    Color? dispColor;
    if (disp != 'stock') {
      dispColor = _dispColors[disp];
      if (disp == 'fecha' && fechaStr != null) {
        final d = DateTime.tryParse(fechaStr);
        dispLabel = d != null
            ? 'Disponible el ${d.day}/${d.month}'
            : 'Fecha específica';
      } else {
        dispLabel = _dispLabels[disp] ?? '';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: visible ? AppColors.background : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: visible ? AppColors.textPrimary : AppColors.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              if (enOferta && pct != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('-${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: 5),
              ],
              Text('RD\$${precio.toStringAsFixed(0)} · ${stock.toStringAsFixed(0)} uds',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
              if (dispLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (dispColor ?? AppColors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(dispLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: dispColor ?? AppColors.primary)),
                ),
              ],
            ]),
          ])),
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _IconToggleBtn(
              icon: visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              active: visible,
              activeColor: AppColors.primary,
              tooltip: visible ? 'Visible' : 'Oculto',
              onTap: () => onChanged(!visible),
            ),
            const SizedBox(width: 6),
            _IconToggleBtn(
              icon: Icons.star_rounded,
              active: permitirResenas,
              activeColor: const Color(0xFFf59e0b),
              tooltip: permitirResenas ? 'Reseñas on' : 'Sin reseñas',
              onTap: () => onChangedResenas(!permitirResenas),
            ),
            const SizedBox(width: 6),
            _IconToggleBtn(
              icon: Icons.restaurant_menu_rounded,
              active: enCarta,
              activeColor: const Color(0xFFFF6B35),
              tooltip: enCarta ? 'En Carta' : 'Fuera de Carta',
              onTap: () => onChangedCarta(!enCarta),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _IconToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;

  const _IconToggleBtn({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.12)
                : AppColors.textMuted.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.35)
                  : AppColors.cardBorder,
              width: 1,
            ),
          ),
          child: Icon(icon, size: 16,
              color: active ? activeColor : AppColors.textMuted),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.cardBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }
}
