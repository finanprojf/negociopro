import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import 'dart:io';
import '../../services/supabase_service.dart';
import '../../services/local_database.dart';
import '../../services/inventario_service.dart';
import '../../utils/constants.dart';

class VitrinaConfigScreen extends StatefulWidget {
  const VitrinaConfigScreen({super.key});

  @override
  State<VitrinaConfigScreen> createState() => _VitrinaConfigScreenState();
}

class _VitrinaConfigScreenState extends State<VitrinaConfigScreen> {
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

  // Productos en vitrina
  List<Map<String, dynamic>> _productos = [];

  final _slugCtrl = TextEditingController();
  final _precioDeliveryCtrl = TextEditingController();
  final _zonaCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();

  static const String _baseUrl = 'https://vitrina-web-beta.vercel.app/t/';

  String get _linkCompleto => '$_baseUrl${_slug.isNotEmpty ? _slug : _empresaId}';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _precioDeliveryCtrl.dispose();
    _zonaCtrl.dispose();
    _horarioCtrl.dispose();
    _mensajeCtrl.dispose();
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
      }

      // Cargar productos con estado vitrina
      final prods = await SupabaseService.client
          .from('productos')
          .select('id, nombre, precio_venta, stock_actual, foto_url, activo')
          .eq('empresa_id', empresaId)
          .eq('activo', true)
          .order('nombre');

      final vitrinaProds = await SupabaseService.client
          .from('vitrina_productos')
          .select('producto_id, visible')
          .eq('empresa_id', empresaId);

      final vitrinaMap = {
        for (final v in vitrinaProds) v['producto_id'] as String: v['visible'] as bool
      };

      _productos = (prods as List).map((p) => {
        ...Map<String, dynamic>.from(p),
        'en_vitrina': vitrinaMap[p['id']] ?? true,
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
              'empresa_id': _empresaId,
              'producto_id': p['id'],
              'visible': p['en_vitrina'],
            }, onConflict: 'empresa_id,producto_id');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Vitrina Digital'),
        actions: [
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                    Text('Tu link', style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(_linkCompleto,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.primary,
                                fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copiarLink,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _compartirLink,
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Compartir'),
                        ),
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
                  Text('Activa o desactiva qué productos se muestran',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  ..._productos.map((p) => _ProductoVitrinaRow(
                    nombre: p['nombre'] as String,
                    precio: (p['precio_venta'] as num).toDouble(),
                    stock: (p['stock_actual'] as num).toDouble(),
                    visible: p['en_vitrina'] as bool,
                    onChanged: (v) => setState(() => p['en_vitrina'] = v),
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
                const SizedBox(height: 40),
              ],
            ),
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
  final String nombre;
  final double precio;
  final double stock;
  final bool visible;
  final ValueChanged<bool> onChanged;

  const _ProductoVitrinaRow({
    required this.nombre, required this.precio, required this.stock,
    required this.visible, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('RD\$${precio.toStringAsFixed(0)} · Stock: ${stock.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
        ])),
        Switch(
          value: visible,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}
