import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';

class VitrinaResenasScreen extends StatefulWidget {
  const VitrinaResenasScreen({super.key});

  @override
  State<VitrinaResenasScreen> createState() => _VitrinaResenasScreenState();
}

class _VitrinaResenasScreenState extends State<VitrinaResenasScreen> {
  bool _loading = true;
  // Reseñas agrupadas: null = negocio general, productoId = producto específico
  Map<String?, List<Map<String, dynamic>>> _grupos = {};
  Map<String, String> _nombresProductos = {};

  List<Map<String, dynamic>> get _todas =>
      _grupos.values.expand((l) => l).toList()
        ..sort((a, b) => (b['created_at'] as String)
            .compareTo(a['created_at'] as String));

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final empresaId = await SupabaseService.getEmpresaId();
      if (empresaId == null) return;

      final res = await SupabaseService.client
          .from('vitrina_resenas')
          .select('*')
          .eq('empresa_id', empresaId)
          .order('created_at', ascending: false);

      // Cargar nombres de productos referenciados
      final ids = (res as List)
          .map((r) => r['producto_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> nombres = {};
      if (ids.isNotEmpty) {
        final prods = await SupabaseService.client
            .from('productos')
            .select('id, nombre')
            .inFilter('id', ids);
        for (final p in prods) {
          nombres[p['id'] as String] = p['nombre'] as String;
        }
      }

      // Agrupar por producto_id (null = negocio general)
      final grupos = <String?, List<Map<String, dynamic>>>{};
      for (final r in res) {
        final pid = r['producto_id'] as String?;
        grupos.putIfAbsent(pid, () => []).add(Map<String, dynamic>.from(r));
      }

      if (mounted) {
        setState(() {
          _grupos = grupos;
          _nombresProductos = nombres;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _responder(Map<String, dynamic> resena) async {
    final ctrl = TextEditingController(text: resena['respuesta'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Responder reseña',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _Stars(estrellas: resena['estrellas'] as int),
                const SizedBox(width: 8),
                Text(resena['nombre'] as String? ?? 'Anónimo',
                    style: GoogleFonts.poppins(fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
              if (resena['comentario'] != null) ...[
                const SizedBox(height: 4),
                Text(resena['comentario'] as String,
                    style: GoogleFonts.poppins(fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Escribe tu respuesta...',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: AppColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Publicar',
                style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await SupabaseService.client
          .from('vitrina_resenas')
          .update({
            'respuesta': ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
            'respondido_en': ctrl.text.trim().isEmpty
                ? null
                : DateTime.now().toIso8601String(),
          })
          .eq('id', resena['id'] as String);
      _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar reseña?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Esta acción no se puede deshacer.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: AppColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client
          .from('vitrina_resenas')
          .delete()
          .eq('id', id);
      _cargar();
    } catch (_) {}
  }

  double _promedioGrupo(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) return 0;
    return lista.fold(0.0, (s, r) => s + (r['estrellas'] as int)) / lista.length;
  }

  @override
  Widget build(BuildContext context) {
    final todas = _todas;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reseñas de clientes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : todas.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Resumen global
                      _buildResumenGlobal(todas),
                      const SizedBox(height: 20),

                      // Sección: Negocio en general
                      if (_grupos.containsKey(null)) ...[
                        _buildSeccionHeader(
                          icono: Icons.store_rounded,
                          titulo: 'Negocio en general',
                          cantidad: _grupos[null]!.length,
                          promedio: _promedioGrupo(_grupos[null]!),
                        ),
                        const SizedBox(height: 8),
                        ..._grupos[null]!.map((r) => _ResenaCard(
                              resena: r,
                              onResponder: () => _responder(r),
                              onEliminar: () => _eliminar(r['id'] as String),
                            )),
                        const SizedBox(height: 16),
                      ],

                      // Secciones por producto
                      ..._grupos.entries
                          .where((e) => e.key != null)
                          .map((entry) {
                        final pid = entry.key!;
                        final lista = entry.value;
                        final nombre = _nombresProductos[pid] ?? 'Producto';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSeccionHeader(
                              icono: Icons.inventory_2_rounded,
                              titulo: nombre,
                              cantidad: lista.length,
                              promedio: _promedioGrupo(lista),
                            ),
                            const SizedBox(height: 8),
                            ...lista.map((r) => _ResenaCard(
                                  resena: r,
                                  onResponder: () => _responder(r),
                                  onEliminar: () => _eliminar(r['id'] as String),
                                )),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildResumenGlobal(List<Map<String, dynamic>> todas) {
    final prom = _promedioGrupo(todas);
    final llenas = prom.round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Column(children: [
          Text(prom.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                  fontSize: 40, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Row(children: List.generate(5, (i) => Icon(
              i < llenas ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: i < llenas ? const Color(0xFFf59e0b) : AppColors.textMuted))),
          const SizedBox(height: 4),
          Text('${todas.length} reseñas en total',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textMuted)),
        ]),
        const SizedBox(width: 20),
        Expanded(child: Column(
          children: [5, 4, 3, 2, 1].map((n) {
            final cnt = todas.where((r) => r['estrellas'] == n).length;
            final pct = todas.isNotEmpty ? cnt / todas.length : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Text('$n', style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded,
                    size: 12, color: Color(0xFFf59e0b)),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceAlt,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFf59e0b)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$cnt', style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textMuted)),
              ]),
            );
          }).toList(),
        )),
      ]),
    );
  }

  Widget _buildSeccionHeader({
    required IconData icono,
    required String titulo,
    required int cantidad,
    required double promedio,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(icono, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Row(children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFf59e0b)),
          const SizedBox(width: 3),
          Text(promedio.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$cantidad',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.star_outline_rounded,
            size: 64, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text('Sin reseñas todavía',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Cuando los clientes dejen reseñas\naparecerán aquí organizadas',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppColors.textMuted)),
      ],
    ));
  }
}

class _ResenaCard extends StatelessWidget {
  final Map<String, dynamic> resena;
  final VoidCallback onResponder;
  final VoidCallback onEliminar;

  const _ResenaCard({
    required this.resena,
    required this.onResponder,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final estrellas = resena['estrellas'] as int;
    final nombre    = resena['nombre'] as String? ?? 'Anónimo';
    final comentario= resena['comentario'] as String?;
    final respuesta = resena['respuesta'] as String?;
    final fecha     = DateTime.tryParse(resena['created_at'] as String? ?? '');
    final fechaStr  = fecha != null
        ? '${fecha.day}/${fecha.month}/${fecha.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Stars(estrellas: estrellas),
          const Spacer(),
          Text(fechaStr,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 4),
        Text(nombre,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        if (comentario != null && comentario.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(comentario,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
        if (respuesta != null && respuesta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('💬 Tu respuesta',
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(respuesta,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          TextButton.icon(
            onPressed: onResponder,
            icon: Icon(
                respuesta != null && respuesta.isNotEmpty
                    ? Icons.edit_rounded
                    : Icons.reply_rounded,
                size: 14),
            label: Text(
                respuesta != null && respuesta.isNotEmpty
                    ? 'Editar respuesta'
                    : 'Responder',
                style: GoogleFonts.poppins(fontSize: 12)),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onEliminar,
            icon: const Icon(Icons.delete_outline_rounded, size: 14),
            label: Text('Eliminar',
                style: GoogleFonts.poppins(fontSize: 12)),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ]),
      ]),
    );
  }
}

class _Stars extends StatelessWidget {
  final int estrellas;
  const _Stars({required this.estrellas});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
          i < estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < estrellas
              ? const Color(0xFFf59e0b)
              : AppColors.textMuted)),
    );
  }
}
